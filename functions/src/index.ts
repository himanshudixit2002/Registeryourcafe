import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import Razorpay from "razorpay";

admin.initializeApp();
const db = admin.firestore();

const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || "";
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || "";
const RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET || "";

function requireRazorpayConfig(): void {
  if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
    throw new HttpsError(
      "failed-precondition",
      "Razorpay is not configured. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET on the Cloud Function.",
    );
  }
}

async function publicDiscoveryEnabled(companyId: string): Promise<boolean> {
  const snap = await db.collection("publicVenues").doc(companyId).get();
  return snap.exists && snap.data()?.showOnDiscovery === true;
}

interface RawCartLine {
  publicMenuItemId?: string;
  quantity?: unknown;
}

interface PricedLine {
  itemId: string;
  name: string;
  price: number;
  quantity: number;
  imageUrl?: string;
}

async function priceLines(
  companyId: string,
  lines: RawCartLine[],
): Promise<{ priced: PricedLine[]; totalRupees: number }> {
  if (!lines.length || lines.length > 40) {
    throw new HttpsError("invalid-argument", "Invalid cart (max 40 lines).");
  }
  const priced: PricedLine[] = [];
  let totalRupees = 0;
  for (const line of lines) {
    const id = (line.publicMenuItemId || "").trim();
    const qty = Math.floor(Number(line.quantity));
    if (!id || qty < 1 || qty > 99) {
      throw new HttpsError("invalid-argument", "Invalid line item.");
    }
    const ref = db
      .collection("companies")
      .doc(companyId)
      .collection("public_menu_items")
      .doc(id);
    const doc = await ref.get();
    if (!doc.exists) {
      throw new HttpsError("not-found", `Menu item not found: ${id}`);
    }
    const d = doc.data() || {};
    if (d.isAvailable === false) {
      throw new HttpsError("failed-precondition", `Item unavailable: ${id}`);
    }
    const name =
      typeof d.name === "string" && d.name.trim()
        ? d.name.trim()
        : "Item";
    let price = 0;
    const pr = d.price;
    if (typeof pr === "number") price = pr;
    else if (pr != null) price = parseFloat(String(pr)) || 0;
    if (price < 0) price = 0;
    const imageUrl =
      typeof d.imageUrl === "string" && d.imageUrl.trim()
        ? d.imageUrl.trim()
        : undefined;
    priced.push({
      itemId: id,
      name,
      price,
      quantity: qty,
      imageUrl,
    });
    totalRupees += price * qty;
  }
  if (totalRupees <= 0) {
    throw new HttpsError(
      "invalid-argument",
      "Order total must be greater than zero.",
    );
  }
  totalRupees = Math.round(totalRupees * 100) / 100;
  return { priced, totalRupees };
}

/**
 * Callable: create Razorpay order + guest_checkouts doc (server-priced).
 */
export const createGuestMenuCheckout = onCall(
  {
    region: process.env.FUNCTIONS_REGION || "asia-south1",
    cors: true,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in to place an order.");
    }
    requireRazorpayConfig();
    const data = request.data as {
      companyId?: string;
      mode?: string;
      tableId?: string;
      tableName?: string;
      lines?: unknown;
      guestName?: string;
      notes?: string;
      venueDisplayName?: string;
    };
    const companyId = (data.companyId || "").trim();
    if (!companyId) {
      throw new HttpsError("invalid-argument", "companyId is required.");
    }
    const mode = data.mode === "table" ? "table" : "counter";
    let tableId: string | undefined;
    let tableName: string | undefined;
    if (mode === "table") {
      tableId = (data.tableId || "").trim() || undefined;
      tableName = (data.tableName || "").trim() || undefined;
      if (!tableId || !tableName) {
        throw new HttpsError(
          "invalid-argument",
          "Select a table for dine-in orders.",
        );
      }
    }
    if (!(await publicDiscoveryEnabled(companyId))) {
      throw new HttpsError(
        "permission-denied",
        "Public ordering is not available.",
      );
    }
    const lines = Array.isArray(data.lines) ? (data.lines as RawCartLine[]) : [];
    const { priced, totalRupees } = await priceLines(companyId, lines);
    const amountPaise = Math.max(100, Math.round(totalRupees * 100));
    const checkoutRef = db
      .collection("companies")
      .doc(companyId)
      .collection("guest_checkouts")
      .doc();
    const checkoutId = checkoutRef.id;
    const rzp = new Razorpay({
      key_id: RAZORPAY_KEY_ID,
      key_secret: RAZORPAY_KEY_SECRET,
    });
    let razorpayOrderId: string;
    try {
      const order = await rzp.orders.create({
        amount: amountPaise,
        currency: "INR",
        receipt: checkoutId.slice(0, 40),
        notes: {
          companyId: String(companyId),
          checkoutId: String(checkoutId),
          uid: String(request.auth.uid),
        },
      });
      razorpayOrderId = order.id;
    } catch (e) {
      logger.error("Razorpay order create failed", e);
      throw new HttpsError(
        "internal",
        "Could not start payment. Try again.",
      );
    }
    const guestName = (data.guestName || "").trim();
    const notes = (data.notes || "").trim();
    await checkoutRef.set({
      requesterUid: request.auth.uid,
      status: "pending_payment",
      companyId,
      mode,
      tableId: tableId || null,
      tableName: tableName || null,
      guestName: guestName || null,
      notes: notes || null,
      lines: priced,
      totalRupees,
      amountPaise,
      currency: "INR",
      razorpayOrderId,
      venueDisplayName: (data.venueDisplayName || "").trim() || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      checkoutId,
      razorpayOrderId,
      keyId: RAZORPAY_KEY_ID,
      amountPaise,
      currency: "INR",
      totalRupees,
      prefillName: guestName || null,
    };
  },
);

function verifyWebhookSignature(
  rawBody: string,
  signature: string | undefined,
): boolean {
  if (!RAZORPAY_WEBHOOK_SECRET || !signature) return false;
  const expected = crypto
    .createHmac("sha256", RAZORPAY_WEBHOOK_SECRET)
    .update(rawBody)
    .digest("hex");
  try {
    return crypto.timingSafeEqual(
      Buffer.from(expected),
      Buffer.from(signature),
    );
  } catch {
    return false;
  }
}

async function fulfillCheckoutFromPayment(
  companyId: string,
  checkoutId: string,
  razorpayPaymentId: string,
  razorpayOrderId: string,
): Promise<void> {
  const checkoutRef = db
    .collection("companies")
    .doc(companyId)
    .collection("guest_checkouts")
    .doc(checkoutId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(checkoutRef);
    if (!snap.exists) {
      logger.warn("guest_checkout missing", { companyId, checkoutId });
      return;
    }
    const c = snap.data() || {};
    if (c.status === "paid") {
      return;
    }
    if (c.razorpayOrderId !== razorpayOrderId) {
      logger.warn("razorpay order mismatch", { checkoutId, razorpayOrderId });
      return;
    }
    const priced = (c.lines || []) as PricedLine[];
    const totalRupees = Number(c.totalRupees) || 0;
    const mode = c.mode === "table" ? "table" : "counter";
    const tableId = c.tableId;
    const tableName = c.tableName;
    const guestName = c.guestName;
    const notes = c.notes;
    const requesterUid = c.requesterUid;
    const counterRef = db
      .collection("companies")
      .doc(companyId)
      .collection("order_counters")
      .doc("C");
    const counterSnap = await tx.get(counterRef);
    let last = 0;
    if (counterSnap.exists) {
      const v = counterSnap.data()?.last;
      last =
        typeof v === "number" ? v : parseInt(String(v || "0"), 10) || 0;
    }
    const next = last + 1;
    const orderId = `C-${String(next).padStart(6, "0")}`;
    tx.set(counterRef, { last: next }, { merge: true });
    const orderRef = db
      .collection("companies")
      .doc(companyId)
      .collection("cafe_orders")
      .doc(orderId);
    const items = priced.map((p) => ({
      itemId: p.itemId,
      name: p.name,
      price: p.price,
      quantity: p.quantity,
      notes: null,
      imageUrl: p.imageUrl || null,
    }));
    tx.set(orderRef, {
      items,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      total: totalRupees,
      paymentBreakdown: { UPI: totalRupees },
      customerId: null,
      customerName: guestName || null,
      tableId: mode === "table" ? tableId || null : null,
      tableName: mode === "table" ? tableName || null : null,
      sessionId: null,
      isBilled: true,
      billedAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: "upi",
      notes: notes || null,
      source: "public_menu",
      requesterUid: requesterUid || null,
      razorpayPaymentId,
      razorpayOrderId,
      publicGuestCheckoutId: checkoutId,
      performedById: null,
      performedByName: "Guest (online)",
      performedByRole: null,
    });
    for (const line of priced) {
      const stockRef = db
        .collection("companies")
        .doc(companyId)
        .collection("stock_items")
        .doc(line.itemId);
      const stockSnap = await tx.get(stockRef);
      if (!stockSnap.exists) continue;
      const data = stockSnap.data() || {};
      const current = Number(data.quantity) || 0;
      const need = line.quantity;
      if (current < need) {
        logger.warn("Insufficient stock in webhook txn", {
          itemId: line.itemId,
          current,
          need,
        });
        continue;
      }
      tx.update(stockRef, {
        quantity: current - need,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    tx.update(checkoutRef, {
      status: "paid",
      cafeOrderId: orderId,
      razorpayPaymentId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

/**
 * Razorpay webhooks — configure in Razorpay Dashboard with the same secret as RAZORPAY_WEBHOOK_SECRET.
 */
export const razorpayWebhook = onRequest(
  {
    region: process.env.FUNCTIONS_REGION || "asia-south1",
    cors: false,
    invoker: "public",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }
    const rawBody =
      req.rawBody != null
        ? req.rawBody.toString("utf8")
        : JSON.stringify(req.body);
    const signature = req.get("x-razorpay-signature");
    if (!verifyWebhookSignature(rawBody, signature)) {
      logger.warn("Invalid Razorpay webhook signature");
      res.status(400).send("Invalid signature");
      return;
    }
    let body: Record<string, unknown>;
    try {
      body = JSON.parse(rawBody) as Record<string, unknown>;
    } catch {
      res.status(400).send("Invalid JSON");
      return;
    }
    const event = (body.event as string) || "";
    if (event !== "payment.captured" && event !== "order.paid") {
      res.status(200).send("ignored");
      return;
    }
    try {
      if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
        logger.error("Razorpay keys missing for webhook fetch");
        res.status(500).send("config");
        return;
      }
      const payload = body.payload as Record<string, unknown> | undefined;
      const payment = payload?.payment as Record<string, unknown> | undefined;
      const entity = payment?.entity as Record<string, unknown> | undefined;
      const paymentEntity = entity;
      if (!paymentEntity) {
        res.status(200).send("no entity");
        return;
      }
      const orderId = paymentEntity.order_id as string | undefined;
      const paymentId = paymentEntity.id as string | undefined;
      if (!orderId || !paymentId) {
        res.status(200).send("no order");
        return;
      }
      const rzp = new Razorpay({
        key_id: RAZORPAY_KEY_ID,
        key_secret: RAZORPAY_KEY_SECRET,
      });
      const rzOrder = await rzp.orders.fetch(orderId);
      const notes = rzOrder.notes || {};
      const companyId = (String(notes.companyId || "")).trim();
      const checkoutId = (String(notes.checkoutId || "")).trim();
      if (!companyId || !checkoutId) {
        logger.warn("Razorpay order missing notes", { orderId });
        res.status(200).send("no notes");
        return;
      }
      await fulfillCheckoutFromPayment(
        companyId,
        checkoutId,
        paymentId,
        orderId,
      );
      res.status(200).send("ok");
    } catch (e) {
      logger.error("Webhook fulfill failed", e);
      res.status(500).send("error");
    }
  },
);

import 'package:flutter/services.dart';
import 'package:registeryourcafe/branding/app_assets.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../utils/app_logger.dart';
import '../utils/firestore_utils.dart';

enum PrintJobType { kotOnly, billOnly, billWithKot }

class PrinterService {
  static Uint8List? _regularFontData;
  static Uint8List? _boldFontData;
  static pw.ImageProvider? _logoImage;

  /// Initializes and pre-caches all assets required for printing.
  /// Should be called once at app startup.
  static Future<void> initialize() async {
    await _initializeAssets();
  }

  static Future<void> _initializeAssets() async {
    if (_regularFontData != null && _logoImage != null) return;
    try {
      final fontUrls = [
        'https://fonts.gstatic.com/s/notosans/v27/o-0IIpQlx3QUlC5A4PNb4g.ttf',
        'https://fonts.gstatic.com/s/notosans/v27/o-0NIpQlx3QUlC5A4PNjXhFlYw.ttf',
      ];
      final fontResponses = await Future.wait(
        fontUrls.map((url) => http.get(Uri.parse(url))),
      );
      _regularFontData = fontResponses[0].statusCode == 200
          ? fontResponses[0].bodyBytes
          : null;
      _boldFontData = fontResponses[1].statusCode == 200
          ? fontResponses[1].bodyBytes
          : null;

      final imageData = await rootBundle.load(AppAssets.printerArt);
      final decodedImage = img.decodeImage(imageData.buffer.asUint8List());
      if (decodedImage != null) {
        final resized = img.copyResize(decodedImage, width: 96);
        _logoImage = pw.MemoryImage(img.encodePng(resized));
      }
    } catch (e) {
      AppLogger.warning(
        'Error initializing printer assets: $e',
        tag: 'PrinterService',
      );
    }
  }

  /// Clears cached font and image assets to ensure fresh layout on next print.
  static void clearCache() {
    _regularFontData = null;
    _boldFontData = null;
    _logoImage = null;
  }

  static const double _cutBufferMm = 12.0;
  static const double _paperWidthMm = 72.0;

  // ---------------------------------------------------------------------------
  // Height estimators — keep in sync with the section builders below.
  // [includeCutBuffer] should be false when a section is part of a combined
  // page that only needs one buffer at the very end.
  // ---------------------------------------------------------------------------

  static double _estimateKotHeightMm({
    required int itemCount,
    required bool hasTable,
    required bool hasCustomer,
    bool includeCutBuffer = true,
  }) {
    double h = 0;
    h += 8; // header block (bordered box + K.O.T text + padding)
    h += 2; // spacing after header
    h += 3.5; // Order row
    if (hasTable) h += 3.5;
    if (hasCustomer) h += 3.5;
    h += 3.5; // Time row
    h += 3; // divider
    h += 3.5; // table header
    h += itemCount * 3.2; // item rows
    h += 3; // divider
    h += 5; // TOTAL row
    if (includeCutBuffer) h += _cutBufferMm;
    return h;
  }

  static double _estimateBillHeightMm({
    required int itemCount,
    required bool hasTable,
    required bool hasCustomer,
    required bool isPTL,
    required bool hasLoser,
    required int discountCount,
    required bool hasCredits,
    bool includeCutBuffer = true,
  }) {
    double h = 0;
    if (_logoImage != null) h += 10;
    h += 7; // brand name + subtitle
    h += 3; // spacing
    h += 3.5; // Bill ID
    if (hasTable) h += 3.5;
    if (isPTL) h += 3.5;
    if (hasLoser) h += 3.5;
    if (hasCustomer) h += 3.5;
    h += 3.5; // Date
    h += 4; // thick divider
    h += 3.5; // table header
    h += itemCount * 3.2; // item rows
    h += 4; // thick divider
    h += 4; // subtotal
    if (discountCount > 0) {
      h += 2; // divider
      h += discountCount * 4;
      h += 2; // divider
      h += 4; // total after discounts
    }
    if (hasCredits) h += 4;
    h += 3; // spacing
    h += 10; // AMOUNT PAID box
    h += 4; // spacing
    h += 6; // thank you + tagline
    if (includeCutBuffer) h += _cutBufferMm;
    return h;
  }

  // ---------------------------------------------------------------------------
  // Print entry point
  // ---------------------------------------------------------------------------

  static Future<void> printDocument({
    required PrintJobType jobType,
    required String id,
    required List<Map<String, dynamic>> items,
    double? total,
    String? customerName,
    String? tableName,
    double? subtotal,
    Map<String, dynamic>? discounts,
    double? creditsUsed,
    bool isPTL = false,
    int? playerCount,
    int? loserPlayerIndex,
    String? loserPlayerName,
    String? jobName,
  }) async {
    await _initializeAssets();
    final regular = _getFont(_regularFontData, 'regular');
    final bold = _getFont(_boldFontData, 'bold');
    final doc = pw.Document();
    final double pageWidth = _paperWidthMm * PdfPageFormat.mm;

    void addSizedPage(pw.Widget content, double heightMm) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            pageWidth,
            heightMm * PdfPageFormat.mm,
            marginLeft: 3,
            marginRight: 3,
            marginTop: 0,
            marginBottom: 0,
          ),
          orientation: pw.PageOrientation.portrait,
          build: (_) => content,
        ),
      );
    }

    double maxPageHeightMm = 0;

    switch (jobType) {
      case PrintJobType.kotOnly:
        final heightMm = _estimateKotHeightMm(
          itemCount: items.length,
          hasTable: tableName != null,
          hasCustomer: customerName != null,
        );
        maxPageHeightMm = heightMm;
        addSizedPage(
          _buildKotSection(
            orderId: id,
            items: items,
            customerName: customerName,
            tableName: tableName,
            regular: regular,
            bold: bold,
          ),
          heightMm,
        );
        break;

      case PrintJobType.billOnly:
        final heightMm = _estimateBillHeightMm(
          itemCount: items.length,
          hasTable: tableName != null,
          hasCustomer: customerName != null,
          isPTL: isPTL,
          hasLoser: loserPlayerName != null || loserPlayerIndex != null,
          discountCount: discounts?.length ?? 0,
          hasCredits: creditsUsed != null && creditsUsed > 0,
        );
        maxPageHeightMm = heightMm;
        addSizedPage(
          _buildBillSection(
            billId: id,
            items: items,
            total: total ?? 0.0,
            customerName: customerName,
            tableName: tableName,
            subtotal: subtotal,
            discounts: discounts,
            creditsUsed: creditsUsed,
            isPTL: isPTL,
            playerCount: playerCount,
            loserPlayerIndex: loserPlayerIndex,
            loserPlayerName: loserPlayerName,
            regular: regular,
            bold: bold,
          ),
          heightMm,
        );
        break;

      case PrintJobType.billWithKot:
        // No cut buffer on KOT; only one at the very end of the combined page.
        final kotHeightMm = _estimateKotHeightMm(
          itemCount: items.length,
          hasTable: tableName != null,
          hasCustomer: customerName != null,
          includeCutBuffer: false,
        );
        final billHeightMm = _estimateBillHeightMm(
          itemCount: items.length,
          hasTable: tableName != null,
          hasCustomer: customerName != null,
          isPTL: isPTL,
          hasLoser: loserPlayerName != null || loserPlayerIndex != null,
          discountCount: discounts?.length ?? 0,
          hasCredits: creditsUsed != null && creditsUsed > 0,
          includeCutBuffer: true,
        );
        final combinedHeightMm = kotHeightMm + 6 + billHeightMm;
        maxPageHeightMm = combinedHeightMm;

        addSizedPage(
          pw.Column(
            children: [
              _buildKotSection(
                orderId: id,
                items: items,
                customerName: customerName,
                tableName: tableName,
                regular: regular,
                bold: bold,
              ),
              pw.SizedBox(height: 2),
              _buildCutLine(regular),
              pw.SizedBox(height: 2),
              _buildBillSection(
                billId: id,
                items: items,
                total: total ?? 0.0,
                customerName: customerName,
                tableName: tableName,
                subtotal: subtotal,
                discounts: discounts,
                creditsUsed: creditsUsed,
                isPTL: isPTL,
                playerCount: playerCount,
                loserPlayerIndex: loserPlayerIndex,
                loserPlayerName: loserPlayerName,
                regular: regular,
                bold: bold,
              ),
            ],
          ),
          combinedHeightMm,
        );
        break;
    }

    final bytes = await doc.save();
    final String uniqueName =
        jobName ??
        'CNC-${jobType.name}-$id-${DateTime.now().millisecondsSinceEpoch}';

    final hintFormat = PdfPageFormat(
      pageWidth,
      maxPageHeightMm * PdfPageFormat.mm,
      marginAll: 0,
    );

    try {
      final printers = await Printing.listPrinters();
      if (printers.isNotEmpty) {
        final printer = printers.firstWhere(
          (p) => p.isDefault,
          orElse: () => printers.first,
        );
        await Printing.directPrintPdf(
          printer: printer,
          name: uniqueName,
          format: hintFormat,
          onLayout: (_) async => bytes,
        );
        return;
      }
    } catch (e, st) {
      AppLogger.debug(
        'directPrintPdf unavailable, using layoutPdf: $e\n$st',
        tag: 'Printer',
      );
    }
    await Printing.layoutPdf(
      name: uniqueName,
      format: hintFormat,
      onLayout: (_) async => bytes,
    );
  }

  // ---------------------------------------------------------------------------
  // Cut-line separator for combined KOT + Bill
  // ---------------------------------------------------------------------------

  static pw.Widget _buildCutLine(pw.Font font) {
    return pw.Divider(
      thickness: 0.4,
      color: PdfColors.grey500,
      borderStyle: pw.BorderStyle.dashed,
    );
  }

  // ---------------------------------------------------------------------------
  // K.O.T  Section
  // ---------------------------------------------------------------------------

  static pw.Widget _buildKotSection({
    required String orderId,
    required List<Map<String, dynamic>> items,
    String? customerName,
    String? tableName,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final double kotTotal = items.fold(
      0.0,
      (sum, item) =>
          sum +
          parseFirestoreDouble(item['price']) *
              parseFirestoreInt(item['quantity'], fallback: 1),
    );

    return pw.Column(
      children: [
        // ---- Header ----
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(width: 1.5),
              bottom: pw.BorderSide(width: 1.5),
            ),
          ),
          child: pw.Center(
            child: pw.Text(
              'K.O.T',
              style: pw.TextStyle(font: bold, fontSize: 14, letterSpacing: 3),
            ),
          ),
        ),
        pw.SizedBox(height: 3),

        // ---- Info rows ----
        _buildInfoRow('Order:', orderId, regular, bold, size: 8.5),
        if (tableName != null)
          _buildInfoRow('Table:', tableName, regular, bold, size: 8.5),
        if (customerName != null)
          _buildInfoRow('Cust:', customerName, regular, bold, size: 8.5),
        _buildInfoRow('Time:', now, regular, bold, size: 8.5),

        // ---- Items ----
        pw.Divider(height: 6, thickness: 0.8),
        _buildItemsTable(items, true, regular, bold),
        pw.Divider(height: 6, thickness: 0.8),

        // ---- Total ----
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(font: bold, fontSize: 11),
                ),
              ),
              pw.Text(
                _fmtRupee(kotTotal),
                style: pw.TextStyle(font: bold, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bill Section
  // ---------------------------------------------------------------------------

  static pw.Widget _buildBillSection({
    required String billId,
    required List<Map<String, dynamic>> items,
    required double total,
    String? customerName,
    String? tableName,
    double? subtotal,
    Map<String, dynamic>? discounts,
    double? creditsUsed,
    bool isPTL = false,
    int? playerCount,
    int? loserPlayerIndex,
    String? loserPlayerName,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // ---- Brand header ----
        if (_logoImage != null) ...[
          pw.Center(
            child: pw.Container(
              height: 24,
              width: 24,
              child: pw.Image(_logoImage!),
            ),
          ),
          pw.SizedBox(height: 1),
        ],
        pw.Center(
          child: pw.Text(
            'Registeryourcafe',
            style: pw.TextStyle(font: bold, fontSize: 13, letterSpacing: 1),
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 1.5,
            ),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            child: pw.Text(
              'FINAL BILL',
              style: pw.TextStyle(font: bold, fontSize: 8, letterSpacing: 2),
            ),
          ),
        ),
        pw.SizedBox(height: 4),

        // ---- Bill details ----
        _buildInfoRow('Bill ID:', billId, regular, bold, size: 8.5),
        if (tableName != null)
          _buildInfoRow('Table:', tableName, regular, bold, size: 8.5),
        if (isPTL)
          _buildInfoRow(
            'Mode:',
            'LTP (${playerCount ?? '-'})',
            regular,
            bold,
            size: 8.5,
          ),
        if (isPTL && loserPlayerName != null)
          _buildInfoRow('Loser:', loserPlayerName, regular, bold, size: 8.5),
        if (isPTL && loserPlayerName == null && loserPlayerIndex != null)
          _buildInfoRow(
            'Loser:',
            'Player $loserPlayerIndex',
            regular,
            bold,
            size: 8.5,
          ),
        if (customerName != null)
          _buildInfoRow('Customer:', customerName, regular, bold, size: 8.5),
        _buildInfoRow('Date:', now, regular, bold, size: 8.5),

        // ---- Thick divider before items ----
        _buildDoubleLine(),

        // ---- Items table ----
        _buildItemsTable(items, false, regular, bold),

        // ---- Thick divider after items ----
        _buildDoubleLine(),

        // ---- Financial summary ----
        _buildFinancialSummary(
          subtotal:
              subtotal ??
              items.fold(
                0.0,
                (sum, item) =>
                    sum +
                    parseFirestoreDouble(item['price']) *
                        parseFirestoreInt(item['quantity'], fallback: 1),
              ),
          discounts: discounts,
          creditsUsed: creditsUsed,
          finalAmount: total,
          regular: regular,
          bold: bold,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Financial summary (part of bill)
  // ---------------------------------------------------------------------------

  static pw.Widget _buildFinancialSummary({
    required double subtotal,
    required double finalAmount,
    required pw.Font regular,
    required pw.Font bold,
    Map<String, dynamic>? discounts,
    double? creditsUsed,
  }) {
    final List<pw.Widget> discountWidgets = [];
    double totalAfterDiscounts = subtotal;
    if (discounts != null) {
      for (var entry in discounts.entries) {
        final pct = parseFirestoreDouble(entry.value);
        final discountAmount = subtotal * pct / 100;
        totalAfterDiscounts -= discountAmount;
        discountWidgets.add(
          _buildAmountRow(
            '${_formatDiscountName(entry.key)} (${pct.toStringAsFixed(0)}%)',
            '-${_fmtRupee(discountAmount)}',
            regular,
            size: 8.5,
          ),
        );
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _buildAmountRow('Subtotal', _fmtRupee(subtotal), regular),
        if (discountWidgets.isNotEmpty) ...[
          pw.Divider(thickness: 0.3, color: PdfColors.grey400, height: 4),
          ...discountWidgets,
          pw.Divider(thickness: 0.3, color: PdfColors.grey400, height: 4),
          _buildAmountRow('Total', _fmtRupee(totalAfterDiscounts), bold),
        ],
        if (creditsUsed != null && creditsUsed > 0)
          _buildAmountRow(
            'Paid by Credits',
            '-${_fmtRupee(creditsUsed)}',
            regular,
            size: 8.5,
          ),
        pw.SizedBox(height: 4),

        // ---- Prominent AMOUNT PAID box ----
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.2)),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'AMOUNT PAID',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              pw.Text(
                _fmtRupee(finalAmount),
                style: pw.TextStyle(font: bold, fontSize: 13),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 5),

        // ---- Footer ----
        pw.Center(
          child: pw.Text(
            '* * * Thank You * * *',
            style: pw.TextStyle(font: bold, fontSize: 8, letterSpacing: 1),
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Center(
          child: pw.Text(
            'Visit us again!',
            style: pw.TextStyle(
              font: regular,
              fontSize: 7,
              color: PdfColors.grey700,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Items table
  // ---------------------------------------------------------------------------

  static pw.Widget _buildItemsTable(
    List<Map<String, dynamic>> items,
    bool showRate,
    pw.Font regular,
    pw.Font bold,
  ) {
    final headerBorder = pw.Border(bottom: const pw.BorderSide(width: 0.6));
    final headerDecor = pw.BoxDecoration(border: headerBorder);

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(5),
        2: pw.FlexColumnWidth(2.8),
      },
      children: [
        // Header row with underline
        pw.TableRow(
          decoration: headerDecor,
          children: [
            _tableCell('QTY', bold, 8, pw.Alignment.centerLeft, vPad: 2),
            _tableCell('ITEM', bold, 8, pw.Alignment.centerLeft, vPad: 2),
            _tableCell(
              showRate ? 'RATE' : 'AMT',
              bold,
              8,
              pw.Alignment.centerRight,
              vPad: 2,
            ),
          ],
        ),
        // Data rows
        ...items.map((item) {
          final qty = parseFirestoreInt(item['quantity'], fallback: 1);
          final price = parseFirestoreDouble(item['price']);
          final val = showRate ? price : price * qty;
          return pw.TableRow(
            children: [
              _tableCell(qty.toString(), regular, 8, pw.Alignment.centerLeft),
              _tableCell(
                item['name']?.toString() ?? '',
                regular,
                8,
                pw.Alignment.centerLeft,
              ),
              _tableCell(_fmtRupee(val), regular, 8, pw.Alignment.centerRight),
            ],
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable helpers
  // ---------------------------------------------------------------------------

  static pw.Widget _tableCell(
    String text,
    pw.Font font,
    double size,
    pw.Alignment align, {
    double vPad = 1.2,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: vPad),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: size),
        ),
      ),
    );
  }

  static pw.Widget _buildDoubleLine() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Column(
        children: [
          pw.Divider(thickness: 0.8, height: 0),
          pw.SizedBox(height: 1),
          pw.Divider(thickness: 0.3, height: 0),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(
    String label,
    String value,
    pw.Font regular,
    pw.Font bold, {
    double size = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 52,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: regular,
                fontSize: size,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: bold, fontSize: size),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAmountRow(
    String label,
    String value,
    pw.Font font, {
    double size = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              label,
              style: pw.TextStyle(font: font, fontSize: size),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: size),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Font _getFont(Uint8List? data, String type) {
    return data != null
        ? pw.Font.ttf(ByteData.view(data.buffer))
        : (type == 'bold' ? pw.Font.helveticaBold() : pw.Font.helvetica());
  }

  static String _fmtRupee(double v) {
    final formatted = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    return '\u20B9$formatted';
  }

  static String _formatDiscountName(String key) {
    if (key.isEmpty) return '';
    return key
        .replaceAll('Percentage', '')
        .replaceAllMapped(
          RegExp(r'(?<=[a-z])(?=[A-Z])'),
          (Match m) => ' ${m[0]!}',
        )
        .capitalize();
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

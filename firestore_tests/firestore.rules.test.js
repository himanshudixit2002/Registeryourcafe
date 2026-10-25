/**
 * Firestore security rules regression tests (run inside emulator).
 *
 * From repo root:
 *   npx firebase-tools emulators:exec --only firestore --project demo-rules-smoke \
 *     "cd firestore_tests && npm ci && npm test"
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-rules-smoke';
const RULES = readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8');

const companyId = 'co_rules_test_1';
const ownerUid = 'uid_owner_1';
const memberUid = 'uid_member_1';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: RULES },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

async function seedTenant() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`companies/${companyId}`).set({
      name: 'Rules Test Cafe',
      ownerUid,
      venueKind: 'gamingCafe',
      createdAt: new Date(),
    });
    await db.doc(`users/${ownerUid}`).set({
      email: 'owner@test.dev',
      name: 'Owner',
      companyId,
      role: 'admin',
      roleId: 'owner',
    });
    await db.doc(`users/${memberUid}`).set({
      email: 'member@test.dev',
      name: 'Member',
      companyId,
      role: 'staff',
      roleId: 'staff',
    });
  });
}

test('unauthenticated cannot read company root', async () => {
  await seedTenant();
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(db.doc(`companies/${companyId}`).get());
});

test('company owner can read company root', async () => {
  await seedTenant();
  const db = testEnv.authenticatedContext(ownerUid).firestore();
  await assertSucceeds(db.doc(`companies/${companyId}`).get());
});

test('company owner can merge postRegisterOnboardingDismissed', async () => {
  await seedTenant();
  const db = testEnv.authenticatedContext(ownerUid).firestore();
  await assertSucceeds(
    db.doc(`companies/${companyId}`).set(
      { postRegisterOnboardingDismissed: true },
      { merge: true },
    ),
  );
});

test('tenant member can read own user doc', async () => {
  await seedTenant();
  const db = testEnv.authenticatedContext(memberUid).firestore();
  await assertSucceeds(db.doc(`users/${memberUid}`).get());
});

test('user from another company cannot read company', async () => {
  await seedTenant();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('users/uid_other').set({
      email: 'other@test.dev',
      name: 'Other',
      companyId: 'co_other',
      role: 'staff',
      roleId: 'staff',
    });
  });
  const db = testEnv.authenticatedContext('uid_other').firestore();
  await assertFails(db.doc(`companies/${companyId}`).get());
});

async function seedCompanyWithRoleUsers() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`companies/${companyId}`).set({
      name: 'Stock Rules Cafe',
      ownerUid,
      venueKind: 'gamingCafe',
      createdAt: new Date(),
    });
    await db.doc(`users/${ownerUid}`).set({
      email: 'owner@test.dev',
      name: 'Owner',
      companyId,
      role: 'admin',
      roleId: 'owner',
    });
    const roles = [
      {
        id: 'role_cafe_admin',
        ids: ['nav.cafe', 'ops.cafe_admin'],
      },
      {
        id: 'role_cafe_only',
        ids: ['nav.cafe'],
      },
      {
        id: 'role_merch',
        ids: ['nav.merchandise', 'ops.merchandise_manage'],
      },
      {
        id: 'role_inventory',
        ids: ['nav.inventory'],
      },
    ];
    for (const r of roles) {
      await db.doc(`companies/${companyId}/permissionRoles/${r.id}`).set({
        name: r.id,
        permissionIds: r.ids,
        isSystem: true,
      });
    }
    await db.doc('users/uid_cafe_admin').set({
      email: 'cafeadmin@test.dev',
      name: 'Cafe Admin',
      companyId,
      role: 'staff',
      roleId: 'role_cafe_admin',
    });
    await db.doc('users/uid_cafe_only').set({
      email: 'cafeonly@test.dev',
      name: 'Cafe Only',
      companyId,
      role: 'staff',
      roleId: 'role_cafe_only',
    });
    await db.doc('users/uid_merch').set({
      email: 'merch@test.dev',
      name: 'Merch',
      companyId,
      role: 'staff',
      roleId: 'role_merch',
    });
    await db.doc('users/uid_inventory').set({
      email: 'inv@test.dev',
      name: 'Inventory',
      companyId,
      role: 'staff',
      roleId: 'role_inventory',
    });
  });
}

test('nav.cafe without ops.cafe_admin cannot write stock_items', async () => {
  await seedCompanyWithRoleUsers();
  const db = testEnv.authenticatedContext('uid_cafe_only').firestore();
  await assertFails(
    db.doc(`companies/${companyId}/stock_items/item_denied`).set({
      name: 'X',
      quantity: 1,
      unit: 'kg',
      isMerchandise: false,
      updatedAt: new Date(),
    }),
  );
});

test('nav.tables alone can create table_type_definitions (parity with client implied ops)', async () => {
  const uidTablesOnly = 'uid_tables_nav_only';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`companies/${companyId}`).set({
      name: 'Table Types Rules Cafe',
      ownerUid,
      venueKind: 'restaurant',
      createdAt: new Date(),
    });
    await db.doc(`users/${uidTablesOnly}`).set({
      email: 'tablesonly@test.dev',
      name: 'Tables Nav Only',
      companyId,
      role: 'staff',
      roleId: 'role_nav_tables_only',
    });
    await db.doc(`companies/${companyId}/permissionRoles/role_nav_tables_only`).set({
      name: 'nav.tables only',
      permissionIds: ['nav.tables'],
      isSystem: true,
    });
  });
  const db = testEnv.authenticatedContext(uidTablesOnly).firestore();
  await assertSucceeds(
    db.doc(`companies/${companyId}/table_type_definitions/seed_std`).set({
      name: 'Standard',
      iconKey: 'table_restaurant',
      colorArgb: 0xff000000,
      sortOrder: 0,
      isArchived: false,
      createdAt: new Date(),
    }),
  );
});

test('nav.customers alone can create membership_type_definitions (parity with client implied ops)', async () => {
  const uidCustomersOnly = 'uid_customers_nav_only';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`companies/${companyId}`).set({
      name: 'Membership Rules Cafe',
      ownerUid,
      venueKind: 'gamingCafe',
      createdAt: new Date(),
    });
    await db.doc(`users/${uidCustomersOnly}`).set({
      email: 'customersonly@test.dev',
      name: 'Customers Nav Only',
      companyId,
      role: 'staff',
      roleId: 'role_nav_customers_only',
    });
    await db
      .doc(`companies/${companyId}/permissionRoles/role_nav_customers_only`)
      .set({
        name: 'nav.customers only',
        permissionIds: ['nav.customers'],
        isSystem: true,
      });
  });
  const db = testEnv.authenticatedContext(uidCustomersOnly).firestore();
  await assertSucceeds(
    db.doc(`companies/${companyId}/membership_type_definitions/plan_seed`).set({
      name: 'Walk-in',
      fee: 0,
      creditsToAdd: 0,
      sortOrder: 0,
      isRegular: true,
      isArchived: false,
      idPrefix: 'WALK',
      createdAt: new Date(),
    }),
  );
});

test('missing roleId falls back to staff permission doc (AppUser.resolvedRoleId parity)', async () => {
  const uidNoRoleId = 'uid_profile_no_role_id';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`companies/${companyId}`).set({
      name: 'No RoleId Field Cafe',
      ownerUid,
      venueKind: 'gamingCafe',
      createdAt: new Date(),
    });
    await db.doc(`companies/${companyId}/permissionRoles/staff`).set({
      name: 'staff',
      permissionIds: ['nav.tables'],
      isSystem: true,
    });
    await db.doc(`users/${uidNoRoleId}`).set({
      email: 'noroleidfield@test.dev',
      name: 'No roleId',
      companyId,
      role: 'staff',
    });
  });
  const db = testEnv.authenticatedContext(uidNoRoleId).firestore();
  await assertSucceeds(
    db.doc(`companies/${companyId}/table_type_definitions/slug_no_rid`).set({
      name: 'From staff fallback',
      iconKey: 'table_restaurant',
      colorArgb: 0xff000000,
      sortOrder: 0,
      isArchived: false,
      createdAt: new Date(),
    }),
  );
});

test('custom role with empty permissionIds cannot create table_type_definitions', async () => {
  const uidEmptyCustom = 'uid_empty_custom_role';
  const customRoleId = 'role_custom_empty';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`companies/${companyId}`).set({
      name: 'Empty Custom Role Cafe',
      ownerUid,
      venueKind: 'gamingCafe',
      createdAt: new Date(),
    });
    await db.doc(`companies/${companyId}/permissionRoles/${customRoleId}`).set({
      name: 'Broken custom',
      permissionIds: [],
      isSystem: false,
    });
    await db.doc(`users/${uidEmptyCustom}`).set({
      email: 'emptycustom@test.dev',
      name: 'Empty custom',
      companyId,
      role: 'staff',
      roleId: customRoleId,
    });
  });
  const db = testEnv.authenticatedContext(uidEmptyCustom).firestore();
  await assertFails(
    db.doc(`companies/${companyId}/table_type_definitions/new_type`).set({
      name: 'X',
      iconKey: 'table_restaurant',
      colorArgb: 0xff000000,
      sortOrder: 0,
      isArchived: false,
      createdAt: new Date(),
    }),
  );
});

test('custom role with nav.tables can create table_type_definitions', async () => {
  const uidCustomTables = 'uid_custom_tables_role';
  const customRoleId = 'role_custom_tables';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`companies/${companyId}`).set({
      name: 'Custom Tables Role Cafe',
      ownerUid,
      venueKind: 'gamingCafe',
      createdAt: new Date(),
    });
    await db.doc(`companies/${companyId}/permissionRoles/${customRoleId}`).set({
      name: 'Floor only',
      permissionIds: ['nav.tables'],
      isSystem: false,
    });
    await db.doc(`users/${uidCustomTables}`).set({
      email: 'customtables@test.dev',
      name: 'Custom tables',
      companyId,
      role: 'staff',
      roleId: customRoleId,
    });
  });
  const db = testEnv.authenticatedContext(uidCustomTables).firestore();
  await assertSucceeds(
    db.doc(`companies/${companyId}/table_type_definitions/custom_ok`).set({
      name: 'Y',
      iconKey: 'table_restaurant',
      colorArgb: 0xff000000,
      sortOrder: 0,
      isArchived: false,
      createdAt: new Date(),
    }),
  );
});


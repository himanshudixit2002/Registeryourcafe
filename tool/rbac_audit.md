# RBAC audit matrix (client)

Reference: [`lib/auth/permission_id.dart`](../lib/auth/permission_id.dart), [`lib/auth/effective_permissions.dart`](../lib/auth/effective_permissions.dart), [`lib/providers/permissions_provider.dart`](../lib/providers/permissions_provider.dart).

## Resolution and caps

| Mechanism | Role |
|-----------|------|
| `effectivePermissionsProvider` | Streams `permissionRoles/{roleId}`; company owner → full catalog |
| `CompanyModuleVisibility.filterPermissionIdsForModules` | Removes nav/ops when module toggles are off |
| `resolvedEffectivePermissions` | Tenant users get empty set while loading (no privileged UI flash) |
| `Ref.watchResolvedPermissions()` | UI entry point for gates |

## Account creation and identity (three tenant models)

| Type | Entry UI | What gets created | Code |
|------|-----------|-------------------|------|
| **Company + owner** | [`RegisterCompanyScreen`](../lib/screens/auth/register_company_screen.dart) (from landing) | Firebase Auth user (primary app) + `companies/{id}` + `users/{uid}` with `roleId: owner` + seeded `permissionRoles` | [`AuthService.registerCompany`](../lib/providers/auth_provider.dart) |
| **Staff login** | [`CreateStaffScreen`](../lib/screens/admin/create_staff_screen.dart) | Firebase Auth user (isolated [`register_ops`](../lib/constants/register_ops_firebase.dart) app) + `users/{newUid}` with chosen `roleId` | [`AuthService.createStaffAccount`](../lib/providers/auth_provider.dart) |
| **Customer record** | [`AddCustomerScreen`](../lib/screens/customers/add_customer_screen.dart) | `companies/{cid}/customers/{id}` only (no staff Auth account) | Customer flows; gated by `nav.customers` / admin ops |

**Landing guest (related):** [`ensureLandingGuestUser`](../lib/utils/landing_guest_auth.dart) signs in **anonymously** for public booking / menu flows—not a staff or venue customer CRM record.

### `staff.invite` vs Firestore

- [`staff.invite`](../lib/auth/permission_id.dart) controls **whether the app shows invite / create-staff affordances**.
- **Only the registered company owner** can complete staff Auth creation: Firestore [`ownerCreatesCompanyMember`](../firestore.rules) requires [`isCompanyOwner`](../firestore.rules). Non-owners with `staff.invite` see an explanation in Settings / Profile instead of a working create flow.

## Firestore rules (server)

[`firestore.rules`](../firestore.rules) still grants broad **read/write** to any tenant member (`companyAccess`) for most `companies/{companyId}/**` paths. **Additional checks:**

| Path (under `companies/{companyId}/`) | Create | Update |
|---------------------------------------|--------|--------|
| `loyalty_conversions/{id}` | `ops.loyalty_convert` **or** `ops.loyalty_configure` (or company owner / `roleId == owner`) | same as create |
| `loyalty_settings/{id}` | `ops.loyalty_configure` | `ops.loyalty_configure` |

`userHasPermission` reads `users/{uid}.roleId` and `permissionRoles/{roleId}.permissionIds`. Owners bypass via `isCompanyOwner` or `roleId == owner`.

## Shell tabs (`MainScreen` + `isShellTitleVisible`)

| Route title | Nav permission | Notes |
|-------------|----------------|-------|
| Dashboard | `nav.dashboard` | Ordering helper uses same |
| Sales | `nav.sales` | |
| Inventory | `nav.inventory` | |
| Leaderboard | `nav.leaderboard` | Hidden for non–gaming venue presets |
| Loyalty | `nav.loyalty` | |
| Tournaments | `nav.tournaments` | Hidden for non–gaming venue presets |
| Merchandise | `nav.merchandise` | |
| Café | `nav.cafe` | |
| Customers | `nav.customers` | |
| Tables | `nav.tables` | |
| Settings / Profile | (none in `navPermissionForShellTitle`) | Individual tiles gated |

## Screens — gate type and permissions

**Legend:** `shell` = tab hidden if missing nav; `own` = `PermissionDeniedScaffold` or equivalent at `build`; `parent` = only reachable under gated parent; `action` = buttons/dialogs gated only.

| Screen / widget | Gate type | Required permission(s) |
|-----------------|-----------|---------------------------|
| `InventoryHubScreen` | own | `nav.inventory` |
| `StockItemCostHistoryScreen` | own | `nav.inventory` |
| `StockScreen` (café) | own | `nav.cafe` |
| `GuestCafeOrdersScreen` | own | `nav.cafe` |
| `LoyaltyScreen` | own | `nav.loyalty`; Convert tab / convert flows → `canConvertLoyaltyPoints()` (`ops.loyalty_convert` or `ops.loyalty_configure`) |
| `LoyaltySettingsScreen` | own + action | `ops.loyalty_configure` (`canConfigureLoyaltySettings`) |
| `LoyaltyConversionHistoryScreen` | own | `nav.loyalty` |
| `CustomerDetailScreen` | own | `nav.customers`; credits card / ledger admin actions → `ops.customers_admin` (read-only balance + history otherwise); edit → `ops.customers_admin` |
| `AddCustomerScreen` | own | `nav.customers` |
| `EditCustomerScreen` | own | `ops.customers_admin` |
| `PublicDiscoverySettingsScreen` | own | `settings.modules` |
| `PublicMenuEditorScreen` | own | `settings.modules` |
| `FloorBookingRequestsScreen` | own | `nav.tables` |
| `CompanyRolesListScreen` | own | `settings.roles` |
| `CompanyRoleEditorScreen` | own | `settings.roles` |
| `CreateStaffScreen` | own | `staff.invite` |
| `RestoreSessionsScreen` | own | `ops.session_admin` |
| `UnifiedRefundScreen` | own | `ops.refund` |
| `UnifiedRefundWidget` (dialog) | own | `ops.refund` |
| `MerchandiseStockScreen` | own | `ops.merchandise_manage` |
| `AwardPointsScreen` | own | `nav.leaderboard` |
| `LeaderboardSettingsScreen` | own | `ops.leaderboard_manage` |
| `DiningSessionScreen` | own | `nav.tables` |
| `AllSessionsHistoryScreen` | own + action | `ops.sessions_history` (history icon on table grid requires same) |
| `TableGridScreen` | own | `nav.tables` |
| `TableSettingsScreen` | own | `canOpenTableSettingsScreens()` |
| `TableTypesSettingsScreen` | own | `canOpenTableTypesSettings()` |
| `LeaderboardCompetitionScreen` | own | `nav.leaderboard` |
| `LeaderboardScreen` | shell + checks | `nav.leaderboard` |
| `CustomerListScreen` | own | `nav.customers` |
| `CreditLedgerScreen` | own | `nav.customers` |
| `AllCreditTransactionsScreen` | own | `ops.customers_admin` |
| `TournamentListScreen` | own | `nav.tournaments` |
| `TournamentDetailScreen` | own | `nav.tournaments`; manage actions → `ops.tournament_manage` |
| `MembershipTypesSettingsScreen` | own | `canOpenMembershipTypesSettings()` |
| `SalesScreen` | shell | `nav.sales` |
| `CafeScreen` | shell | `nav.cafe` |
| `MerchandiseScreen` | shell | `nav.merchandise` |
| `RefundService` (server-side throw) | API | `ops.refund` |

### Default role seed (`DefaultRolePermissions.staff`)

Includes `ops.sessions_history` so floor staff keep session history access while the screen stays gated for custom roles that omit it.

## Parent-gated children (no separate `own` unless reused)

| Parent | Children |
|--------|----------|
| `InventoryHubScreen` | `ReceiveStockScreen`, `VendorsListScreen`, `StockReceiptsListScreen`, `InventoryPricingScreen`, `InventoryAnalysisScreen` |

## Follow-up batches (Phase B)

1. Re-scan `Navigator.push` / `AppMaterialPageRoute` after refactors; ensure new `*Screen` files add `own` row above.
2. Align duplicate “access denied” copy with `PermissionDeniedScaffold` where helpful.
3. ~~Optional: Firestore rules review~~ — loyalty conversion + loyalty settings writes now permission-checked (see **Firestore rules** above); other collections still `companyAccess`-only.

## Legacy `UserRole`

Coarse `UserRole` remains for profile display and audit fields (`performedByRole`, etc.). Capability helpers on `UserRoleExtension` are deprecated; use `watchResolvedPermissions()` + `PermissionIds`.

## `lib/widgets` — navigation / dialogs

Ripgrep (`Navigator.push` / `AppMaterialPageRoute` under `lib/widgets/`): [`dashboard_leaderboard_widget`](../lib/widgets/dashboard_leaderboard_widget.dart), [`dashboard_tournament_widget`](../lib/widgets/dashboard_tournament_widget.dart), [`players_selection_dialog`](../lib/widgets/dialogs/players_selection_dialog.dart), [`customer_selection_dialog`](../lib/widgets/dialogs/customer_selection_dialog.dart), [`enhanced_customer_search`](../lib/widgets/enhanced_customer_search.dart). All push targets are gated at destination or by nav permission on the widget; no extra changes in this pass.

| File | Behavior | RBAC |
|------|------------|------|
| `widgets/dashboard_leaderboard_widget.dart` | Push `LeaderboardCompetitionScreen`; shell navigate from row tap | `nav.leaderboard` disables “View All” and row `onTap` |
| `widgets/dashboard_tournament_widget.dart` | Push `TournamentDetailShell`; shell navigate | `nav.tournaments` disables tap + “View All” |
| `widgets/dialogs/unified_refund_widget.dart` | Refund dialog | `ops.refund` |
| `widgets/dialogs/players_selection_dialog.dart` | Push `AddCustomerScreen` | Snackbar + hide Add if no `nav.customers`; destination still gated |
| `widgets/dialogs/customer_selection_dialog.dart` | Push `AddCustomerScreen` | Same |
| `widgets/enhanced_customer_search.dart` | Push `AddCustomerScreen` | `canAddCustomer` from caller (`nav.customers`); hides add affordances when false |
| `widgets/dialogs/bill_summary_dialog.dart` | Checkout confirm | Caller context (session/table) |
| `widgets/dialogs/payment_method_dialog.dart` | Payment pick | Caller context |
| `widgets/dialogs/partial_payment_dialog.dart` | Partial pay | Caller context |
| `widgets/linked_stock_picker.dart` | Pick stock item | Caller context (`nav.cafe` / inventory) |
| `widgets/mobile_adaptive_dialog.dart` | Generic wrapper | N/A |
| `widgets/app_drawer.dart` | Drawer chrome | Items from parent |
| Other `widgets/**` | No tenant `Navigator` pushes | N/A or caller |

## Per-file triage (`lib/screens`)

Complete path list (category + account-relevance hints): [`tool/screens_rbac_inventory.md`](screens_rbac_inventory.md) — regenerated together with the per-file scan. **Per-file flags** (every `lib/screens` + `lib/widgets` path): [`tool/rbac_per_file_scan.md`](rbac_per_file_scan.md). **Regenerate both:** `python3 tool/generate_rbac_per_file_scan.py`. **Gate:** `own` = route guard; `shell` = workspace tab; `parent` = only under listed screen; `action` = buttons/dialogs use `PermissionIds` inside; `N/A` = no tenant RBAC.

### Maintainer checklist (RBAC changes)

1. Run `dart analyze lib` (no errors).
2. After permission or navigation changes, run `python3 tool/generate_rbac_per_file_scan.py` and commit updated [`rbac_per_file_scan.md`](rbac_per_file_scan.md) + [`screens_rbac_inventory.md`](screens_rbac_inventory.md).
3. Update the **Per-file triage** table in this doc when adding a new tenant `*Screen` or changing required `PermissionIds`.

| Path | Category | Gate | Permission / parent |
|------|----------|------|---------------------|
| `admin/create_staff_screen.dart` | tenant | own | `staff.invite` to open; **only registered company owner** can submit (matches Firestore `ownerCreatesCompanyMember`) |
| `admin/restore_sessions_screen.dart` | tenant | own | `ops.session_admin` |
| `auth/login_screen.dart` | pre_auth | N/A | — |
| `auth/register_company_screen.dart` | pre_auth | N/A | — |
| `cafe/cafe_screen.dart` | tenant | shell + action | `nav.cafe`; **New Customer** in order association only if `nav.customers` |
| `cafe/components/*` | tenant | parent | `CafeScreen` |
| `cafe/guest_cafe_orders_screen.dart` | tenant | own | `nav.cafe` |
| `cafe/stock_screen.dart` | tenant | own | `nav.cafe` |
| `customers/add_customer_screen.dart` | tenant | own | `nav.customers` |
| `customers/all_credit_transactions_screen.dart` | tenant | own | `ops.customers_admin` |
| `customers/credit_ledger_screen.dart` | tenant | own | `nav.customers` |
| `customers/customer_detail/*` | tenant | parent | `CustomerDetailScreen`; loyalty section needs `nav.loyalty` to view; **Convert** needs `ops.loyalty_convert` or `ops.loyalty_configure` |
| `customers/customer_detail_screen.dart` | tenant | own | `nav.customers`; `CustomerActionsColumn` hides add-credits / reconcile / WhatsApp export without `ops.customers_admin`; handlers still enforce |
| `customers/customer_list_screen.dart` | tenant | own | `nav.customers` |
| `customers/edit_customer_screen.dart` | tenant | own | `ops.customers_admin` |
| `customers/membership_types_settings_screen.dart` | tenant | own | `canOpenMembershipTypesSettings()` |
| `dashboard/components/*` | tenant | parent | `DashboardScreen` |
| `dashboard/dashboard_screen.dart` | tenant | own | `nav.dashboard` |
| `dashboard/widgets/*` | tenant | parent | `DashboardScreen` |
| `debug/widget_catalog_screen.dart` | tenant | own | Debug; opened from Settings |
| `inventory/inventory_hub_screen.dart` | tenant | own | `nav.inventory` |
| `inventory/inventory_analysis_screen.dart` | tenant | parent | `InventoryHubScreen` |
| `inventory/inventory_pricing_screen.dart` | tenant | parent | `InventoryHubScreen` |
| `inventory/receive_stock_screen.dart` | tenant | parent | `InventoryHubScreen` |
| `inventory/stock_item_cost_history_screen.dart` | tenant | own | `nav.inventory` |
| `inventory/stock_receipts_list_screen.dart` | tenant | parent | `InventoryHubScreen` |
| `inventory/vendors_list_screen.dart` | tenant | parent | `InventoryHubScreen` |
| `landing/*` | public | N/A | Anonymous / discovery |
| `leaderboard/award_points_screen.dart` | tenant | own | `nav.leaderboard` |
| `leaderboard/leaderboard_competition_screen.dart` | tenant | own | `nav.leaderboard` |
| `leaderboard/leaderboard_screen.dart` | tenant | shell | `nav.leaderboard` |
| `leaderboard/leaderboard_settings_screen.dart` | tenant | own | `ops.leaderboard_manage` |
| `legal/*` | public | N/A | — |
| `loyalty/components/convert_points_dialog.dart` | tenant | action | `nav.loyalty` + `canConvertLoyaltyPoints()` |
| `loyalty/components/loyalty_stats_card.dart` | tenant | parent | `LoyaltyScreen` |
| `loyalty/loyalty_conversion_history_screen.dart` | tenant | own | `nav.loyalty` |
| `loyalty/loyalty_screen.dart` | tenant | own | `nav.loyalty`; Convert tab → `canConvertLoyaltyPoints()` |
| `loyalty/loyalty_settings_screen.dart` | tenant | own | `ops.loyalty_configure` |
| `merchandise/components/merchandise_order_card.dart` | tenant | parent | `MerchandiseScreen` |
| `merchandise/merchandise_screen.dart` | tenant | shell | `nav.merchandise` |
| `merchandise/merchandise_stock_screen.dart` | tenant | own | `ops.merchandise_manage` |
| `profile/profile_screen.dart` | tenant | action | `staff.invite` for admin tools tile |
| `refund/unified_refund_screen.dart` | tenant | own | `ops.refund` |
| `sales/sales_screen.dart` | tenant | shell | `nav.sales` |
| `sales/components/*` | tenant | parent | `SalesScreen` |
| `sales/providers/sales_providers.dart` | service | N/A | No UI RBAC |
| `sales/services/*` | service | N/A | No UI RBAC |
| `settings/floor_booking_requests_screen.dart` | tenant | own | `nav.tables` |
| `settings/public_discovery_settings_screen.dart` | tenant | own | `settings.modules` |
| `settings/public_menu_editor_screen.dart` | tenant | own | `settings.modules` |
| `settings/roles/company_role_editor_screen.dart` | tenant | own | `settings.roles` |
| `settings/roles/company_roles_list_screen.dart` | tenant | own | `settings.roles` |
| `settings/settings_hub_screen.dart` | tenant | action | Per-tile `PermissionIds` |
| `tables/all_sessions_history_screen.dart` | tenant | own | `ops.sessions_history` |
| `tables/components/table_card.dart` | tenant | parent | `TableGridScreen` |
| `tables/dining/dining_session_screen.dart` | tenant | own | `nav.tables` |
| `tables/session_checkout_flow.dart` | tenant | parent | Session / table UI |
| `tables/session_details_dialog.dart` | tenant | action | Refund, session admin, etc. |
| `tables/table_grid_screen.dart` | tenant | own | `nav.tables` |
| `tables/table_settings_screen.dart` | tenant | own | `canOpenTableSettingsScreens()` |
| `tables/table_types_settings_screen.dart` | tenant | own | `canOpenTableTypesSettings()` |
| `tournament/*_dialog.dart` | tenant | action | Opened from tournament UI; `approve_registration_dialog` requires `ops.tournament_manage`; **create new customer** on public registrations also requires `nav.customers` (link-existing unchanged) |
| `tournament/tournament_bracket_widget.dart` | tenant | parent | `TournamentDetailScreen` |
| `tournament/tournament_detail_screen.dart` | tenant | own | `nav.tournaments` |
| `tournament/tournament_list_screen.dart` | tenant | own | `nav.tournaments` |

## Verification log (batch2)

- Removed unused `cafe/components/order_association_section.dart` and its barrel export (café and merchandise use inline order-association sections).
- `CafeScreen`: **New Customer** in the order-association block is hidden when the user lacks `nav.customers` (aligned with `AddCustomerScreen`).
- `ApproveRegistrationDialog`: root `build` shows a permission-denied dialog when missing `ops.tournament_manage`; `_approveRegistration` and `_showRejectDialog` snackbar-guard the same.
- `CustomerDetailScreen` → `CustomerActionsColumn`: without `ops.customers_admin`, credits are shown read-only; ledger list stays visible but reconcile, bulk WhatsApp export, and top-up/membership controls are hidden (handlers unchanged).

## Verification log (batch3)

- **`ops.loyalty_convert`**: new permission in `PermissionIds`; default staff/cashier include it; `canConvertLoyaltyPoints()` also true when `ops.loyalty_configure`; legacy system role docs get `arrayUnion` on bootstrap when they have `nav.loyalty` but not convert.
- **Loyalty UI**: `LoyaltyScreen` hides the Convert tab without convert permission; `ConvertPointsDialog`, customer loyalty section, and convert-tab customer cards use the same gate.
- **Firestore**: `loyalty_conversions` create/update and `loyalty_settings` create/update require matching role permissions (see **Firestore rules**).
- **Dashboard leaderboard**: row taps use `onTap: null` when `nav.leaderboard` is missing so the list does not look interactive for denied users.

## Verification log (batch4)

- **Add customer entry points:** `CustomerSelectionDialog`, `PlayersSelectionDialog`, and `EnhancedCustomerSearchDelegate` block push / hide Add when `nav.customers` is false; café and award-points search pass `canAddCustomer` into the delegate.
- **Scan script:** `generate_rbac_per_file_scan.py` now treats `effectivePermissionsProvider` as in-file RBAC surface for REVIEW heuristics, adds **effPermStream** column, and regenerates `screens_rbac_inventory.md`.

## Verification log (batch5)

- **`ApproveRegistrationDialog`:** public registration “create new customer” is gated with `nav.customers` (UI + snackbar before `AddCustomerScreen` push); users without it default to link-existing and see a short inline note on the disabled path.

## Verification log (batch6)

- **Firestore rules (emulator):** [`firestore_tests/`](../firestore_tests/) runs `@firebase/rules-unit-testing` under `firebase emulators:exec` in CI (see [`.github/workflows/flutter-ci.yml`](../.github/workflows/flutter-ci.yml)). Covers unauthenticated company read denial, owner company read/update (including `postRegisterOnboardingDismissed` merge), tenant member self `users/{uid}` read, cross-company isolation, and **denial** of `stock_items` create for `nav.cafe` without `ops.cafe_admin`. Positive `stock_items` creates are not asserted here (catch-all create chain can hit emulator expression limits).

## Rules vs client matrix (batch7)

When the UI synthesizes permissions in [`lib/providers/permissions_provider.dart`](../lib/providers/permissions_provider.dart) (`_effectivePermissionIdsForRole`) or opens screens on **`nav.*`** alone, Firestore still reads **`companies/{cid}/permissionRoles/{roleId}.permissionIds`** for guarded paths. Mismatches cause **permission denied** on write.

| Firestore helper | Subpaths | Rule logic (summary) | Client pointers |
|------------------|----------|----------------------|-----------------|
| `userMayWriteInventoryStockCollections` | `stock_items`, `vendors`, `stock_receipts` | `nav.inventory` **or** (`nav.cafe` + `ops.cafe_admin`) **or** (`nav.merchandise` + `ops.merchandise_manage`) | [`StockScreen`](../lib/screens/cafe/stock_screen.dart) (café), [`merchandise_stock_screen.dart`](../lib/screens/merchandise/merchandise_stock_screen.dart), [`InventoryHubScreen`](../lib/screens/inventory/inventory_hub_screen.dart) |
| `userMayWriteCategoriesDoc` | `categories` | inventory **or** café **or** `ops.merchandise_manage` | Category editors under café / inventory |
| `userMayWriteTableTypeDefinitions` | `table_type_definitions` | See [`firestore.rules`](../firestore.rules) | [`effective_permissions.dart`](../lib/auth/effective_permissions.dart) `canMutateTableTypeDefinitions` |
| `userMayWriteMembershipTypeDefinitions` | `membership_type_definitions` | See [`firestore.rules`](../firestore.rules) | `canMutateMembershipTypeDefinitions` |
| `userMayConvertLoyalty` / `userMayConfigureLoyalty` | `loyalty_conversions`, `loyalty_settings` | Role doc must include convert/configure (or owner) | `canConvertLoyaltyPoints`, `canConfigureLoyaltySettings` |
| `userMayManageLeaderboardAdmin` | leaderboard admin docs | `ops.leaderboard_manage` | `canManageLeaderboardConfig` |
| Role pairing backfill | — | — | [`CompanyRolesService.ensureNavPairedOpsInPermissionRoles`](../lib/services/company_roles_service.dart) |

Deploy [`firestore.rules`](../firestore.rules) after any change (`firebase deploy --only firestore:rules`).

## Verification log (batch7)

- **`userMayWriteInventoryStockCollections`:** extended for café (`nav.cafe` + `ops.cafe_admin`) and merchandise (`nav.merchandise` + `ops.merchandise_manage`); [`StockScreen`](../lib/screens/cafe/stock_screen.dart) mutations gated on `ops.cafe_admin`; rules tests assert **denial** for café-only role on `stock_items` create (emulator limits positive catch-all creates).

# RBAC per-file heuristic scan

Generated for every Dart file under `lib/screens/` and `lib/widgets/`.

```bash
python3 tool/generate_rbac_per_file_scan.py
```

| Column | Meaning |
|--------|---------|
| **watchResolved** | `watchResolvedPermissions` / `readResolvedPermissions` |
| **PermissionDenied** | `PermissionDeniedScaffold` |
| **effPermStream** | `effectivePermissionsProvider` (in-file permission stream) |
| **PermissionIds** | `PermissionIds.` or `canOpen*(` on effective permissions |
| **push/route** | `Navigator.push` / `AppMaterialPageRoute` |
| **showDialog** | `showDialog` |

**REVIEW** is a heuristic: file pushes routes but has no in-file `watchResolved` / `PermissionDenied` / `effectivePermissionsProvider` — verify parent or destination (see [`rbac_audit.md`](rbac_audit.md)).

## `screens/` (114 files)

| File | watchResolved | PermissionDenied | effPermStream | PermissionIds | push/route | showDialog | Notes |
|------|---------------|------------------|---------------|---------------|------------|------------|-------|
| `admin/create_staff_screen.dart` | True | True | False | True | False | False | — |
| `admin/restore_sessions_screen.dart` | True | True | False | True | False | False | — |
| `auth/login_screen.dart` | False | False | False | False | False | False | — |
| `auth/register_company_screen.dart` | False | False | False | False | False | False | — |
| `cafe/cafe_screen.dart` | True | False | False | True | True | True | — |
| `cafe/components/category_filter_bar.dart` | False | False | False | False | False | False | — |
| `cafe/components/components.dart` | False | False | False | False | False | False | — |
| `cafe/components/current_order_list.dart` | False | False | False | False | False | False | — |
| `cafe/components/historical_order_card.dart` | False | False | False | False | False | False | — |
| `cafe/components/kitchen_column.dart` | False | False | False | False | False | False | — |
| `cafe/components/kitchen_order_card.dart` | False | False | False | False | False | False | — |
| `cafe/components/order_status_chip.dart` | False | False | False | False | False | False | — |
| `cafe/components/order_summary_actions.dart` | False | False | False | False | False | False | — |
| `cafe/components/payment_dialog.dart` | False | False | False | False | False | True | — |
| `cafe/components/product_grid.dart` | False | False | False | False | False | False | — |
| `cafe/components/sellable_stock_item_card.dart` | True | False | False | True | False | True | — |
| `cafe/guest_cafe_orders_screen.dart` | True | True | False | True | False | False | — |
| `cafe/stock_screen.dart` | True | True | False | True | True | True | — |
| `customers/add_customer_screen.dart` | True | True | False | True | False | True | — |
| `customers/all_credit_transactions_screen.dart` | True | False | False | True | False | False | — |
| `customers/credit_ledger_screen.dart` | True | False | False | True | False | False | — |
| `customers/customer_detail/customer_actions_column.dart` | False | False | False | False | False | False | — |
| `customers/customer_detail/customer_credit_transactions_section.dart` | False | False | False | False | False | False | — |
| `customers/customer_detail/customer_credits_membership_card.dart` | False | False | False | False | False | False | — |
| `customers/customer_detail/customer_games_leaderboard_section.dart` | False | False | False | False | False | False | — |
| `customers/customer_detail/customer_loyalty_section.dart` | True | False | False | True | False | True | — |
| `customers/customer_detail/customer_profile_section.dart` | False | False | False | False | False | False | — |
| `customers/customer_detail_screen.dart` | True | False | False | True | True | True | — |
| `customers/customer_list_screen.dart` | True | False | False | True | True | False | — |
| `customers/edit_customer_screen.dart` | True | False | False | True | False | False | — |
| `customers/membership_types_settings_screen.dart` | True | False | True | True | False | True | — |
| `dashboard/components/components.dart` | False | False | False | False | False | False | — |
| `dashboard/components/leaderboard_section.dart` | False | False | False | False | False | False | — |
| `dashboard/components/popular_items_card.dart` | False | False | False | False | False | False | — |
| `dashboard/components/quick_stats_grid.dart` | False | False | False | False | False | False | — |
| `dashboard/components/revenue_chart.dart` | False | False | False | False | False | False | — |
| `dashboard/components/top_performers_card.dart` | False | False | False | False | False | False | — |
| `dashboard/dashboard_screen.dart` | True | False | False | True | True | True | — |
| `dashboard/widgets/dashboard_category_sales.dart` | False | False | False | False | False | False | — |
| `dashboard/widgets/dashboard_hero_header.dart` | False | False | False | False | False | False | — |
| `dashboard/widgets/dashboard_insights.dart` | False | False | False | False | False | False | — |
| `dashboard/widgets/dashboard_kpi_grid.dart` | False | False | False | False | False | False | — |
| `dashboard/widgets/dashboard_load_error.dart` | False | False | False | False | False | False | — |
| `dashboard/widgets/dashboard_section.dart` | False | False | False | False | False | False | — |
| `debug/widget_catalog_screen.dart` | False | False | False | False | False | False | — |
| `inventory/inventory_analysis_screen.dart` | False | False | False | False | False | False | — |
| `inventory/inventory_hub_screen.dart` | True | True | False | True | False | False | — |
| `inventory/inventory_pricing_screen.dart` | False | False | False | False | True | False | tab under InventoryHubScreen (`nav.inventory`) |
| `inventory/receive_stock_screen.dart` | False | False | False | False | False | True | — |
| `inventory/stock_item_cost_history_screen.dart` | True | True | False | True | False | False | — |
| `inventory/stock_receipts_list_screen.dart` | False | False | False | False | False | False | — |
| `inventory/vendors_list_screen.dart` | False | False | False | False | False | True | — |
| `landing/discover_venues_screen.dart` | False | False | False | False | False | False | — |
| `landing/discovery_filters.dart` | False | False | False | False | False | False | — |
| `landing/landing_events_tab.dart` | False | False | False | False | False | True | — |
| `landing/landing_home_tab.dart` | False | False | False | False | True | False | leaf/public/parent |
| `landing/landing_page.dart` | False | False | False | False | True | False | leaf/public/parent |
| `landing/landing_providers.dart` | False | False | False | False | False | False | — |
| `landing/landing_public_widgets.dart` | False | False | False | False | False | False | — |
| `landing/public_floor_booking_sheet.dart` | False | False | False | False | False | False | — |
| `landing/public_menu_ordering_tab.dart` | False | False | False | False | False | False | — |
| `landing/public_venue_detail_screen.dart` | False | False | False | False | True | True | leaf/public/parent |
| `leaderboard/award_points_screen.dart` | True | False | False | True | False | True | — |
| `leaderboard/leaderboard_competition_screen.dart` | True | True | False | True | False | False | — |
| `leaderboard/leaderboard_screen.dart` | True | False | False | True | True | True | — |
| `leaderboard/leaderboard_settings_screen.dart` | True | False | False | True | False | False | — |
| `legal/legal_document_screen.dart` | False | False | False | False | False | False | — |
| `legal/legal_sections.dart` | False | False | False | False | False | False | — |
| `loyalty/components/convert_points_dialog.dart` | True | False | False | True | False | True | — |
| `loyalty/components/loyalty_stats_card.dart` | False | False | False | False | False | False | — |
| `loyalty/loyalty_conversion_history_screen.dart` | True | True | False | True | False | False | — |
| `loyalty/loyalty_screen.dart` | True | True | False | True | True | True | — |
| `loyalty/loyalty_settings_screen.dart` | True | True | False | False | False | False | — |
| `merchandise/components/merchandise_order_card.dart` | False | False | False | False | False | False | — |
| `merchandise/merchandise_screen.dart` | True | False | False | True | True | True | — |
| `merchandise/merchandise_stock_screen.dart` | True | False | False | True | True | True | — |
| `profile/profile_screen.dart` | True | False | False | True | True | False | — |
| `refund/unified_refund_screen.dart` | True | True | False | True | False | True | — |
| `sales/components/breakdown_table_widget.dart` | False | False | False | False | False | False | — |
| `sales/components/credit_report_widget.dart` | False | False | False | False | False | False | — |
| `sales/components/filters_widget.dart` | False | False | False | False | False | False | — |
| `sales/components/payment_method_breakdown_widget.dart` | False | False | False | False | False | False | — |
| `sales/components/revenue_type_breakdown_widget.dart` | False | False | False | False | False | False | — |
| `sales/components/summary_cards_widget.dart` | False | False | False | False | False | False | — |
| `sales/components/transactions_list_widget.dart` | True | False | False | True | False | True | — |
| `sales/providers/sales_providers.dart` | False | False | False | False | False | False | — |
| `sales/sales_screen.dart` | True | False | False | True | False | False | — |
| `sales/services/sales_csv_exporter.dart` | False | False | False | False | False | False | — |
| `sales/services/sales_csv_exporter_io.dart` | False | False | False | False | False | False | — |
| `sales/services/sales_csv_exporter_stub.dart` | False | False | False | False | False | False | — |
| `sales/services/sales_csv_exporter_web_impl.dart` | False | False | False | False | False | False | — |
| `sales/services/sales_data_service.dart` | False | False | False | False | False | False | — |
| `settings/floor_booking_requests_screen.dart` | True | True | False | True | False | True | — |
| `settings/public_discovery_settings_screen.dart` | True | True | False | True | True | True | — |
| `settings/public_menu_editor_screen.dart` | True | True | False | True | False | True | — |
| `settings/roles/company_role_editor_screen.dart` | True | False | False | True | False | False | — |
| `settings/roles/company_roles_list_screen.dart` | True | True | False | True | True | True | — |
| `settings/settings_hub_screen.dart` | True | False | False | True | True | False | — |
| `tables/all_sessions_history_screen.dart` | True | True | False | True | True | True | — |
| `tables/components/table_card.dart` | False | False | False | False | False | True | — |
| `tables/dining/dining_session_screen.dart` | True | False | False | True | True | True | — |
| `tables/session_checkout_flow.dart` | False | False | False | False | False | True | — |
| `tables/session_details_dialog.dart` | True | False | False | True | True | True | — |
| `tables/table_grid_screen.dart` | True | False | False | True | True | True | — |
| `tables/table_settings_screen.dart` | True | True | False | True | True | True | — |
| `tables/table_types_settings_screen.dart` | True | False | True | True | False | True | — |
| `tournament/add_participant_dialog.dart` | False | False | False | False | False | True | — |
| `tournament/approve_registration_dialog.dart` | True | False | False | True | True | True | — |
| `tournament/create_tournament_dialog.dart` | False | False | False | False | False | False | — |
| `tournament/refund_registration_dialog.dart` | False | False | False | False | False | False | — |
| `tournament/register_tournament_dialog.dart` | False | False | False | False | False | False | — |
| `tournament/tournament_bracket_widget.dart` | False | False | False | False | False | False | — |
| `tournament/tournament_detail_screen.dart` | True | False | False | True | False | True | — |
| `tournament/tournament_list_screen.dart` | True | False | False | True | True | True | — |

## `widgets/` (57 files)

| File | watchResolved | PermissionDenied | effPermStream | PermissionIds | push/route | showDialog | Notes |
|------|---------------|------------------|---------------|---------------|------------|------------|-------|
| `active_session_card.dart` | False | False | False | False | False | False | — |
| `animated_card.dart` | False | False | False | False | False | False | — |
| `app_card.dart` | False | False | False | False | False | False | — |
| `app_drawer.dart` | False | False | False | False | False | False | — |
| `cart_bottom_sheet.dart` | False | False | False | False | False | False | — |
| `constrained_page_content.dart` | False | False | False | False | False | False | — |
| `credit_transaction_tile.dart` | False | False | False | False | False | False | — |
| `customer_association_section.dart` | False | False | False | False | False | False | — |
| `customer_ui_components.dart` | False | False | False | False | False | False | — |
| `dashboard_leaderboard_widget.dart` | True | False | False | True | True | False | — |
| `dashboard_skeleton.dart` | False | False | False | False | False | False | — |
| `dashboard_tournament_widget.dart` | True | False | False | True | True | False | — |
| `dialogs/bill_summary_dialog.dart` | False | False | False | False | False | True | — |
| `dialogs/confirmation_dialog.dart` | False | False | False | False | False | False | — |
| `dialogs/customer_selection_dialog.dart` | True | False | False | True | True | False | — |
| `dialogs/item_revenue_dialog.dart` | False | False | False | False | False | False | — |
| `dialogs/partial_payment_dialog.dart` | False | False | False | False | False | False | — |
| `dialogs/payment_method_dialog.dart` | False | False | False | False | False | True | — |
| `dialogs/players_selection_dialog.dart` | True | False | False | True | True | False | — |
| `dialogs/ptl_loser_selection_dialog.dart` | False | False | False | False | False | False | — |
| `dialogs/unified_refund_widget.dart` | True | False | False | True | False | False | — |
| `empty_state_widget.dart` | False | False | False | False | False | False | — |
| `enhanced_customer_search.dart` | False | False | False | False | True | False | push AddCustomerScreen; `canAddCustomer` from caller |
| `floating_cart_button.dart` | False | False | False | False | False | False | — |
| `glass_modal_bottom_sheet.dart` | False | False | False | False | False | False | — |
| `glass_panel.dart` | False | False | False | False | False | False | — |
| `info_placeholder.dart` | False | False | False | False | False | False | — |
| `key_value_text.dart` | False | False | False | False | False | False | — |
| `leaderboard_card.dart` | False | False | False | False | False | False | — |
| `legal_footer_links.dart` | False | False | False | False | False | False | — |
| `linked_stock_picker.dart` | False | False | False | False | False | True | — |
| `loading_indicator.dart` | False | False | False | False | False | False | — |
| `match_history_widget.dart` | False | False | False | False | False | False | — |
| `mobile_adaptive_dialog.dart` | False | False | False | False | False | True | — |
| `mobile_button.dart` | False | False | False | False | False | False | — |
| `mobile_plan_selector.dart` | False | False | False | False | False | False | — |
| `mobile_stat_card.dart` | False | False | False | False | False | False | — |
| `occupied_table_timer_text.dart` | False | False | False | False | False | False | — |
| `order_expansion_tile.dart` | False | False | False | False | False | False | — |
| `order_history_filter.dart` | False | False | False | False | False | False | — |
| `page_header.dart` | False | False | False | False | False | False | — |
| `permission_denied_scaffold.dart` | False | True | False | False | False | False | — |
| `pull_to_refresh_wrapper.dart` | False | False | False | False | False | False | — |
| `refund_history_widget.dart` | False | False | False | False | False | False | — |
| `responsive_grid.dart` | False | False | False | False | False | False | — |
| `responsive_scaffold.dart` | False | False | False | False | False | False | — |
| `safe_network_avatar.dart` | False | False | False | False | False | False | — |
| `section_async_error.dart` | False | False | False | False | False | False | — |
| `session_activity_timeline.dart` | False | False | False | False | False | False | — |
| `session_summary_breakdown.dart` | False | False | False | False | False | False | — |
| `shimmer_skeleton.dart` | False | False | False | False | False | False | — |
| `skeleton_loader.dart` | False | False | False | False | False | False | — |
| `stat_card.dart` | False | False | False | False | False | False | — |
| `table_search_delegate.dart` | False | False | False | False | False | False | — |
| `table_skeletons.dart` | False | False | False | False | False | False | — |
| `widgets.dart` | False | False | False | False | False | False | — |
| `workspace_nav_popover.dart` | False | False | False | False | False | False | — |

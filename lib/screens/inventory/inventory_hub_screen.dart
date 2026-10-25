import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/permission_id.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/permission_denied_scaffold.dart';
import 'inventory_analysis_screen.dart';
import 'inventory_pricing_screen.dart';
import 'receive_stock_screen.dart';
import 'stock_receipts_list_screen.dart';
import 'vendors_list_screen.dart';

/// Vendor receiving, vendors CRUD, receipt history, pricing, and analysis.
class InventoryHubScreen extends ConsumerStatefulWidget {
  const InventoryHubScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<InventoryHubScreen> createState() => _InventoryHubScreenState();
}

class _InventoryHubScreenState extends ConsumerState<InventoryHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final idx = widget.initialTabIndex.clamp(0, 4);
    _tabController = TabController(length: 5, vsync: this, initialIndex: idx);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watchResolvedPermissions();
    if (!perms.can(PermissionIds.navInventory)) {
      return const PermissionDeniedScaffold(
        title: 'Inventory',
        message: 'You do not have access to inventory.',
      );
    }

    final isMobile = AppTheme.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isMobile,
          tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
          tabs: const [
            Tab(text: 'Receive'),
            Tab(text: 'Vendors'),
            Tab(text: 'Receipts'),
            Tab(text: 'Pricing'),
            Tab(text: 'Analysis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ReceiveStockScreen(),
          VendorsListScreen(),
          StockReceiptsListScreen(),
          InventoryPricingScreen(),
          InventoryAnalysisScreen(),
        ],
      ),
    );
  }
}

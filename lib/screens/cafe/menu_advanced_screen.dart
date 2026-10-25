import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/menu_advanced.dart';
import '../../providers/tenant_provider.dart';
import '../../services/menu_advanced_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class MenuAdvancedScreen extends ConsumerStatefulWidget {
  const MenuAdvancedScreen({super.key});

  @override
  ConsumerState<MenuAdvancedScreen> createState() =>
      _MenuAdvancedScreenState();
}

class _MenuAdvancedScreenState extends ConsumerState<MenuAdvancedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu management'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Recipes'),
            Tab(text: 'Waste tracking'),
            Tab(text: 'Daily specials'),
            Tab(text: 'Nutrition'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _RecipesTab(),
          _WasteTab(),
          _SpecialsTab(),
          _NutritionTab(),
        ],
      ),
    );
  }
}

class _RecipesTab extends ConsumerWidget {
  const _RecipesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<Recipe>>(
      stream: MenuAdvancedService(tenant).watchRecipes(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final recipes = snap.data ?? [];
        if (recipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text('No recipes yet', style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: recipes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = recipes[i];
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.itemName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (r.prepTimeMinutes > 0)
                    Text(
                      'Prep: ${r.prepTimeMinutes} min',
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingredients: ${r.ingredients.map((e) => '${e.quantity} ${e.unit} ${e.name}').join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WasteTab extends ConsumerWidget {
  const _WasteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<FoodWasteEntry>>(
      stream: MenuAdvancedService(tenant).watchWaste(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final entries = snap.data ?? [];
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No waste recorded',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final e = entries[i];
            return AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.delete_sweep,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.itemName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${e.quantity} units \u2022 ${e.reason}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${e.date.day}/${e.date.month}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SpecialsTab extends ConsumerWidget {
  const _SpecialsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return StreamBuilder<List<DailySpecial>>(
      stream: MenuAdvancedService(tenant).watchTodaySpecials(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerList();
        }
        final specials = snap.data ?? [];
        if (specials.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_outline,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No specials today',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: specials.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final s = specials[i];
            return AppCard(
              child: Row(
                children: [
                  Icon(Icons.star, color: Theme.of(context).colorScheme.tertiary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.itemName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (s.description != null)
                          Text(
                            s.description!,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (s.specialPrice != null)
                    Text(
                      '\u20B9${s.specialPrice!.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NutritionTab extends StatelessWidget {
  const _NutritionTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.monitor_heart_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Nutritional information',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add allergens, calories, and macros\nto individual menu items from stock settings.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

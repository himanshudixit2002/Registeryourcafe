import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../legal/legal_launch.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';

/// One entry in the workspace module grid.
class WorkspaceNavItem {
  const WorkspaceNavItem({
    required this.title,
    required this.icon,
    required this.activeIcon,
  });

  final String title;
  final IconData icon;
  final IconData activeIcon;
}

/// Glass “bento” grid of modules; opens from the workspace hub with staggered tiles.
class WorkspaceNavPopover extends StatefulWidget {
  const WorkspaceNavPopover({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onClose,
  });

  final List<WorkspaceNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onClose;

  @override
  State<WorkspaceNavPopover> createState() => _WorkspaceNavPopoverState();
}

class _WorkspaceNavPopoverState extends State<WorkspaceNavPopover>
    with SingleTickerProviderStateMixin {
  late AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _stagger.forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 520;
    final crossAxisCount = isCompact ? 2 : 3;
    final n = widget.items.length;

    return Material(
      color: Colors.transparent,
      child: GlassPanel(
        blur: GlassBlur.modal,
        borderRadius: 0,
        borderRadiusGeometry: const BorderRadius.only(
          topRight: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        borderColor: theme.colorScheme.primary.withValues(alpha: 0.32),
        padding: const EdgeInsets.fromLTRB(18, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workspace',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Modules',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: AnimatedBuilder(
                animation: _stagger,
                builder: (context, _) {
                  return GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: isCompact ? 1.02 : 1.12,
                    ),
                    itemCount: n,
                    itemBuilder: (context, i) {
                      final start = i / (n + 2);
                      final span = 0.55;
                      final t = ((_stagger.value - start) / span).clamp(
                        0.0,
                        1.0,
                      );
                      final curved = Curves.easeOutCubic.transform(t);
                      final item = widget.items[i];
                      final selected = i == widget.selectedIndex;
                      return Opacity(
                        opacity: curved,
                        child: Transform.translate(
                          offset: Offset(0, (1 - curved) * 16),
                          child: Transform.scale(
                            scale: 0.94 + 0.06 * curved,
                            child: _NavTile(
                              item: item,
                              selected: selected,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onSelected(i);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 20),
            TextButton.icon(
              onPressed: () {
                widget.onClose();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    LegalLaunch.showLegalSupportSheet(context);
                  }
                });
              },
              icon: const Icon(Icons.policy_outlined, size: 20),
              label: const Text('Legal & support'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final WorkspaceNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        child: AnimatedContainer(
          duration: AppTheme.kAnimationDurationShort,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
            color: selected
                ? cs.primary.withValues(alpha: 0.18)
                : cs.surfaceContainerHighest.withValues(alpha: 0.35),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.55)
                  : cs.outline.withValues(alpha: 0.14),
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 26,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? cs.primary : cs.onSurface,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

Color _onSaturatedAccent(Color accent, ColorScheme cs) {
  return accent.computeLuminance() < 0.5 ? cs.onPrimary : cs.onSurface;
}

/// A mobile-optimized plan/membership selector with smooth animations
/// Replaces DataTable for better touch experience on small screens
class MobilePlanSelector<T> extends StatefulWidget {
  final List<PlanOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T?> onChanged;
  final String? title;
  final bool showCompactView;

  const MobilePlanSelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.title,
    this.showCompactView = false,
  });

  @override
  State<MobilePlanSelector<T>> createState() => _MobilePlanSelectorState<T>();
}

class _MobilePlanSelectorState<T> extends State<MobilePlanSelector<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.options.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final option = widget.options[index];
            final isSelected = option.value == widget.selectedValue;
            return _MobilePlanCard<T>(
              option: option,
              isSelected: isSelected,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onChanged(option.value);
              },
              showCompact: widget.showCompactView,
              animationDelay: index * 50,
            );
          },
        ),
      ],
    );
  }
}

class _MobilePlanCard<T> extends StatefulWidget {
  final PlanOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showCompact;
  final int animationDelay;

  const _MobilePlanCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
    this.showCompact = false,
    this.animationDelay = 0,
  });

  @override
  State<_MobilePlanCard<T>> createState() => _MobilePlanCardState<T>();
}

class _MobilePlanCardState<T> extends State<_MobilePlanCard<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    Future<void>.delayed(Duration(milliseconds: widget.animationDelay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final option = widget.option;
    final primaryColor = option.color ?? theme.colorScheme.primary;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            ),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: Transform.scale(
            scale: _isPressed ? 0.98 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.all(widget.showCompact ? 12 : 16),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? primaryColor.withValues(alpha: 0.08)
                    : cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isSelected ? primaryColor : cs.outlineVariant,
                  width: widget.isSelected ? 2 : 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  // Selection indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isSelected
                          ? primaryColor
                          : Colors.transparent,
                      border: Border.all(
                        color: widget.isSelected ? primaryColor : cs.outline,
                        width: 2,
                      ),
                    ),
                    child: widget.isSelected
                        ? Icon(
                            Icons.check_rounded,
                            color: _onSaturatedAccent(primaryColor, cs),
                            size: 16,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  // Plan icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      option.icon ?? Icons.card_membership,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Plan details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                option.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: widget.isSelected
                                      ? primaryColor
                                      : cs.onSurface,
                                ),
                              ),
                            ),
                            if (option.badge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  option.badge!,
                                  style: TextStyle(
                                    color: _onSaturatedAccent(primaryColor, cs),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (option.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            option.subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (!widget.showCompact &&
                            option.details.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: option.details.map((detail) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  detail,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Price
                  if (option.price != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          option.price!,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        if (option.priceSubtitle != null)
                          Text(
                            option.priceSubtitle!,
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Data class for plan options
class PlanOption<T> {
  final T value;
  final String title;
  final String? subtitle;
  final String? price;
  final String? priceSubtitle;
  final IconData? icon;
  final Color? color;
  final String? badge;
  final List<String> details;

  const PlanOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.price,
    this.priceSubtitle,
    this.icon,
    this.color,
    this.badge,
    this.details = const [],
  });
}

/// A compact chip-based selector for horizontal layouts
class MobileChipSelector<T> extends StatelessWidget {
  final List<ChipOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T?> onChanged;
  final bool scrollable;

  const MobileChipSelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget buildChips() {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = option.value == selectedValue;
          final color = option.color ?? theme.colorScheme.primary;

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(opacity: value, child: child),
            ),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(option.value);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? color : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : cs.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (option.icon != null) ...[
                      Icon(
                        option.icon,
                        size: 16,
                        color: isSelected
                            ? _onSaturatedAccent(color, cs)
                            : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? _onSaturatedAccent(color, cs)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: AppTheme.scrollPhysicsFor(context),
        child: buildChips(),
      );
    }

    return buildChips();
  }
}

/// Data class for chip options
class ChipOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;

  const ChipOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });
}

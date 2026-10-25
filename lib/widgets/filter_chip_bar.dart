import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Describes a single filter chip inside [FilterChipBar].
class FilterChipDef {
  const FilterChipDef({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
}

/// Describes a dropdown filter inside [FilterChipBar].
class FilterDropdownDef<T> {
  const FilterDropdownDef({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
}

/// Unified filter bar with search field and filter chips/dropdowns.
///
/// On mobile: search as a compact pill with horizontal-scroll chips below.
/// On desktop: inline row with search and dropdowns side by side.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    this.searchHint = 'Search...',
    this.searchValue = '',
    this.onSearchChanged,
    this.chips = const [],
    this.dropdowns = const [],
    this.trailing,
    this.hasActiveFilters = false,
    this.onClearFilters,
  });

  final String searchHint;
  final String searchValue;
  final ValueChanged<String>? onSearchChanged;
  final List<FilterChipDef> chips;
  final List<FilterDropdownDef<dynamic>> dropdowns;
  final Widget? trailing;
  final bool hasActiveFilters;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: isMobile ? 6 : 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchRow(theme, isMobile),
          if (chips.isNotEmpty || dropdowns.isNotEmpty) ...[
            SizedBox(height: isMobile ? 6 : 8),
            _buildFilters(context, theme, isMobile),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchRow(ThemeData theme, bool isMobile) {
    return Container(
      height: isMobile ? 40 : 46,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: isMobile ? 18 : 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 14,
                  vertical: isMobile ? 10 : 12,
                ),
              ),
              style: TextStyle(fontSize: isMobile ? 13 : 14),
              onChanged: onSearchChanged,
            ),
          ),
          if (hasActiveFilters && onClearFilters != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: Icon(
                  Icons.filter_alt_off_rounded,
                  size: isMobile ? 18 : 20,
                  color: theme.colorScheme.primary,
                ),
                tooltip: 'Clear filters',
                onPressed: onClearFilters,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: trailing!,
            ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, ThemeData theme, bool isMobile) {
    final List<Widget> filterWidgets = [];

    for (final chip in chips) {
      filterWidgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: Text(chip.label),
            selected: chip.selected,
            onSelected: (_) => chip.onTap(),
            avatar: chip.icon != null ? Icon(chip.icon, size: 16) : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
            labelStyle: TextStyle(fontSize: isMobile ? 11 : 13),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
          ),
        ),
      );
    }

    for (final dropdown in dropdowns) {
      filterWidgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _CompactDropdown(
            dropdown: dropdown,
            isMobile: isMobile,
          ),
        ),
      );
    }

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: filterWidgets),
      );
    }

    return Wrap(
      spacing: 0,
      runSpacing: 6,
      children: filterWidgets,
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  const _CompactDropdown({required this.dropdown, required this.isMobile});

  final FilterDropdownDef<dynamic> dropdown;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = dropdown.value != null;

    return Container(
      height: isMobile ? 32 : 36,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: hasValue
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
        border: Border.all(
          color: hasValue
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<dynamic>(
          value: dropdown.value,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dropdown.icon != null) ...[
                Icon(dropdown.icon, size: isMobile ? 14 : 16),
                const SizedBox(width: 4),
              ],
              Text(
                dropdown.label,
                style: TextStyle(fontSize: isMobile ? 11 : 13),
              ),
            ],
          ),
          items: [
            DropdownMenuItem<dynamic>(
              value: null,
              child: Text(
                'All',
                style: TextStyle(fontSize: isMobile ? 11 : 13),
              ),
            ),
            ...dropdown.items,
          ],
          onChanged: dropdown.onChanged,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, size: isMobile ? 16 : 20),
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

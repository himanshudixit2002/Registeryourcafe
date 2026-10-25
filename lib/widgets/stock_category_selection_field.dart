import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../firestore/tenant_firestore.dart';
import '../theme/app_theme.dart';

/// Category dropdown + optional “new category” name field for café / merchandise
/// stock dialogs. Uses a controlled [DropdownButtonFormField.value] and defers
/// focus to the text field after the dropdown closes (avoids keyboard fights).
class StockCategorySelectionField extends StatefulWidget {
  const StockCategorySelectionField({
    super.key,
    required this.tenant,
    required this.isMerchandise,
    required this.selectedCategory,
    required this.addingNewCategory,
    required this.newCategoryController,
    required this.onCategorySelected,
    required this.onAddNewToggled,
  });

  final TenantRef tenant;
  final bool isMerchandise;
  final String? selectedCategory;
  final bool addingNewCategory;
  final TextEditingController newCategoryController;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<bool> onAddNewToggled;

  static const String addNewMarker = '__ADD_NEW__';

  @override
  State<StockCategorySelectionField> createState() =>
      _StockCategorySelectionFieldState();
}

class _StockCategorySelectionFieldState
    extends State<StockCategorySelectionField> {
  late final FocusNode _newCategoryFocus;

  @override
  void initState() {
    super.initState();
    _newCategoryFocus = FocusNode();
  }

  @override
  void dispose() {
    _newCategoryFocus.dispose();
    super.dispose();
  }

  void _deferFocusNewCategoryField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _newCategoryFocus.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.tenant
          .categories()
          .where('isMerchandise', isEqualTo: widget.isMerchandise)
          .orderBy('name')
          .snapshots(),
      builder: (context, catSnapshot) {
        if (catSnapshot.connectionState == ConnectionState.waiting) {
          return AbsorbPointer(
            child: DropdownButtonFormField<String>(
              hint: const Text('Loading categories...'),
              decoration: AppTheme.baseInputDecoration.copyWith(
                labelText: 'Category',
                prefixIcon: const Icon(Icons.hourglass_empty_rounded),
              ),
              items: const [],
              onChanged: null,
            ),
          );
        }

        if (catSnapshot.hasError) {
          return TextFormField(
            initialValue: 'Could not load categories.',
            readOnly: true,
            decoration: AppTheme.baseInputDecoration.copyWith(
              labelText: 'Category',
              prefixIcon: Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          );
        }

        final categories =
            catSnapshot.data?.docs
                .map(
                  (e) => (e.data() as Map<String, dynamic>)['name'] as String? ?? '',
                )
                .toSet()
                .toList() ??
            [];

        if (widget.selectedCategory != null &&
            !categories.contains(widget.selectedCategory)) {
          categories.insert(0, widget.selectedCategory!);
        }

        if (!categories.contains(StockCategorySelectionField.addNewMarker)) {
          categories.add(StockCategorySelectionField.addNewMarker);
        }

        final existingCategoriesLower = categories
            .where((c) => c != StockCategorySelectionField.addNewMarker)
            .map((c) => c.toLowerCase())
            .toList();

        final theme = Theme.of(context);
        final categoryMenuItems = categories
            .map(
              (c) => DropdownMenuItem<String>(
                value: c,
                child: Text(
                  c == StockCategorySelectionField.addNewMarker
                      ? '+ Add New Category'
                      : c,
                  style: TextStyle(
                    color: c == StockCategorySelectionField.addNewMarker
                        ? theme.colorScheme.primary
                        : null,
                    fontWeight: c == StockCategorySelectionField.addNewMarker
                        ? FontWeight.bold
                        : null,
                  ),
                ),
              ),
            )
            .toList();

        final String? dropdownValue = widget.addingNewCategory
            ? StockCategorySelectionField.addNewMarker
            : widget.selectedCategory;

        final itemValues = categoryMenuItems
            .map((e) => e.value)
            .whereType<String>()
            .toSet();
        final String? safeValue =
            dropdownValue != null && itemValues.contains(dropdownValue)
            ? dropdownValue
            : null;

        // Key forces FormField state to reset when parent selection mode changes
        // (initialValue is only applied on first mount for this field type).
        final dropdownKey =
            '${widget.addingNewCategory}|${widget.selectedCategory ?? ''}|'
            '${Object.hashAll(categories)}';

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey<String>(dropdownKey),
              initialValue: safeValue,
              isExpanded: true,
              decoration: AppTheme.baseInputDecoration.copyWith(
                labelText: 'Category',
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              items: categoryMenuItems,
              selectedItemBuilder: (context) =>
                  AppTheme.dropdownSelectedItemBuilders(
                    theme,
                    categoryMenuItems,
                  ),
              onChanged: widget.addingNewCategory
                  ? null
                  : (v) {
                      if (v == StockCategorySelectionField.addNewMarker) {
                        widget.onAddNewToggled(true);
                        _deferFocusNewCategoryField();
                      } else {
                        widget.onCategorySelected(v);
                      }
                    },
              validator: (_) {
                if (!widget.addingNewCategory &&
                    (widget.selectedCategory == null ||
                        widget.selectedCategory!.isEmpty)) {
                  return 'Please select a category.';
                }
                return null;
              },
            ),
            if (widget.addingNewCategory) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('stock_new_category_name'),
                controller: widget.newCategoryController,
                focusNode: _newCategoryFocus,
                decoration: AppTheme.baseInputDecoration.copyWith(
                  labelText: 'New Category Name',
                  prefixIcon: const Icon(Icons.new_label_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: AppStrings.cancel,
                    onPressed: () {
                      widget.onAddNewToggled(false);
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category name.';
                  }
                  if (existingCategoriesLower.contains(
                    value.trim().toLowerCase(),
                  )) {
                    return 'This category already exists.';
                  }
                  return null;
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

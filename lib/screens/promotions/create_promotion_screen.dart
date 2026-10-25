import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/promotion.dart';
import '../../providers/promotion_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_card.dart';

class CreatePromotionScreen extends ConsumerStatefulWidget {
  const CreatePromotionScreen({super.key});

  @override
  ConsumerState<CreatePromotionScreen> createState() =>
      _CreatePromotionScreenState();
}

class _CreatePromotionScreenState
    extends ConsumerState<CreatePromotionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _valueController = TextEditingController();
  final _couponController = TextEditingController();
  final _startHourController = TextEditingController();
  final _endHourController = TextEditingController();
  PromotionType _type = PromotionType.percentageDiscount;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _couponController.dispose();
    _startHourController.dispose();
    _endHourController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final promo = Promotion(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        type: _type,
        value: double.parse(_valueController.text.trim()),
        couponCode: _type == PromotionType.couponCode
            ? _couponController.text.trim().toUpperCase()
            : null,
        startDate: _startDate,
        endDate: _endDate,
        startHour: _type == PromotionType.happyHour
            ? _startHourController.text.trim()
            : null,
        endHour: _type == PromotionType.happyHour
            ? _endHourController.text.trim()
            : null,
        createdAt: DateTime.now(),
      );
      await ref
          .read(promotionServiceProvider)
          ?.createPromotion(promo);
      if (mounted) {
        context.showSuccessSnackbar('Promotion created');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppTheme.isDesktop(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New promotion')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(
          isDesktop
              ? AppTheme.kSpacingXLarge
              : AppTheme.kSpacingMedium,
          AppTheme.kSpacingMedium,
          isDesktop
              ? AppTheme.kSpacingXLarge
              : AppTheme.kSpacingMedium,
          AppTheme.kSpacingXLarge,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Promotion name',
                        prefixIcon:
                            Icon(Icons.local_offer_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        prefixIcon:
                            Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<PromotionType>(
                      value: _type,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        prefixIcon:
                            Icon(Icons.category_outlined),
                      ),
                      items: PromotionType.values
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t.label)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _type = v ?? _type),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _valueController,
                      decoration: InputDecoration(
                        labelText:
                            _type == PromotionType.flatDiscount
                                ? 'Amount (\u20B9)'
                                : 'Value (%)',
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(v.trim()) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                    if (_type == PromotionType.couponCode) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _couponController,
                        decoration: const InputDecoration(
                          labelText: 'Coupon code',
                          prefixIcon: Icon(
                              Icons.confirmation_number_outlined),
                        ),
                        textCapitalization:
                            TextCapitalization.characters,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required for coupon type'
                                : null,
                      ),
                    ],
                    if (_type == PromotionType.happyHour) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _startHourController,
                              decoration: const InputDecoration(
                                labelText:
                                    'Start hour (e.g. 14:00)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _endHourController,
                              decoration: const InputDecoration(
                                labelText:
                                    'End hour (e.g. 18:00)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                'Start: ${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime.now().subtract(
                                    const Duration(days: 30)),
                                lastDate: DateTime.now().add(
                                    const Duration(days: 365)),
                              );
                              if (d != null) {
                                setState(() => _startDate = d);
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                'End: ${_endDate.day}/${_endDate.month}/${_endDate.year}'),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                    const Duration(days: 365)),
                              );
                              if (d != null) {
                                setState(() => _endDate = d);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5),
                      )
                    : const Text('Create promotion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

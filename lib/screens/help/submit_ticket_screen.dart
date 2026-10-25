import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_card.dart';

class SubmitTicketScreen extends ConsumerStatefulWidget {
  const SubmitTicketScreen({super.key});

  @override
  ConsumerState<SubmitTicketScreen> createState() => _SubmitTicketScreenState();
}

class _SubmitTicketScreenState extends ConsumerState<SubmitTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  String _category = 'General';
  bool _submitting = false;

  static const _categories = ['General', 'Bug report', 'Feature request', 'Billing', 'Account'];

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    setState(() => _submitting = true);
    try {
      final user = ref.read(appUserProvider).valueOrNull;
      await tenant.companyDoc().collection('supportTickets').add({
        'subject': _subjectController.text.trim(),
        'body': _bodyController.text.trim(),
        'category': _category,
        'status': 'open',
        'companyId': tenant.companyId,
        'userEmail': user?.email ?? '',
        'userName': user?.name ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        context.showSuccessSnackbar('Support ticket submitted');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppTheme.isDesktop(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Submit support ticket')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingMedium,
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
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
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _category = v ?? _category),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.title)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _bodyController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe your issue or request in detail...',
                        prefixIcon: Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 6,
                      minLines: 3,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Submit ticket'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

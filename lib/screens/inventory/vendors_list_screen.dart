import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vendor.dart';
import '../../providers/tenant_provider.dart';
import '../../services/vendor_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/glass_panel.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class VendorsListScreen extends ConsumerStatefulWidget {
  const VendorsListScreen({super.key});

  @override
  ConsumerState<VendorsListScreen> createState() => _VendorsListScreenState();
}

class _VendorsListScreenState extends ConsumerState<VendorsListScreen> {
  Future<void> _showVendorDialog({Vendor? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    bool active = existing?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: Text(existing == null ? 'Add vendor' : 'Edit vendor'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: AppTheme.baseInputDecoration.copyWith(
                          labelText: 'Name',
                          prefixIcon: const Icon(Icons.business_outlined),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: AppTheme.baseInputDecoration.copyWith(
                          labelText: 'Phone (optional)',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: AppTheme.baseInputDecoration.copyWith(
                          labelText: 'Email (optional)',
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: AppTheme.baseInputDecoration.copyWith(
                          labelText: 'Notes (optional)',
                          prefixIcon: const Icon(Icons.notes_outlined),
                        ),
                      ),
                      if (existing != null) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
                          value: active,
                          onChanged: (v) => setS(() => active = v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(AppStrings.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  child: const Text(AppStrings.save),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
      emailController.dispose();
      notesController.dispose();
    }

    if (ok != true || !mounted) return;

    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) {
      if (mounted) {
        context.showErrorSnackbar('No company context');
      }
      return;
    }

    try {
      if (existing == null) {
        await VendorService.createVendor(
          tenant,
          name: nameController.text,
          phone: phoneController.text,
          email: emailController.text,
          notes: notesController.text,
        );
        if (mounted) {
          context.showSuccessSnackbar('Vendor added');
        }
      } else {
        await VendorService.updateVendor(
          tenant,
          id: existing.id,
          name: nameController.text,
          phone: phoneController.text,
          email: emailController.text,
          notes: notesController.text,
          isActive: active,
        );
        if (mounted) {
          context.showSuccessSnackbar('Vendor updated');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenant = ref.watch(tenantRefProvider);

    if (tenant == null) {
      return const Scaffold(body: Center(child: Text('No company context')));
    }

    return Scaffold(
      body: StreamBuilder<List<Vendor>>(
        stream: VendorService.watchVendors(tenant, activeOnly: false),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 56,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  const Text('No vendors yet'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showVendorDialog(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add vendor'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = list[i];
              return AppSurface(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(v.name),
                  subtitle: Text(
                    [
                      if (v.phone != null && v.phone!.isNotEmpty) v.phone!,
                      if (v.email != null && v.email!.isNotEmpty) v.email!,
                      if (!v.isActive) 'Inactive',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showVendorDialog(existing: v),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-vendors-list',
        onPressed: () => _showVendorDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Vendor'),
      ),
    );
  }
}

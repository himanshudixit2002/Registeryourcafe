import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/permission_id.dart';
import '../../firestore/tenant_firestore.dart';
import '../../models/public_menu_item.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/permission_denied_scaffold.dart';
import '../../services/storage_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/email_verification_guard.dart';
import '../../widgets/safe_network_avatar.dart';

/// CRUD for [TenantRef.publicMenuItems] (shown on public landing when discovery is on).
class PublicMenuEditorScreen extends ConsumerStatefulWidget {
  const PublicMenuEditorScreen({super.key});

  @override
  ConsumerState<PublicMenuEditorScreen> createState() =>
      _PublicMenuEditorScreenState();
}

class _PublicMenuEditorScreenState extends ConsumerState<PublicMenuEditorScreen> {
  Future<void> _openItemDialog(
    TenantRef tenant,
    PublicMenuItem? existing,
  ) async {
    if (existing?.syncedFromStock == true) return;
    if (!EmailVerificationGuard.requireVerifiedForSensitiveAction(context)) {
      return;
    }
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    final descCtl = TextEditingController(text: existing?.description ?? '');
    final priceCtl = TextEditingController(
      text: existing != null ? existing.price.toString() : '',
    );
    final catCtl = TextEditingController(text: existing?.categoryLabel ?? '');
    final sortCtl = TextEditingController(text: '${existing?.sortOrder ?? 0}');
    var available = existing?.isAvailable ?? true;

    Uint8List? pickedBytes;
    String? pickedExt;
    var clearImage = false;
    final String? currentImageUrl = existing?.imageUrl;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(existing == null ? 'Add menu item' : 'Edit item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (pickedBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.memory(
                              pickedBytes!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          SafeNetworkAvatar(
                            imageUrl: clearImage ? null : currentImageUrl,
                            radius: 28,
                            fallbackIcon: Icons.restaurant_rounded,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final result =
                                      await FilePicker.platform.pickFiles(
                                        type: FileType.image,
                                        withData: true,
                                      );
                                  if (result == null ||
                                      result.files.isEmpty ||
                                      result.files.single.bytes == null) {
                                    return;
                                  }
                                  final f = result.files.single;
                                  final ext = (f.extension ?? 'jpg')
                                      .toLowerCase();
                                  setLocal(() {
                                    pickedBytes = f.bytes;
                                    pickedExt = ext;
                                    clearImage = false;
                                  });
                                },
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text('Photo'),
                              ),
                              if ((currentImageUrl != null &&
                                      currentImageUrl.trim().isNotEmpty) ||
                                  pickedBytes != null)
                                TextButton(
                                  onPressed: () => setLocal(() {
                                    clearImage = true;
                                    pickedBytes = null;
                                    pickedExt = null;
                                  }),
                                  child: const Text('Remove photo'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: descCtl,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                      maxLines: 2,
                    ),
                    TextField(
                      controller: priceCtl,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                    TextField(
                      controller: catCtl,
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                      ),
                    ),
                    TextField(
                      controller: sortCtl,
                      decoration: const InputDecoration(
                        labelText: 'Sort order',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Available on public menu'),
                      value: available,
                      onChanged: (v) => setLocal(() => available = v),
                    ),
                  ],
                ),
              ),
              actions: [
                if (existing != null)
                  TextButton(
                    onPressed: () async {
                      if (!EmailVerificationGuard
                          .requireVerifiedForSensitiveAction(ctx)) {
                        return;
                      }
                      await tenant.publicMenuItems().doc(existing.id).delete();
                      if (ctx.mounted) Navigator.pop(ctx, false);
                    },
                    child: const Text('Delete'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) {
      nameCtl.dispose();
      descCtl.dispose();
      priceCtl.dispose();
      catCtl.dispose();
      sortCtl.dispose();
      return;
    }

    final price = double.tryParse(priceCtl.text.trim()) ?? 0;
    final sort = int.tryParse(sortCtl.text.trim()) ?? 0;
    final docRef = existing != null
        ? tenant.publicMenuItems().doc(existing.id)
        : tenant.publicMenuItems().doc();

    String? finalImageUrl;
    if (clearImage) {
      finalImageUrl = null;
    } else if (pickedBytes != null && pickedBytes!.isNotEmpty) {
      try {
        if (mounted) {
          unawaited(
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  const Center(child: CircularProgressIndicator()),
            ),
          );
        }
        finalImageUrl = await ref.read(storageServiceProvider).uploadPublicMenuItemImage(
              data: pickedBytes!,
              companyId: tenant.companyId,
              itemId: docRef.id,
              fileExt: pickedExt ?? 'jpg',
            );
      } catch (e, st) {
        AppLogger.error(
          'Public menu image upload failed',
          error: e,
          stackTrace: st,
          tag: 'PublicMenuEditor',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image upload failed: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        nameCtl.dispose();
        descCtl.dispose();
        priceCtl.dispose();
        catCtl.dispose();
        sortCtl.dispose();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        return;
      } finally {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
    } else {
      finalImageUrl = existing?.imageUrl;
    }

    final item = PublicMenuItem(
      id: docRef.id,
      name: nameCtl.text.trim().isEmpty ? 'Item' : nameCtl.text.trim(),
      description: descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
      price: price,
      categoryLabel: catCtl.text.trim().isEmpty ? null : catCtl.text.trim(),
      sortOrder: sort,
      isAvailable: available,
      imageUrl: finalImageUrl,
      syncedFromStock: false,
    );

    nameCtl.dispose();
    descCtl.dispose();
    priceCtl.dispose();
    catCtl.dispose();
    sortCtl.dispose();

    final payload = item.toFirestore();
    if (clearImage) {
      payload['imageUrl'] = FieldValue.delete();
    }
    await docRef.set(payload, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenant = ref.watch(tenantRefProvider);
    if (tenant == null) {
      return const Scaffold(body: Center(child: Text('No company context.')));
    }

    if (!ref.watchResolvedPermissions().can(PermissionIds.settingsModules)) {
      return const PermissionDeniedScaffold(
        title: 'Public menu',
        message: 'You do not have permission to edit the public menu.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Public menu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openItemDialog(tenant, null),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tenant.publicMenuItems().orderBy('sortOrder').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No menu items yet. Add dishes here, or mark items as sellable in Café stock — they sync here. '
                'Guests only see name, description, and price (never stock counts).',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = PublicMenuItem.fromFirestore(docs[i]);
              final synced = item.syncedFromStock;
              return Card(
                child: ListTile(
                  leading: SafeNetworkAvatar(
                    imageUrl: item.imageUrl,
                    radius: 22,
                    fallbackIcon: Icons.restaurant_rounded,
                  ),
                  title: Text(item.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (synced)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Synced from Café inventory — edit sellable, price, and stock there.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (item.description != null &&
                          item.description!.trim().isNotEmpty)
                        Text(item.description!)
                      else
                        Text(
                          item.isAvailable ? 'Available' : 'Hidden',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  trailing: Text(
                    '\u20B9${item.price.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: synced
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'This row is synced from Café stock. Open Café → Stock to change it.',
                              ),
                            ),
                          );
                        }
                      : () => _openItemDialog(tenant, item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

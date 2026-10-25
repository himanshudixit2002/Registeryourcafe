import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/firestore_collections.dart';
import '../../firestore/tenant_firestore.dart';
import '../../models/public_venue_listing.dart';
import '../../models/venue_kind.dart';
import '../../auth/permission_id.dart';
import '../../providers/company_module_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/permission_denied_scaffold.dart';
import '../../services/public_venue_sync_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/email_verification_guard.dart';
import '../../widgets/safe_network_avatar.dart';
import 'public_menu_editor_screen.dart';

/// Opt-in public listing: anonymous users see this venue on the landing app.
class PublicDiscoverySettingsScreen extends ConsumerStatefulWidget {
  const PublicDiscoverySettingsScreen({super.key});

  @override
  ConsumerState<PublicDiscoverySettingsScreen> createState() =>
      _PublicDiscoverySettingsScreenState();
}

class _PublicDiscoverySettingsScreenState
    extends ConsumerState<PublicDiscoverySettingsScreen> {
  final _displayNameCtl = TextEditingController();
  final _taglineCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _hoursCtl = TextEditingController();
  final _cityCtl = TextEditingController();
  final _areaCtl = TextEditingController();
  final _discoveryTagsCtl = TextEditingController();

  String? _seedKey;
  String _defaultDisplayName = '';
  bool _saving = false;
  String? _coverImageUrl;

  @override
  void dispose() {
    _displayNameCtl.dispose();
    _taglineCtl.dispose();
    _addressCtl.dispose();
    _phoneCtl.dispose();
    _hoursCtl.dispose();
    _cityCtl.dispose();
    _areaCtl.dispose();
    _discoveryTagsCtl.dispose();
    super.dispose();
  }

  void _applyDocToControllers(
    DocumentSnapshot<Map<String, dynamic>>? doc,
    VenueKind venueKind,
  ) {
    final key = '${doc?.id ?? ''}_${doc?.data()?.toString() ?? 'none'}';
    if (key == _seedKey) return;
    _seedKey = key;

    if (doc != null && doc.exists && doc.data() != null) {
      final l = PublicVenueListing.fromFirestore(doc);
      _displayNameCtl.text = l.displayName;
      _taglineCtl.text = l.tagline ?? '';
      _addressCtl.text = l.address ?? '';
      _phoneCtl.text = l.phone ?? '';
      _hoursCtl.text = l.hoursNote ?? '';
      _cityCtl.text = l.city ?? '';
      _areaCtl.text = l.area ?? '';
      _discoveryTagsCtl.text = l.discoveryTags.join(', ');
      _coverImageUrl = l.coverImageUrl;
    } else {
      _displayNameCtl.text = _defaultDisplayName;
      _taglineCtl.clear();
      _addressCtl.clear();
      _phoneCtl.clear();
      _hoursCtl.clear();
      _cityCtl.clear();
      _areaCtl.clear();
      _discoveryTagsCtl.clear();
      _coverImageUrl = null;
    }
  }

  static List<String> _parseTagsInput(String raw) {
    return raw
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .take(24)
        .toList();
  }

  Future<void> _loadDefaultName(TenantRef tenant) async {
    if (_defaultDisplayName.isNotEmpty) return;
    final snap = await tenant.companyDoc().get();
    final n = snap.data()?['name'] as String?;
    if (mounted) {
      setState(() {
        _defaultDisplayName = (n != null && n.trim().isNotEmpty) ? n : 'Venue';
      });
    }
  }

  Future<void> _persistListing({
    required TenantRef tenant,
    required VenueKind venueKind,
    required bool showOnDiscovery,
  }) async {
    final listing = PublicVenueListing(
      companyId: tenant.companyId,
      displayName: _displayNameCtl.text.trim().isEmpty
          ? _defaultDisplayName
          : _displayNameCtl.text.trim(),
      venueKind: venueKind,
      tagline: _taglineCtl.text.trim().isEmpty ? null : _taglineCtl.text.trim(),
      showOnDiscovery: showOnDiscovery,
      address: _addressCtl.text.trim().isEmpty ? null : _addressCtl.text.trim(),
      phone: _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
      hoursNote: _hoursCtl.text.trim().isEmpty ? null : _hoursCtl.text.trim(),
      city: _cityCtl.text.trim().isEmpty ? null : _cityCtl.text.trim(),
      area: _areaCtl.text.trim().isEmpty ? null : _areaCtl.text.trim(),
      discoveryTags: _parseTagsInput(_discoveryTagsCtl.text),
      coverImageUrl:
          _coverImageUrl != null && _coverImageUrl!.trim().isNotEmpty
          ? _coverImageUrl!.trim()
          : null,
    );

    final payload = listing.toFirestore();
    if (listing.coverImageUrl == null) {
      payload['coverImageUrl'] = FieldValue.delete();
    }

    await FirebaseFirestore.instance
        .collection(FirestoreCollections.publicVenues)
        .doc(tenant.companyId)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> _setDiscovery(
    TenantRef tenant,
    VenueKind venueKind,
    bool enabled,
  ) async {
    if (enabled &&
        !EmailVerificationGuard.requireVerifiedForSensitiveAction(context)) {
      return;
    }
    setState(() => _saving = true);
    try {
      if (enabled) {
        await _loadDefaultName(tenant);
        await _persistListing(
          tenant: tenant,
          venueKind: venueKind,
          showOnDiscovery: true,
        );
        await PublicVenueSyncService.backfillAllTables(tenant);
        await PublicVenueSyncService.backfillPublicMenuFromStock(tenant);
      } else {
        await PublicVenueSyncService.clearPublicFloor(tenant);
        await _persistListing(
          tenant: tenant,
          venueKind: venueKind,
          showOnDiscovery: false,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Public discovery is on. Live floor will update as tables change.'
                  : 'Public discovery is off. Floor mirrors were cleared.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDetailsOnly(
    TenantRef tenant,
    VenueKind venueKind,
    bool currentDiscoveryFlag,
  ) async {
    if (currentDiscoveryFlag &&
        !EmailVerificationGuard.requireVerifiedForSensitiveAction(context)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _persistListing(
        tenant: tenant,
        venueKind: venueKind,
        showOnDiscovery: currentDiscoveryFlag,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Listing saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickCoverPhoto(
    TenantRef tenant, {
    required bool listingIsLive,
  }) async {
    if (listingIsLive &&
        !EmailVerificationGuard.requireVerifiedForSensitiveAction(context)) {
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.single.bytes == null) {
      return;
    }
    final f = result.files.single;
    final bytes = f.bytes!;
    final ext = (f.extension ?? 'jpg').toLowerCase();

    setState(() => _saving = true);
    try {
      if (mounted) {
        unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          ),
        );
      }
      final url = await ref.read(storageServiceProvider).uploadPublicVenueCover(
            data: bytes,
            companyId: tenant.companyId,
            fileExt: ext,
          );
      if (mounted) {
        setState(() => _coverImageUrl = url);
      }
    } catch (e, st) {
      AppLogger.error(
        'Cover upload failed',
        error: e,
        stackTrace: st,
        tag: 'PublicDiscovery',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cover upload failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tenant = ref.watch(tenantRefProvider);
    final profile = ref.watch(companyProfileProvider).valueOrNull;

    if (tenant == null || profile == null) {
      return const Scaffold(body: Center(child: Text('Loading…')));
    }

    if (!ref.watchResolvedPermissions().can(PermissionIds.settingsModules)) {
      return const PermissionDeniedScaffold(
        title: 'Public discovery',
        message:
            'You do not have permission to manage public discovery settings.',
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultName(tenant);
    });

    final pubRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.publicVenues)
        .doc(tenant.companyId);

    return Scaffold(
      appBar: AppBar(title: const Text('Public discovery')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: pubRef.snapshots(),
        builder: (context, snap) {
          final doc = snap.data;
          final discoveryOn = doc?.data()?['showOnDiscovery'] == true;
          _applyDocToControllers(doc, profile.venueKind);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'When enabled, your venue appears under Discover on the sign-in landing page. '
                'Only safe fields are public: name, tagline, live table status mirror, and your public menu '
                '(names, descriptions, prices — never stock counts).',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Show on public landing'),
                subtitle: Text(
                  'Venue kind: ${profile.venueKind.label} (from registration)',
                ),
                value: discoveryOn,
                onChanged: _saving
                    ? null
                    : (v) => _setDiscovery(tenant, profile.venueKind, v),
              ),
              const Divider(height: 32),
              Text(
                'Cover photo (optional)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SafeNetworkAvatar(
                    imageUrl: _coverImageUrl,
                    radius: 36,
                    fallbackIcon: Icons.store_mall_directory_outlined,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _pickCoverPhoto(
                                    tenant,
                                    listingIsLive: discoveryOn,
                                  ),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Upload cover'),
                        ),
                        if (_coverImageUrl != null &&
                            _coverImageUrl!.trim().isNotEmpty)
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _coverImageUrl = null),
                            child: const Text('Remove cover'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _displayNameCtl,
                decoration: const InputDecoration(
                  labelText: 'Public display name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _taglineCtl,
                decoration: const InputDecoration(
                  labelText: 'Tagline (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtl,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtl,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hoursCtl,
                decoration: const InputDecoration(
                  labelText: 'Hours note (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityCtl,
                decoration: const InputDecoration(
                  labelText: 'City (optional)',
                  helperText: 'Helps guests find you in search',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _areaCtl,
                decoration: const InputDecoration(
                  labelText: 'Area / neighborhood (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _discoveryTagsCtl,
                decoration: const InputDecoration(
                  labelText: 'Discovery tags (optional)',
                  helperText: 'Comma-separated, e.g. italian, outdoor, wifi',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () => _saveDetailsOnly(
                        tenant,
                        profile.venueKind,
                        discoveryOn,
                      ),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save details'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving || !discoveryOn
                    ? null
                    : () async {
                        if (!EmailVerificationGuard
                            .requireVerifiedForSensitiveAction(context)) {
                          return;
                        }
                        setState(() => _saving = true);
                        try {
                          await PublicVenueSyncService.backfillAllTables(
                            tenant,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Public floor refreshed.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh public floor'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PublicMenuEditorScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Edit public menu'),
              ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}

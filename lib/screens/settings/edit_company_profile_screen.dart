import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/company_module_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/company_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_card.dart';

class EditCompanyProfileScreen extends ConsumerStatefulWidget {
  const EditCompanyProfileScreen({super.key});

  @override
  ConsumerState<EditCompanyProfileScreen> createState() =>
      _EditCompanyProfileScreenState();
}

class _EditCompanyProfileScreenState
    extends ConsumerState<EditCompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();

  final Map<String, TextEditingController> _hoursControllers = {};
  static const _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  bool _isLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    for (final day in _weekDays) {
      _hoursControllers[day] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    for (final c in _hoursControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initFromProfile() {
    if (_initialized) return;
    final profile = ref.read(companyProfileProvider).valueOrNull;
    if (profile == null) return;
    _initialized = true;
    _nameController.text = profile.name ?? '';
    _descriptionController.text = profile.description ?? '';
    _addressController.text = profile.address ?? '';
    _phoneController.text = profile.phone ?? '';
    _websiteController.text = profile.socialLinks['website'] ?? '';
    _instagramController.text = profile.socialLinks['instagram'] ?? '';
    _facebookController.text = profile.socialLinks['facebook'] ?? '';
    for (final day in _weekDays) {
      _hoursControllers[day]!.text = profile.operatingHours[day] ?? '';
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      setState(() => _isLoading = true);
      final ext = file.extension ?? 'png';
      final url = await ref.read(storageServiceProvider).uploadCompanyLogo(
        data: Uint8List.fromList(file.bytes!),
        companyId: tenant.companyId,
        fileExt: ext,
      );
      await CompanyService(tenant).updateLogoUrl(url);
      if (mounted) {
        context.showSuccessSnackbar('Logo updated');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Failed to upload logo: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    setState(() => _isLoading = true);
    try {
      final hours = <String, String>{};
      for (final day in _weekDays) {
        final v = _hoursControllers[day]!.text.trim();
        if (v.isNotEmpty) hours[day] = v;
      }
      final socials = <String, String>{};
      if (_websiteController.text.trim().isNotEmpty) {
        socials['website'] = _websiteController.text.trim();
      }
      if (_instagramController.text.trim().isNotEmpty) {
        socials['instagram'] = _instagramController.text.trim();
      }
      if (_facebookController.text.trim().isNotEmpty) {
        socials['facebook'] = _facebookController.text.trim();
      }
      await CompanyService(tenant).updateProfile(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        operatingHours: hours,
        socialLinks: socials,
      );
      if (mounted) {
        context.showSuccessSnackbar('Profile updated');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Failed to save: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(companyProfileProvider);
    profileAsync.whenData((_) => _initFromProfile());
    final profile = profileAsync.valueOrNull;
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit company profile')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingMedium,
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingXLarge + MediaQuery.paddingOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _isLoading ? null : _pickAndUploadLogo,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: profile?.logoUrl != null
                        ? NetworkImage(profile!.logoUrl!)
                        : null,
                    child: profile?.logoUrl == null
                        ? Icon(
                            Icons.add_a_photo_outlined,
                            size: 32,
                            color: theme.colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap to change logo',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel(context, 'Basic info'),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Company name',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel(context, 'Operating hours'),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < _weekDays.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      TextFormField(
                        controller: _hoursControllers[_weekDays[i]],
                        decoration: InputDecoration(
                          labelText: _weekDays[i],
                          hintText: 'e.g. 10:00 AM - 11:00 PM',
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel(context, 'Social links'),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Website',
                        prefixIcon: Icon(Icons.language_outlined),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _instagramController,
                      decoration: const InputDecoration(
                        labelText: 'Instagram',
                        prefixIcon: Icon(Icons.camera_alt_outlined),
                        hintText: '@handle or URL',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _facebookController,
                      decoration: const InputDecoration(
                        labelText: 'Facebook',
                        prefixIcon: Icon(Icons.facebook_outlined),
                        hintText: 'Page URL',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

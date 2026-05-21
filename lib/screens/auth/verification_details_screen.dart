import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_gradient_button.dart';

class VerificationDetailsScreen extends StatefulWidget {
  const VerificationDetailsScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<VerificationDetailsScreen> createState() =>
      _VerificationDetailsScreenState();
}

class _VerificationDetailsScreenState extends State<VerificationDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _gstNumber = TextEditingController();
  final _ownerName = TextEditingController();
  final _businessPhone = TextEditingController();
  final _businessAddress = TextEditingController();
  final _instagramLink = TextEditingController();
  String _city = 'Guwahati';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ownerName.text = widget.currentUser.name;
    _businessPhone.text = widget.currentUser.phone;
    final lastCity = widget.currentUser.lastKnownCity.trim();
    if (AppConstants.cities.contains(lastCity) && lastCity != 'All') {
      _city = lastCity;
    }
  }

  @override
  void dispose() {
    _businessName.dispose();
    _gstNumber.dispose();
    _ownerName.dispose();
    _businessPhone.dispose();
    _businessAddress.dispose();
    _instagramLink.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.submitVerificationDetails(
        user: widget.currentUser,
        businessName: _businessName.text,
        gstNumber: _gstNumber.text,
        ownerName: _ownerName.text,
        businessPhone: _businessPhone.text,
        businessAddress: _businessAddress.text,
        city: _city,
        instagramLink: _instagramLink.text,
        documentUploadStatus: 'pending_upload',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted for admin approval.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = widget.currentUser.isClubAdmin ? 'Venue' : 'Promoter';
    return NeonScaffold(
      appBar: AppBar(
        title: Text('$roleLabel verification'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: AuthService.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: GlassCard(
              borderRadius: 8,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      widget.currentUser.isClubAdmin
                          ? Icons.storefront_outlined
                          : Icons.campaign_outlined,
                      color: AppTheme.accentPink,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Complete $roleLabel details',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Submit business details for manual admin review. Document upload is optional for now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 20),
                    _Field(
                      controller: _businessName,
                      label: widget.currentUser.isClubAdmin
                          ? 'Business / Venue name'
                          : 'Business / Promoter brand name',
                    ),
                    _Field(controller: _gstNumber, label: 'GST number'),
                    _Field(controller: _ownerName, label: 'Owner name'),
                    _Field(controller: _businessPhone, label: 'Business phone'),
                    _Field(
                      controller: _businessAddress,
                      label: 'Business address',
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _city,
                      decoration: const InputDecoration(labelText: 'City'),
                      items: AppConstants.cities
                          .where((city) => city != 'All')
                          .map(
                            (city) => DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _city = value ?? _city),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _instagramLink,
                      label: 'Instagram link',
                      requiredField: false,
                    ),
                    const SizedBox(height: 2),
                    const _DocumentUploadNotice(),
                    const SizedBox(height: 18),
                    PremiumGradientButton(
                      onPressed: _saving ? null : _submit,
                      loading: _saving,
                      icon: Icons.verified_outlined,
                      label: 'Submit for approval',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.requiredField = true,
  });

  final TextEditingController controller;
  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (!requiredField) return null;
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }
}

class _DocumentUploadNotice extends StatelessWidget {
  const _DocumentUploadNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.upload_file_outlined, color: AppTheme.accentPink),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'ID/GST document upload is optional right now. If skipped, documentUploadStatus will be pending_upload.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

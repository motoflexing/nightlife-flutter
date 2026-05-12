import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/neon_scaffold.dart';

class ClubOnboardingScreen extends StatefulWidget {
  const ClubOnboardingScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<ClubOnboardingScreen> createState() => _ClubOnboardingScreenState();
}

class _ClubOnboardingScreenState extends State<ClubOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clubName = TextEditingController();
  final _ownerName = TextEditingController();
  final _businessEmail = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _instagram = TextEditingController();
  final _maps = TextEditingController();
  final _document = TextEditingController();
  String _city = 'Guwahati';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ownerName.text = widget.currentUser.name;
    _businessEmail.text = widget.currentUser.email;
    _phone.text = widget.currentUser.phone;
  }

  @override
  void dispose() {
    _clubName.dispose();
    _ownerName.dispose();
    _businessEmail.dispose();
    _phone.dispose();
    _address.dispose();
    _instagram.dispose();
    _maps.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.submitClubOnboarding(
        user: widget.currentUser,
        clubName: _clubName.text,
        ownerName: _ownerName.text,
        businessEmail: _businessEmail.text,
        phone: _phone.text,
        city: _city,
        address: _address.text,
        instagram: _instagram.text,
        googleMapsLink: _maps.text,
        documentUrl: _document.text,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: AppBar(
        title: const Text('Club onboarding'),
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
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Verify your club',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Dashboard access unlocks after Super Admin approval.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 20),
                      _Field(controller: _clubName, label: 'Club name'),
                      _Field(controller: _ownerName, label: 'Owner name'),
                      _Field(controller: _businessEmail, label: 'Business email'),
                      _Field(controller: _phone, label: 'Phone'),
                      DropdownButtonFormField<String>(
                        initialValue: _city,
                        decoration: const InputDecoration(labelText: 'City'),
                        items: AppConstants.cities
                            .where((city) => city != 'All')
                            .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                            .toList(),
                        onChanged: (value) => setState(() => _city = value ?? _city),
                      ),
                      const SizedBox(height: 12),
                      _Field(controller: _address, label: 'Address'),
                      _Field(controller: _instagram, label: 'Instagram link', isRequired: false),
                      _Field(controller: _maps, label: 'Google Maps link', isRequired: false),
                      _Field(
                        controller: _document,
                        label: 'GST/license/document link',
                        isRequired: false,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: const Text('Submit for approval'),
                      ),
                    ],
                  ),
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
    this.isRequired = true,
  });

  final TextEditingController controller;
  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (!isRequired) return null;
          if (value == null || value.trim().isEmpty) return '$label is required';
          return null;
        },
      ),
    );
  }
}

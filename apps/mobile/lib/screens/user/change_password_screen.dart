import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/neon_scaffold.dart';

/// Lets an email/password user change their password. Re-authenticates with the
/// current password (Firebase requires a recent login for updatePassword) and
/// then updates it. Reuses [AuthService.friendlyAuthMessage] for error copy.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _hideCurrent = true;
  bool _hideNext = true;
  bool _hideConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateNew(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter a new password.';
    if (text.length < 8) return 'Use at least 8 characters.';
    if (text == _current.text) {
      return 'New password must be different from the current one.';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Confirm your new password.';
    if (value != _next.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email?.trim();
      if (user == null || email == null || email.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Please sign in again to change your password.'),
          ),
        );
        setState(() => _saving = false);
        return;
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: _current.text,
      );
      await user
          .reauthenticateWithCredential(credential)
          .timeout(const Duration(seconds: 20));
      await user
          .updatePassword(_next.text)
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.friendlyAuthMessage(error))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: AppBar(title: const Text('Change password')),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _PasswordField(
                controller: _current,
                label: 'Current password',
                obscure: _hideCurrent,
                onToggle: () => setState(() => _hideCurrent = !_hideCurrent),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter your current password.'
                    : null,
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _next,
                label: 'New password',
                obscure: _hideNext,
                onToggle: () => setState(() => _hideNext = !_hideNext),
                validator: _validateNew,
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _confirm,
                label: 'Confirm new password',
                obscure: _hideConfirm,
                onToggle: () => setState(() => _hideConfirm = !_hideConfirm),
                validator: _validateConfirm,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction:
          onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}

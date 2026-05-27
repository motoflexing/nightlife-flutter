import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_gradient_button.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  String _selectedRole = 'user';
  bool _loading = false;
  bool _hidePassword = true;

  final List<Map<String, String>> _roles = const [
    {'label': 'User', 'value': 'user'},
    {'label': 'Promoter', 'value': 'promoter'},
    {'label': 'Venue', 'value': 'clubAdmin'},
  ];

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await AuthService.instance.signIn(
        email: _email.text.trim(),
        password: _password.text.trim(),
        requestedRole: _selectedRole,
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
        content: Text(message),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange.shade700,
        content: Text(message),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final email = await _showForgotPasswordDialog();
    if (email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      if (mounted) _showMessage('Password reset link sent.');
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showError(error.message ?? 'Unable to send password reset email.');
      }
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  Future<String?> _showForgotPasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: _email.text.trim());

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Reset password'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Email is required';
                if (!email.contains('@')) return 'Enter valid email';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop(emailController.text.trim());
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Widget _roleSelector() {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: _roles.map((role) {
          final value = role['value']!;
          final isSelected = _selectedRole == value;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _loading
                  ? null
                  : () => setState(() => _selectedRole = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.premiumGradient : null,
                  borderRadius: BorderRadius.circular(28),
                ),
                alignment: Alignment.center,
                child: Text(
                  role['label']!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < 500;

    return NeonScaffold(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 16 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: GlassCard(
                padding: EdgeInsets.all(isPhone ? 14 : 18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        child: Container(
                          width: isPhone ? 54 : 64,
                          height: isPhone ? 54 : 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.premiumGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.neonViolet.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 30,
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.nightlife,
                            color: Colors.white,
                            size: isPhone ? 28 : 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Login to manage your night.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _roleSelector(),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _email,
                        enabled: !_loading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Email is required';
                          if (!email.contains('@')) return 'Enter valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _password,
                        enabled: !_loading,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 46,
                        child: PremiumGradientButton(
                          onPressed: _loading ? null : _submit,
                          loading: _loading,
                          icon: Icons.login,
                          label: 'Login',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          );
                        },
                        child: const Text('Create an account'),
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

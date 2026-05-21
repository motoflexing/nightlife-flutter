import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../screens/super_admin/super_admin_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/fiery_unlock_overlay.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_gradient_button.dart';
import '../../widgets/secret_super_admin_unlock_gate.dart';
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
  final _userRoleKey = GlobalKey();
  final _venueRoleKey = GlobalKey();

  String _selectedRole = 'user';
  bool _loading = false;
  bool _hidePassword = true;
  bool _superAdminUnlockArmed = false;
  bool _unlockingSuperAdmin = false;

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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await AuthService.instance.signIn(
        email: _email.text.trim(),
        password: _password.text,
        requestedRole: _superAdminUnlockArmed ? 'superAdmin' : _selectedRole,
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _forgotPassword() async {
    final email = await _showForgotPasswordDialog();
    if (email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      if (!mounted) return;
      _showMessage('Password reset link sent to your email.');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showError(error.message ?? 'Unable to send password reset email.');
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
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
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.glassBorder),
          ),
          title: const Text('Reset password'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Email is required';
                if (!email.contains('@')) return 'Enter a valid email';
                return null;
              },
              onFieldSubmitted: (_) {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop(emailController.text.trim());
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
              child: const Text('Send link'),
            ),
          ],
        );
      },
    ).whenComplete(emailController.dispose);
  }

  Future<void> _handleSuperAdminUnlockGesture() async {
    if (_unlockingSuperAdmin) return;
    _unlockingSuperAdmin = true;
    _superAdminUnlockArmed = true;
    AuthService.instance.armSuperAdminUnlock();

    await _playSuperAdminUnlockSoundHook();
    await _triggerSuperAdminVibrationHook();
    if (mounted) await showFieryUnlockOverlay(context);

    final allowed = await AuthService.instance.verifyCurrentUserIsSuperAdmin();
    final profile = allowed
        ? await AuthService.instance.getCurrentProfile()
        : null;

    if (mounted && profile != null && profile.isSuperAdmin) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SuperAdminScreen(currentUser: profile),
        ),
      );
    }

    _unlockingSuperAdmin = false;
  }

  Future<void> _playSuperAdminUnlockSoundHook() async {
    // Hook for a future cyberpunk unlock sound asset.
  }

  Future<void> _triggerSuperAdminVibrationHook() {
    return HapticFeedback.heavyImpact();
  }

  Widget _roleSelector() {
    return SecretSuperAdminUnlockGate(
      userKey: _userRoleKey,
      venueKey: _venueRoleKey,
      enabled: !_loading && _selectedRole == 'clubAdmin',
      onUnlock: _handleSuperAdminUnlockGesture,
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.glassBorder),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryViolet.withValues(alpha: 0.12),
              blurRadius: 18,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Row(
          children: _roles.map((role) {
            final isSelected = _selectedRole == role['value'];
            final key = switch (role['value']) {
              'user' => _userRoleKey,
              'clubAdmin' => _venueRoleKey,
              _ => null,
            };

            return Expanded(
              child: GestureDetector(
                key: key,
                onTap: _loading
                    ? null
                    : () {
                        setState(() {
                          _selectedRole = role['value']!;
                        });
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.premiumGradient : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.neonViolet.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 16,
                              spreadRadius: -8,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    role['label']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              constraints: const BoxConstraints(maxWidth: 430),
              child: GlassCard(
                padding: EdgeInsets.fromLTRB(
                  isPhone ? 18 : 22,
                  isPhone ? 22 : 26,
                  isPhone ? 18 : 22,
                  20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.premiumGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.neonViolet.withValues(
                                  alpha: 0.34,
                                ),
                                blurRadius: 26,
                                spreadRadius: -6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.nightlife,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: isPhone ? 26 : 30,
                            ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'Login to manage your night.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 24),

                      _roleSelector(),

                      const SizedBox(height: 18),

                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() {
                                _hidePassword = !_hidePassword;
                              });
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

                      const SizedBox(height: 12),

                      SizedBox(
                        height: 56,
                        child: PremiumGradientButton(
                          onPressed: _loading ? null : _submit,
                          loading: _loading,
                          icon: Icons.login,
                          label: 'Login',
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
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

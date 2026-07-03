import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
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
      AnalyticsService.instance.logLogin('email');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error, stackTrace) {
      // Keep the real error for debugging, but never show raw exception text
      // (code/plugin/runtimeType) to the user.
      _recordError(error, stackTrace, reason: 'login_submit');
      if (mounted) {
        if (error is FirebaseAuthException) {
          _showError(AuthService.friendlyAuthMessage(error));
        } else {
          _showError('Something went wrong. Please try again.');
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.destructive,
        content: Text(
          message,
          style: const TextStyle(color: AppColors.obsidian),
        ),
      ),
    );
  }

  /// Records the real error (with stack) to Crashlytics for debugging, so user
  /// facing copy can stay generic without losing diagnosability. No-op on web,
  /// matching the app's Crashlytics setup in main.dart.
  void _recordError(Object error, StackTrace stackTrace, {String? reason}) {
    if (kIsWeb) return;
    FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: reason);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.espresso,
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textHigh),
        ),
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
      if (mounted) _showError(AuthService.friendlyAuthMessage(error));
    } catch (error, stackTrace) {
      _recordError(error, stackTrace, reason: 'forgot_password');
      if (mounted) {
        _showError('Unable to send password reset email. Please try again.');
      }
    }
  }

  Future<String?> _showForgotPasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: _email.text.trim());

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceEspresso,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.goldBorder, width: 1),
          ),
          title: Text(
            'Reset Password',
            style: AppTypography.headlineMedium.copyWith(fontSize: 20),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textHigh),
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Email is required';
                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!emailRegex.hasMatch(email)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop(emailController.text.trim());
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.champagne,
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  /// Tracked uppercase field label (design underline-input label).
  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          fontSize: 10,
          letterSpacing: 0.24 * 10,
          color: AppColors.textCaption,
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    // Pill segmented control — champagne fill on the selected role.
    return Row(
      children: _roles.map((role) {
        final value = role['value']!;
        final isSelected = _selectedRole == value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _loading
                  ? null
                  : () => setState(() => _selectedRole = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.champagne : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.champagne
                        : AppColors.textDisabled,
                    width: 1,
                  ),
                ),
                child: Text(
                  role['label']!.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.14 * 11,
                    color: isSelected
                        ? AppColors.obsidian
                        : AppColors.textBody,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Email'),
        TextFormField(
          controller: _email,
          enabled: !_loading,
          keyboardType: TextInputType.emailAddress,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textHigh),
          decoration: const InputDecoration(hintText: 'you@example.com'),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return 'Email is required';
            final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
            if (!emailRegex.hasMatch(email)) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        _fieldLabel('Password'),
        TextFormField(
          controller: _password,
          enabled: !_loading,
          obscureText: _hidePassword,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textHigh),
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password is required';
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            if (!RegExp(r'[A-Z]').hasMatch(value)) {
              return 'Include at least one uppercase letter';
            }
            if (!RegExp(r'[0-9]').hasMatch(value)) {
              return 'Include at least one number';
            }
            return null;
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(top: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.textSecondary,
            ),
            onPressed: _loading ? null : _forgotPassword,
            child: Text(
              'Forgot password?',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    // Ivory primary CTA, obsidian tracked-uppercase label (design §7).
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _loading
              ? AppColors.ivory.withValues(alpha: 0.5)
              : AppColors.ivory,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            splashColor: Colors.transparent,
            highlightColor: AppColors.obsidian.withValues(alpha: 0.08),
            onTap: _loading ? null : _submit,
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.obsidian,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Sign In'.toUpperCase(),
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.obsidian,
                        letterSpacing: 0.16 * 12,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textHigh),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tracked eyebrow + gold hairline (design section intro).
              Row(
                children: [
                  Text(
                    'Sign In'.toUpperCase(),
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.champagne,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.champagne.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Playfair hero.
              Text(
                'Welcome\nBack',
                style: AppTypography.displayMedium.copyWith(height: 1.05),
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in to your account',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textBodyDim,
                ),
              ),
              const SizedBox(height: 40),
              _buildRoleSelector(),
              const SizedBox(height: 32),
              _buildFormFields(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SignupScreen(),
                      ),
                    ),
                    child: Text(
                      'Sign Up',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.champagne,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

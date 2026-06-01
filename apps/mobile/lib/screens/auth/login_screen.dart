import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
    } catch (error) {
      if (mounted) {
        if (error is FirebaseAuthException) {
          _showError('[${error.code}] ${error.message ?? 'no message'}');
        } else if (error is FirebaseException) {
          _showError(
            '[${error.plugin}/${error.code}] ${error.message ?? 'no message'}',
          );
        } else {
          _showError('${error.runtimeType}: $error');
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
        backgroundColor: Colors.red.shade800,
        content: Text(message),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1C22),
        content: Text(message, style: const TextStyle(color: Color(0xFFF5F5F0))),
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
          backgroundColor: const Color(0xFF0D0D0F),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0x1FFFFFFF)),
          ),
          title: const Text(
            'Reset Password',
            style: TextStyle(
              color: Color(0xFFF5F5F0),
              fontWeight: FontWeight.w400,
              fontSize: 16,
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14, color: Color(0xFFF5F5F0)),
              decoration: _inputDecoration(hint: 'Email address'),
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
                foregroundColor: const Color(0x59FFFFFF),
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop(emailController.text.trim());
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF59E0B),
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Color(0x33FFFFFF)),
      filled: true,
      fillColor: const Color(0xFF1C1C22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0x14FFFFFF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0x14FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFF59E0B)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          color: Color(0x59FFFFFF),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x12FFFFFF)),
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
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF59E0B)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  role['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w500 : FontWeight.w400,
                    color: isSelected
                        ? const Color(0xFF080809)
                        : const Color(0x59FFFFFF),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFormContainer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x12FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Email'),
          TextFormField(
            controller: _email,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 14, color: Color(0xFFF5F5F0)),
            decoration: _inputDecoration(hint: 'you@example.com'),
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
          const SizedBox(height: 16),
          _fieldLabel('Password'),
          TextFormField(
            controller: _password,
            enabled: !_loading,
            obscureText: _hidePassword,
            style: const TextStyle(fontSize: 14, color: Color(0xFFF5F5F0)),
            decoration: _inputDecoration(
              hint: '••••••••',
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _hidePassword = !_hidePassword),
                icon: Icon(
                  _hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: const Color(0x59FFFFFF),
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
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _loading ? null : _forgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0x59FFFFFF),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _loading
              ? const Color(0x4DF59E0B)
              : const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _loading ? null : _submit,
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Color(0xFF080809),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'SIGN IN',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                        color: Color(0xFF080809),
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
      backgroundColor: const Color(0xFF080809),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFFF5F5F0)),
        title: const Text(
          'Sign In',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
            color: Color(0xB3FFFFFF),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Welcome\nBack',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFFF5F5F0),
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to your account',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0x59FFFFFF),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 36),
              _buildRoleSelector(),
              const SizedBox(height: 16),
              _buildFormContainer(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0x4DFFFFFF),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SignupScreen(),
                      ),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w500,
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

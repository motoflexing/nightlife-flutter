import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/neon_scaffold.dart';
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
        requestedRole: _selectedRole,
      );
    } on AuthException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.nightlife,
                          color: AppTheme.neonPink,
                          size: 46,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppConstants.appName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Login to manage your night.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          height: 58,
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              textStyle: WidgetStateProperty.all(
                                const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(horizontal: 4),
                              ),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: 'user',
                                label: Text(
                                  'User',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ButtonSegment(
                                value: 'promoter',
                                label: Text(
                                  'Promoter',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ButtonSegment(
                                value: 'clubAdmin',
                                label: Text(
                                  'Venue',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            selected: {_selectedRole},
                            onSelectionChanged: _loading
                                ? null
                                : (value) => setState(
                                      () => _selectedRole = value.first,
                                    ),
                          ),
                        ),

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
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
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

                        const SizedBox(height: 20),

                        SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _submit,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: const Text('Login'),
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
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_gradient_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _dob = TextEditingController();
  final _gender = TextEditingController();
  final _instagramId = TextEditingController();
  final _snapchatId = TextEditingController();

  String _selectedRole = 'user';
  String _selectedTitle = 'Mr';

  bool _loading = false;
  bool _hidePassword = true;

  final List<Map<String, String>> _roles = const [
    {'label': 'User', 'value': 'user'},
    {'label': 'Promoter', 'value': 'promoter'},
    {'label': 'Venue', 'value': 'clubAdmin'},
  ];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _dob.dispose();
    _gender.dispose();
    _instagramId.dispose();
    _snapchatId.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1950),
      lastDate: now,
    );

    if (picked != null) {
      _dob.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await AuthService.instance.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        requestedRole: _selectedRole,
        title: _selectedTitle,
        gender: _gender.text.trim(),
        dob: _dob.text.trim(),
        instagramId: _instagramId.text.trim(),
        snapchatId: _snapchatId.text.trim(),
        validIdUrl: '',
      );

      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _gap() => const SizedBox(height: 14);

  Widget _roleSelector() {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: _roles.map((role) {
          final isSelected = _selectedRole == role['value'];

          return Expanded(
            child: GestureDetector(
              onTap: _loading
                  ? null
                  : () => setState(() => _selectedRole = role['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.premiumGradient : null,
                  borderRadius: BorderRadius.circular(28),
                ),
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
              constraints: const BoxConstraints(maxWidth: 460),
              child: GlassCard(
                padding: EdgeInsets.all(isPhone ? 18 : 22),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.premiumGradient,
                          ),
                          child: const Icon(
                            Icons.nightlife,
                            size: 34,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Complete your profile to start your nightlife journey.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _roleSelector(),
                      const SizedBox(height: 18),

                      DropdownButtonFormField<String>(
                        initialValue: _selectedTitle,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Mr', child: Text('Mr')),
                          DropdownMenuItem(value: 'Mrs', child: Text('Mrs')),
                          DropdownMenuItem(value: 'Miss', child: Text('Miss')),
                          DropdownMenuItem(value: 'Ms', child: Text('Ms')),
                          DropdownMenuItem(value: 'Dr', child: Text('Dr')),
                          DropdownMenuItem(value: 'Prof', child: Text('Prof')),
                        ],
                        onChanged: _loading
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _selectedTitle = value);
                                }
                              },
                      ),

                      _gap(),

                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Enter your full name';
                          }
                          return null;
                        },
                      ),

                      _gap(),

                      TextFormField(
                        controller: _gender,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.wc_outlined),
                          hintText: 'Male / Female / Other',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your gender';
                          }
                          return null;
                        },
                      ),

                      _gap(),

                      TextFormField(
                        controller: _dob,
                        readOnly: true,
                        onTap: _loading ? null : _pickDob,
                        decoration: const InputDecoration(
                          labelText: 'Date of birth',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Select your date of birth';
                          }
                          return null;
                        },
                      ),

                      _gap(),

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

                      _gap(),

                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.call_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 8) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),

                      _gap(),

                      TextFormField(
                        controller: _instagramId,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Instagram ID (optional)',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),

                      _gap(),

                      TextFormField(
                        controller: _snapchatId,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Snapchat ID (optional)',
                          prefixIcon: Icon(Icons.camera_alt_outlined),
                        ),
                      ),

                      _gap(),

                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Valid ID upload will be connected with Firebase Storage next.',
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Upload valid ID'),
                      ),

                      _gap(),

                      TextFormField(
                        controller: _password,
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
                            return 'Use at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 22),

                      PremiumGradientButton(
                        onPressed: _loading ? null : _submit,
                        loading: _loading,
                        icon: Icons.person_add_alt,
                        label: 'Sign up',
                      ),

                      const SizedBox(height: 22),

                      TextButton(
                        onPressed:
                            _loading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Already have an account? Login'),
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
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_gradient_button.dart';
import '../super_admin/super_admin_screen.dart';

class SuperAdminLoginScreen extends StatefulWidget {
  const SuperAdminLoginScreen({super.key});

  @override
  State<SuperAdminLoginScreen> createState() => _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends State<SuperAdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;
  bool _allowedEntry = false;

  @override
  void initState() {
    super.initState();
    _allowedEntry = AuthService.instance.isSuperAdminUnlockArmed;
    if (!_allowedEntry) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

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
        requestedRole: 'superAdmin',
      );

      final allowed = await AuthService.instance
          .verifyCurrentUserIsSuperAdmin();
      final profile = allowed
          ? await AuthService.instance.getCurrentProfile()
          : null;

      if (!mounted) return;
      if (profile == null || !profile.isSuperAdmin) {
        _showError('This account is not cleared for restricted access.');
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SuperAdminScreen(currentUser: profile),
        ),
      );
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowedEntry) {
      return const Scaffold(backgroundColor: AppTheme.background);
    }

    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 500;

    return NeonScaffold(
      appBar: AppBar(
        title: const Text('Restricted Access'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isPhone ? 16 : 24,
              20,
              isPhone ? 16 : 24,
              28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 18 * (1 - value)),
                    child: Transform.scale(
                      scale: 0.97 + value * 0.03,
                      child: child,
                    ),
                  ),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 420),
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentPink.withValues(alpha: 0.92),
                        AppTheme.neonViolet.withValues(alpha: 0.72),
                        AppTheme.neonLime.withValues(alpha: 0.54),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPink.withValues(alpha: 0.26),
                        blurRadius: 46,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
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
                          const _RestrictedBadge(),
                          const SizedBox(height: 16),
                          Align(
                            child: Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [
                                    AppTheme.neonLime,
                                    AppTheme.accentPink,
                                    AppTheme.deepPurple,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentPink.withValues(
                                      alpha: 0.38,
                                    ),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_outlined,
                                color: Colors.white,
                                size: 35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Super Admin Console',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: isPhone ? 25 : 29,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Restricted access. Credentials are role-checked before command mode opens.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Super Admin Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Email is required';
                              if (!email.contains('@')) {
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
                              labelText: 'Restricted Password',
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
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 56,
                            child: PremiumGradientButton(
                              onPressed: _loading ? null : _submit,
                              loading: _loading,
                              icon: Icons.security_outlined,
                              label: 'Enter Restricted Mode',
                            ),
                          ),
                          const SizedBox(height: 14),
                          const _WarningPanel(),
                        ],
                      ),
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

class _RestrictedBadge extends StatelessWidget {
  const _RestrictedBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.accentPink.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.neonLime.withValues(alpha: 0.42)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 16, color: AppTheme.neonLime),
            SizedBox(width: 8),
            Text(
              'RESTRICTED ACCESS',
              style: TextStyle(
                color: AppTheme.neonLime,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningPanel extends StatelessWidget {
  const _WarningPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.deepPurple.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_clock_outlined, color: AppTheme.accentPink, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This screen is hidden and unlock-gated. Failed role checks will not open command mode.',
              style: TextStyle(color: AppTheme.textMuted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

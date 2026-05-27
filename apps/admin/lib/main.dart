import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nightlife_shared/nightlife_shared.dart';

import 'firebase_options.dart';
import 'screens/super_admin_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminDashboardApp());
}

class AdminDashboardApp extends StatelessWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nightlife Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      initialRoute: '/admin',
      routes: {
        '/admin/login': (_) => const AdminLoginScreen(),
        '/admin': (_) => const AdminGate(),
      },
      onUnknownRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const AdminGate()),
    );
  }
}

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.instance.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const NeonScaffold(
            child: LoadingView(message: 'Checking session'),
          );
        }
        if (authSnapshot.data == null) return const AdminLoginScreen();

        return FutureBuilder<AppUser?>(
          future: _loadVerifiedAdmin(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const NeonScaffold(
                child: LoadingView(message: 'Verifying admin access'),
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null || !profile.isSuperAdmin) {
              return const _AccessDeniedScreen();
            }

            return SuperAdminScreen(currentUser: profile);
          },
        );
      },
    );
  }

  Future<AppUser?> _loadVerifiedAdmin() async {
    final allowed = await AuthService.instance.verifyCurrentUserIsSuperAdmin();
    if (!allowed) return null;
    return AuthService.instance.getCurrentProfile();
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    setState(() => _loading = true);

    try {
      await AuthService.instance.signIn(
        email: _email.text.trim(),
        password: _password.text,
        requestedRole: 'superAdmin',
      );
      final allowed = await AuthService.instance
          .verifyCurrentUserIsSuperAdmin();
      if (!mounted) return;

      if (!allowed) {
        await AuthService.instance.signOut();
        _showError('This account is not authorized for Super Admin access.');
        return;
      }

      Navigator.of(context).pushReplacementNamed('/admin');
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

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 560;

    return NeonScaffold(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isPhone ? 18 : 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: GlassCard(
                padding: EdgeInsets.all(isPhone ? 18 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Color(0xFFFF7A00),
                        size: 54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Super Admin Dashboard',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Protected web access for platform operations.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        enabled: !_loading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Admin email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Email is required';
                          if (!email.contains('@')) return 'Enter valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        enabled: !_loading,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
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
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 48,
                        child: PremiumGradientButton(
                          onPressed: _loading ? null : _submit,
                          loading: _loading,
                          icon: Icons.login,
                          label: 'Enter dashboard',
                        ),
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

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      child: Center(
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.redAccent, size: 44),
              const SizedBox(height: 12),
              Text(
                'Access denied',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'This account does not have Super Admin permissions.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  await AuthService.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/admin/login');
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PremiumLoader(),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

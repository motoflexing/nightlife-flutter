import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/neon_scaffold.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 520;

    return NeonScaffold(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isPhone ? 20 : 28,
              28,
              isPhone ? 20 : 28,
              28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 36),
                  const _BrandHeader(),
                  const SizedBox(height: 96),
                  _WelcomeButton(
                    label: 'Sign In',
                    icon: Icons.login,
                    filled: true,
                    onPressed: () => _open(context, const LoginScreen()),
                  ),
                  const SizedBox(height: 14),
                  _WelcomeButton(
                    label: 'Sign Up',
                    icon: Icons.person_add_alt,
                    onPressed: () => _open(context, const SignupScreen()),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.premiumGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentPink.withValues(alpha: 0.34),
                blurRadius: 34,
                spreadRadius: -8,
              ),
            ],
          ),
          child: const Icon(Icons.nightlife, color: Colors.white, size: 38),
        ),
        const SizedBox(height: 18),
        Text(
          'Nightlife',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 40,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Discover the city after dark',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _WelcomeButton extends StatelessWidget {
  const _WelcomeButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);

    return SizedBox(
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: filled ? AppTheme.premiumGradient : null,
          color: filled ? null : AppTheme.surface.withValues(alpha: 0.82),
          border: Border.all(
            color: filled
                ? Colors.white.withValues(alpha: 0.12)
                : AppTheme.accentPink.withValues(alpha: 0.48),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentPink.withValues(
                alpha: filled ? 0.26 : 0.12,
              ),
              blurRadius: 24,
              spreadRadius: -10,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

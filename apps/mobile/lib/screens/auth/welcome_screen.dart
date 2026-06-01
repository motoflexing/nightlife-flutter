import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080809),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFF59E0B)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.nightlife,
                        size: 24,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'The Night\nStarts Here',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFFF5F5F0),
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Discover events. Get on the list.\nBe where it happens.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0x66FFFFFF),
                        height: 1.6,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 64),
              _LuxuryButton(
                label: 'Sign In',
                onTap: () => _open(context, const LoginScreen()),
                filled: true,
              ),
              const SizedBox(height: 12),
              _LuxuryButton(
                label: 'Create Account',
                onTap: () => _open(context, const SignupScreen()),
                filled: false,
              ),
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'By continuing you agree to our Terms & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0x33FFFFFF),
                    height: 1.5,
                  ),
                ),
              ),
            ],
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

class _LuxuryButton extends StatelessWidget {
  const _LuxuryButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filled ? const Color(0xFFF59E0B) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: filled ? null : Border.all(color: const Color(0x26FFFFFF)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            splashColor: const Color(0x33F59E0B),
            highlightColor: const Color(0x1AF59E0B),
            onTap: onTap,
            child: Center(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: filled ? FontWeight.w500 : FontWeight.w400,
                  letterSpacing: 0.8,
                  color: filled
                      ? const Color(0xFF080809)
                      : const Color(0xB3FFFFFF),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

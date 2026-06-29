import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
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
              const Center(child: _LegalLinksText()),
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

/// The "By continuing you agree to our Terms & Privacy Policy" line, with the
/// "Terms" and "Privacy Policy" portions tappable so they open the respective
/// hosted policy URLs in the browser. Stateful so the [TapGestureRecognizer]s
/// are owned and disposed correctly.
class _LegalLinksText extends StatefulWidget {
  const _LegalLinksText();

  @override
  State<_LegalLinksText> createState() => _LegalLinksTextState();
}

class _LegalLinksTextState extends State<_LegalLinksText> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl(AppConstants.termsOfServiceUrl);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl(AppConstants.privacyPolicyUrl);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    var launched = false;
    if (uri != null) {
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the link")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 11,
      color: Color(0x33FFFFFF),
      height: 1.5,
    );
    const linkStyle = TextStyle(
      fontSize: 11,
      color: Color(0xFFF59E0B),
      height: 1.5,
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFFF59E0B),
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(
            text: 'Terms',
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
        ],
      ),
      textAlign: TextAlign.center,
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

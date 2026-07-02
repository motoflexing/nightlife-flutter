import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../services/referral_service.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _claimCode() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'PLEASE ENTER A VALID INVITATION CODE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Color(0xFF0E0E10),
            ),
          ),
          backgroundColor: const Color(0xFFCFAC4F), // Champagne gold
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    // Capture the invite code in our ReferralService
    ReferralService.instance.setCode(code);

    // Show premium confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'INVITATION CODE ACCEPTED. WELCOME TO THE ENTRY.',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Color(0xFF0E0E10),
          ),
        ),
        backgroundColor: const Color(0xFFF3EFE6), // Warm Ivory
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    // Navigate to registration
    _open(context, const SignupScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10), // Base Background: Deep Obsidian
      body: Stack(
        children: [
          // Soft radial vignette layer that darkens the outer edges
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Color(0xFF0E0E10),
                  ],
                  stops: [0.15, 1.0],
                ),
              ),
            ),
          ),
          // Main layout content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Spacer(flex: 2),
                            
                            // Top Branding: Center a minimal, geometric thin-line Art Deco circular "N" monogram
                            Center(
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: CustomPaint(
                                  painter: const _ArtDecoMonogramPainter(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            
                            // Eyebrow line flanked by thin gold rules reading "01 · THE ENTRY"
                            Row(
                              children: [
                                const Expanded(
                                  child: Divider(
                                    color: Color(0x4DCFAC4F), // Semi-transparent Champagne gold
                                    thickness: 0.75,
                                    endIndent: 12,
                                  ),
                                ),
                                const Text(
                                  '01 · THE ENTRY',
                                  style: TextStyle(
                                    color: Color(0xFFCFAC4F), // Champagne gold
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3.0,
                                  ),
                                ),
                                const Expanded(
                                  child: Divider(
                                    color: Color(0x4DCFAC4F), // Semi-transparent Champagne gold
                                    thickness: 0.75,
                                    indent: 12,
                                  ),
                                ),
                              ],
                            ),
                            
                            const Spacer(flex: 3),
                            
                            // Hero Typography: Display "After dark, by invitation."
                            const Center(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'After dark,\n',
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 34,
                                        fontWeight: FontWeight.w300,
                                        color: Color(0xFFF3EFE6), // Warm Ivory
                                        height: 1.25,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'by invitation.',
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontStyle: FontStyle.italic,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w300,
                                        color: Color(0xFFF3EFE6), // Warm Ivory
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            
                            const Spacer(flex: 3),
                            
                            // Interactive Card utilizing the Espresso background token
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1210), // Card Surfaces: Espresso
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFCFAC4F), // 1px hairline border in Champagne gold
                                  width: 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Tracked, uppercase small-caps label above the input
                                  const Text(
                                    'ENTER YOUR CODE',
                                    style: TextStyle(
                                      color: Color(0x99F3EFE6), // faint warm-grey
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Underline-only input field (no box, no background fill)
                                  TextField(
                                    controller: _codeController,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFF3EFE6), // Warm Ivory
                                      fontSize: 16,
                                      letterSpacing: 4.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    cursorColor: const Color(0xFFCFAC4F), // Champagne cursor
                                    decoration: const InputDecoration(
                                      filled: false,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                                      border: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Color(0x33F3EFE6), width: 1.0), // Faint warm-grey
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Color(0x33F3EFE6), width: 1.0), // Faint warm-grey
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Color(0xFFCFAC4F), width: 1.5), // Brilliant Champagne gold on focus
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Primary Action Button: "CLAIM INVITATION"
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _claimCode,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF3EFE6), // Solid Ivory fill
                                        foregroundColor: const Color(0xFF0E0E10), // Obsidian text
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8), // Moderately rounded corners (8px)
                                        ),
                                      ),
                                      child: const Text(
                                        'CLAIM INVITATION',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Secondary Action Button: A ghost button labeled "EXISTING MEMBER LOGIN"
                            SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: () => _open(context, const LoginScreen()),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: const Color(0xFFCFAC4F), // Champagne gold text
                                  side: const BorderSide(
                                    color: Color(0xFFCFAC4F), // Thin 1px Champagne gold outline
                                    width: 1.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'EXISTING MEMBER LOGIN',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            
                            const Spacer(flex: 3),
                            
                            // Footer Legal Links
                            const Center(child: _LegalLinksText()),
                            const Spacer(flex: 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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

/// Circular, geometric thin-line Art Deco monogram painter drawing a custom 'N'
class _ArtDecoMonogramPainter extends CustomPainter {
  const _ArtDecoMonogramPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final center = Offset(width / 2, height / 2);
    final radius = width / 2;

    final outerPaint = Paint()
      ..color = const Color(0xFFCFAC4F) // Champagne gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    // Outer circle
    canvas.drawCircle(center, radius, outerPaint);

    final innerPaint = Paint()
      ..color = const Color(0xFFCFAC4F).withValues(alpha: 0.5) // Faint inner circle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..isAntiAlias = true;

    // Concentric inner circle
    canvas.drawCircle(center, radius - 4, innerPaint);

    final nPaint = Paint()
      ..color = const Color(0xFFCFAC4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = true;

    // Art Deco geometric dimensions for the "N"
    final double nWidth = radius * 0.7;
    final double nHeight = radius * 0.85;
    
    final double leftX = center.dx - nWidth / 2;
    final double rightX = center.dx + nWidth / 2;
    final double topY = center.dy - nHeight / 2;
    final double bottomY = center.dy + nHeight / 2;

    // Left vertical stem
    canvas.drawLine(Offset(leftX, topY), Offset(leftX, bottomY), nPaint);
    // Right vertical stem
    canvas.drawLine(Offset(rightX, topY), Offset(rightX, bottomY), nPaint);
    // Connecting diagonal
    canvas.drawLine(Offset(leftX, topY), Offset(rightX, bottomY), nPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
      fontSize: 10,
      color: Color(0x66F3EFE6), // Warm Ivory with low opacity
      height: 1.5,
      letterSpacing: 0.5,
    );
    const linkStyle = TextStyle(
      fontSize: 10,
      color: Color(0xFFCFAC4F), // Champagne gold
      height: 1.5,
      letterSpacing: 0.5,
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFFCFAC4F),
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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/nocturne_monogram.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// The entry screen: role selection (Guest / Promoter / Club·Venue) leading to
/// signup, plus an existing-member login path and legal links. Matches the
/// Nocturne "Welcome · role selection" design. (App name stays "Nightlife".)
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianDeep,
      body: Stack(
        children: [
          // Design canvas: oxblood wash from the top + soft gold glow at the base.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    AppColors.oxblood.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 1.1),
                  radius: 1.0,
                  colors: [
                    AppColors.champagne.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.6],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // "N" monogram medallion — thin gold ring, Playfair N.
                            const NocturneMonogram(size: 40),
                            const SizedBox(height: 40),

                            // Playfair hero.
                            Text.rich(
                              TextSpan(
                                style: AppTypography.displayMedium.copyWith(
                                  fontSize: 42,
                                  height: 1.05,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'The city keeps\nits best rooms\n',
                                  ),
                                  TextSpan(
                                    text: 'quiet.',
                                    style: AppTypography.italic(
                                      AppTypography.displayMedium,
                                    ).copyWith(
                                      fontSize: 42,
                                      height: 1.05,
                                      color: AppColors.champagne,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: Text(
                                'Find them. An invitation-led guide to '
                                'after-hours culture. Choose how you\'ll enter.',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textBodyDim,
                                  height: 1.7,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Tracked eyebrow.
                            Text(
                              'I am a…'.toUpperCase(),
                              style: AppTypography.labelSmall.copyWith(
                                letterSpacing: 0.26 * 10,
                                color: AppColors.textCaption,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Role cards → signup, each pre-selecting its role.
                            _RoleCard(
                              icon: Icons.local_bar,
                              title: 'Guest',
                              subtitle: 'Discover & reserve the night',
                              highlighted: true,
                              onTap: () => _openSignup(context, 'user'),
                            ),
                            const SizedBox(height: 12),
                            _RoleCard(
                              icon: Icons.campaign,
                              title: 'Promoter',
                              subtitle: 'Fill rooms, earn your standing',
                              onTap: () => _openSignup(context, 'promoter'),
                            ),
                            const SizedBox(height: 12),
                            _RoleCard(
                              icon: Icons.domain,
                              title: 'Club / Venue',
                              subtitle: 'Host & manage your house',
                              onTap: () => _openSignup(context, 'clubAdmin'),
                            ),
                            const SizedBox(height: 28),

                            // Existing-member login path.
                            Center(
                              child: TextButton(
                                onPressed: () =>
                                    _open(context, const LoginScreen()),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.champagne,
                                ),
                                child: Text(
                                  'Existing member · Sign in'.toUpperCase(),
                                  style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.champagne,
                                  ),
                                ),
                              ),
                            ),

                            const Spacer(),
                            const SizedBox(height: 24),
                            const Center(child: _LegalLinksText()),
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

  /// Opens signup with the tapped role pre-selected. The role string maps
  /// directly to the app's real role values ('user'/'promoter'/'clubAdmin').
  void _openSignup(BuildContext context, String role) {
    _open(context, SignupScreen(initialRole: role));
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

// ─── Role card ─────────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    // The primary (Guest) card gets the gold outline + wash; the rest are faint.
    final borderColor =
        highlighted ? AppColors.champagne : AppColors.textDisabled;
    final iconColor = highlighted ? AppColors.champagne : AppColors.textBody;
    final arrowColor =
        highlighted ? AppColors.champagne : AppColors.textSecondary;

    return Material(
      color: highlighted ? AppColors.goldWash : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        splashColor: AppColors.goldWash,
        highlightColor: AppColors.goldWash,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textBodyDim,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward, size: 20, color: arrowColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Legal links (Privacy / Terms — wired to AppConstants) ─────────────────────

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
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final baseStyle = AppTypography.bodySmall.copyWith(
      fontSize: 11,
      height: 1.7,
      color: AppColors.textCaption,
    );
    final linkStyle = baseStyle.copyWith(
      color: AppColors.champagne,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.champagne,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'By entering you accept our\n'),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: 'Terms of Service',
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

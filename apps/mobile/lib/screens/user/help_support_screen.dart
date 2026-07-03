import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/support_sheets.dart';

/// Static Help & Support surface (no backend): honest FAQ answers, a support
/// email link, and legal shortcuts. Rendered inside the user shell's content
/// area, so it's a plain scrollable body rather than its own Scaffold.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    _Faq(
      question: 'How do I RSVP to an event?',
      answer:
          'Open an event, tap Confirm RSVP, and confirm the details. Your RSVP '
          'then appears under My RSVPs. Final admission still depends on age, '
          'capacity, dress code, and venue policy.',
    ),
    _Faq(
      question: "What does 'pay at venue' mean?",
      answer:
          'You reserve your spot in the app but pay any cover or entry charge '
          'directly at the venue. No payment is taken inside the app.',
    ),
    _Faq(
      question: 'How do I save events?',
      answer:
          'Tap the heart on any event card or event page to save it. Saved '
          'events appear on your Favorites tab so you can find them later.',
    ),
    _Faq(
      question: 'How do I become a promoter?',
      answer:
          'Sign out, choose Promoter on the sign-up screen, and create a '
          'promoter account. You get a referral code and a dashboard to track '
          'the RSVPs made through your link.',
    ),
    _Faq(
      question: "What's the minimum age to use the app?",
      answer:
          'You must be at least 18 years old. Sign-up asks for your date of '
          'birth and blocks anyone under 18.',
    ),
    _Faq(
      question: 'How do I delete my account?',
      answer:
          'Go to Settings > Delete account. You confirm your password, then '
          'your account is deactivated and scheduled for deletion. This cannot '
          'be undone.',
    ),
  ];

  Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: const {'subject': 'Nightlife app support'},
    );
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open your email app")),
      );
    }
  }

  Future<void> _openLegalUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    var launched = false;
    if (uri != null) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the link")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      children: [
        Text(
          'Help',
          style: AppTypography.displayMedium.copyWith(fontSize: 30),
        ),
        const SizedBox(height: 28),

        // ── FAQ ──────────────────────────────────────────────────────────
        const _SectionEyebrow('FAQ'),
        for (final faq in _faqs) _FaqTile(faq: faq),
        const SizedBox(height: 26),

        // ── Contact ──────────────────────────────────────────────────────
        const _SectionEyebrow('Contact'),
        _SupportTile(
          icon: Icons.mail_outline,
          title: 'Email us',
          subtitle: 'Account, RSVP, and event help.',
          onTap: () => _emailSupport(context),
        ),
        const SizedBox(height: 26),

        // ── Event issues ─────────────────────────────────────────────────
        const _SectionEyebrow('Event Issues'),
        _SupportTile(
          icon: Icons.report_gmailerrorred_outlined,
          title: 'Report an event',
          subtitle: 'Flag inaccurate, misleading, or unsafe listings.',
          onTap: () => showReportEventSheet(context),
        ),
        const _RowHairline(),
        _SupportTile(
          icon: Icons.confirmation_number_outlined,
          title: 'RSVP problem',
          subtitle: 'Get help with pending, duplicate, or missing RSVPs.',
          onTap: () => showRsvpProblemSheet(context),
        ),
        const SizedBox(height: 26),

        // ── Legal ────────────────────────────────────────────────────────
        const _SectionEyebrow('Legal'),
        _SupportTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          trailingIcon: Icons.north_east,
          onTap: () => _openLegalUrl(context, AppConstants.privacyPolicyUrl),
        ),
        const _RowHairline(),
        _SupportTile(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          trailingIcon: Icons.north_east,
          onTap: () => _openLegalUrl(context, AppConstants.termsOfServiceUrl),
        ),
      ],
    );
  }
}

class _Faq {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final _Faq faq;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: AppColors.goldBorder),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 14),
        iconColor: AppColors.champagne,
        collapsedIconColor: AppColors.textSecondary,
        title: Text(
          faq.question,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textHigh),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              faq.answer,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textBodyDim,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingIcon,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.champagne),
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textHigh),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textCaption,
              ),
            ),
      trailing: Icon(
        trailingIcon ?? Icons.chevron_right,
        color: AppColors.textSecondary,
        size: trailingIcon == null ? 18 : 18,
      ),
      onTap: onTap,
    );
  }
}

class _RowHairline extends StatelessWidget {
  const _RowHairline();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.goldBorder);
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.champagne,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.champagne.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

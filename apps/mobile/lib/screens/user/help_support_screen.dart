import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _SupportSection(
          title: 'FAQ',
          child: Column(
            children: [
              for (final faq in _faqs) _FaqTile(faq: faq),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SupportSection(
          title: 'CONTACT',
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: const Icon(Icons.mail_outline, color: AppTheme.accentPink),
            title: const Text(
              'Email us',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Account, RSVP, and event help.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _emailSupport(context),
          ),
        ),
        const SizedBox(height: 14),
        _SupportSection(
          title: 'EVENT ISSUES',
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(
                  Icons.report_gmailerrorred_outlined,
                  color: AppTheme.accentPink,
                ),
                title: const Text(
                  'Report an event',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Flag inaccurate, misleading, or unsafe listings.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showReportEventSheet(context),
              ),
              Divider(
                height: 1,
                indent: 56,
                endIndent: 14,
                color: AppTheme.glassBorder.withValues(alpha: 0.75),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppTheme.accentPink,
                ),
                title: const Text(
                  'RSVP problem',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Get help with pending, duplicate, or missing RSVPs.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showRsvpProblemSheet(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SupportSection(
          title: 'LEGAL',
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(
                  Icons.privacy_tip_outlined,
                  color: AppTheme.accentPink,
                ),
                title: const Text(
                  'Privacy Policy',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _openLegalUrl(context, AppConstants.privacyPolicyUrl),
              ),
              Divider(
                height: 1,
                indent: 56,
                endIndent: 14,
                color: AppTheme.glassBorder.withValues(alpha: 0.75),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppTheme.accentPink,
                ),
                title: const Text(
                  'Terms of Service',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _openLegalUrl(context, AppConstants.termsOfServiceUrl),
              ),
            ],
          ),
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
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        iconColor: AppTheme.accentPink,
        collapsedIconColor: AppTheme.textMuted,
        title: Text(
          faq.question,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              faq.answer,
              style: const TextStyle(color: AppTheme.textMuted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportSection extends StatelessWidget {
  const _SupportSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.neonLime,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

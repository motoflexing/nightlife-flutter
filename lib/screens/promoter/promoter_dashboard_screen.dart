import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/promoter.dart';
import '../../models/rsvp.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/state_views.dart';

class PromoterDashboardScreen extends StatelessWidget {
  const PromoterDashboardScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: AppBar(
        title: const Text('Promoter dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: AuthService.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      child: StreamBuilder<Promoter?>(
        stream: FirestoreService.instance.promoterForUserStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading promoter profile');
          }
          if (snapshot.hasError) return ErrorStateView(message: snapshot.error.toString());
          final promoter = snapshot.data;
          if (promoter == null) {
            return const EmptyView(
              title: 'Promoter profile pending',
              message: 'Ask an admin to switch your role to promoter again to create the referral profile.',
              icon: Icons.campaign_outlined,
            );
          }
          return _PromoterContent(promoter: promoter);
        },
      ),
    );
  }
}

class _PromoterContent extends StatelessWidget {
  const _PromoterContent({required this.promoter});

  final Promoter promoter;

  @override
  Widget build(BuildContext context) {
    final link = Uri.base.replace(queryParameters: {'ref': promoter.referralCode}).toString();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 860;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _MetricCard(
                  title: 'Referral code',
                  value: promoter.referralCode,
                  icon: Icons.qr_code_2,
                  action: IconButton(
                    tooltip: 'Copy code',
                    onPressed: () => _copy(context, promoter.referralCode),
                    icon: const Icon(Icons.copy),
                  ),
                ),
                _MetricCard(
                  title: 'Total RSVP credits',
                  value: promoter.totalRsvps.toString(),
                  icon: Icons.trending_up,
                ),
                _MetricCard(
                  title: 'Status',
                  value: promoter.isActive ? 'Active' : 'Inactive',
                  icon: Icons.verified_user_outlined,
                ),
              ]
                  .map(
                    (child) => SizedBox(
                      width: wide ? (constraints.maxWidth - 60) / 3 : double.infinity,
                      child: child,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Referral link',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(link, style: const TextStyle(color: AppTheme.neonCyan)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _copy(context, link),
                      icon: const Icon(Icons.link),
                      label: const Text('Copy link'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Generated RSVPs',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<Rsvp>>(
              stream: FirestoreService.instance.promoterRsvpsStream(promoter.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return ErrorStateView(message: snapshot.error.toString());
                }
                final rsvps = snapshot.data ?? [];
                if (rsvps.isEmpty) {
                  return const EmptyView(
                    title: 'No RSVP credits yet',
                    message: 'Share your referral link or code to start tracking.',
                    icon: Icons.insights_outlined,
                  );
                }
                return Column(
                  children: rsvps.map((rsvp) => _RsvpRow(rsvp: rsvp)).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.action,
  });

  final String title;
  final String value;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.neonPink.withValues(alpha: 0.14),
              child: Icon(icon, color: AppTheme.neonPink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _RsvpRow extends StatelessWidget {
  const _RsvpRow({required this.rsvp});

  final Rsvp rsvp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          title: Text(rsvp.eventTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
            '${rsvp.userName} • ${rsvp.userPhone} • ${Formatters.eventDate(rsvp.createdAt)}',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          trailing: Chip(label: Text(Formatters.titleCase(rsvp.status))),
        ),
      ),
    );
  }
}

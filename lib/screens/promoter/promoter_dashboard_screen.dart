// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
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
        title: const Text('Promoter'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: AuthService.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      child: StreamBuilder<Promoter?>(
        stream: FirestoreService.instance.promoterForUserStream(
          currentUser.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading promoter profile');
          }
          if (snapshot.hasError)
            return ErrorStateView(message: snapshot.error.toString());
          final promoter = snapshot.data;
          if (promoter == null) {
            return const EmptyView(
              title: 'Promoter profile unavailable',
              message: 'Sign out and back in to refresh your referral profile.',
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
    return StreamBuilder<List<Rsvp>>(
      stream: FirestoreService.instance.promoterRsvpsStream(promoter.id),
      builder: (context, snapshot) {
        final rsvps = snapshot.data ?? [];
        final eventCounts = <String, int>{};
        for (final rsvp in rsvps) {
          eventCounts[rsvp.eventId] = (eventCounts[rsvp.eventId] ?? 0) + 1;
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 860;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children:
                      [
                            _MetricCard(
                              title: 'Referral code',
                              value: promoter.referralCode,
                              icon: Icons.qr_code_2,
                              action: IconButton(
                                tooltip: 'Copy code',
                                onPressed: () =>
                                    _copy(context, promoter.referralCode),
                                icon: const Icon(Icons.copy),
                              ),
                            ),
                            _MetricCard(
                              title: 'Total RSVP credits',
                              value:
                                  snapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? '...'
                                  : rsvps.length.toString(),
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
                              width: wide
                                  ? (constraints.maxWidth - 60) / 3
                                  : double.infinity,
                              child: child,
                            ),
                          )
                          .toList(),
                ),
                Text(
                  'Active Events',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Copy any live event link. Promoters can share immediately.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<NightlifeEvent>>(
                  stream: FirestoreService.instance.activeEventsStream(),
                  builder: (context, eventSnapshot) {
                    final events = eventSnapshot.data ?? [];
                    if (eventSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (events.isEmpty) {
                      return const EmptyView(
                        title: 'No active events',
                        message: 'Share event links and track your RSVPs.',
                        icon: Icons.local_activity_outlined,
                      );
                    }
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: events
                          .map(
                            (event) => SizedBox(
                              width: wide
                                  ? (constraints.maxWidth - 46) / 2
                                  : double.infinity,
                              child: _PromoterEventCard(
                                event: event,
                                rsvpCount: eventCounts[event.id] ?? 0,
                                referralLink: _eventReferralLink(
                                  event,
                                  promoter.referralCode,
                                ),
                                onCopy: (value) => _copy(context, value),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Generated RSVPs',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  ErrorStateView(message: snapshot.error.toString())
                else if (rsvps.isEmpty)
                  const EmptyView(
                    title: 'No RSVP credits yet',
                    message:
                        'Share your referral link or code to start tracking.',
                    icon: Icons.insights_outlined,
                  )
                else
                  Column(
                    children: rsvps
                        .map((rsvp) => _RsvpRow(rsvp: rsvp))
                        .toList(),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  String _eventReferralLink(NightlifeEvent event, String referralCode) {
    return '/event/${Uri.encodeComponent(event.id)}?ref=$referralCode';
  }
}

class _PromoterEventCard extends StatelessWidget {
  const _PromoterEventCard({
    required this.event,
    required this.rsvpCount,
    required this.referralLink,
    required this.onCopy,
  });

  final NightlifeEvent event;
  final int rsvpCount;
  final String referralLink;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: event.posterUrl.isEmpty
                ? const _PosterFallback()
                : Image.network(
                    event.posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _PosterFallback(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _EventLine(icon: Icons.place_outlined, text: event.venueName),
                _EventLine(
                  icon: Icons.location_city_outlined,
                  text: event.city,
                ),
                _EventLine(
                  icon: Icons.schedule,
                  text: Formatters.eventDate(event.dateTime),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text('$rsvpCount RSVPs'),
                      avatar: const Icon(Icons.confirmation_number, size: 18),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onCopy(referralLink),
                      icon: const Icon(Icons.link),
                      label: const Text('Copy referral link'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.elevated,
      child: const Icon(
        Icons.local_activity_outlined,
        color: AppTheme.neonCyan,
        size: 48,
      ),
    );
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
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
                  Text(
                    title,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
          title: Text(
            rsvp.eventTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${rsvp.userName} - ${rsvp.userPhone} - ${Formatters.eventDate(rsvp.createdAt)}',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          trailing: Chip(label: Text(Formatters.titleCase(rsvp.status))),
        ),
      ),
    );
  }
}

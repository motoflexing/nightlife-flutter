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
import '../../widgets/compact_ui.dart';
import '../../widgets/event_poster.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/state_views.dart';

class PromoterDashboardScreen extends StatelessWidget {
  const PromoterDashboardScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: AppBar(
        title: const Text('Promoter Studio'),
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
          if (snapshot.hasError) {
            return ErrorStateView(message: snapshot.error.toString());
          }
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

  static const _commissionPerApprovedRsvp = 120;

  final Promoter promoter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Rsvp>>(
      stream: FirestoreService.instance.promoterRsvpsStream(promoter.id),
      builder: (context, rsvpSnapshot) {
        if (rsvpSnapshot.hasError) {
          return ErrorStateView(message: rsvpSnapshot.error.toString());
        }
        final rsvps = rsvpSnapshot.data ?? [];
        final pending = rsvps.where((rsvp) => rsvp.status == 'pending').length;
        final approved = rsvps
            .where((rsvp) => rsvp.status == 'approved')
            .length;
        final total = rsvps.length;
        final conversion = total == 0 ? 0 : (approved / total * 100).round();
        final estimatedEarnings = approved * _commissionPerApprovedRsvp;
        final thisWeek = rsvps.where((rsvp) {
          return DateTime.now().difference(rsvp.createdAt).inDays <= 7;
        }).length;
        final eventCounts = <String, int>{};
        for (final rsvp in rsvps) {
          eventCounts[rsvp.eventId] = (eventCounts[rsvp.eventId] ?? 0) + 1;
        }

        return StreamBuilder<List<NightlifeEvent>>(
          stream: FirestoreService.instance.activeEventsStream(),
          builder: (context, eventSnapshot) {
            if (eventSnapshot.hasError) {
              return ErrorStateView(message: eventSnapshot.error.toString());
            }
            final events = eventSnapshot.data ?? [];
            final bestEvent = _bestEventTitle(events, eventCounts);

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: compactScreenPadding(context, bottom: 28),
              children: [
                _HeroPanel(
                  promoter: promoter,
                  total: total,
                  earnings: estimatedEarnings,
                  onCopy: (value) => _copy(context, value),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 980 ? 4 : 2;
                    final width =
                        (constraints.maxWidth - ((columns - 1) * 8)) / columns;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                                _MetricCard(
                                  title: 'Total RSVP credits',
                                  value: total.toString(),
                                  icon: Icons.trending_up,
                                ),
                                _MetricCard(
                                  title: 'Approved RSVPs',
                                  value: approved.toString(),
                                  icon: Icons.verified_outlined,
                                  accent: AppTheme.neonLime,
                                ),
                                _MetricCard(
                                  title: 'Conversion rate',
                                  value: '$conversion%',
                                  icon: Icons.insights_outlined,
                                ),
                                _MetricCard(
                                  title: 'Estimated earnings',
                                  value: 'INR $estimatedEarnings',
                                  icon: Icons.payments_outlined,
                                  accent: AppTheme.neonLime,
                                ),
                              ]
                              .map(
                                (child) => SizedBox(width: width, child: child),
                              )
                              .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _PerformancePanel(
                  total: total,
                  pending: pending,
                  approved: approved,
                  bestEvent: bestEvent,
                  earnings: estimatedEarnings,
                  thisWeek: thisWeek,
                ),
                const SizedBox(height: 16),
                const _GrowthSuggestions(),
                const SizedBox(height: 18),
                _SectionHeader(
                  title: 'Active Events',
                  subtitle:
                      eventSnapshot.connectionState == ConnectionState.waiting
                      ? 'Loading events to promote...'
                      : 'Pick the highest-fit event and push your link now.',
                ),
                const SizedBox(height: 10),
                if (eventSnapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (events.isEmpty)
                  const EmptyView(
                    title: 'No active events',
                    message:
                        'Events will appear here when venues publish nights you can promote.',
                    icon: Icons.local_activity_outlined,
                  )
                else
                  ...events.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PromoterEventCard(
                        event: event,
                        rsvpCount: eventCounts[event.id] ?? 0,
                        commissionPerRsvp: _commissionPerApprovedRsvp,
                        referralLink: _eventReferralLink(
                          event,
                          promoter.referralCode,
                        ),
                        onCopy: (value) => _copy(context, value),
                      ),
                    ),
                  ),
                if (rsvpSnapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (rsvps.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _SectionHeader(
                    title: 'Recent RSVP Credits',
                    subtitle: 'Fresh activity from your referral traffic.',
                  ),
                  const SizedBox(height: 10),
                  ...rsvps.take(5).map((rsvp) => _RsvpRow(rsvp: rsvp)),
                ],
              ],
            );
          },
        );
      },
    );
  }

  static String _bestEventTitle(
    List<NightlifeEvent> events,
    Map<String, int> eventCounts,
  ) {
    if (eventCounts.isEmpty) return 'No winner yet';
    final bestId = eventCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return events
            .firstWhere(
              (event) => event.id == bestId,
              orElse: () => NightlifeEvent.empty(),
            )
            .title
            .trim()
            .isEmpty
        ? 'Event $bestId'
        : events.firstWhere((event) => event.id == bestId).title;
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied referral link')));
  }

  String _eventReferralLink(NightlifeEvent event, String referralCode) {
    return '/event/${Uri.encodeComponent(event.id)}?ref=$referralCode';
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.promoter,
    required this.total,
    required this.earnings,
    required this.onCopy,
  });

  final Promoter promoter;
  final int total;
  final int earnings;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    return Container(
      padding: EdgeInsets.all(mobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.glassSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPink.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: mobile ? 40 : 50,
                height: mobile ? 40 : 50,
                decoration: BoxDecoration(
                  gradient: AppTheme.premiumGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.campaign_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promoter.name.isEmpty ? 'Promoter Studio' : promoter.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      promoter.isActive ? 'Active growth profile' : 'Inactive',
                      style: TextStyle(
                        color: promoter.isActive
                            ? AppTheme.neonLime
                            : AppTheme.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: mobile ? 10 : 14),
          Container(
            padding: EdgeInsets.all(mobile ? 9 : 12),
            decoration: BoxDecoration(
              color: AppTheme.elevated.withValues(alpha: 0.64),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    promoter.referralCode,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: mobile ? 20 : null,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Copy referral code',
                  onPressed: () => onCopy(promoter.referralCode),
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$total tracked RSVPs - estimated INR $earnings earned',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PerformancePanel extends StatelessWidget {
  const _PerformancePanel({
    required this.total,
    required this.pending,
    required this.approved,
    required this.bestEvent,
    required this.earnings,
    required this.thisWeek,
  });

  final int total;
  final int pending;
  final int approved;
  final String bestEvent;
  final int earnings;
  final int thisWeek;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Promoter Performance',
            subtitle: 'What your traffic is doing for the business.',
          ),
          const SizedBox(height: 12),
          _InsightRow(label: 'Total RSVPs generated', value: total.toString()),
          _InsightRow(label: 'Pending RSVPs', value: pending.toString()),
          _InsightRow(label: 'Approved RSVPs', value: approved.toString()),
          _InsightRow(label: 'Best performing event', value: bestEvent),
          _InsightRow(label: 'Estimated commission', value: 'INR $earnings'),
          _InsightRow(label: 'This week', value: '$thisWeek RSVPs'),
        ],
      ),
    );
  }
}

class _GrowthSuggestions extends StatelessWidget {
  const _GrowthSuggestions();

  static const _tips = [
    'Share before 7 PM',
    'Post story with referral link',
    'Target nearby college crowd',
    'Promote guestlist closing time',
    'Share WhatsApp status',
  ];

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Boost your RSVPs',
            subtitle: 'Small moves that usually convert better tonight.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tips
                .map(
                  (tip) => Chip(
                    avatar: const Icon(Icons.bolt_outlined, size: 17),
                    label: Text(tip),
                    backgroundColor: AppTheme.accentPink.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: AppTheme.accentPink.withValues(alpha: 0.28),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PromoterEventCard extends StatelessWidget {
  const _PromoterEventCard({
    required this.event,
    required this.rsvpCount,
    required this.commissionPerRsvp,
    required this.referralLink,
    required this.onCopy,
  });

  final NightlifeEvent event;
  final int rsvpCount;
  final int commissionPerRsvp;
  final String referralLink;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final earnings = rsvpCount * commissionPerRsvp;
    final hot = rsvpCount >= 5;
    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 142,
            child: Stack(
              fit: StackFit.expand,
              children: [
                EventPoster(event: event, borderRadius: 8, showTitle: false),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xE6050509)],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Text(
                    event.title.isEmpty ? 'Untitled Event' : event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EventLine(
                  icon: Icons.storefront_outlined,
                  text: '${event.venueName} - ${event.city}',
                ),
                _EventLine(
                  icon: Icons.schedule,
                  text: Formatters.eventDate(event.dateTime),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniChip(label: '$rsvpCount RSVPs'),
                    _MiniChip(label: 'INR $earnings est.'),
                    _MiniChip(
                      label: hot ? 'High intent' : 'Needs push',
                      color: hot ? AppTheme.neonLime : AppTheme.accentPink,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onCopy(referralLink),
                        icon: const Icon(Icons.link),
                        label: const Text('Copy link'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Share',
                      onPressed: () => onCopy(referralLink),
                      icon: const Icon(Icons.ios_share_outlined),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.accent = AppTheme.accentPink,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CompactStatCard(
      icon: icon,
      value: value,
      label: title,
      accent: accent,
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
      child: _Panel(
        child: Row(
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              color: AppTheme.accentPink,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rsvp.eventTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${rsvp.userName} - ${Formatters.eventDate(rsvp.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _MiniChip(label: Formatters.titleCase(rsvp.status)),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    return Container(
      padding: padding == const EdgeInsets.all(14)
          ? EdgeInsets.all(mobile ? 12 : 14)
          : padding,
      decoration: BoxDecoration(
        color: AppTheme.glassSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonViolet.withValues(alpha: 0.08),
            blurRadius: mobile ? 14 : 22,
            offset: Offset(0, mobile ? 8 : 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: AppTheme.textMuted)),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, this.color = AppTheme.neonViolet});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

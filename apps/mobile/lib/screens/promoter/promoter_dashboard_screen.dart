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
import '../../widgets/premium_loader.dart';
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
            tooltip: 'Profile',
            onPressed: () => _showPromoterProfile(context, null, currentUser),
            icon: const Icon(Icons.person_outline),
          ),
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
          return _PromoterContent(promoter: promoter, currentUser: currentUser);
        },
      ),
    );
  }
}

class _PromoterContent extends StatelessWidget {
  const _PromoterContent({required this.promoter, required this.currentUser});

  static const _commissionPerApprovedRsvp = 120;

  final Promoter promoter;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Rsvp>>(
      stream: FirestoreService.instance.promoterRsvpsStream(promoter.id),
      builder: (context, rsvpSnapshot) {
        if (rsvpSnapshot.hasError) {
          return ErrorStateView(message: rsvpSnapshot.error.toString());
        }

        final rsvps = rsvpSnapshot.data ?? [];
        final stats = _PromoterStats.fromRsvps(
          rsvps,
          commissionPerApprovedRsvp: _commissionPerApprovedRsvp,
        );

        return StreamBuilder<List<NightlifeEvent>>(
          stream: FirestoreService.instance.activeEventsStream(),
          builder: (context, eventSnapshot) {
            if (eventSnapshot.hasError) {
              return ErrorStateView(message: eventSnapshot.error.toString());
            }

            final events = eventSnapshot.data ?? [];
            final bestEvent = stats.bestEventTitle(events);
            final highestConversionEvent = stats.highestConversionEventTitle(
              events,
            );
            final needsPush = _eventsNeedingPush(events, stats.eventTotals);
            final referralCode = promoter.referralCode.trim();
            final generalReferralLink = _generalReferralLink(referralCode);

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: compactScreenPadding(context, bottom: 30),
              children: [
                _PromoterProfilePanel(
                  promoter: promoter,
                  currentUser: currentUser,
                  totalRsvps: stats.total,
                  estimatedEarnings: stats.estimatedEarnings,
                  referralLink: generalReferralLink,
                  onCopy: (value) => _copy(context, value),
                  onShare: (value) => _share(context, value),
                  onProfile: () =>
                      _showPromoterProfile(context, promoter, currentUser),
                  onLogout: AuthService.instance.signOut,
                ),
                const SizedBox(height: 14),
                if (rsvpSnapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: PremiumLoader(message: 'Loading RSVP credits...'),
                  )
                else if (stats.total == 0)
                  _PromoterEmptyState(
                    hasEvents: events.isNotEmpty,
                    onCopyReferral: () => _copy(context, generalReferralLink),
                    onShareEvent: () {
                      final eventLink = events.isEmpty
                          ? generalReferralLink
                          : _eventReferralLink(events.first, referralCode);
                      _share(context, eventLink);
                    },
                  ),
                const SizedBox(height: 14),
                _KpiGrid(
                  stats: stats,
                  bestEvent: bestEvent,
                  thisMonthEarnings: stats.thisMonthEarnings,
                ),
                const SizedBox(height: 16),
                _RevenueOverview(stats: stats),
                const SizedBox(height: 16),
                _PerformanceInsights(
                  bestEvent: bestEvent,
                  highestConversionEvent: highestConversionEvent,
                  needsPush: needsPush,
                  recommendedAction: _recommendedAction(stats, needsPush),
                ),
                const SizedBox(height: 18),
                _SectionHeader(
                  title: 'Active Events',
                  subtitle:
                      eventSnapshot.connectionState == ConnectionState.waiting
                      ? 'Loading events to promote...'
                      : 'Push the right event, track the return, repeat.',
                ),
                const SizedBox(height: 10),
                if (eventSnapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: PremiumLoader(message: 'Curating events...'),
                  )
                else if (events.isEmpty)
                  const EmptyView(
                    title: 'No active events',
                    message:
                        'Events will appear here when venues publish nights you can promote.',
                    icon: Icons.local_activity_outlined,
                  )
                else
                  ...events.map((event) {
                    final eventRsvps = stats.eventTotals[event.id] ?? 0;
                    final approved = stats.eventApprovedTotals[event.id] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PromoterEventCard(
                        event: event,
                        rsvpCount: eventRsvps,
                        approvedCount: approved,
                        commissionPerRsvp: _commissionPerApprovedRsvp,
                        referralLink: _eventReferralLink(event, referralCode),
                        onCopy: (value) => _copy(context, value),
                        onShare: (value) => _share(context, value),
                      ),
                    );
                  }),
                if (rsvps.isNotEmpty) ...[
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

  static List<String> _eventsNeedingPush(
    List<NightlifeEvent> events,
    Map<String, int> eventTotals,
  ) {
    return events
        .where((event) => (eventTotals[event.id] ?? 0) < 3)
        .take(2)
        .map((event) => event.title.trim().isEmpty ? 'Untitled' : event.title)
        .toList(growable: false);
  }

  static String _recommendedAction(
    _PromoterStats stats,
    List<String> needsPush,
  ) {
    if (stats.total == 0) return 'Share your best event link before 7 PM.';
    if (needsPush.isNotEmpty) return 'Push guestlist closing time tonight.';
    if (stats.conversionRate < 50) {
      return 'Share WhatsApp status with the link.';
    }
    return 'Double down on your best performing event.';
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied referral link')));
  }

  void _share(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral link copied and ready to share')),
    );
  }

  String _eventReferralLink(NightlifeEvent event, String referralCode) {
    return '/event/${Uri.encodeComponent(event.id)}?ref=$referralCode';
  }

  String _generalReferralLink(String referralCode) {
    return referralCode.isEmpty ? '/?ref=' : '/?ref=$referralCode';
  }
}

class _PromoterStats {
  const _PromoterStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.conversionRate,
    required this.estimatedEarnings,
    required this.approvedCommission,
    required this.pendingCommission,
    required this.thisWeekRsvps,
    required this.thisMonthEarnings,
    required this.eventTotals,
    required this.eventApprovedTotals,
    required this.eventConversionRates,
  });

  final int total;
  final int pending;
  final int approved;
  final int conversionRate;
  final int estimatedEarnings;
  final int approvedCommission;
  final int pendingCommission;
  final int thisWeekRsvps;
  final int thisMonthEarnings;
  final Map<String, int> eventTotals;
  final Map<String, int> eventApprovedTotals;
  final Map<String, int> eventConversionRates;

  factory _PromoterStats.fromRsvps(
    List<Rsvp> rsvps, {
    required int commissionPerApprovedRsvp,
  }) {
    final now = DateTime.now();
    var pending = 0;
    var approved = 0;
    var thisWeek = 0;
    var approvedThisMonth = 0;
    final eventTotals = <String, int>{};
    final eventApprovedTotals = <String, int>{};

    for (final rsvp in rsvps) {
      final status = rsvp.status.toLowerCase();
      if (status == 'pending') pending++;
      if (status == 'approved') {
        approved++;
        eventApprovedTotals[rsvp.eventId] =
            (eventApprovedTotals[rsvp.eventId] ?? 0) + 1;
        if (rsvp.createdAt.year == now.year &&
            rsvp.createdAt.month == now.month) {
          approvedThisMonth++;
        }
      }
      if (now.difference(rsvp.createdAt).inDays <= 7) thisWeek++;
      eventTotals[rsvp.eventId] = (eventTotals[rsvp.eventId] ?? 0) + 1;
    }

    final conversion = rsvps.isEmpty
        ? 0
        : (approved / rsvps.length * 100).round();
    final eventConversionRates = <String, int>{};
    for (final entry in eventTotals.entries) {
      final eventApproved = eventApprovedTotals[entry.key] ?? 0;
      eventConversionRates[entry.key] = entry.value == 0
          ? 0
          : (eventApproved / entry.value * 100).round();
    }

    return _PromoterStats(
      total: rsvps.length,
      pending: pending,
      approved: approved,
      conversionRate: conversion,
      estimatedEarnings: approved * commissionPerApprovedRsvp,
      approvedCommission: approved * commissionPerApprovedRsvp,
      pendingCommission: pending * commissionPerApprovedRsvp,
      thisWeekRsvps: thisWeek,
      thisMonthEarnings: approvedThisMonth * commissionPerApprovedRsvp,
      eventTotals: eventTotals,
      eventApprovedTotals: eventApprovedTotals,
      eventConversionRates: eventConversionRates,
    );
  }

  String bestEventTitle(List<NightlifeEvent> events) {
    if (eventTotals.isEmpty) return 'No winner yet';
    final bestId = eventTotals.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return _eventTitle(events, bestId);
  }

  String highestConversionEventTitle(List<NightlifeEvent> events) {
    if (eventConversionRates.isEmpty) return 'Needs more data';
    final bestId = eventConversionRates.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return _eventTitle(events, bestId);
  }

  String _eventTitle(List<NightlifeEvent> events, String eventId) {
    for (final event in events) {
      if (event.id == eventId && event.title.trim().isNotEmpty) {
        return event.title;
      }
    }
    return eventId.trim().isEmpty ? 'Unknown event' : 'Event $eventId';
  }
}

class _PromoterProfilePanel extends StatelessWidget {
  const _PromoterProfilePanel({
    required this.promoter,
    required this.currentUser,
    required this.totalRsvps,
    required this.estimatedEarnings,
    required this.referralLink,
    required this.onCopy,
    required this.onShare,
    required this.onProfile,
    required this.onLogout,
  });

  final Promoter promoter;
  final AppUser currentUser;
  final int totalRsvps;
  final int estimatedEarnings;
  final String referralLink;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onShare;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    final name = promoter.name.trim().isEmpty
        ? currentUser.name.trim().isEmpty
              ? 'Promoter Studio'
              : currentUser.name
        : promoter.name;
    final code = promoter.referralCode.trim().isEmpty
        ? 'NO-CODE'
        : promoter.referralCode.trim();

    return _Panel(
      padding: EdgeInsets.all(mobile ? 13 : 16),
      glow: AppTheme.accentPink.withValues(alpha: 0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PromoterAvatar(name: name, size: mobile ? 48 : 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MiniChip(
                          label: promoter.isActive
                              ? 'Active Promoter'
                              : 'Inactive',
                          color: promoter.isActive
                              ? AppTheme.neonLime
                              : AppTheme.textMuted,
                        ),
                        _MiniChip(label: '$totalRsvps tracked RSVPs'),
                      ],
                    ),
                  ],
                ),
              ),
              _CompactIconAction(
                tooltip: 'Profile settings',
                icon: Icons.manage_accounts_outlined,
                onPressed: onProfile,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.elevated.withValues(alpha: 0.64),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Referral code',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontSize: mobile ? 22 : 26,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    _CompactIconAction(
                      tooltip: 'Copy referral code',
                      icon: Icons.copy,
                      onPressed: () => onCopy(code),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroValue(
                  label: 'Estimated earnings',
                  value: 'INR $estimatedEarnings',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroValue(
                  label: 'Growth status',
                  value: totalRsvps == 0 ? 'Launch' : 'Live',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                icon: Icons.link,
                label: 'Copy Link',
                onPressed: () => onCopy(referralLink),
              ),
              _ActionButton(
                icon: Icons.ios_share_outlined,
                label: 'Share Link',
                onPressed: () => onShare(referralLink),
              ),
              _ActionButton(
                icon: Icons.person_outline,
                label: 'Profile',
                onPressed: onProfile,
              ),
              _ActionButton(
                icon: Icons.logout,
                label: 'Logout',
                subtle: true,
                onPressed: onLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.stats,
    required this.bestEvent,
    required this.thisMonthEarnings,
  });

  final _PromoterStats stats;
  final String bestEvent;
  final int thisMonthEarnings;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiCardData(
        title: 'Total RSVPs',
        value: stats.total.toString(),
        caption: 'All referral credits',
        icon: Icons.trending_up,
      ),
      _KpiCardData(
        title: 'Approved RSVPs',
        value: stats.approved.toString(),
        caption: 'Commission-ready',
        icon: Icons.verified_outlined,
        accent: AppTheme.neonLime,
      ),
      _KpiCardData(
        title: 'Pending RSVPs',
        value: stats.pending.toString(),
        caption: 'Awaiting approval',
        icon: Icons.hourglass_top_outlined,
      ),
      _KpiCardData(
        title: 'Conversion Rate',
        value: '${stats.conversionRate}%',
        caption: 'Approved vs total',
        icon: Icons.insights_outlined,
      ),
      _KpiCardData(
        title: 'Estimated Earnings',
        value: 'INR ${stats.estimatedEarnings}',
        caption: 'Projected payout',
        icon: Icons.payments_outlined,
        accent: AppTheme.neonLime,
      ),
      _KpiCardData(
        title: 'Best Event',
        value: bestEvent,
        caption: 'Top RSVP source',
        icon: Icons.local_fire_department_outlined,
      ),
      _KpiCardData(
        title: 'This Week RSVPs',
        value: stats.thisWeekRsvps.toString(),
        caption: 'Recent traffic',
        icon: Icons.calendar_view_week_outlined,
      ),
      _KpiCardData(
        title: 'This Month Earnings',
        value: 'INR $thisMonthEarnings',
        caption: 'Approved this month',
        icon: Icons.account_balance_wallet_outlined,
        accent: AppTheme.neonLime,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 640;
        final columns = constraints.maxWidth >= 980
            ? 4
            : mobile
            ? 1
            : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 8)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _KpiCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _RevenueOverview extends StatelessWidget {
  const _RevenueOverview({required this.stats});

  final _PromoterStats stats;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Earnings Snapshot',
            subtitle: 'Commission visibility based on tracked RSVP status.',
          ),
          const SizedBox(height: 12),
          _MoneyRow(
            label: 'Estimated commission',
            value: 'INR ${stats.estimatedEarnings + stats.pendingCommission}',
          ),
          _MoneyRow(
            label: 'Approved commission',
            value: 'INR ${stats.approvedCommission}',
            color: AppTheme.neonLime,
          ),
          _MoneyRow(
            label: 'Pending commission',
            value: 'INR ${stats.pendingCommission}',
          ),
          _MoneyRow(label: 'Payout status', value: 'Pending setup'),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: stats.total == 0 ? 0 : stats.conversionRate / 100,
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            color: AppTheme.neonLime,
          ),
          const SizedBox(height: 8),
          Text(
            stats.total == 0
                ? 'Start sharing to unlock referral performance.'
                : '${stats.conversionRate}% of tracked RSVPs are approved.',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PerformanceInsights extends StatelessWidget {
  const _PerformanceInsights({
    required this.bestEvent,
    required this.highestConversionEvent,
    required this.needsPush,
    required this.recommendedAction,
  });

  final String bestEvent;
  final String highestConversionEvent;
  final List<String> needsPush;
  final String recommendedAction;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Performance Insights',
            subtitle: 'Know where to push next and what is converting.',
          ),
          const SizedBox(height: 12),
          _InsightRow(label: 'Best performing event', value: bestEvent),
          _InsightRow(
            label: 'Highest conversion event',
            value: highestConversionEvent,
          ),
          _InsightRow(
            label: 'Events needing push',
            value: needsPush.isEmpty ? 'None right now' : needsPush.join(', '),
          ),
          _InsightRow(label: 'Recommended action', value: recommendedAction),
        ],
      ),
    );
  }
}

class _PromoterEmptyState extends StatelessWidget {
  const _PromoterEmptyState({
    required this.hasEvents,
    required this.onCopyReferral,
    required this.onShareEvent,
  });

  final bool hasEvents;
  final VoidCallback onCopyReferral;
  final VoidCallback onShareEvent;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      glow: AppTheme.neonViolet.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppTheme.premiumGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.rocket_launch_outlined),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Launch your first campaign',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Start sharing your referral link to track RSVPs and earnings.',
                      style: TextStyle(color: AppTheme.textMuted, height: 1.32),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                icon: Icons.link,
                label: 'Copy referral link',
                onPressed: onCopyReferral,
              ),
              _ActionButton(
                icon: Icons.ios_share_outlined,
                label: hasEvents ? 'Share event' : 'Share link',
                onPressed: onShareEvent,
              ),
              _ActionButton(
                icon: Icons.local_activity_outlined,
                label: 'View active events',
                subtle: true,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Active events are listed below.'),
                    ),
                  );
                },
              ),
            ],
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
    required this.approvedCount,
    required this.commissionPerRsvp,
    required this.referralLink,
    required this.onCopy,
    required this.onShare,
  });

  final NightlifeEvent event;
  final int rsvpCount;
  final int approvedCount;
  final int commissionPerRsvp;
  final String referralLink;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onShare;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    final earnings = approvedCount * commissionPerRsvp;
    final conversion = rsvpCount == 0
        ? 0
        : (approvedCount / rsvpCount * 100).round();
    final performing = rsvpCount >= 5 || conversion >= 60;
    final badge = performing ? 'Performing well' : 'Needs push';
    final badgeColor = performing ? AppTheme.neonLime : AppTheme.accentPink;

    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: mobile ? 156 : 190,
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
                  top: 12,
                  child: _MiniChip(label: badge, color: badgeColor),
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
            padding: EdgeInsets.all(mobile ? 12 : 14),
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniChip(label: '$rsvpCount RSVPs generated'),
                    _MiniChip(
                      label: 'INR $earnings est.',
                      color: AppTheme.neonLime,
                    ),
                    _MiniChip(label: '$conversion% conversion'),
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
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => onShare(referralLink),
                        icon: const Icon(Icons.ios_share_outlined),
                        label: const Text('Share'),
                      ),
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

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiCardData data;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(12),
      glow: data.accent.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: data.accent.withValues(alpha: 0.34)),
            ),
            child: Icon(data.icon, color: data.accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  data.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCardData {
  const _KpiCardData({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    this.accent = AppTheme.accentPink,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color accent;
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.glow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    return Container(
      width: double.infinity,
      padding: padding == const EdgeInsets.all(14)
          ? EdgeInsets.all(mobile ? 12 : 14)
          : padding,
      decoration: BoxDecoration(
        color: AppTheme.glassSurface.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: [
          BoxShadow(
            color: glow ?? AppTheme.neonViolet.withValues(alpha: 0.08),
            blurRadius: mobile ? 16 : 24,
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
        Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textMuted, height: 1.3),
        ),
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

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  final String label;
  final String value;
  final Color color;

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
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.subtle = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final button = subtle
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
    return SizedBox(height: 40, child: button);
  }
}

class _CompactIconAction extends StatelessWidget {
  const _CompactIconAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _PromoterAvatar extends StatelessWidget {
  const _PromoterAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.premiumGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPink.withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
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

void _showPromoterProfile(
  BuildContext context,
  Promoter? promoter,
  AppUser currentUser,
) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final name = promoter?.name.trim().isNotEmpty == true
          ? promoter!.name
          : currentUser.name.trim().isEmpty
          ? 'Promoter Studio'
          : currentUser.name;
      final email = promoter?.email.trim().isNotEmpty == true
          ? promoter!.email
          : currentUser.email;
      final code = promoter?.referralCode.trim().isNotEmpty == true
          ? promoter!.referralCode
          : currentUser.promoterCode ?? '';

      return SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.glassBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _PromoterAvatar(name: name, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const Text(
                              'Active Promoter',
                              style: TextStyle(
                                color: AppTheme.neonLime,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ProfileLine(label: 'Email', value: email),
                  _ProfileLine(label: 'Referral code', value: code),
                  _ProfileLine(
                    label: 'Status',
                    value: promoter?.isActive == false
                        ? 'Inactive'
                        : 'Active Promoter',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: AuthService.instance.signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return initials.isEmpty ? '?' : initials;
}

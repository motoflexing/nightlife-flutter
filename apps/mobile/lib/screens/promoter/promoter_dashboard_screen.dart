import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../models/promoter.dart';
import '../../models/rsvp.dart';
import '../../services/firestore_service.dart';
import '../../widgets/event_poster.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_loader.dart';
import '../../widgets/state_views.dart';
import 'promoter_profile_screen.dart';

// --- Promoter dashboard visual language -------------------------------------
// Nocturne (DESIGN_TOKENS.md): obsidian canvas, champagne gold as the single
// accent, ivory text at opacity, Playfair figures, tracked uppercase labels,
// gold hairlines. No violet/pink neon, no glass glow. All colour comes from the
// shared AppColors tokens — no raw hex in this screen.

class PromoterDashboardScreen extends StatelessWidget {
  const PromoterDashboardScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      child: StreamBuilder<Promoter?>(
        stream: FirestoreService.instance.promoterForUserStream(
          currentUser.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorStateView(
              message: ErrorStateView.sanitizeError(snapshot.error),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PromoterDashboardSkeleton();
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

class _PromoterContent extends StatefulWidget {
  const _PromoterContent({required this.promoter, required this.currentUser});

  final Promoter promoter;
  final AppUser currentUser;

  @override
  State<_PromoterContent> createState() => _PromoterContentState();
}

class _PromoterContentState extends State<_PromoterContent> {
  final _scrollController = ScrollController();
  final _eventsKey = GlobalKey();
  final _activityKey = GlobalKey();

  /// Which bottom-nav tab is active: 0 = Home, 1 = Events, 2 = Activity.
  /// Profile (3) is not a tab — it pushes the profile screen — so it never
  /// becomes the selected index.
  int _tabIndex = 0;

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 650));
  }

  void _selectTab(int index) {
    if (_tabIndex == index) {
      // Re-tapping the active Home tab scrolls back to the top, matching the
      // previous behaviour.
      if (index == 0 && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _tabIndex = index);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Rsvp>>(
      stream: FirestoreService.instance.promoterRsvpsStream(
        widget.promoter.referralCode,
      ),
      builder: (context, rsvpSnapshot) {
        if (rsvpSnapshot.hasError) {
          return ErrorStateView(
            message: ErrorStateView.sanitizeError(rsvpSnapshot.error),
          );
        }

        return StreamBuilder<List<NightlifeEvent>>(
          stream: FirestoreService.instance.activeEventsStream(),
          builder: (context, eventSnapshot) {
            if (eventSnapshot.hasError) {
              return ErrorStateView(
                message: ErrorStateView.sanitizeError(eventSnapshot.error),
              );
            }

            final loading =
                rsvpSnapshot.connectionState == ConnectionState.waiting ||
                eventSnapshot.connectionState == ConnectionState.waiting;
            final rsvps = rsvpSnapshot.data ?? const <Rsvp>[];
            final events = eventSnapshot.data ?? const <NightlifeEvent>[];
            final stats = _PromoterStats.fromRsvps(rsvps);
            final snapshot = _DashboardSnapshot(
              promoter: widget.promoter,
              currentUser: widget.currentUser,
              stats: stats,
              events: events,
              rsvps: rsvps,
              referralLink: _generalReferralLink(
                widget.promoter.referralCode.trim(),
              ),
            );

            return Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _buildHomeTab(context, snapshot, stats, events, loading),
                      _PromoterEventsTab(
                        events: events,
                        loading: loading,
                        hasError: eventSnapshot.hasError,
                        referralCode: widget.promoter.referralCode.trim(),
                        onCopy: (link) => _copy(
                          context,
                          link,
                          message: 'Event link copied',
                        ),
                        onShare: (link, event) => _shareEvent(link, event),
                      ),
                      _PromoterActivityTab(
                        rsvps: rsvps,
                        loading: loading,
                        hasError: rsvpSnapshot.hasError,
                        referralLink: snapshot.referralLink,
                        onShareReferral: () =>
                            _shareReferral(snapshot.referralLink),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 18 + MediaQuery.paddingOf(context).bottom,
                  child: _FloatingBottomNav(
                    selectedIndex: _tabIndex,
                    onHome: () => _selectTab(0),
                    onEvents: () => _selectTab(1),
                    onAnalytics: () => _selectTab(2),
                    onProfile: () => _showPromoterProfile(
                      context,
                      widget.promoter,
                      widget.currentUser,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// The original single-scroll dashboard, now the Home tab. Unchanged in
  /// content — referral hero, share button, stat cards, impact chart, quick
  /// actions, today's performance, top events, and recent activity.
  Widget _buildHomeTab(
    BuildContext context,
    _DashboardSnapshot snapshot,
    _PromoterStats stats,
    List<NightlifeEvent> events,
    bool loading,
  ) {
    return RefreshIndicator(
      color: AppColors.champagne,
      backgroundColor: AppColors.espresso,
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 112),
            sliver: SliverList.list(
              children: [
                _MobileHeader(
                  name: snapshot.promoterName,
                  onMenu: () => _showPromoterProfile(
                    context,
                    widget.promoter,
                    widget.currentUser,
                  ),
                  onProfile: () => _showPromoterProfile(
                    context,
                    widget.promoter,
                    widget.currentUser,
                  ),
                ),
                const SizedBox(height: 16),
                // Focal point: real referral code + share.
                if (loading)
                  const _HeroSkeleton()
                else
                  _ReferralHeroCard(
                    referralCode: widget.promoter.referralCode.trim(),
                    referralLink: snapshot.referralLink,
                    isActive: widget.promoter.isActive,
                    onCopy: () => _copy(
                      context,
                      widget.promoter.referralCode.trim(),
                      message: 'Referral code copied',
                    ),
                    onShare: () => _shareReferral(snapshot.referralLink),
                  ),
                const SizedBox(height: 14),
                // Real RSVP-derived counts only — no earnings.
                _StatCardRow(stats: stats),
                const SizedBox(height: 18),
                if (loading)
                  const _HeroSkeleton()
                else
                  _ImpactHeroCard(snapshot: snapshot),
                const SizedBox(height: 18),
                _QuickActionGrid(
                  onReferralLinks: () => _copy(
                    context,
                    snapshot.referralLink,
                    message: 'Referral link copied',
                  ),
                  onEvents: () => _selectTab(1),
                  onRsvps: () => _selectTab(2),
                ),
                const SizedBox(height: 22),
                _SectionTitle(
                  title: "Today's Performance",
                  trailing: 'Swipe',
                ),
                const SizedBox(height: 10),
                _TodayPerformanceStrip(snapshot: snapshot),
                const SizedBox(height: 22),
                KeyedSubtree(
                  key: _eventsKey,
                  child: const _SectionTitle(
                    title: 'Top Performing Events',
                  ),
                ),
                const SizedBox(height: 10),
                if (loading)
                  const _EventSkeletonList()
                else if (events.isEmpty)
                  _MobileEmptyState(
                    icon: Icons.local_activity_outlined,
                    title: 'No events to promote yet',
                    message:
                        'When venues publish active events, your share cards will appear here.',
                    actionLabel: 'Copy general link',
                    onAction: () => _copy(
                      context,
                      snapshot.referralLink,
                      message: 'Referral link copied',
                    ),
                  )
                else
                  ...snapshot.topEvents.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _TopEventCard(
                        item: item,
                        onCopy: () => _copy(
                          context,
                          _eventReferralLink(
                            item.event,
                            widget.promoter.referralCode.trim(),
                          ),
                          message: 'Event link copied',
                        ),
                        onShare: () => _shareEvent(
                          _eventReferralLink(
                            item.event,
                            widget.promoter.referralCode.trim(),
                          ),
                          item.event,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                KeyedSubtree(
                  key: _activityKey,
                  child: const _SectionTitle(
                    title: 'Recent Activity',
                  ),
                ),
                const SizedBox(height: 10),
                if (loading)
                  const _ActivitySkeletonList()
                else if (snapshot.activities.isEmpty)
                  _MobileEmptyState(
                    icon: Icons.bolt_outlined,
                    title: 'No activity yet',
                    message:
                        'Share a link and fresh RSVP activity will start showing up here.',
                    actionLabel: 'Copy referral link',
                    onAction: () => _copy(
                      context,
                      snapshot.referralLink,
                      message: 'Referral link copied',
                    ),
                  )
                else
                  ...snapshot.activities.map(
                    (activity) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActivityCard(activity: activity),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareEvent(String link, NightlifeEvent event) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: link,
          subject: event.title.trim().isEmpty
              ? 'Check out this event'
              : event.title.trim(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _copy(context, link, message: 'Event link copied');
    }
  }

  Future<void> _shareReferral(String link) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: link,
          subject: 'My Nightlife referral link',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _copy(context, link, message: 'Referral link copied');
    }
  }

  void _copy(BuildContext context, String value, {required String message}) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    required this.today,
    required this.thisWeekRsvps,
    required this.conversionRate,
    required this.eventTotals,
    required this.eventApprovedTotals,
    required this.eventConversionRates,
    required this.growthSeries,
  });

  final int total;
  final int pending;
  final int approved;
  final int today;
  final int thisWeekRsvps;
  final int conversionRate;
  final Map<String, int> eventTotals;
  final Map<String, int> eventApprovedTotals;
  final Map<String, int> eventConversionRates;

  /// Real RSVP counts for each of the last 7 days (oldest → today). Genuinely
  /// all-zero when there is no recent activity; never backfilled with fake data.
  final List<int> growthSeries;

  factory _PromoterStats.fromRsvps(List<Rsvp> rsvps) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    var pending = 0;
    var approved = 0;
    var today = 0;
    var thisWeek = 0;
    final eventTotals = <String, int>{};
    final eventApprovedTotals = <String, int>{};
    final series = List<int>.filled(7, 0);

    for (final rsvp in rsvps) {
      final status = rsvp.status.toLowerCase();
      final created = rsvp.createdAt;
      if (status == 'pending') pending++;
      if (status == 'approved' || status == 'confirmed') {
        approved++;
        eventApprovedTotals[rsvp.eventId] =
            (eventApprovedTotals[rsvp.eventId] ?? 0) + 1;
      }
      if (!created.isBefore(startOfToday)) today++;
      final daysAgo = now.difference(created).inDays;
      if (daysAgo <= 7) thisWeek++;
      if (daysAgo >= 0 && daysAgo < 7) {
        series[6 - daysAgo] = series[6 - daysAgo] + 1;
      }
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
      today: today,
      thisWeekRsvps: thisWeek,
      conversionRate: conversion,
      eventTotals: eventTotals,
      eventApprovedTotals: eventApprovedTotals,
      eventConversionRates: eventConversionRates,
      growthSeries: series,
    );
  }
}

class _DashboardSnapshot {
  const _DashboardSnapshot({
    required this.promoter,
    required this.currentUser,
    required this.stats,
    required this.events,
    required this.rsvps,
    required this.referralLink,
  });

  final Promoter promoter;
  final AppUser currentUser;
  final _PromoterStats stats;
  final List<NightlifeEvent> events;
  final List<Rsvp> rsvps;
  final String referralLink;

  String get promoterName {
    if (promoter.name.trim().isNotEmpty) return promoter.name.trim();
    if (currentUser.name.trim().isNotEmpty) return currentUser.name.trim();
    return 'Promoter';
  }

  String get bestEvent {
    if (topEvents.isEmpty) return 'No winner yet';
    return topEvents.first.title;
  }

  List<_EventPerformance> get topEvents {
    final items = events.map((event) {
      final total = stats.eventTotals[event.id] ?? 0;
      final approved = stats.eventApprovedTotals[event.id] ?? 0;
      final conversion = stats.eventConversionRates[event.id] ?? 0;
      return _EventPerformance(
        event: event,
        rsvps: total,
        approved: approved,
        conversion: conversion,
      );
    }).toList();
    items.sort((a, b) {
      final byRsvp = b.rsvps.compareTo(a.rsvps);
      if (byRsvp != 0) return byRsvp;
      return a.event.dateTime.compareTo(b.event.dateTime);
    });
    return items;
  }

  List<_ActivityItem> get activities {
    final recent = rsvps.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recent
        .take(7)
        .map((rsvp) {
          final name = rsvp.userName.trim().isEmpty ? 'A guest' : rsvp.userName;
          final eventTitle = rsvp.eventTitle.trim().isEmpty
              ? 'an event'
              : rsvp.eventTitle;
          final approved =
              rsvp.status.toLowerCase() == 'approved' ||
              rsvp.status.toLowerCase() == 'confirmed';
          return _ActivityItem(
            icon: approved
                ? Icons.verified_outlined
                : Icons.check_circle_outline,
            title: '$name RSVP\'d',
            subtitle: 'For $eventTitle',
            value: Formatters.titleCase(rsvp.status),
            time: _relativeTime(rsvp.createdAt),
            approved: approved,
          );
        })
        .toList(growable: false);
  }
}

class _EventPerformance {
  const _EventPerformance({
    required this.event,
    required this.rsvps,
    required this.approved,
    required this.conversion,
  });

  final NightlifeEvent event;
  final int rsvps;
  final int approved;
  final int conversion;

  String get title =>
      event.title.trim().isEmpty ? 'Untitled Event' : event.title;
}

class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.time,
    required this.approved,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String time;

  /// Approved/confirmed RSVPs read at full champagne emphasis; still-pending
  /// ones use the low-emphasis ivory tone. Single-accent Nocturne palette.
  final bool approved;
}

/// EVENTS TAB — the promoter's core tool. Lists ALL active events (from the
/// same activeEventsStream the dashboard already streams), with search by
/// title/venue and a city filter (reusing AppConstants.cities). Each card has a
/// Share button that shares a per-event deep link with the promoter's referral
/// code attached: /event/{id}?ref=CODE — the exact format the app's deep-link
/// router and ReferralService already understand. No new backend query, no fake
/// data.
class _PromoterEventsTab extends StatefulWidget {
  const _PromoterEventsTab({
    required this.events,
    required this.loading,
    required this.hasError,
    required this.referralCode,
    required this.onCopy,
    required this.onShare,
  });

  final List<NightlifeEvent> events;
  final bool loading;
  final bool hasError;
  final String referralCode;
  final ValueChanged<String> onCopy;
  final void Function(String link, NightlifeEvent event) onShare;

  @override
  State<_PromoterEventsTab> createState() => _PromoterEventsTabState();
}

class _PromoterEventsTabState extends State<_PromoterEventsTab> {
  final _searchController = TextEditingController();
  String _query = '';
  String _city = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _eventLink(NightlifeEvent event) {
    return '/event/${Uri.encodeComponent(event.id)}?ref=${widget.referralCode}';
  }

  List<NightlifeEvent> get _filtered {
    final query = _query.trim().toLowerCase();
    return widget.events.where((event) {
      final matchesCity = _city == 'All' || event.city == _city;
      if (!matchesCity) return false;
      if (query.isEmpty) return true;
      return event.title.toLowerCase().contains(query) ||
          event.venueName.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasError) {
      return const ErrorStateView(
        message: 'Something went wrong loading events. Please try again.',
      );
    }

    final filtered = _filtered;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        112 + MediaQuery.paddingOf(context).bottom,
      ),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        const _TabTitle(
          title: 'Active Nights',
          subtitle: 'Share any night with your code attached.',
        ),
        const SizedBox(height: 14),
        _SearchField(
          controller: _searchController,
          hint: 'Search title or venue',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        _CityFilterChips(
          selected: _city,
          onSelected: (city) => setState(() => _city = city),
        ),
        const SizedBox(height: 16),
        if (widget.loading)
          const _EventSkeletonList()
        else if (widget.events.isEmpty)
          const EmptyView(
            title: 'No active events yet',
            message:
                'When venues publish active events, they will appear here ready '
                'to share with your referral code.',
            icon: Icons.local_activity_outlined,
          )
        else if (filtered.isEmpty)
          const EmptyView(
            title: 'No matching events',
            message: 'Try a different search term or city filter.',
            icon: Icons.search_off_rounded,
          )
        else
          ...filtered.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _PromoterEventCard(
                event: event,
                onCopy: () => widget.onCopy(_eventLink(event)),
                onShare: () => widget.onShare(_eventLink(event), event),
              ),
            ),
          ),
      ],
    );
  }
}

/// A single shareable event card for the Events tab: real poster, tracked
/// eyebrow, Playfair title, venue, date, plus Copy + Share (per-event referral
/// link) actions.
class _PromoterEventCard extends StatelessWidget {
  const _PromoterEventCard({
    required this.event,
    required this.onCopy,
    required this.onShare,
  });

  final NightlifeEvent event;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final title = event.title.trim().isEmpty ? 'Untitled Event' : event.title;
    final venue = event.venueName.trim();
    final city = event.city.trim();
    final venueLine = [
      if (venue.isNotEmpty) venue,
      if (city.isNotEmpty) city,
    ].join(' · ');

    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.72,
            child: EventPoster(event: event, borderRadius: 4),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineMedium.copyWith(fontSize: 18),
                ),
                if (venueLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    venueLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textCaption,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        Formatters.eventDate(event.dateTime),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textCaption,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _GhostButton(
                        icon: Icons.link_rounded,
                        label: 'Copy link',
                        onPressed: onCopy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PrimaryButton(
                        icon: Icons.ios_share_rounded,
                        label: 'Share',
                        onPressed: onShare,
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

/// ACTIVITY TAB — the promoter's real RSVP feed from promoterRsvpsStream:
/// who RSVP'd, which event, status, and when. Most recent first (the stream is
/// already sorted). Real data only — clean empty state when there are none.
class _PromoterActivityTab extends StatelessWidget {
  const _PromoterActivityTab({
    required this.rsvps,
    required this.loading,
    required this.hasError,
    required this.referralLink,
    required this.onShareReferral,
  });

  final List<Rsvp> rsvps;
  final bool loading;
  final bool hasError;
  final String referralLink;
  final VoidCallback onShareReferral;

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return const ErrorStateView(
        message: 'Something went wrong loading your RSVPs. Please try again.',
      );
    }

    final padding = EdgeInsets.fromLTRB(
      16,
      14,
      16,
      112 + MediaQuery.paddingOf(context).bottom,
    );

    if (loading) {
      return ListView(
        padding: padding,
        children: const [
          _TabTitle(
            title: 'Activity',
            subtitle: 'Every RSVP driven by your referral code.',
          ),
          SizedBox(height: 14),
          _ActivitySkeletonList(),
        ],
      );
    }

    if (rsvps.isEmpty) {
      return ListView(
        padding: padding,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          const _TabTitle(
            title: 'Activity',
            subtitle: 'Every RSVP driven by your referral code.',
          ),
          const SizedBox(height: 24),
          const EmptyView(
            title: 'Your code is ready to work',
            message: 'The moment someone RSVPs with your code, it lands here. '
                'Share it and watch the room fill.',
            icon: Icons.bolt_outlined,
          ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 240,
              child: _PrimaryButton(
                icon: Icons.ios_share_rounded,
                label: 'Share your code',
                onPressed: onShareReferral,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: padding,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: rsvps.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _TabTitle(
              title: 'Activity',
              subtitle: '${rsvps.length} total from your referral code.',
            ),
          );
        }
        final rsvp = rsvps[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RsvpActivityRow(rsvp: rsvp),
        );
      },
    );
  }
}

/// One real RSVP row: guest name, event title, status badge, relative time.
class _RsvpActivityRow extends StatelessWidget {
  const _RsvpActivityRow({required this.rsvp});

  final Rsvp rsvp;

  @override
  Widget build(BuildContext context) {
    final name = rsvp.userName.trim().isEmpty ? 'A guest' : rsvp.userName.trim();
    final eventTitle = rsvp.eventTitle.trim().isEmpty
        ? 'an event'
        : rsvp.eventTitle.trim();
    final status = rsvp.status.toLowerCase();
    final approved = status == 'approved' || status == 'confirmed';

    return _Panel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _RoundIcon(
            icon: approved
                ? Icons.verified_outlined
                : Icons.check_circle_outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name RSVP\'d',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  'For $eventTitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textCaption,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.titleCase(rsvp.status).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  color: approved
                      ? AppColors.champagne
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _relativeTime(rsvp.createdAt),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textCaption,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared tab heading — Playfair display title + low-emphasis subtitle.
class _TabTitle extends StatelessWidget {
  const _TabTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.displayMedium.copyWith(fontSize: 30),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textCaption,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.textHigh),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textCaption,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.surfaceEspresso,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: AppColors.goldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: AppColors.champagne),
        ),
      ),
    );
  }
}

class _CityFilterChips extends StatelessWidget {
  const _CityFilterChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: AppConstants.cities.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final city = AppConstants.cities[index];
          final isSelected = city == selected;
          // Selected pill = solid gold with obsidian text; others = ghost gold.
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(city);
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.champagne : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isSelected
                      ? AppColors.champagne
                      : AppColors.goldBorder,
                ),
              ),
              child: Text(
                city.toUpperCase(),
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  color: isSelected
                      ? AppColors.obsidian
                      : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.name,
    required this.onMenu,
    required this.onProfile,
  });

  final String name;
  final VoidCallback onMenu;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting().toUpperCase(),
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.28 * 10,
                  color: AppColors.textCaption,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.displayMedium.copyWith(fontSize: 26),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onProfile,
          child: _PromoterAvatar(name: name, size: 44),
        ),
      ],
    );
  }
}

/// Focal hero: the promoter's real referral code, ACTIVE badge, copy button,
/// short link, and the ivory "Share your code" button — over the Nocturne gold
/// gradient-tint card.
class _ReferralHeroCard extends StatelessWidget {
  const _ReferralHeroCard({
    required this.referralCode,
    required this.referralLink,
    required this.isActive,
    required this.onCopy,
    required this.onShare,
  });

  /// The promoter's REAL referral code (e.g. PROMWCRK) — never hardcoded.
  final String referralCode;
  final String referralLink;
  final bool isActive;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final code = referralCode.trim().isEmpty ? '—' : referralCode.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        // Gold-tint → oxblood gradient (design promoter referral hero).
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.champagne.withValues(alpha: 0.16),
            AppColors.oxblood.withValues(alpha: 0.4),
          ],
        ),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'YOUR REFERRAL CODE',
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.28 * 10,
                    color: AppColors.textBodyDim,
                  ),
                ),
              ),
              _StatusPill(isActive: isActive),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Playfair-gold code, the design's signature figure.
                  style: AppTypography.displayMedium.copyWith(
                    fontSize: 34,
                    color: AppColors.champagne,
                    letterSpacing: 2,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Copy code',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onCopy();
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.goldWash,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.goldBorder),
                    ),
                    child: const Icon(
                      Icons.copy_rounded,
                      color: AppColors.champagne,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            referralLink,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textBodyDim,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            icon: Icons.ios_share_rounded,
            label: 'Share your code',
            onPressed: onShare,
            height: 50,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.champagne : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? AppColors.goldWash : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'ACTIVE' : 'INACTIVE',
            style: AppTypography.labelSmall.copyWith(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of stat cards, all derived from real RSVP data via
/// promoterRsvpsStream(referralCode): Total RSVPs, Approved, and This week.
class _StatCardRow extends StatelessWidget {
  const _StatCardRow({required this.stats});

  final _PromoterStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: stats.total.toString(),
            label: 'Total RSVPs',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: stats.approved.toString(),
            label: 'Approved',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: stats.thisWeekRsvps.toString(),
            label: 'This week',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Playfair-gold figure.
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.displayMedium.copyWith(
              fontSize: 30,
              color: AppColors.champagne,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 9,
              letterSpacing: 0.16 * 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactHeroCard extends StatefulWidget {
  const _ImpactHeroCard({required this.snapshot});

  final _DashboardSnapshot snapshot;

  @override
  State<_ImpactHeroCard> createState() => _ImpactHeroCardState();
}

class _ImpactHeroCardState extends State<_ImpactHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.snapshot.stats;
    return _Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR IMPACT',
            style: AppTypography.labelSmall.copyWith(
              fontSize: 10,
              letterSpacing: 0.26 * 10,
              color: AppColors.textCaption,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stats.total.toString(),
            style: AppTypography.displayLarge.copyWith(
              fontSize: 48,
              color: AppColors.champagne,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total RSVPs generated',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ImpactChip(
                label: 'Confirmed',
                value: stats.approved.toString(),
              ),
              _ImpactChip(
                label: 'Pending',
                value: stats.pending.toString(),
              ),
              _ImpactChip(
                label: 'This week',
                value: stats.thisWeekRsvps.toString(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 86,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _RsvpLineChartPainter(
                    values: stats.growthSeries,
                    pulse: _controller.value,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.onReferralLinks,
    required this.onEvents,
    required this.onRsvps,
  });

  final VoidCallback onReferralLinks;
  final VoidCallback onEvents;
  final VoidCallback onRsvps;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.62,
      children: [
        _QuickActionTile(
          icon: Icons.link_rounded,
          label: 'My Referral Links',
          onPressed: onReferralLinks,
        ),
        _QuickActionTile(
          icon: Icons.local_activity_outlined,
          label: 'My Events',
          onPressed: onEvents,
        ),
        _QuickActionTile(
          icon: Icons.fact_check_outlined,
          label: 'My RSVPs',
          onPressed: onRsvps,
        ),
      ],
    );
  }
}

class _TodayPerformanceStrip extends StatelessWidget {
  const _TodayPerformanceStrip({required this.snapshot});

  final _DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final stats = snapshot.stats;
    final cards = [
      _MetricCardData(
        label: "Today's RSVPs",
        value: stats.today.toString(),
        icon: Icons.today_outlined,
      ),
      _MetricCardData(
        label: 'This Week RSVPs',
        value: stats.thisWeekRsvps.toString(),
        icon: Icons.calendar_view_week_outlined,
      ),
      _MetricCardData(
        label: 'Top Event',
        value: snapshot.bestEvent,
        icon: Icons.local_fire_department_outlined,
      ),
      _MetricCardData(
        label: 'Conversion Rate',
        value: '${stats.conversionRate}%',
        icon: Icons.insights_outlined,
      ),
    ];

    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) => _MetricCard(data: cards[index]),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: cards.length,
      ),
    );
  }
}

class _TopEventCard extends StatelessWidget {
  const _TopEventCard({
    required this.item,
    required this.onCopy,
    required this.onShare,
  });

  final _EventPerformance item;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final progress = (item.conversion / 100).clamp(0.0, 1.0);
    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                EventPoster(event: item.event, borderRadius: 4),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Pill(
                        text: item.rsvps >= 5 ? 'Hot event' : 'Ready to push',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineMedium.copyWith(
                          fontSize: 20,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _EventStat(
                        value: item.rsvps.toString(),
                        label: 'RSVPs',
                      ),
                    ),
                    Expanded(
                      child: _EventStat(
                        value: item.approved.toString(),
                        label: 'Approved',
                      ),
                    ),
                    Expanded(
                      child: _EventStat(
                        value: '${item.conversion}%',
                        label: 'Conversion',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: AppColors.goldWash,
                    color: AppColors.champagne,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _GhostButton(
                        icon: Icons.link_rounded,
                        label: 'Copy',
                        onPressed: onCopy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PrimaryButton(
                        icon: Icons.ios_share_rounded,
                        label: 'Share',
                        onPressed: onShare,
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final _ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _RoundIcon(icon: activity.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textCaption,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                activity.value.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  color: activity.approved
                      ? AppColors.champagne
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                activity.time,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textCaption,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({
    required this.selectedIndex,
    required this.onHome,
    required this.onEvents,
    required this.onAnalytics,
    required this.onProfile,
  });

  /// Active tab index (0 Home, 1 Events, 2 Activity). Profile is not a tab so
  /// it is never highlighted.
  final int selectedIndex;
  final VoidCallback onHome;
  final VoidCallback onEvents;
  final VoidCallback onAnalytics;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.obsidianDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(
            icon: Icons.home_rounded,
            tooltip: 'Home',
            selected: selectedIndex == 0,
            onTap: onHome,
          ),
          _NavIcon(
            icon: Icons.local_activity_outlined,
            tooltip: 'Events',
            selected: selectedIndex == 1,
            onTap: onEvents,
          ),
          _NavIcon(
            icon: Icons.bolt_outlined,
            tooltip: 'Activity',
            selected: selectedIndex == 2,
            onTap: onAnalytics,
          ),
          _NavIcon(
            icon: Icons.person_outline_rounded,
            tooltip: 'Profile',
            selected: false,
            onTap: onProfile,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surfaceEspresso,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.goldWash,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Icon(widget.icon, color: AppColors.champagne, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: _Panel(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.goldWash,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Icon(data.icon, color: AppColors.champagne, size: 21),
            ),
            const Spacer(),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headlineMedium.copyWith(
                fontSize: 22,
                color: AppColors.champagne,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

/// Section eyebrow — tracked uppercase gold label + fading gold hairline
/// (design §11). [trailing] renders a small low-emphasis hint on the right.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.labelLarge.copyWith(color: AppColors.champagne),
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
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Text(
            trailing!.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(fontSize: 9),
          ),
        ],
      ],
    );
  }
}

class _ImpactChip extends StatelessWidget {
  const _ImpactChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.goldWash,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 13,
              color: AppColors.champagne,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              fontSize: 9,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventStat extends StatelessWidget {
  const _EventStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headlineMedium.copyWith(
            fontSize: 16,
            color: AppColors.champagne,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(fontSize: 9),
        ),
      ],
    );
  }
}

class _MobileEmptyState extends StatelessWidget {
  const _MobileEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.goldWash,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Icon(icon, color: AppColors.champagne),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTypography.headlineMedium.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textCaption,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _PrimaryButton(
            icon: Icons.link_rounded,
            label: actionLabel,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

class _PromoterDashboardSkeleton extends StatelessWidget {
  const _PromoterDashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(
          children: [
            _SkeletonLine(width: double.infinity, height: 54),
            SizedBox(height: 18),
            _HeroSkeleton(),
            SizedBox(height: 18),
            _SkeletonLine(width: double.infinity, height: 88),
            SizedBox(height: 12),
            PremiumLoader(message: 'Loading promoter dashboard...'),
          ],
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonLine(width: 110, height: 13),
          SizedBox(height: 14),
          _SkeletonLine(width: 132, height: 46),
          SizedBox(height: 12),
          Row(
            children: [
              _SkeletonLine(width: 86, height: 32),
              SizedBox(width: 8),
              _SkeletonLine(width: 76, height: 32),
              SizedBox(width: 8),
              _SkeletonLine(width: 98, height: 32),
            ],
          ),
          SizedBox(height: 18),
          _SkeletonLine(width: double.infinity, height: 82),
        ],
      ),
    );
  }
}

class _EventSkeletonList extends StatelessWidget {
  const _EventSkeletonList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Panel(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              _SkeletonLine(width: double.infinity, height: 176),
              SizedBox(height: 12),
              _SkeletonLine(width: double.infinity, height: 52),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivitySkeletonList extends StatelessWidget {
  const _ActivitySkeletonList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SkeletonLine(width: double.infinity, height: 68),
        SizedBox(height: 10),
        _SkeletonLine(width: double.infinity, height: 68),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder),
      ),
    );
  }
}

/// Flat espresso panel with a gold hairline — the Nocturne card surface used
/// throughout this screen (design §9). Replaces the old glass/blur panel.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: child,
    );
  }
}

class _RsvpLineChartPainter extends CustomPainter {
  _RsvpLineChartPainter({required this.values, required this.pulse});

  final List<int> values;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = math.max(1, values.reduce(math.max));
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final normalized = values[i] / maxValue;
      final y = size.height - (normalized * size.height * 0.78) - 8;
      points.add(Offset(x, y.clamp(6.0, size.height - 6)));
    }

    final areaPath = Path()..moveTo(points.first.dx, size.height);
    for (final point in points) {
      areaPath.lineTo(point.dx, point.dy);
    }
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.champagne.withValues(alpha: 0.22),
          AppColors.champagne.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(areaPath, fillPaint);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final linePaint = Paint()
      ..color = AppColors.champagne
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final point = points.last;
    final dotPaint = Paint()..color = AppColors.champagne;
    canvas.drawCircle(point, 3.5 + pulse * 1.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RsvpLineChartPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.values != values;
  }
}

/// Gold-ring circle icon tile used on activity rows (design activity feed).
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.goldWash,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Icon(icon, color: AppColors.champagne, size: 20),
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
        color: AppColors.surfaceEspresso,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.champagne, width: 1),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: AppTypography.headlineMedium.copyWith(
            fontSize: size * 0.38,
            color: AppColors.champagne,
          ),
        ),
      ),
    );
  }
}

/// Ivory primary button (design §7): warm-white fill, obsidian label, crisp
/// corners, tracked uppercase.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.height = 46,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            splashColor: Colors.transparent,
            highlightColor: AppColors.obsidian.withValues(alpha: 0.08),
            onTap: () {
              HapticFeedback.mediumImpact();
              onPressed();
            },
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: AppColors.obsidian),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.obsidian,
                        letterSpacing: 0.16 * 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghost / secondary button (design §7): transparent fill, champagne outline
/// and label.
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.champagne,
          side: const BorderSide(color: AppColors.champagne, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: AppTypography.labelMedium,
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        icon: Icon(icon),
        color: selected ? AppColors.champagne : AppColors.textSecondary,
        iconSize: 24,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.goldWash,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.champagne.withValues(alpha: 0.4)),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          fontSize: 9,
          color: AppColors.champagne,
        ),
      ),
    );
  }
}

void _showPromoterProfile(
  BuildContext context,
  Promoter? promoter,
  AppUser currentUser,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PromoterProfileScreen(currentUser: currentUser),
    ),
  );
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

String _relativeTime(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return '${diff.inHours} hrs ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays} days ago';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'P' : initials;
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
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

// --- Promoter dashboard design tokens ---------------------------------------
// The shared AppTheme currently maps neonViolet/accentPink to gold. The new
// promoter visual spec calls for a deep-violet primary with a restrained pink
// accent, so these tokens are scoped locally to this screen to avoid changing
// the global theme (which other screens depend on).
const Color _kViolet = Color(0xFF6321D6); // primary deep violet
const Color _kVioletBright = Color(0xFF7C3AED); // gradient highlight
const Color _kPink = Color(0xFFF2479A); // restrained pink accent
const Color _kActiveGreen = Color(0xFF38E1A0); // ACTIVE badge / live dot
const Color _kBackdropTop = Color(0xFF0A0712); // dark nightlife base
const Color _kBackdropMid = Color(0xFF120A1F);
const Color _kPanel = Color(0xFF14101F); // glass panel fill

const LinearGradient _kShareGradient = LinearGradient(
  colors: [_kViolet, _kVioletBright, _kPink],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

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

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 650));
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
                const Positioned.fill(child: _PremiumMobileBackdrop()),
                SafeArea(
                  bottom: false,
                  child: RefreshIndicator(
                    color: AppTheme.neonViolet,
                    backgroundColor: AppTheme.surface,
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
                                onNotifications: _showComingSoon,
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
                                  referralCode: widget.promoter.referralCode
                                      .trim(),
                                  referralLink: snapshot.referralLink,
                                  isActive: widget.promoter.isActive,
                                  onCopy: () => _copy(
                                    context,
                                    widget.promoter.referralCode.trim(),
                                    message: 'Referral code copied',
                                  ),
                                  onShare: () =>
                                      _share(context, snapshot.referralLink),
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
                                onEvents: () => _scrollTo(_eventsKey),
                                onRsvps: () => _scrollTo(_activityKey),
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
                                      onShare: () => _share(
                                        context,
                                        _eventReferralLink(
                                          item.event,
                                          widget.promoter.referralCode.trim(),
                                        ),
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
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 18 + MediaQuery.paddingOf(context).bottom,
                  child: _FloatingBottomNav(
                    onHome: () => _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                    ),
                    onEvents: () => _scrollTo(_eventsKey),
                    onCreateLink: () => _copy(
                      context,
                      snapshot.bestEventLink(
                        widget.promoter.referralCode.trim(),
                      ),
                      message: 'Best event link copied',
                    ),
                    onAnalytics: () => _scrollTo(_activityKey),
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

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    HapticFeedback.selectionClick();
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _showComingSoon() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications are ready for your next push'),
      ),
    );
  }

  void _copy(BuildContext context, String value, {required String message}) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _share(BuildContext context, String value) {
    _copy(context, value, message: 'Event link copied and ready to share');
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
            accent: approved ? AppTheme.neonLime : AppTheme.neonViolet,
          );
        })
        .toList(growable: false);
  }

  String bestEventLink(String referralCode) {
    if (topEvents.isEmpty) return referralLink;
    return '/event/${Uri.encodeComponent(topEvents.first.event.id)}?ref=$referralCode';
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
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String time;
  final Color accent;
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.name,
    required this.onMenu,
    required this.onNotifications,
    required this.onProfile,
  });

  final String name;
  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleIconButton(
          tooltip: 'Menu',
          icon: Icons.menu_rounded,
          onPressed: onMenu,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        _CircleIconButton(
          tooltip: 'Notifications',
          icon: Icons.notifications_none_rounded,
          onPressed: onNotifications,
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onProfile,
          child: _PromoterAvatar(name: name, size: 42),
        ),
      ],
    );
  }
}

/// Focal hero: the promoter's real referral code, ACTIVE badge, copy button,
/// short link, and the violet→pink "Share your code" gradient button.
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
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1230), Color(0xFF221141)],
        ),
        border: Border.all(color: _kViolet.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: _kViolet.withValues(alpha: 0.34),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'YOUR REFERRAL CODE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _kActiveGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _kActiveGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isActive ? _kActiveGreen : AppTheme.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        color: isActive ? _kActiveGreen : AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Copy code',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onCopy();
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Icon(
                      Icons.copy_rounded,
                      color: Colors.white,
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
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _kShareGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _kPink.withValues(alpha: 0.4),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onShare();
                  },
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Share your code',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
            accent: _kViolet,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: stats.approved.toString(),
            label: 'Approved',
            accent: _kPink,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: stats.thisWeekRsvps.toString(),
            label: 'This week',
            accent: _kActiveGreen,
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
    required this.accent,
  });

  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _kPanel.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      glow: AppTheme.neonViolet.withValues(alpha: 0.36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Impact',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.neonLime.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.neonLime.withValues(alpha: 0.28),
                  ),
                ),
                child: const Text(
                  '+23% This Month',
                  style: TextStyle(
                    color: AppTheme.neonLime,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stats.total.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              height: 0.95,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Total RSVPs Generated',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
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
                color: AppTheme.neonLime,
              ),
              _ImpactChip(
                label: 'Pending',
                value: stats.pending.toString(),
                color: AppTheme.neonViolet,
              ),
              _ImpactChip(
                label: 'This week',
                value: stats.thisWeekRsvps.toString(),
                color: AppTheme.accentPink,
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
          gradient: const [Color(0xFF7C3AED), Color(0xFFFF3D8B)],
          onPressed: onReferralLinks,
        ),
        _QuickActionTile(
          icon: Icons.local_activity_outlined,
          label: 'My Events',
          gradient: const [Color(0xFF2563EB), Color(0xFFA855F7)],
          onPressed: onEvents,
        ),
        _QuickActionTile(
          icon: Icons.fact_check_outlined,
          label: 'My RSVPs',
          gradient: const [Color(0xFF10B981), Color(0xFF7C3AED)],
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
        color: AppTheme.neonViolet,
      ),
      _MetricCardData(
        label: 'This Week RSVPs',
        value: stats.thisWeekRsvps.toString(),
        icon: Icons.calendar_view_week_outlined,
        color: AppTheme.accentPink,
      ),
      _MetricCardData(
        label: 'Top Event',
        value: snapshot.bestEvent,
        icon: Icons.local_fire_department_outlined,
        color: AppTheme.neonLime,
      ),
      _MetricCardData(
        label: 'Conversion Rate',
        value: '${stats.conversionRate}%',
        icon: Icons.insights_outlined,
        color: const Color(0xFF38BDF8),
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
    return _GlassPanel(
      padding: EdgeInsets.zero,
      glow: item.rsvps > 0
          ? AppTheme.accentPink.withValues(alpha: 0.22)
          : AppTheme.neonViolet.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                EventPoster(event: item.event, borderRadius: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.76),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Pill(
                        text: item.rsvps >= 5 ? 'Hot event' : 'Ready to push',
                        color: item.rsvps >= 5
                            ? AppTheme.neonLime
                            : AppTheme.neonViolet,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          shadows: [
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
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: AppTheme.neonViolet,
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
                      child: _GlowButton(
                        icon: Icons.send_rounded,
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
    return _GlassPanel(
      padding: const EdgeInsets.all(12),
      glow: activity.accent.withValues(alpha: 0.12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: activity.accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: activity.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(activity.icon, color: activity.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
                activity.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                activity.time,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
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
    required this.onHome,
    required this.onEvents,
    required this.onCreateLink,
    required this.onAnalytics,
    required this.onProfile,
  });

  final VoidCallback onHome;
  final VoidCallback onEvents;
  final VoidCallback onCreateLink;
  final VoidCallback onAnalytics;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonViolet.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavIcon(
                icon: Icons.home_rounded,
                tooltip: 'Home',
                onTap: onHome,
              ),
              _NavIcon(
                icon: Icons.local_activity_outlined,
                tooltip: 'Events',
                onTap: onEvents,
              ),
              _CenterNavButton(onTap: onCreateLink),
              _NavIcon(
                icon: Icons.bar_chart_rounded,
                tooltip: 'Activity',
                onTap: onAnalytics,
              ),
              _NavIcon(
                icon: Icons.person_outline_rounded,
                tooltip: 'Profile',
                onTap: onProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final List<Color> gradient;
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.gradient.first.withValues(alpha: 0.94),
                widget.gradient.last.withValues(alpha: 0.74),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.last.withValues(alpha: 0.26),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
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
      child: _GlassPanel(
        padding: const EdgeInsets.all(13),
        glow: data.color.withValues(alpha: 0.12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: data.color.withValues(alpha: 0.34)),
              ),
              child: Icon(data.icon, color: data.color, size: 21),
            ),
            const Spacer(),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
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
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _ImpactChip extends StatelessWidget {
  const _ImpactChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
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
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppTheme.premiumGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: AppTheme.textMuted, height: 1.35),
          ),
          const SizedBox(height: 14),
          _GlowButton(
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
    return const Stack(
      children: [
        Positioned.fill(child: _PremiumMobileBackdrop()),
        SafeArea(
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
        ),
      ],
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _GlassPanel(
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
        _GlassPanel(
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
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.glow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF14121F).withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            boxShadow: [
              BoxShadow(
                color: glow ?? AppTheme.neonViolet.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PremiumMobileBackdrop extends StatelessWidget {
  const _PremiumMobileBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBackdropTop, _kBackdropMid, _kBackdropTop],
        ),
      ),
      child: CustomPaint(painter: _BackdropPainter()),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final violet = Paint()
      ..color = _kViolet.withValues(alpha: 0.26)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
    canvas.drawCircle(
      Offset(size.width * 0.80, size.height * 0.12),
      112,
      violet,
    );

    final pink = Paint()
      ..color = _kPink.withValues(alpha: 0.13)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 86);
    canvas.drawCircle(Offset(size.width * 0.10, size.height * 0.38), 140, pink);

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 28), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          AppTheme.neonViolet.withValues(alpha: 0.25),
          AppTheme.neonViolet.withValues(alpha: 0.00),
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

    final glowPaint = Paint()
      ..color = AppTheme.neonViolet.withValues(alpha: 0.34 + pulse * 0.18)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11);
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppTheme.accentPink, AppTheme.neonViolet, Color(0xFF38BDF8)],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final point = points.last;
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(point, 4 + pulse * 1.5, dotPaint);
    final dotGlow = Paint()
      ..color = AppTheme.neonViolet.withValues(alpha: 0.36)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(point, 11 + pulse * 4, dotGlow);
  }

  @override
  bool shouldRepaint(covariant _RsvpLineChartPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.values != values;
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
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
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonViolet.withValues(alpha: 0.36),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _GlowButton extends StatelessWidget {
  const _GlowButton({
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
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.neonViolet,
          foregroundColor: Colors.white,
          shadowColor: AppTheme.neonViolet.withValues(alpha: 0.45),
          elevation: 10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

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
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

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
        color: Colors.white.withValues(alpha: 0.88),
        iconSize: 25,
      ),
    );
  }
}

class _CenterNavButton extends StatelessWidget {
  const _CenterNavButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Create Link',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.premiumGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonViolet.withValues(alpha: 0.56),
                blurRadius: 28,
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
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

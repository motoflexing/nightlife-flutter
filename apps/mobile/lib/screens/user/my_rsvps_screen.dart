import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/rsvp.dart';
import '../../services/firestore_service.dart';
import '../../widgets/compact_ui.dart';
import '../../widgets/state_views.dart';

class MyRsvpsScreen extends StatelessWidget {
  const MyRsvpsScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Rsvp>>(
      stream: FirestoreService.instance.userRsvpsStream(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading RSVPs');
        }
        if (snapshot.hasError) {
          return ErrorStateView(
            message: ErrorStateView.sanitizeError(snapshot.error),
          );
        }
        final rsvps = snapshot.data ?? [];
        if (rsvps.isEmpty) {
          return const EmptyView(
            title: 'No RSVPs yet',
            message: 'Book your first night from the events feed.',
            icon: Icons.confirmation_number_outlined,
          );
        }

        final approved = rsvps.where((r) => r.status == 'approved').toList();
        final upcoming = rsvps
            .where(
              (r) =>
                  r.status != 'attended' &&
                  r.status != 'rejected' &&
                  r.status != 'cancelled',
            )
            .toList();
        final past = rsvps.where((r) => r.status == 'attended').toList();
        final cancelled = rsvps
            .where((r) => r.status == 'rejected' || r.status == 'cancelled')
            .toList();

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SummaryCard(
                  total: rsvps.length,
                  approved: approved.length,
                ),
              ),
              const SizedBox(height: 10),
              const _RsvpTabs(),
              Expanded(
                child: TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _RsvpList(rsvps: upcoming, empty: 'No upcoming RSVPs yet'),
                    _RsvpList(
                      rsvps: past,
                      empty: 'Past nights will appear here',
                    ),
                    _RsvpList(rsvps: cancelled, empty: 'No cancelled RSVPs'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RsvpTabs extends StatelessWidget {
  const _RsvpTabs();

  @override
  Widget build(BuildContext context) {
    return TabBar(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      indicatorColor: AppTheme.accentPink,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: AppTheme.accentPink,
      unselectedLabelColor: AppTheme.textMuted,
      dividerColor: Colors.white.withValues(alpha: 0.08),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
      unselectedLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      tabs: const [
        Tab(text: 'Upcoming'),
        Tab(text: 'Past'),
        Tab(text: 'Cancelled'),
      ],
    );
  }
}

class _RsvpList extends StatelessWidget {
  const _RsvpList({required this.rsvps, required this.empty});

  final List<Rsvp> rsvps;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (rsvps.isEmpty) {
      return EmptyView(
        title: empty,
        message: 'Explore events and join a guestlist when you are ready.',
        icon: Icons.confirmation_number_outlined,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: compactScreenPadding(context, bottom: 112).copyWith(top: 14),
      itemCount: rsvps.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == rsvps.length) return const _RsvpPromoCard();
        return _RsvpTile(rsvp: rsvps[index]);
      },
    );
  }
}

class _RsvpPromoCard extends StatelessWidget {
  const _RsvpPromoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentPink.withValues(alpha: 0.18)),
      ),
      child: const Row(
        children: [
          Icon(Icons.workspace_premium, color: AppTheme.accentPink),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Want Faster Entry?',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 3),
                Text(
                  'Get Premium & skip the lines',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppTheme.paidAccent),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.approved});

  final int total;
  final int approved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.glassSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            color: AppTheme.accentPink,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$total RSVPs tracked',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          _StatusChip(label: '$approved approved', status: 'approved'),
        ],
      ),
    );
  }
}

class _RsvpTile extends StatelessWidget {
  const _RsvpTile({required this.rsvp});

  final Rsvp rsvp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: AppTheme.elevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.confirmation_number,
              color: AppTheme.accentPink,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rsvp.eventTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const SizedBox(height: 5),
                Text(
                  Formatters.eventDate(rsvp.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _StatusChip(
                  label: Formatters.titleCase(rsvp.status),
                  status: rsvp.status,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.accentPink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_activity,
              color: AppTheme.accentPink,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => AppTheme.neonLime,
      'rejected' => AppTheme.neonPink,
      'cancelled' => AppTheme.neonPink,
      _ => AppTheme.neonCyan,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

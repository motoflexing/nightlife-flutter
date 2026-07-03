import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/rsvp.dart';
import '../../services/firestore_service.dart';
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Text(
                  'Your RSVPs',
                  style: AppTypography.displayMedium.copyWith(fontSize: 30),
                ),
              ),
              const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      indicatorColor: AppColors.champagne,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorWeight: 1.5,
      labelColor: AppColors.textHigh,
      unselectedLabelColor: AppColors.textCaption,
      dividerColor: AppColors.goldBorder,
      labelStyle: AppTypography.labelSmall.copyWith(
        fontSize: 11,
        letterSpacing: 0.1 * 11,
      ),
      unselectedLabelStyle: AppTypography.labelSmall.copyWith(
        fontSize: 11,
        letterSpacing: 0.1 * 11,
      ),
      tabs: const [
        Tab(text: 'UPCOMING'),
        Tab(text: 'PAST'),
        Tab(text: 'CANCELLED'),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 112),
      itemCount: rsvps.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _RsvpTile(rsvp: rsvps[index]),
    );
  }
}

class _RsvpTile extends StatelessWidget {
  const _RsvpTile({required this.rsvp});

  final Rsvp rsvp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceEspresso,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.goldBorder, width: 1),
            ),
            child: const Icon(
              Icons.local_activity_outlined,
              color: AppColors.champagne,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rsvp.eventTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 5),
                Text(
                  Formatters.eventDate(rsvp.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textCaption,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                _StatusChip(
                  label: Formatters.titleCase(rsvp.status),
                  status: rsvp.status,
                ),
              ],
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
    // Single-accent Nocturne palette: positive states in champagne, negative
    // (rejected/cancelled) in destructive red.
    final destructive = status == 'rejected' || status == 'cancelled';
    final color = destructive ? AppColors.destructive : AppColors.champagne;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: destructive
            ? AppColors.destructive.withValues(alpha: 0.12)
            : AppColors.goldWash,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          fontSize: 10,
          letterSpacing: 0.14 * 10,
          color: color,
        ),
      ),
    );
  }
}

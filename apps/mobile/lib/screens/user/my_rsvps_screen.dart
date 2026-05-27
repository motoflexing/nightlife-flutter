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
          return ErrorStateView(message: snapshot.error.toString());
        }
        final rsvps = snapshot.data ?? [];
        if (rsvps.isEmpty) {
          return const EmptyView(
            title: 'No RSVPs yet',
            message: 'Book your first night from the events feed.',
            icon: Icons.confirmation_number_outlined,
          );
        }

        final pending = rsvps.where((r) => r.status == 'pending').toList();
        final approved = rsvps.where((r) => r.status == 'approved').toList();
        final past = rsvps.where((r) => r.status == 'attended').toList();
        final upcoming = rsvps
            .where((r) => r.status != 'attended' && r.status != 'rejected')
            .toList();

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: compactScreenPadding(context, bottom: 28),
          children: [
            _SummaryCard(total: rsvps.length, approved: approved.length),
            const SizedBox(height: 12),
            _RsvpSection(title: 'Upcoming', rsvps: upcoming),
            _RsvpSection(title: 'Pending', rsvps: pending),
            _RsvpSection(title: 'Approved', rsvps: approved, showQr: true),
            _RsvpSection(title: 'Past', rsvps: past),
          ],
        );
      },
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

class _RsvpSection extends StatelessWidget {
  const _RsvpSection({
    required this.title,
    required this.rsvps,
    this.showQr = false,
  });

  final String title;
  final List<Rsvp> rsvps;
  final bool showQr;

  @override
  Widget build(BuildContext context) {
    if (rsvps.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...rsvps.map(
            (rsvp) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RsvpTile(rsvp: rsvp, showQr: showQr),
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpTile extends StatelessWidget {
  const _RsvpTile({required this.rsvp, required this.showQr});

  final Rsvp rsvp;
  final bool showQr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppTheme.premiumGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              showQr ? Icons.qr_code_2 : Icons.local_activity_outlined,
            ),
          ),
          const SizedBox(width: 10),
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
                Text(
                  '${Formatters.eventDate(rsvp.createdAt)} - ${rsvp.promoterCode ?? 'Direct RSVP'}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
                if (showQr) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'QR ticket placeholder ready at door approval.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(
            label: Formatters.titleCase(rsvp.status),
            status: rsvp.status,
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

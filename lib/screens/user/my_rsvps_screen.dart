import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
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
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rsvps.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _RsvpTile(rsvp: rsvps[index]),
        );
      },
    );
  }
}

class _RsvpTile extends StatelessWidget {
  const _RsvpTile({required this.rsvp});

  final Rsvp rsvp;

  @override
  Widget build(BuildContext context) {
    final color = switch (rsvp.status) {
      'approved' => AppTheme.neonLime,
      'rejected' => AppTheme.neonPink,
      _ => AppTheme.neonCyan,
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.16),
          child: Icon(Icons.confirmation_number, color: color),
        ),
        title: Text(
          rsvp.eventTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${Formatters.eventDate(rsvp.createdAt)} - ${rsvp.promoterCode ?? 'Direct'}',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        trailing: Text(
          Formatters.titleCase(rsvp.status),
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

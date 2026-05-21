import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/state_views.dart';
import '../auth/access_state_screen.dart';
import '../auth/login_screen.dart';
import 'event_details_screen.dart';

class EventLinkScreen extends StatelessWidget {
  const EventLinkScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const NeonScaffold(child: LoadingView());
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) return const LoginScreen();

        return StreamBuilder<AppUser?>(
          stream: AuthService.instance.profileStream(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const NeonScaffold(
                child: LoadingView(message: 'Loading profile'),
              );
            }
            if (profileSnapshot.hasError) {
              return NeonScaffold(
                child: ErrorStateView(
                  message: profileSnapshot.error.toString(),
                ),
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null) {
              return FutureBuilder<AppUser>(
                future: AuthService.instance.ensureSafeProfile(firebaseUser),
                builder: (context, safeSnapshot) {
                  if (safeSnapshot.connectionState == ConnectionState.waiting) {
                    return const NeonScaffold(
                      child: LoadingView(message: 'Creating profile'),
                    );
                  }
                  if (safeSnapshot.hasError) {
                    return NeonScaffold(
                      child: ErrorStateView(
                        message: safeSnapshot.error.toString(),
                      ),
                    );
                  }
                  return const NeonScaffold(
                    child: LoadingView(message: 'Loading event'),
                  );
                },
              );
            }

            if (profile.isRejected || !profile.isActive) {
              return const AccessStateScreen(
                title: 'Account rejected',
                message: 'This account is not approved for RSVP access.',
                icon: Icons.block_outlined,
              );
            }

            return StreamBuilder<NightlifeEvent?>(
              stream: FirestoreService.instance.eventStream(eventId),
              builder: (context, eventSnapshot) {
                if (eventSnapshot.connectionState == ConnectionState.waiting) {
                  return const NeonScaffold(
                    child: LoadingView(message: 'Loading event'),
                  );
                }
                if (eventSnapshot.hasError) {
                  return NeonScaffold(
                    child: ErrorStateView(
                      message: eventSnapshot.error.toString(),
                    ),
                  );
                }

                final event = eventSnapshot.data;
                if (event == null || !event.isActive) {
                  return const NeonScaffold(
                    child: EmptyView(
                      title: 'Event unavailable',
                      message: 'This event is no longer active.',
                      icon: Icons.event_busy_outlined,
                    ),
                  );
                }

                return EventDetailsScreen(event: event, currentUser: profile);
              },
            );
          },
        );
      },
    );
  }
}

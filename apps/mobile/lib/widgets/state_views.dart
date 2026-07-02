import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import 'premium_loader.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: PremiumLoader(message: message));
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.nights_stay_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            // Dashed-feel gold hairline framing the honest empty state (design).
            border: Border.all(color: AppColors.goldBorder, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 34,
                color: AppColors.champagne.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 14),
              // Playfair title (design empty state, e.g. "Nothing yet").
              Text(
                title,
                style: AppTypography.headlineMedium.copyWith(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textCaption,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!.toUpperCase()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;

  static String sanitizeError(Object? error) {
    if (error == null) return 'An unexpected error occurred.';
    final raw = error.toString();
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }
    if (raw.contains('permission-denied') ||
        raw.contains('PERMISSION_DENIED')) {
      return 'You don\'t have permission to view this.';
    }
    if (raw.contains('not-found') || raw.contains('NOT_FOUND')) {
      return 'This content could not be found.';
    }
    if (raw.contains('unauthenticated') ||
        raw.contains('UNAUTHENTICATED')) {
      return 'Please log in to continue.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// User-facing message for any caught error, safe to show directly (e.g. in a
  /// SnackBar). Prefer this over `error.toString()` — the app's typed exceptions
  /// ([AuthException], [FirestoreAppException], [LocationServiceException]) carry
  /// an already-friendly `message`, raw [FirebaseAuthException]s are mapped via
  /// [AuthService.friendlyAuthMessage], and anything else falls back to
  /// [sanitizeError] (which never leaks a raw exception string).
  static String friendlyError(Object? error) {
    if (error is AuthException) return error.message;
    if (error is FirestoreAppException) return error.message;
    if (error is LocationServiceException) return error.message;
    if (error is FirebaseAuthException) {
      return AuthService.friendlyAuthMessage(error);
    }
    return sanitizeError(error);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.destructive.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Offline/error uses the destructive tone (design "Lost the room").
              const Icon(
                Icons.wifi_off,
                color: AppColors.destructive,
                size: 34,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: AppTypography.headlineMedium.copyWith(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textCaption,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('RETRY'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

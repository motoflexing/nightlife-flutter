import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../services/location_service.dart';

/// Outcome of [ensureLocationPermissionWithRationale].
enum LocationRationaleResult {
  /// OS permission is granted (either it already was, or the user accepted the
  /// rationale and then granted it at the system prompt). Safe to fetch
  /// location.
  granted,

  /// The user declined the in-app rationale ("Not now"). The OS prompt was
  /// NOT shown. Callers should abort the location action gracefully.
  declined,

  /// The user accepted the rationale but permission was not granted at the OS
  /// level (denied / permanently denied / services off / error). Callers
  /// handle this the same way as their existing "location unavailable" path.
  denied,
}

/// Shows a prominent in-app disclosure explaining WHAT location data is used and
/// WHY, BEFORE the OS permission prompt — as required by Google Play for
/// foreground location. Returns true if the user chose to continue, false if
/// they chose "Not now" (or dismissed the dialog).
///
/// This dialog is shown only when permission has NOT yet been granted; callers
/// should not invoke it when [LocationService.hasLocationPermission] is already
/// true (use [ensureLocationPermissionWithRationale], which handles that).
Future<bool> showLocationRationaleDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surfaceEspresso,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.goldBorder, width: 1),
      ),
      title: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.champagne),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Allow location access?',
              style: AppTypography.headlineMedium.copyWith(fontSize: 20),
            ),
          ),
        ],
      ),
      content: Text(
        'We use your device location (approximate or precise) to show events '
        'and venues near you and to calculate distances.\n\n'
        'Your location is only used while you\'re using the app — never in the '
        'background.',
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textBodyDim),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Not now',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Continue',
            style: TextStyle(color: AppColors.champagne),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single entry point all location callers should use before fetching a
/// location. It guarantees the Google Play foreground-location flow:
///
///  1. If permission is ALREADY granted -> returns [LocationRationaleResult
///     .granted] immediately (no rationale nag).
///  2. Otherwise it shows the in-app rationale dialog FIRST.
///       - "Not now"  -> returns [LocationRationaleResult.declined]; the OS
///         prompt is NOT triggered.
///       - "Continue" -> calls the existing [LocationService.requestPermission]
///         (which triggers the OS prompt) and maps the outcome to
///         [LocationRationaleResult.granted] / [LocationRationaleResult.denied].
///
/// The underlying Geolocator / permission logic is unchanged — this only
/// inserts the rationale step before the OS request.
Future<LocationRationaleResult> ensureLocationPermissionWithRationale(
  BuildContext context,
) async {
  // Already granted: go straight through, never re-show the rationale.
  if (await LocationService.instance.hasLocationPermission()) {
    return LocationRationaleResult.granted;
  }

  if (!context.mounted) return LocationRationaleResult.declined;

  final shouldContinue = await showLocationRationaleDialog(context);
  if (!shouldContinue) return LocationRationaleResult.declined;

  // User acknowledged the disclosure — now trigger the real OS prompt via the
  // existing, unchanged permission flow.
  final permission = await LocationService.instance.requestPermission();
  return permission.isGranted
      ? LocationRationaleResult.granted
      : LocationRationaleResult.denied;
}

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Shared two-step "Delete account" flow used by the user, promoter, and club
/// profile screens.
///
/// Step 1 — a confirmation dialog with accurate soft-delete wording (the account
/// is deactivated and scheduled for deletion, NOT instantly erased). Step 2 — a
/// password prompt to re-authenticate before deletion.
///
/// Returns the entered password, or null if the user cancels at either step.
Future<String?> confirmAndRequestDeletePassword(
  BuildContext context, {
  String message =
      'Your account will be deactivated and scheduled for deletion. '
      'You will be signed out and lose access immediately. This cannot be undone.',
}) async {
  final confirmed = await _confirmDeleteAccount(context, message: message);
  if (confirmed != true) return null;
  if (!context.mounted) return null;
  return _requestDeletePassword(context);
}

Future<bool?> _confirmDeleteAccount(
  BuildContext context, {
  required String message,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete account?'),
      content: Text(
        message,
        style: const TextStyle(color: AppColors.textCaption, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Continue',
            style: TextStyle(color: AppColors.destructive),
          ),
        ),
      ],
    ),
  );
}

Future<String?> _requestDeletePassword(BuildContext context) async {
  final controller = TextEditingController();
  final password = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your password to deactivate this account and schedule it '
            'for deletion.',
            style: TextStyle(color: AppColors.textCaption),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onSubmitted: (value) {
              final text = value.trim();
              if (text.isEmpty) return;
              Navigator.of(context).pop(text);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isEmpty) return;
            Navigator.of(context).pop(text);
          },
          child: const Text(
            'Delete',
            style: TextStyle(color: AppColors.destructive),
          ),
        ),
      ],
    ),
  );
  controller.dispose();
  return password;
}

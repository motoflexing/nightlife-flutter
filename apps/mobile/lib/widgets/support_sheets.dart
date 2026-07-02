import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../services/firestore_service.dart';
import 'state_views.dart';

/// Opens the "Report an event" bottom sheet. Writes a real row to the
/// `event_reports` collection via [FirestoreService.submitEventReport].
Future<void> showReportEventSheet(BuildContext context) {
  return _showFormSheet(
    context: context,
    title: 'Report an event',
    icon: Icons.report_gmailerrorred_outlined,
    child: const _ReportEventForm(),
  );
}

/// Opens the "RSVP problem" bottom sheet. Writes a real row to the
/// `support_tickets` collection via [FirestoreService.submitRsvpProblemTicket].
Future<void> showRsvpProblemSheet(BuildContext context) {
  return _showFormSheet(
    context: context,
    title: 'RSVP problem',
    icon: Icons.confirmation_number_outlined,
    child: const _RsvpProblemForm(),
  );
}

Future<void> _showFormSheet({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Widget child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Nocturne sheet surface + strong scrim (DESIGN_TOKENS.md §10). Top corners
    // 22px, bottom crisp — flush to the screen edge.
    backgroundColor: AppColors.surfaceEspresso,
    barrierColor: AppColors.scrim,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetGrabHandle(),
            Row(
              children: [
                Icon(icon, color: AppColors.champagne, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  // Playfair sheet title (design bottom-sheet heading).
                  child: Text(
                    title,
                    style: AppTypography.headlineMedium.copyWith(fontSize: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    ),
  );
}

/// Centered low-emphasis grab handle at the top of every bottom sheet
/// (DESIGN_TOKENS.md §10 — 40×4 pill, ivory .25).
class _SheetGrabHandle extends StatelessWidget {
  const _SheetGrabHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.textDisabled,
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}

class _ReportEventForm extends StatefulWidget {
  const _ReportEventForm();

  @override
  State<_ReportEventForm> createState() => _ReportEventFormState();
}

class _ReportEventFormState extends State<_ReportEventForm> {
  static const _reasons = [
    'Inappropriate content',
    'Misleading information',
    'Event cancelled/fake',
    'Safety concern',
    'Other',
  ];
  static const _maxDetails = 500;

  final _formKey = GlobalKey<FormState>();
  final _eventName = TextEditingController();
  final _details = TextEditingController();
  String _reason = _reasons.first;
  bool _submitting = false;

  @override
  void dispose() {
    _eventName.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await FirestoreService.instance.submitEventReport(
        eventName: _eventName.text,
        reason: _reason,
        details: _details.text,
      );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(ErrorStateView.friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _eventName,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Event name',
              prefixIcon: Icon(Icons.nightlife_outlined),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Enter the event name.'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(
              labelText: 'Reason',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: [
              for (final reason in _reasons)
                DropdownMenuItem(value: reason, child: Text(reason)),
            ],
            onChanged: _submitting
                ? null
                : (value) {
                    if (value != null) setState(() => _reason = value);
                  },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _details,
            minLines: 3,
            maxLines: 5,
            maxLength: _maxDetails,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 8),
          _SubmitButton(
            label: 'Submit report',
            busy: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _RsvpProblemForm extends StatefulWidget {
  const _RsvpProblemForm();

  @override
  State<_RsvpProblemForm> createState() => _RsvpProblemFormState();
}

class _RsvpProblemFormState extends State<_RsvpProblemForm> {
  static const _maxMessage = 1000;

  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await FirestoreService.instance.submitRsvpProblemTicket(
        message: _message.text,
      );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(ErrorStateView.friendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _message,
            minLines: 4,
            maxLines: 7,
            maxLength: _maxMessage,
            decoration: const InputDecoration(
              labelText: 'Describe the problem',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.support_agent_outlined),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Tell us what went wrong.'
                : null,
          ),
          const SizedBox(height: 8),
          _SubmitButton(
            label: 'Submit request',
            busy: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                height: 18,
                width: 18,
                // Obsidian on the ivory primary fill for contrast.
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.obsidian,
                ),
              )
            : Text(label),
      ),
    );
  }
}

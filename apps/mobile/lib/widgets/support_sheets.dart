import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
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
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.accentPink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}

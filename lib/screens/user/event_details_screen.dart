import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/firestore_service.dart';
import '../../services/referral_service.dart';
import '../../widgets/neon_scaffold.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({
    super.key,
    required this.event,
    required this.currentUser,
  });

  final NightlifeEvent event;
  final AppUser currentUser;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late final TextEditingController _codeController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: ReferralService.instance.code ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _rsvp() async {
    setState(() => _submitting = true);
    try {
      await FirestoreService.instance.createRsvp(
        event: widget.event,
        user: widget.currentUser,
        promoterCode: _codeController.text,
      );
      ReferralService.instance.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RSVP created. Status is pending approval.')),
      );
      Navigator.of(context).pop();
    } on FirestoreAppException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return NeonScaffold(
      appBar: AppBar(title: const Text('Event details')),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 780;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _Poster(event: event)),
                          const SizedBox(width: 22),
                          Expanded(
                            flex: 4,
                            child: _Details(
                              event: event,
                              currentUser: widget.currentUser,
                              codeController: _codeController,
                              submitting: _submitting,
                              onRsvp: _rsvp,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Poster(event: event),
                          const SizedBox(height: 18),
                          _Details(
                            event: event,
                            currentUser: widget.currentUser,
                            codeController: _codeController,
                            submitting: _submitting,
                            onRsvp: _rsvp,
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.event});

  final NightlifeEvent event;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: event.posterUrl.isEmpty
            ? Container(
                color: AppTheme.elevated,
                child: const Icon(Icons.nightlife, size: 80, color: AppTheme.neonCyan),
              )
            : Image.network(event.posterUrl, fit: BoxFit.cover),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.event,
    required this.currentUser,
    required this.codeController,
    required this.submitting,
    required this.onRsvp,
  });

  final NightlifeEvent event;
  final AppUser currentUser;
  final TextEditingController codeController;
  final bool submitting;
  final VoidCallback onRsvp;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                Chip(label: Text(event.city)),
              ],
            ),
            const SizedBox(height: 14),
            _Info(icon: Icons.place_outlined, text: '${event.venueName}, ${event.address}'),
            _Info(icon: Icons.schedule, text: Formatters.eventDate(event.dateTime)),
            _Info(icon: Icons.music_note_outlined, text: event.musicType),
            _Info(icon: Icons.groups_2_outlined, text: event.crowdType),
            _Info(icon: Icons.rule_outlined, text: event.entryRules),
            const SizedBox(height: 12),
            Text(event.description, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.neonCyan.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.22)),
              ),
              child: Text(
                event.priceText.isEmpty ? 'Entry details available at venue.' : event.priceText,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            if (currentUser.isUser && currentUser.isApproved) ...[
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Promoter code',
                  hintText: 'Optional referral code',
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: submitting ? null : onRsvp,
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_reg),
                label: const Text('RSVP now'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textMuted))),
        ],
      ),
    );
  }
}

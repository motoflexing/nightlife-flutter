// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../models/rsvp.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/compact_ui.dart';
import '../../widgets/event_card.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_loader.dart';
import '../../widgets/state_views.dart';
import '../../widgets/venue_location_picker.dart';
import 'club_profile_screen.dart';

class ClubAdminDashboardScreen extends StatefulWidget {
  const ClubAdminDashboardScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<ClubAdminDashboardScreen> createState() =>
      _ClubAdminDashboardScreenState();
}

class _ClubAdminDashboardScreenState extends State<ClubAdminDashboardScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _ClubEvents(currentUser: widget.currentUser),
      _ClubRsvps(currentUser: widget.currentUser),
      ClubProfileScreen(currentUser: widget.currentUser),
    ];
    return NeonScaffold(
      appBar: AppBar(
        title: Text(switch (_index) {
          0 => 'Club events',
          1 => 'Club RSVPs',
          _ => 'Club profile',
        }),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_activity_outlined),
            selectedIcon: Icon(Icons.local_activity),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'RSVPs',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
      child: pages[_index],
    );
  }
}

class _ClubEvents extends StatelessWidget {
  const _ClubEvents({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NightlifeEvent>>(
      stream: FirestoreService.instance.clubEventsStream(currentUser),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading club events');
        }
        if (snapshot.hasError)
          return ErrorStateView(
            message: ErrorStateView.sanitizeError(snapshot.error),
          );
        final events = snapshot.data ?? [];
        return ListView(
          padding: compactScreenPadding(context),
          children: [
            // Playfair title + real count eyebrow (design venue overview).
            Text(
              'Your Nights',
              style: AppTypography.displayMedium.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 4),
            Text(
              events.isEmpty
                  ? 'Publish a night to put it on the map.'
                  : '${events.length} ${events.length == 1 ? 'event' : 'events'} in your house.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textCaption,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _openEventForm(context, currentUser: currentUser),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('CREATE EVENT'),
              ),
            ),
            const SizedBox(height: 16),
            if (events.isEmpty)
              const EmptyView(
                title: 'No club events yet',
                message: 'Create your first event after approval.',
                icon: Icons.storefront_outlined,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900 ? 2 : 1;
                  final spacing = columns == 1 ? 12.0 : 10.0;
                  final tileWidth =
                      (constraints.maxWidth - (spacing * (columns - 1))) /
                      columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: events.map((event) {
                      return SizedBox(
                        width: tileWidth,
                        child: _ClubEventTile(
                          event: event,
                          onEdit: () => _openEventForm(
                            context,
                            currentUser: currentUser,
                            event: event,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  void _openEventForm(
    BuildContext context, {
    required AppUser currentUser,
    NightlifeEvent? event,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceEspresso,
      barrierColor: AppColors.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _ClubEventForm(currentUser: currentUser, event: event),
    );
  }
}

class _ClubEventTile extends StatefulWidget {
  const _ClubEventTile({required this.event, required this.onEdit});

  final NightlifeEvent event;
  final VoidCallback onEdit;

  @override
  State<_ClubEventTile> createState() => _ClubEventTileState();
}

class _ClubEventTileState extends State<_ClubEventTile> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EventCard(event: widget.event, compact: true, onTap: widget.onEdit),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit, size: 17),
                  label: const Text(
                    'Edit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: _deleting
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Event'),
                              content: const Text(
                                'Are you sure you want to delete this event? '
                                'This cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: AppColors.destructive,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          setState(() => _deleting = true);
                          try {
                            await FirestoreService.instance.deactivateEvent(
                              widget.event.id,
                            );
                          } finally {
                            if (mounted) setState(() => _deleting = false);
                          }
                        },
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: _deleting
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Delete',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ClubRsvps extends StatelessWidget {
  const _ClubRsvps({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Rsvp>>(
      stream: FirestoreService.instance.clubRsvpsStream(currentUser),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading club RSVPs');
        }
        if (snapshot.hasError)
          return ErrorStateView(
            message: ErrorStateView.sanitizeError(snapshot.error),
          );
        final rsvps = snapshot.data ?? [];
        if (rsvps.isEmpty) {
          return const EmptyView(
            title: 'No RSVPs yet',
            message: 'Bookings for your club events will appear here.',
            icon: Icons.fact_check_outlined,
          );
        }
        return ListView.separated(
          padding: compactScreenPadding(context),
          // +1 leading item for the Playfair title + real "Door list · N".
          itemCount: rsvps.length + 1,
          separatorBuilder: (_, index) =>
              SizedBox(height: index == 0 ? 16 : 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Door List',
                    style: AppTypography.displayMedium.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rsvps.length} ${rsvps.length == 1 ? 'RSVP' : 'RSVPs'} across your nights.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textCaption,
                    ),
                  ),
                ],
              );
            }
            return _ClubRsvpRow(rsvp: rsvps[index - 1]);
          },
        );
      },
    );
  }
}

/// One real door-list row: guest name, phone, RSVP date, and a status chip.
/// All fields come straight off the [Rsvp] from clubRsvpsStream — no fabricated
/// capacity or "on the list" numbers.
class _ClubRsvpRow extends StatelessWidget {
  const _ClubRsvpRow({required this.rsvp});

  final Rsvp rsvp;

  @override
  Widget build(BuildContext context) {
    final name = rsvp.userName.trim().isEmpty ? 'A guest' : rsvp.userName.trim();
    final phone = rsvp.userPhone.trim();
    final meta = [
      if (phone.isNotEmpty) phone,
      Formatters.eventDate(rsvp.createdAt),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gold-ring monogram (design door-list avatar).
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.goldWash,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              _rsvpInitials(name),
              style: AppTypography.headlineMedium.copyWith(
                fontSize: 15,
                color: AppColors.champagne,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rsvp.eventTitle.trim().isEmpty
                      ? 'Event'
                      : rsvp.eventTitle.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBodyDim,
                    fontSize: 13,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textCaption,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RsvpStatusChip(status: rsvp.status),
        ],
      ),
    );
  }
}

/// RSVP status pill. Single-accent Nocturne palette: approved/confirmed states
/// read in champagne, rejected/cancelled in destructive red, everything else
/// (e.g. pending) in low-emphasis ivory.
class _RsvpStatusChip extends StatelessWidget {
  const _RsvpStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final negative = normalized == 'rejected' || normalized == 'cancelled';
    final positive = normalized == 'approved' || normalized == 'confirmed';
    final Color color;
    if (negative) {
      color = AppColors.destructive;
    } else if (positive) {
      color = AppColors.champagne;
    } else {
      color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: negative
            ? AppColors.destructive.withValues(alpha: 0.12)
            : positive
            ? AppColors.goldWash
            : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        Formatters.titleCase(status).toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          fontSize: 9,
          color: color,
        ),
      ),
    );
  }
}

class _ClubEventForm extends StatefulWidget {
  const _ClubEventForm({required this.currentUser, this.event});

  final AppUser currentUser;
  final NightlifeEvent? event;

  @override
  State<_ClubEventForm> createState() => _ClubEventFormState();
}

class _ClubEventFormState extends State<_ClubEventForm> {
  final _formKey = GlobalKey<FormState>();
  late NightlifeEvent _event;
  late final TextEditingController _title;
  late final TextEditingController _venue;
  late final TextEditingController _address;
  late final TextEditingController _music;
  late final TextEditingController _crowd;
  late final TextEditingController _rules;
  late final TextEditingController _description;
  late final TextEditingController _posterUrl;
  late final TextEditingController _price;
  late final TextEditingController _fullAddress;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _mapsLink;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _event =
        widget.event ??
        NightlifeEvent.empty(createdBy: widget.currentUser.uid).copyWith(
          venueId: widget.currentUser.clubId,
          clubId: widget.currentUser.clubId,
        );
    _title = TextEditingController(text: _event.title);
    _venue = TextEditingController(text: _event.venueName);
    _address = TextEditingController(text: _event.address);
    _music = TextEditingController(text: _event.musicType);
    _crowd = TextEditingController(text: _event.crowdType);
    _rules = TextEditingController(text: _event.entryRules);
    _description = TextEditingController(text: _event.description);
    _posterUrl = TextEditingController(text: _event.posterUrl);
    _price = TextEditingController(text: _event.priceText);
    _fullAddress = TextEditingController(text: _event.fullAddress);
    _latitude = TextEditingController(text: _formatCoordinate(_event.latitude));
    _longitude = TextEditingController(
      text: _formatCoordinate(_event.longitude),
    );
    _mapsLink = TextEditingController(text: _event.googleMapsLink);
  }

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _address.dispose();
    _music.dispose();
    _crowd.dispose();
    _rules.dispose();
    _description.dispose();
    _posterUrl.dispose();
    _price.dispose();
    _fullAddress.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _mapsLink.dispose();
    super.dispose();
  }

  void _syncLocationControllers(NightlifeEvent event) {
    _fullAddress.text = event.fullAddress;
    _latitude.text = _formatCoordinate(event.latitude);
    _longitude.text = _formatCoordinate(event.longitude);
    _mapsLink.text = event.googleMapsLink;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    final mapsLink = _mapsLink.text.trim().isNotEmpty
        ? _mapsLink.text.trim()
        : latitude == null || longitude == null
        ? ''
        : LocationService.instance.googleMapsLink(
            latitude: latitude,
            longitude: longitude,
            label: _venue.text.trim(),
          );
    var next = _event.copyWith(
      title: _title.text.trim(),
      venueName: _venue.text.trim(),
      address: _address.text.trim(),
      fullAddress: _fullAddress.text.trim(),
      latitude: latitude,
      longitude: longitude,
      googleMapsLink: mapsLink,
      musicType: _music.text.trim(),
      crowdType: _crowd.text.trim(),
      entryRules: _rules.text.trim(),
      description: _description.text.trim(),
      posterUrl: _posterUrl.text.trim(),
      priceText: _price.text.trim(),
      venueId: widget.currentUser.clubId,
      clubId: widget.currentUser.clubId,
      createdBy: _event.createdBy.isEmpty
          ? widget.currentUser.uid
          : _event.createdBy,
    );

    if (next.latitude == null || next.longitude == null) {
      final geocoded = await LocationService.instance.geocodeAddress(
        '${next.venueName}, ${next.address}, ${next.city}',
      );
      if (geocoded != null) {
        next = next.copyWith(
          latitude: geocoded.latitude,
          longitude: geocoded.longitude,
          googleMapsLink: LocationService.instance.googleMapsLink(
            latitude: geocoded.latitude,
            longitude: geocoded.longitude,
            label: next.venueName,
          ),
        );
      }
    }

    try {
      await FirestoreService.instance.createOrUpdateEvent(next);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorStateView.friendlyError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      minChildSize: 0.55,
      builder: (context, controller) {
        return Form(
          key: _formKey,
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            children: [
              Text(
                _event.id.isEmpty ? 'New Night' : 'Edit Night',
                style: AppTypography.headlineMedium.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 16),
              _Field(controller: _title, label: 'Title'),
              DropdownButtonFormField<String>(
                initialValue: _event.city,
                decoration: const InputDecoration(labelText: 'City'),
                items: AppConstants.cities
                    .where((city) => city != 'All')
                    .map(
                      (city) =>
                          DropdownMenuItem(value: city, child: Text(city)),
                    )
                    .toList(),
                onChanged: (value) => setState(
                  () => _event = _event.copyWith(city: value ?? _event.city),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _event.isActive,
                title: const Text('Active'),
                onChanged: (value) =>
                    setState(() => _event = _event.copyWith(isActive: value)),
              ),
              _Field(controller: _venue, label: 'Venue name'),
              _Field(controller: _address, label: 'Venue address'),
              _Field(controller: _fullAddress, label: 'Full address'),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _latitude,
                      label: 'Latitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: _coordinateValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _longitude,
                      label: 'Longitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: _coordinateValidator,
                    ),
                  ),
                ],
              ),
              _Field(
                controller: _mapsLink,
                label: 'Google Maps link',
                isRequired: false,
                keyboardType: TextInputType.url,
              ),
              VenueLocationPicker(
                event: _event,
                venueName: _venue.text,
                onChanged: (event) => setState(() {
                  _event = event;
                  _syncLocationControllers(event);
                }),
                onAddressResolved: (address) {
                  if (address.trim().isNotEmpty) {
                    _address.text = address;
                    _fullAddress.text = address;
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(Formatters.eventDate(_event.dateTime)),
                subtitle: const Text('Event date and time'),
                trailing: OutlinedButton(
                  onPressed: _pickDateTime,
                  child: const Text('Change'),
                ),
              ),
              _Field(controller: _music, label: 'Music type'),
              _Field(controller: _crowd, label: 'Crowd type'),
              _Field(controller: _rules, label: 'Entry rules'),
              _Field(controller: _price, label: 'Price text'),
              _Field(
                controller: _description,
                label: 'Description',
                maxLines: 4,
              ),
              _Field(
                controller: _posterUrl,
                label: 'Poster URL',
                isRequired: false,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const PremiumLoader.compact(size: 18)
                    : const Icon(Icons.save, size: 18),
                label: const Text('PUBLISH NIGHT'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _event.dateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_event.dateTime),
    );
    if (time == null) return;
    setState(() {
      _event = _event.copyWith(
        dateTime: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    });
  }

  static String _formatCoordinate(double? coordinate) {
    return coordinate == null ? '' : coordinate.toStringAsFixed(7);
  }

  static String? _coordinateValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Coordinate is required';
    if (double.tryParse(text) == null) return 'Enter a valid coordinate';
    return null;
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.isRequired = true,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final bool isRequired;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        validator:
            validator ??
            (value) {
              if (!isRequired) return null;
              if (value == null || value.trim().isEmpty)
                return '$label is required';
              return null;
            },
      ),
    );
  }
}

String _rsvpInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return initials.isEmpty ? '?' : initials;
}

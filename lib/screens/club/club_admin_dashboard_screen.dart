// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
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
import '../../widgets/state_views.dart';
import '../../widgets/venue_location_picker.dart';

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
    ];
    return NeonScaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Club events' : 'Club RSVPs'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: AuthService.instance.signOut,
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
          return ErrorStateView(message: snapshot.error.toString());
        final events = snapshot.data ?? [];
        return ListView(
          padding: compactScreenPadding(context),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _openEventForm(context, currentUser: currentUser),
                icon: const Icon(Icons.add),
                label: const Text('Create event'),
              ),
            ),
            const SizedBox(height: 14),
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
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: columns == 1 ? 204 : 214,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Column(
                        children: [
                          Expanded(
                            child: EventCard(
                              event: event,
                              onTap: () => _openEventForm(
                                context,
                                currentUser: currentUser,
                                event: event,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openEventForm(
                                    context,
                                    currentUser: currentUser,
                                    event: event,
                                  ),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => FirestoreService.instance
                                      .deactivateEvent(event.id),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
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
      backgroundColor: AppTheme.surface,
      builder: (_) => _ClubEventForm(currentUser: currentUser, event: event),
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
          return ErrorStateView(message: snapshot.error.toString());
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
          itemCount: rsvps.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final rsvp = rsvps[index];
            return Card(
              child: ListTile(
                title: Text(
                  rsvp.eventTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${rsvp.userName} - ${rsvp.userPhone} - ${Formatters.eventDate(rsvp.createdAt)}',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                trailing: Chip(label: Text(Formatters.titleCase(rsvp.status))),
              ),
            );
          },
        );
      },
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
        NightlifeEvent.empty(
          createdBy: widget.currentUser.uid,
        ).copyWith(clubId: widget.currentUser.clubId);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
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
                _event.id.isEmpty ? 'Create event' : 'Edit event',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
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
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save event'),
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

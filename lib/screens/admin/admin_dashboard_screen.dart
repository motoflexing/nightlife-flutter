// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/club.dart';
import '../../models/event.dart';
import '../../models/promoter.dart';
import '../../models/rsvp.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/event_card.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/state_views.dart';
import '../../widgets/venue_location_picker.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final sections = [
      _AdminOverview(currentUser: widget.currentUser),
      const _ApprovalsAdmin(),
      _EventsAdmin(currentUser: widget.currentUser),
      const _UsersAdmin(),
      const _ClubsAdmin(),
      const _PromotersAdmin(),
      const _RsvpsAdmin(),
    ];
    final labels = [
      'Super Admin',
      'Approvals',
      'Events',
      'Users',
      'Clubs',
      'Promoters',
      'RSVPs',
    ];
    final icons = [
      Icons.dashboard_outlined,
      Icons.verified_user_outlined,
      Icons.local_activity_outlined,
      Icons.people_outline,
      Icons.storefront_outlined,
      Icons.campaign_outlined,
      Icons.fact_check_outlined,
    ];
    return NeonScaffold(
      appBar: AppBar(
        title: Text(labels[_index]),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: AuthService.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 820) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationRailDestination(
                        icon: Icon(icons[i]),
                        selectedIcon: Icon(icons[i], color: AppTheme.neonPink),
                        label: Text(labels[i]),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: sections[_index]),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: sections[_index]),
              NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationDestination(
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _StreamCountCard<NightlifeEvent>(
              title: 'Events',
              icon: Icons.local_activity,
              stream: FirestoreService.instance.adminEventsStream(),
            ),
            _StreamCountCard<AppUser>(
              title: 'Users',
              icon: Icons.people,
              stream: FirestoreService.instance.usersStream(),
            ),
            _StreamCountCard<Promoter>(
              title: 'Promoters',
              icon: Icons.campaign,
              stream: FirestoreService.instance.promotersStream(),
            ),
            _StreamCountCard<Rsvp>(
              title: 'RSVPs',
              icon: Icons.fact_check,
              stream: FirestoreService.instance.allRsvpsStream(),
            ),
            _StreamCountCard<Club>(
              title: 'Clubs',
              icon: Icons.storefront,
              stream: FirestoreService.instance.clubsStream(),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operator console',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage inventory, roles, referral distribution, and RSVP approvals from one Firebase-backed control room.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      FirestoreService.instance.seedDemoEvents(currentUser.uid),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Seed demo events'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StreamCountCard<T> extends StatelessWidget {
  const _StreamCountCard({
    required this.title,
    required this.icon,
    required this.stream,
  });

  final String title;
  final IconData icon;
  final Stream<List<T>> stream;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<T>>(
            stream: stream,
            builder: (context, snapshot) {
              return Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.neonCyan.withValues(alpha: 0.14),
                    child: Icon(icon, color: AppTheme.neonCyan),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      Text(
                        snapshot.hasData
                            ? snapshot.data!.length.toString()
                            : '...',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ApprovalsAdmin extends StatelessWidget {
  const _ApprovalsAdmin();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: FirestoreService.instance.pendingApprovalsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading approvals');
        }
        if (snapshot.hasError)
          return ErrorStateView(message: snapshot.error.toString());
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const EmptyView(
            title: 'No pending approvals',
            message: 'Club admin requests will appear here.',
            icon: Icons.verified_user_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.hourglass_top_outlined,
                  color: AppTheme.neonCyan,
                ),
                title: Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${user.email} - ${user.role} - ${user.status}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _runAction(
                        context,
                        () => FirestoreService.instance.rejectUser(user),
                      ),
                      icon: const Icon(Icons.close, color: AppTheme.neonPink),
                      label: const Text('Reject'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _runAction(
                        context,
                        () => FirestoreService.instance.approveUser(user),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _EventsAdmin extends StatelessWidget {
  const _EventsAdmin({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NightlifeEvent>>(
      stream: FirestoreService.instance.adminEventsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading events');
        }
        if (snapshot.hasError)
          return ErrorStateView(message: snapshot.error.toString());
        final events = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => _openEventForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Add event'),
              ),
            ),
            const SizedBox(height: 14),
            if (events.isEmpty)
              const EmptyView(
                title: 'No events yet',
                message: 'Create the first drop for Guwahati or Delhi.',
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
                      childAspectRatio: columns == 1 ? 0.8 : 0.78,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Column(
                        children: [
                          Expanded(
                            child: EventCard(
                              event: event,
                              onTap: () =>
                                  _openEventForm(context, event: event),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _openEventForm(context, event: event),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => FirestoreService.instance
                                      .deactivateEvent(event.id),
                                  icon: const Icon(
                                    Icons.visibility_off_outlined,
                                  ),
                                  label: const Text('Deactivate'),
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

  void _openEventForm(BuildContext context, {NightlifeEvent? event}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => _EventForm(currentUser: currentUser, event: event),
    );
  }
}

class _EventForm extends StatefulWidget {
  const _EventForm({required this.currentUser, this.event});

  final AppUser currentUser;
  final NightlifeEvent? event;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
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
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _event =
        widget.event ?? NightlifeEvent.empty(createdBy: widget.currentUser.uid);
    _title = TextEditingController(text: _event.title);
    _venue = TextEditingController(text: _event.venueName);
    _address = TextEditingController(text: _event.address);
    _music = TextEditingController(text: _event.musicType);
    _crowd = TextEditingController(text: _event.crowdType);
    _rules = TextEditingController(text: _event.entryRules);
    _description = TextEditingController(text: _event.description);
    _posterUrl = TextEditingController(text: _event.posterUrl);
    _price = TextEditingController(text: _event.priceText);
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
    super.dispose();
  }

  Future<void> _pickPoster() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 86,
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      final url = await StorageService.instance.uploadEventPoster(
        bytes: bytes,
        fileName: file.name,
        contentType: file.mimeType ?? 'image/jpeg',
      );
      _posterUrl.text = url;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Poster uploaded')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    var next = _event.copyWith(
      title: _title.text.trim(),
      venueName: _venue.text.trim(),
      address: _address.text.trim(),
      fullAddress: _address.text.trim(),
      musicType: _music.text.trim(),
      crowdType: _crowd.text.trim(),
      entryRules: _rules.text.trim(),
      description: _description.text.trim(),
      posterUrl: _posterUrl.text.trim(),
      priceText: _price.text.trim(),
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
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            children: [
              Text(
                _event.id.isEmpty ? 'Add event' : 'Edit event',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _TextField(controller: _title, label: 'Title'),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _event.city,
                      decoration: const InputDecoration(labelText: 'City'),
                      items: const ['Guwahati', 'Delhi']
                          .map(
                            (city) => DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _event = _event.copyWith(
                          city: value ?? _event.city,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _event.isActive,
                      title: const Text('Active'),
                      onChanged: (value) => setState(
                        () => _event = _event.copyWith(isActive: value),
                      ),
                    ),
                  ),
                ],
              ),
              _TextField(controller: _venue, label: 'Venue name'),
              _TextField(controller: _address, label: 'Venue address'),
              VenueLocationPicker(
                event: _event,
                venueName: _venue.text,
                onChanged: (event) => setState(() => _event = event),
                onAddressResolved: (address) {
                  if (address.trim().isNotEmpty) _address.text = address;
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
              _TextField(controller: _music, label: 'Music type'),
              _TextField(controller: _crowd, label: 'Crowd type'),
              _TextField(controller: _rules, label: 'Entry rules'),
              _TextField(controller: _price, label: 'Price text'),
              _TextField(
                controller: _description,
                label: 'Description',
                maxLines: 4,
              ),
              Row(
                children: [
                  Expanded(
                    child: _TextField(
                      controller: _posterUrl,
                      label: 'Poster URL',
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _pickPoster,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: const Text('Upload'),
                  ),
                ],
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
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (label == 'Poster URL') return null;
          if (value == null || value.trim().isEmpty)
            return '$label is required';
          return null;
        },
      ),
    );
  }
}

class _UsersAdmin extends StatelessWidget {
  const _UsersAdmin();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: FirestoreService.instance.usersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading users');
        }
        if (snapshot.hasError)
          return ErrorStateView(message: snapshot.error.toString());
        final users = snapshot.data ?? [];
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              child: ListTile(
                title: Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${user.email} - ${user.phone}'),
                trailing: Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(label: Text(Formatters.titleCase(user.status))),
                    DropdownButton<String>(
                      value: user.role,
                      items: AppConstants.roles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                      onChanged: (role) {
                        if (role != null) {
                          FirestoreService.instance.updateUserRole(user, role);
                        }
                      },
                    ),
                    Switch(
                      value: user.isActive,
                      onChanged: (value) => FirestoreService.instance
                          .setUserActive(user.uid, value),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ClubsAdmin extends StatelessWidget {
  const _ClubsAdmin();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Club>>(
      stream: FirestoreService.instance.clubsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading clubs');
        }
        if (snapshot.hasError)
          return ErrorStateView(message: snapshot.error.toString());
        final clubs = snapshot.data ?? [];
        if (clubs.isEmpty) {
          return const EmptyView(
            title: 'No clubs yet',
            message: 'Club onboarding submissions will appear here.',
            icon: Icons.storefront_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: clubs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final club = clubs[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.storefront, color: AppTheme.neonCyan),
                title: Text(
                  club.clubName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${club.city} - ${club.businessEmail} - ${club.address}',
                ),
                trailing: Chip(
                  label: Text(Formatters.titleCase(club.verificationStatus)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PromotersAdmin extends StatelessWidget {
  const _PromotersAdmin();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Promoter>>(
      stream: FirestoreService.instance.promotersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading promoters');
        }
        if (snapshot.hasError)
          return ErrorStateView(message: snapshot.error.toString());
        final promoters = snapshot.data ?? [];
        if (promoters.isEmpty) {
          return const EmptyView(
            title: 'No promoters yet',
            message:
                'Change a user role to promoter to create a referral profile.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: promoters.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final promoter = promoters[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.campaign, color: AppTheme.neonCyan),
                title: Text(
                  promoter.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${promoter.referralCode} - ${promoter.email}'),
                trailing: Text(
                  '${promoter.totalRsvps} RSVPs',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RsvpsAdmin extends StatelessWidget {
  const _RsvpsAdmin();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Rsvp>>(
      stream: FirestoreService.instance.allRsvpsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading RSVPs');
        }
        if (snapshot.hasError)
          return ErrorStateView(message: snapshot.error.toString());
        final rsvps = snapshot.data ?? [];
        if (rsvps.isEmpty) {
          return const EmptyView(
            title: 'No RSVPs yet',
            message: 'RSVPs will appear here once users start booking.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
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
                  '${rsvp.userName} - ${rsvp.userPhone} - ${rsvp.promoterCode ?? 'Direct'}',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(label: Text(Formatters.titleCase(rsvp.status))),
                    IconButton(
                      tooltip: 'Approve',
                      onPressed: () => FirestoreService.instance
                          .updateRsvpStatus(rsvp.id, 'approved'),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.neonLime,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reject',
                      onPressed: () => FirestoreService.instance
                          .updateRsvpStatus(rsvp.id, 'rejected'),
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: AppTheme.neonPink,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

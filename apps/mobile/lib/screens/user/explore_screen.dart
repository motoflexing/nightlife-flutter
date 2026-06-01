import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/app_preferences_service.dart';
import '../../services/event_discovery_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/compact_ui.dart';
import '../../widgets/event_card.dart';
import '../../widgets/state_views.dart';
import 'event_details_screen.dart';

enum _ExploreShortcut {
  clubCollections('Club Collections', Icons.storefront_outlined),
  guestlistDeals('Guestlist Deals', Icons.confirmation_number_outlined),
  lateNight('Late Night', Icons.dark_mode_outlined);

  const _ExploreShortcut(this.label, this.icon);

  final String label;
  final IconData icon;
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _city = 'All';
  String? _genre;
  _ExploreShortcut? _shortcut;

  static const _genres = [
    'Techno',
    'Bollywood',
    'House',
    'Hip-Hop',
    'Live Music',
    'Psytrance',
  ];

  @override
  void initState() {
    super.initState();
    _loadCity();
  }

  Future<void> _loadCity() async {
    final city = await AppPreferencesService.instance.loadSelectedCity();
    if (!mounted || !AppConstants.cities.contains(city)) return;
    setState(() => _city = city);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NightlifeEvent>>(
      stream: FirestoreService.instance.activeEventsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Opening discovery');
        }
        if (snapshot.hasError) {
          return ErrorStateView(message: snapshot.error.toString());
        }

        final allEvents = snapshot.data ?? [];
        final cityEvents = _city == 'All'
            ? allEvents
            : allEvents.where((event) => event.city == _city).toList();
        final filteredEvents = EventDiscoveryService.instance.filterEvents(
          events: cityEvents,
          category: _genre,
        );
        final events = _filterByShortcut(filteredEvents);

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: compactScreenPadding(context, bottom: 28),
          children: [
            _ExploreHeader(count: events.length),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: AppConstants.cities
                  .map(
                    (city) => DropdownMenuItem(value: city, child: Text(city)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _city = value);
                AppPreferencesService.instance.saveSelectedCity(value);
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _genres.map((genre) {
                return FilterChip(
                  selected: _genre == genre,
                  label: Text(genre),
                  onSelected: (_) => setState(() {
                    _genre = _genre == genre ? null : genre;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _CollectionsStrip(
              selectedShortcut: _shortcut,
              onShortcutTap: _toggleShortcut,
            ),
            const SizedBox(height: 14),
            Text(
              'All Events',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (events.isEmpty)
              const EmptyView(
                title: 'No events in this filter',
                message: 'Try another city or music vibe.',
                icon: Icons.explore_off_outlined,
              )
            else
              ...events.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EventCard(
                    event: event,
                    compact: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EventDetailsScreen(
                          event: event,
                          currentUser: widget.currentUser,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _toggleShortcut(_ExploreShortcut shortcut) {
    setState(() {
      _shortcut = _shortcut == shortcut ? null : shortcut;
    });
  }

  List<NightlifeEvent> _filterByShortcut(List<NightlifeEvent> events) {
    final shortcut = _shortcut;
    if (shortcut == null) return events;

    return events.where((event) {
      final searchable = [
        event.title,
        event.venueName,
        event.address,
        event.city,
        event.musicType,
        event.crowdType,
        event.entryRules,
        event.description,
        event.priceText,
      ].join(' ').toLowerCase();

      return switch (shortcut) {
        _ExploreShortcut.clubCollections =>
          event.venueName.trim().isNotEmpty ||
              searchable.contains('club') ||
              searchable.contains('venue'),
        _ExploreShortcut.guestlistDeals =>
          searchable.contains('guestlist') ||
              searchable.contains('guest list') ||
              searchable.contains('guest') ||
              searchable.contains('free') ||
              searchable.contains('rsvp'),
        _ExploreShortcut.lateNight =>
          event.dateTime.hour >= 22 ||
              event.dateTime.hour < 4 ||
              searchable.contains('late night') ||
              searchable.contains('after hours'),
      };
    }).toList();
  }
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.glassSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppTheme.premiumGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.explore_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore Events',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  '$count nights matching your filters',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionsStrip extends StatelessWidget {
  const _CollectionsStrip({
    required this.selectedShortcut,
    required this.onShortcutTap,
  });

  final _ExploreShortcut? selectedShortcut;
  final ValueChanged<_ExploreShortcut> onShortcutTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _ExploreShortcut.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final shortcut = _ExploreShortcut.values[index];
          final selected = selectedShortcut == shortcut;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onShortcutTap(shortcut),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.accentPink.withValues(alpha: 0.16)
                      : AppTheme.elevated.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? AppTheme.accentPink.withValues(alpha: 0.72)
                        : AppTheme.glassBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(shortcut.icon, color: AppTheme.accentPink),
                    const Spacer(),
                    Text(
                      shortcut.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
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

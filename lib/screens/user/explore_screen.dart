import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/app_preferences_service.dart';
import '../../services/event_discovery_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/event_card.dart';
import '../../widgets/state_views.dart';
import 'event_details_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _city = 'All';
  String? _genre;

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
        final events = EventDiscoveryService.instance.filterEvents(
          events: cityEvents,
          category: _genre,
        );

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            _ExploreHeader(count: events.length),
            const SizedBox(height: 14),
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
            const SizedBox(height: 14),
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
            const SizedBox(height: 18),
            const _CollectionsStrip(),
            const SizedBox(height: 20),
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
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glassSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
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
  const _CollectionsStrip();

  @override
  Widget build(BuildContext context) {
    const collections = [
      ('Club Collections', Icons.storefront_outlined),
      ('Guestlist Deals', Icons.confirmation_number_outlined),
      ('Late Night', Icons.dark_mode_outlined),
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: collections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = collections[index];
          return Container(
            width: 156,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.elevated.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.$2, color: AppTheme.accentPink),
                const Spacer(),
                Text(
                  item.$1,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

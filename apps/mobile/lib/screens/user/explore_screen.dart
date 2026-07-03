import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/app_preferences_service.dart';
import '../../services/event_discovery_service.dart';
import '../../services/explore_filter_request.dart';
import '../../services/firestore_service.dart';
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
    _applyPendingFilter();
    // A saved collection can be opened while Explore is already alive (the
    // shell keeps primary panels mounted), so also react to later requests.
    ExploreFilterRequest.instance.pending.addListener(_applyPendingFilter);
  }

  @override
  void dispose() {
    ExploreFilterRequest.instance.pending.removeListener(_applyPendingFilter);
    super.dispose();
  }

  Future<void> _loadCity() async {
    final city = await AppPreferencesService.instance.loadSelectedCity();
    if (!mounted || !AppConstants.cities.contains(city)) return;
    setState(() => _city = city);
  }

  void _applyPendingFilter() {
    final filter = ExploreFilterRequest.instance.take();
    if (filter == null) return;
    final genre = filter.genre != null && _genres.contains(filter.genre)
        ? filter.genre
        : null;
    final shortcut = _shortcutFromName(filter.shortcut);
    if (!mounted) {
      _genre = genre;
      _shortcut = shortcut;
      return;
    }
    setState(() {
      _genre = genre;
      _shortcut = shortcut;
    });
  }

  _ExploreShortcut? _shortcutFromName(String? name) {
    if (name == null) return null;
    for (final shortcut in _ExploreShortcut.values) {
      if (shortcut.name == name) return shortcut;
    }
    return null;
  }

  String? _activeCollectionLabel() {
    if (_shortcut != null) return _shortcut!.label;
    if (_genre != null) return _genre;
    return null;
  }

  Future<void> _saveCurrentCollection() async {
    final shortcut = _shortcut;
    final genre = _genre;
    final String id;
    final String label;
    if (shortcut != null) {
      id = 'shortcut_${shortcut.name}';
      label = shortcut.label;
    } else if (genre != null) {
      id = 'genre_${genre.toLowerCase()}';
      label = genre;
    } else {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirestoreService.instance.saveCollection(
        collectionId: id,
        label: label,
        genre: genre,
        shortcut: shortcut?.name,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved "$label" to your collections.'),
          duration: const Duration(milliseconds: 1400),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save collection. Please try again.'),
          duration: Duration(milliseconds: 1600),
        ),
      );
    }
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
          return ErrorStateView(
            message: ErrorStateView.sanitizeError(snapshot.error),
          );
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
        final activeCollection = _activeCollectionLabel();

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            // Playfair screen title.
            Text(
              'Explore',
              style: AppTypography.displayMedium.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 28),

            // ── City (pill row, backed by AppConstants.cities) ─────────────
            const _FilterGroupLabel('City'),
            _CityChips(
              selected: _city,
              onSelected: (value) {
                setState(() => _city = value);
                AppPreferencesService.instance.saveSelectedCity(value);
              },
            ),
            const SizedBox(height: 26),

            // ── Music (gold pills → filterEvents category) ─────────────────
            const _FilterGroupLabel('Music'),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: _genres.map((genre) {
                return _GoldPillChip(
                  label: genre,
                  selected: _genre == genre,
                  onTap: () => setState(() {
                    _genre = _genre == genre ? null : genre;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 26),

            // ── Collections (shortcut filters) ─────────────────────────────
            const _FilterGroupLabel('Collections'),
            _CollectionsStrip(
              selectedShortcut: _shortcut,
              onShortcutTap: _toggleShortcut,
            ),

            // Save the active filter as a Collection (real saveCollection path).
            if (activeCollection != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _saveCurrentCollection,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text('Save "$activeCollection"'.toUpperCase()),
                ),
              ),
            ],
            const SizedBox(height: 28),

            // ── Results ────────────────────────────────────────────────────
            _SectionEyebrow('${events.length} Nights'),
            if (events.isEmpty)
              const EmptyView(
                title: 'Nothing yet',
                message: 'Try another city or sound. The night is young.',
                icon: Icons.explore_off_outlined,
              )
            else
              ...events.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
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

// ─── Filter group label (tracked uppercase eyebrow) ────────────────────────────

class _FilterGroupLabel extends StatelessWidget {
  const _FilterGroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          fontSize: 10,
          letterSpacing: 0.26 * 10,
          color: AppColors.textCaption,
        ),
      ),
    );
  }
}

// ─── Section eyebrow (label + trailing gold hairline) ──────────────────────────

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.champagne,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.champagne.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gold pill chip (champagne-fill selected / gold-outline unselected) ────────

class _GoldPillChip extends StatelessWidget {
  const _GoldPillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.champagne : Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        splashColor: AppColors.goldWash,
        highlightColor: AppColors.goldWash,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? AppColors.champagne : AppColors.textDisabled,
              width: 1,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              fontSize: 10,
              letterSpacing: 0.12 * 10,
              color: selected ? AppColors.obsidian : AppColors.textBody,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── City chips (real cities from AppConstants) ────────────────────────────────

class _CityChips extends StatelessWidget {
  const _CityChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: AppConstants.cities.map((city) {
        return _GoldPillChip(
          label: city,
          selected: selected == city,
          onTap: () => onSelected(city),
        );
      }).toList(),
    );
  }
}

// ─── Collections strip (shortcut filters, unchanged logic) ─────────────────────

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
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _ExploreShortcut.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final shortcut = _ExploreShortcut.values[index];
          final selected = selectedShortcut == shortcut;
          return Material(
            color: selected ? AppColors.goldWash : AppColors.surfaceEspresso,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              splashColor: AppColors.goldWash,
              highlightColor: AppColors.goldWash,
              onTap: () => onShortcutTap(shortcut),
              child: Container(
                width: 150,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: selected
                        ? AppColors.champagne
                        : AppColors.goldBorder,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      shortcut.icon,
                      size: 22,
                      color: selected
                          ? AppColors.champagne
                          : AppColors.textSecondary,
                    ),
                    const Spacer(),
                    Text(
                      shortcut.label,
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 14,
                        color: selected
                            ? AppColors.champagne
                            : AppColors.textHigh,
                      ),
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

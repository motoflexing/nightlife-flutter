import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/app_preferences_service.dart';
import '../../services/event_discovery_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/event_card.dart';
import '../../widgets/event_poster.dart';
import '../../widgets/location_permission_flow.dart';
import '../../widgets/premium_loader.dart';
import '../../widgets/state_views.dart';
import 'event_details_screen.dart';

enum _DiscoveryFilter {
  all('All'),
  tonight('Tonight'),
  nearby('Nearby'),
  freeEntry('Free Entry'),
  paid('Paid'),
  guestlist('Guestlist'),
  dj('DJ Night'),
  featured('Featured'),
  techno('Techno'),
  house('House');

  const _DiscoveryFilter(this.label);

  final String label;
}

enum _DateFilterOption {
  allDates('All Dates'),
  tomorrow('Tomorrow'),
  thisWeekend('This Weekend'),
  manualDate('Manual Date Selection');

  const _DateFilterOption(this.label);

  final String label;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final List<NightlifeEvent> _events = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  String _city = 'All';
  DateTime? _selectedDate;
  _DateFilterOption _dateFilter = _DateFilterOption.allDates;
  _DiscoveryFilter _filter = _DiscoveryFilter.all;

  bool _loading = true;
  bool _loadingMore = false;
  bool _loadingNearby = false;
  bool _hasMore = true;
  bool _nearbyEnabled = false;

  double? _userLatitude;
  double? _userLongitude;
  String? _userCity;
  String? _locationMessage;
  String? _error;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _initializeFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeFeed() async {
    await _restoreSelectedCity();
    if (!mounted) return;
    await _loadFirstPage();
  }

  Future<void> _restoreSelectedCity() async {
    final city = await AppPreferencesService.instance.loadSelectedCity();
    if (!mounted || !AppConstants.cities.contains(city)) return;
    setState(() => _city = city);
  }

  Future<void> _loadFirstPage() async {
    final requestId = ++_loadRequestId;
    setState(() {
      _loading = true;
      _error = null;
      _events.clear();
      _lastDocument = null;
      _hasMore = true;
      if (_filter == _DiscoveryFilter.nearby && !_nearbyEnabled) {
        _filter = _DiscoveryFilter.all;
      }
    });
    await _loadPage(isFirstPage: true, requestId: requestId);
  }

  Future<void> _loadPage({bool isFirstPage = false, int? requestId}) async {
    if (!_hasMore && !isFirstPage) return;
    final activeRequestId = requestId ?? _loadRequestId;
    if (!isFirstPage) setState(() => _loadingMore = true);

    try {
      final page = await FirestoreService.instance.fetchEvents(
        city: _city,
        startAfter: isFirstPage ? null : _lastDocument,
      );
      if (!mounted || activeRequestId != _loadRequestId) return;

      setState(() {
        if (isFirstPage) {
          _events
            ..clear()
            ..addAll(_uniqueEvents(page.events));
        } else {
          _events
            ..clear()
            ..addAll(_uniqueEvents([..._events, ...page.events]));
        }
        if (_nearbyEnabled) _sortEventsByDistance();
        _lastDocument = page.lastDocument;
        _hasMore = page.lastDocument != null;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || activeRequestId != _loadRequestId) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _activateNearby() async {
    if (_loadingNearby) return;

    setState(() {
      _filter = _DiscoveryFilter.nearby;
      _loadingNearby = true;
      _error = null;
      _locationMessage = 'Finding parties closest to you...';
    });

    // Show the in-app location disclosure BEFORE the OS prompt (Google Play
    // foreground-location requirement). Already-granted users skip the dialog.
    final permissionResult = await ensureLocationPermissionWithRationale(
      context,
    );
    if (permissionResult != LocationRationaleResult.granted) {
      if (!mounted) return;
      final message = permissionResult == LocationRationaleResult.declined
          ? 'Location access is needed to show parties near you.'
          : 'Location permission was denied.';
      setState(() {
        _nearbyEnabled = false;
        _loadingNearby = false;
        _userLatitude = null;
        _userLongitude = null;
        _locationMessage = message;
      });
      _showLocationMessage(message);
      return;
    }

    // STAGE 1 - location only (must stand on its own).
    UserLocationSnapshot snapshot;
    try {
      snapshot = await LocationService.instance.getUserLocationSnapshot();
    } on LocationServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _nearbyEnabled = false;
        _loadingNearby = false;
        _userLatitude = null;
        _userLongitude = null;
        _locationMessage = error.message;
      });
      _showLocationMessage(error.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nearbyEnabled = false;
        _loadingNearby = false;
        _userLatitude = null;
        _userLongitude = null;
        _locationMessage = 'Location is unavailable right now.';
      });
      _showLocationMessage('Location is unavailable right now.');
      return;
    }

    // STAGE 2 - Firestore write (best-effort, must NOT fail Nearby).
    try {
      await FirestoreService.instance.updateUserLastKnownLocation(
        userId: widget.currentUser.uid,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        city: snapshot.city,
        fullAddress: snapshot.fullAddress,
      );
    } catch (_) {
      // Best-effort: a failed location write must not block Nearby.
    }

    // STAGE 3 - fetch events (its own error, never "location unavailable").
    PagedEvents page;
    try {
      page = await FirestoreService.instance.fetchEvents(city: 'All');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _nearbyEnabled = true;
        _loadingNearby = false;
        _userLatitude = snapshot.latitude;
        _userLongitude = snapshot.longitude;
        _userCity = snapshot.city.isEmpty ? null : snapshot.city;
        _error = error.toString();
        _loading = false;
      });
      _showLocationMessage('Could not load events. Pull to refresh.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _nearbyEnabled = true;
      _loadingNearby = false;
      _userLatitude = snapshot.latitude;
      _userLongitude = snapshot.longitude;
      _userCity = snapshot.city.isEmpty ? null : snapshot.city;
      _locationMessage = snapshot.fullAddress.isEmpty
          ? 'Sorted from your current GPS location'
          : 'Sorted from your current location';
      _events
        ..clear()
        ..addAll(_uniqueEvents(page.events));
      _lastDocument = page.lastDocument;
      _hasMore = page.lastDocument != null;
      _loading = false;
      _sortEventsByDistance();
    });
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onScroll() {
    if (_loadingMore ||
        _loading ||
        _loadingNearby ||
        !_hasMore ||
        _filter == _DiscoveryFilter.nearby) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 360) {
      _loadPage();
    }
  }

  List<NightlifeEvent> _uniqueEvents(Iterable<NightlifeEvent> events) {
    return EventDiscoveryService.instance.uniqueEvents(events);
  }

  double? _distanceFor(NightlifeEvent event) {
    if (!_nearbyEnabled) return null;
    final userLatitude = _userLatitude;
    final userLongitude = _userLongitude;
    final eventLatitude = event.latitude;
    final eventLongitude = event.longitude;
    if (userLatitude == null ||
        userLongitude == null ||
        eventLatitude == null ||
        eventLongitude == null) {
      return null;
    }

    return LocationService.instance.distanceInKm(
      fromLatitude: userLatitude,
      fromLongitude: userLongitude,
      toLatitude: eventLatitude,
      toLongitude: eventLongitude,
    );
  }

  void _sortEventsByDistance() {
    if (!_nearbyEnabled) return;
    _events.sort((a, b) {
      final distanceA = _distanceFor(a);
      final distanceB = _distanceFor(b);
      if (distanceA == null && distanceB == null) {
        return a.dateTime.compareTo(b.dateTime);
      }
      if (distanceA == null) return 1;
      if (distanceB == null) return -1;
      return distanceA.compareTo(distanceB);
    });
  }

  List<NightlifeEvent> get _visibleEvents {
    final filtered = _uniqueEvents(_events).where((event) {
      if (_filter != _DiscoveryFilter.nearby &&
          _city != 'All' &&
          event.city != _city) {
        return false;
      }
      if (!_matchesDate(event)) return false;
      return _matchesDiscoveryFilter(event);
    }).toList();

    filtered.sort((a, b) {
      if (_filter == _DiscoveryFilter.nearby) {
        final distanceA = _distanceFor(a);
        final distanceB = _distanceFor(b);
        if (distanceA == null && distanceB == null) {
          return a.dateTime.compareTo(b.dateTime);
        }
        if (distanceA == null) return 1;
        if (distanceB == null) return -1;
        return distanceA.compareTo(distanceB);
      }
      return a.dateTime.compareTo(b.dateTime);
    });

    return filtered;
  }

  bool _matchesDate(NightlifeEvent event) {
    final now = DateTime.now();
    return switch (_dateFilter) {
      _DateFilterOption.allDates => true,
      _DateFilterOption.tomorrow => _sameDay(
        event.dateTime,
        now.add(const Duration(days: 1)),
      ),
      _DateFilterOption.thisWeekend => _isInThisWeekend(event.dateTime, now),
      _DateFilterOption.manualDate =>
        _selectedDate == null ? true : _sameDay(event.dateTime, _selectedDate!),
    };
  }

  bool _matchesDiscoveryFilter(NightlifeEvent event) {
    final haystack =
        '${event.title} ${event.musicType} ${event.description} ${event.entryRules}'
            .toLowerCase();
    final price = event.priceText.toLowerCase();
    final free =
        price.isEmpty ||
        price.contains('free') ||
        price.contains('guest') ||
        price == '0' ||
        price.contains('rs 0') ||
        price.contains('inr 0');

    return switch (_filter) {
      _DiscoveryFilter.all => true,
      _DiscoveryFilter.tonight => _sameDay(event.dateTime, DateTime.now()),
      _DiscoveryFilter.nearby => _nearbyEnabled && _distanceFor(event) != null,
      _DiscoveryFilter.freeEntry => free,
      _DiscoveryFilter.paid => !free,
      _DiscoveryFilter.guestlist => price.contains('guest'),
      _DiscoveryFilter.dj => haystack.contains('dj'),
      _DiscoveryFilter.featured =>
        haystack.contains('featured') ||
            haystack.contains('popular') ||
            haystack.contains('trending'),
      _DiscoveryFilter.techno => haystack.contains('techno'),
      _DiscoveryFilter.house => haystack.contains('house'),
    };
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInThisWeekend(DateTime eventDate, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final daysUntilSaturday = DateTime.saturday - today.weekday;

    final start = today.weekday == DateTime.sunday
        ? today
        : today.add(
            Duration(days: daysUntilSaturday < 0 ? 0 : daysUntilSaturday),
          );
    final end = today.weekday == DateTime.sunday
        ? today
        : start.add(const Duration(days: 1));

    return !eventDay.isBefore(start) && !eventDay.isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
    final visibleEvents = _visibleEvents;
    final cityLabel =
        _filter == _DiscoveryFilter.nearby && (_userCity?.isNotEmpty ?? false)
        ? _userCity!
        : _city;

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      color: AppColors.champagne,
      backgroundColor: AppColors.surfaceEspresso,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _HomeTopBar(
              city: cityLabel,
              selectedCity: _city,
              dateLabel: _dateLabel(),
              onCityChanged: _changeCity,
              onDateSelected: _selectDateFilter,
            ),
          ),
          SliverToBoxAdapter(
            child: _DiscoveryControls(
              title: _sectionTitle(visibleEvents.length),
              subtitle: _sectionSubtitle(visibleEvents.length),
              selectedFilter: _filter,
              loadingNearby: _loadingNearby,
              onFilterSelected: _selectFilter,
            ),
          ),
          if (_loading || _loadingNearby)
            const SliverToBoxAdapter(child: _LoadingFeedSkeleton())
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorStateView(message: _error!, onRetry: _loadFirstPage),
            )
          else
            SliverToBoxAdapter(
              child: _EventsContent(
                events: visibleEvents,
                loadingMore: _loadingMore,
                nearbyEnabled: _filter == _DiscoveryFilter.nearby,
                distanceFor: _distanceFor,
                onOpen: (event) => _openEvent(context, event),
              ),
            ),
        ],
      ),
    );
  }

  void _changeCity(String value) {
    setState(() {
      _city = value;
      if (_filter == _DiscoveryFilter.nearby) {
        _filter = _DiscoveryFilter.all;
      }
    });
    AppPreferencesService.instance.saveSelectedCity(value);
    _loadFirstPage();
  }

  void _selectFilter(_DiscoveryFilter filter) {
    if (filter == _DiscoveryFilter.nearby) {
      _activateNearby();
      return;
    }
    // The chip filter and the date selector are independent. "Tonight" already
    // filters to today's events on its own (see _matchesDiscoveryFilter), so it
    // must NOT touch _selectedDate / _dateFilter. Previously it forced the date
    // selector to "Today" and never reset it, leaving the date stuck on Today
    // after switching to another chip (a hidden, contradictory date filter).
    setState(() {
      _filter = filter;
    });
  }

  String _sectionTitle(int count) {
    if (_filter == _DiscoveryFilter.nearby) return '$count Nearby Events';
    if (_filter == _DiscoveryFilter.tonight ||
        (_dateFilter == _DateFilterOption.manualDate &&
            _selectedDate != null &&
            _sameDay(_selectedDate!, DateTime.now()))) {
      return "$count Tonight's Events";
    }
    return '$count Events Found';
  }

  String _sectionSubtitle(int count) {
    if (_filter == _DiscoveryFilter.nearby) {
      final locationMessage = _locationMessage?.trim();
      if (locationMessage != null && locationMessage.isNotEmpty) {
        return locationMessage;
      }
      return _nearbyEnabled
          ? '$count nights sorted by distance'
          : 'Tap Nearby to enable location';
    }
    final city = _city == 'All' ? 'all cities' : _city;
    return count == 1
        ? '1 curated night in $city'
        : '$count curated nights in $city';
  }

  Future<void> _selectDateFilter(_DateFilterOption option) async {
    if (option == _DateFilterOption.manualDate) {
      await _pickDate();
      return;
    }

    setState(() {
      _dateFilter = option;
      if (option == _DateFilterOption.allDates) {
        _selectedDate = null;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: 'Select event date',
      cancelText: 'Cancel',
      confirmText: 'Apply',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _dateFilter = _DateFilterOption.manualDate;
    });
  }

  String _dateLabel() {
    if (_dateFilter == _DateFilterOption.allDates) return 'All Dates';
    if (_dateFilter == _DateFilterOption.tomorrow) return 'Tomorrow';
    if (_dateFilter == _DateFilterOption.thisWeekend) return 'This Weekend';

    final date = _selectedDate;
    if (date == null) return 'Manual Date';
    final now = DateTime.now();
    if (_sameDay(date, now)) return 'Today';
    if (_sameDay(date, now.add(const Duration(days: 1)))) return 'Tomorrow';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = date.day.toString().padLeft(2, '0');
    return '$day ${months[date.month - 1]}';
  }

  void _openEvent(BuildContext context, NightlifeEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EventDetailsScreen(event: event, currentUser: widget.currentUser),
      ),
    );
  }

}

// ─── Home header (design: "Tonight in" eyebrow → city + chevron, actions) ──────

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.city,
    required this.selectedCity,
    required this.dateLabel,
    required this.onCityChanged,
    required this.onDateSelected,
  });

  final String city;
  final String selectedCity;
  final String dateLabel;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<_DateFilterOption> onDateSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tracked eyebrow.
                Text(
                  'Tonight in'.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 9,
                    letterSpacing: 0.3 * 9,
                    color: AppColors.textCaption,
                  ),
                ),
                const SizedBox(height: 4),
                // City selector — Playfair city name + chevron (design header).
                _CityMenu(
                  selectedCity: selectedCity,
                  cityLabel: city,
                  onCityChanged: onCityChanged,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Date filter lives here as a thin-line action (keeps existing flow).
          _DatePickerButton(
            tooltip: 'Select date',
            icon: Icons.calendar_today_outlined,
            label: dateLabel,
            onSelected: onDateSelected,
          ),
        ],
      ),
    );
  }
}

/// City picker rendered as the design's Playfair city name + gold chevron.
class _CityMenu extends StatelessWidget {
  const _CityMenu({
    required this.selectedCity,
    required this.cityLabel,
    required this.onCityChanged,
  });

  final String selectedCity;
  final String cityLabel;
  final ValueChanged<String> onCityChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Select city',
      onSelected: onCityChanged,
      color: AppColors.surfaceEspresso,
      itemBuilder: (context) => AppConstants.cities
          .map((value) => PopupMenuItem<String>(value: value, child: Text(value)))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              cityLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headlineMedium.copyWith(fontSize: 24),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.expand_more,
            size: 20,
            color: AppColors.champagne,
          ),
        ],
      ),
    );
  }
}

// ─── Featured hero (design: 400px hero — badge, favorite, eyebrow, title) ──────

class _FeaturedHero extends StatelessWidget {
  const _FeaturedHero({required this.event, required this.onOpen});

  final NightlifeEvent event;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final venue = event.venueName.trim().isEmpty ? event.city : event.venueName;
    final location = event.address.trim().isEmpty ? event.city : event.address;
    final eyebrow = _heroEyebrow(event);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 400,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Reuses the Nocturne poster (tint gradient / photo + scrim).
                EventPoster(event: event, borderRadius: 8),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.obsidianDeep],
                      stops: [0.4, 1],
                    ),
                  ),
                ),
                // Featured badge — gold pill (design "✦ Editor's pick" slot; we
                // use the event's own badge label, no invented flag).
                Positioned(
                  top: 16,
                  left: 16,
                  child: _HeroBadge(label: _heroBadgeLabel(event)),
                ),
                const Positioned(
                  top: 16,
                  right: 16,
                  child: Icon(
                    Icons.favorite_border,
                    size: 24,
                    color: AppColors.ivory,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 9,
                            letterSpacing: 0.24 * 9,
                            color: AppColors.champagne,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          event.title.trim().isEmpty
                              ? 'Featured Night'
                              : event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.displayMedium.copyWith(
                            fontSize: 34,
                            height: 1.02,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 15,
                              color: AppColors.textBodyDim,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$venue · $location',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textBodyDim,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tracked eyebrow for the hero — day · doors · genre when available.
  String _heroEyebrow(NightlifeEvent event) {
    final music = event.musicType.trim();
    if (music.isNotEmpty) return music;
    final vibe = event.crowdType.trim();
    if (vibe.isNotEmpty) return vibe;
    return _heroBadgeLabel(event);
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.obsidian.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            fontSize: 9,
            letterSpacing: 0.2 * 9,
            color: AppColors.champagne,
          ),
        ),
      ),
    );
  }
}

// ─── Section header (design: tracked eyebrow + trailing gold hairline) ─────────

class _DiscoveryControls extends StatelessWidget {
  const _DiscoveryControls({
    required this.title,
    required this.subtitle,
    required this.selectedFilter,
    required this.loadingNearby,
    required this.onFilterSelected,
  });

  final String title;
  final String subtitle;
  final _DiscoveryFilter selectedFilter;
  final bool loadingNearby;
  final ValueChanged<_DiscoveryFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tracked uppercase eyebrow + fading gold hairline (design rail label).
          Row(
            children: [
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textHigh,
                    letterSpacing: 0.28 * 14,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(child: _GoldHairline()),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textCaption,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              itemCount: _DiscoveryFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _DiscoveryFilter.values[index];
                return _FilterChipButton(
                  label: filter.label,
                  selected: selectedFilter == filter,
                  loading: loadingNearby && filter == _DiscoveryFilter.nearby,
                  onTap: () => onFilterSelected(filter),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The signature champagne hairline that fades to transparent.
class _GoldHairline extends StatelessWidget {
  const _GoldHairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.champagne.withValues(alpha: 0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ─── Filter chip — pill, gold-selected (design filter chips) ───────────────────

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.champagne : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppColors.champagne : AppColors.textDisabled,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const PremiumLoader.compact(size: 12),
              const SizedBox(width: 7),
            ],
            Text(
              label.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                fontSize: 11,
                letterSpacing: 0.14 * 11,
                color: selected ? AppColors.obsidian : AppColors.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Events content: hero (first) + list, using the Nocturne EventCard ─────────

class _EventsContent extends StatelessWidget {
  const _EventsContent({
    required this.events,
    required this.loadingMore,
    required this.nearbyEnabled,
    required this.distanceFor,
    required this.onOpen,
  });

  final List<NightlifeEvent> events;
  final bool loadingMore;
  final bool nearbyEnabled;
  final double? Function(NightlifeEvent event) distanceFor;
  final ValueChanged<NightlifeEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _InlineEmptyFilterState(
        title: 'Nothing yet',
        message: 'Try changing your filters or city. The night is young.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 980
            ? 3
            : width >= 640
            ? 2
            : 1;
        if (columns == 1) {
          return _VerticalEventsList(
            events: events,
            loadingMore: loadingMore,
            nearbyEnabled: nearbyEnabled,
            distanceFor: distanceFor,
            onOpen: onOpen,
          );
        }

        return _ResponsiveEventsGrid(
          events: events,
          loadingMore: loadingMore,
          columns: columns,
          nearbyEnabled: nearbyEnabled,
          distanceFor: distanceFor,
          onOpen: onOpen,
        );
      },
    );
  }
}

class _VerticalEventsList extends StatelessWidget {
  const _VerticalEventsList({
    required this.events,
    required this.loadingMore,
    required this.nearbyEnabled,
    required this.distanceFor,
    required this.onOpen,
  });

  final List<NightlifeEvent> events;
  final bool loadingMore;
  final bool nearbyEnabled;
  final double? Function(NightlifeEvent event) distanceFor;
  final ValueChanged<NightlifeEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    // The first event gets the design's large featured-hero treatment; the rest
    // render as the standard Nocturne EventCard. Same data, no extra query.
    final hero = events.first;
    final rest = events.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FeaturedHero(event: hero, onOpen: () => onOpen(hero)),
        if (rest.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 6),
            child: Row(
              children: [
                Text(
                  'More Nights'.toUpperCase(),
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textHigh,
                    letterSpacing: 0.28 * 14,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(child: _GoldHairline()),
              ],
            ),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 112),
          itemCount: rest.length + (loadingMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            if (index == rest.length) {
              return const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Center(
                  child: PremiumLoader(message: 'Curating more nights...'),
                ),
              );
            }
            final event = rest[index];
            return EventCard(
              event: event,
              compact: true,
              distanceKm: nearbyEnabled ? distanceFor(event) : null,
              onTap: () => onOpen(event),
              onRsvp: () => onOpen(event),
            );
          },
        ),
      ],
    );
  }
}

class _ResponsiveEventsGrid extends StatelessWidget {
  const _ResponsiveEventsGrid({
    required this.events,
    required this.loadingMore,
    required this.columns,
    required this.nearbyEnabled,
    required this.distanceFor,
    required this.onOpen,
  });

  final List<NightlifeEvent> events;
  final bool loadingMore;
  final int columns;
  final bool nearbyEnabled;
  final double? Function(NightlifeEvent event) distanceFor;
  final ValueChanged<NightlifeEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    final itemCount = events.length + (loadingMore ? 1 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 112),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 214,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        if (index == events.length) {
          return const Center(
            child: PremiumLoader(message: 'Curating more nights...'),
          );
        }
        final event = events[index];
        return EventCard(
          event: event,
          compact: true,
          distanceKm: nearbyEnabled ? distanceFor(event) : null,
          onTap: () => onOpen(event),
          onRsvp: () => onOpen(event),
        );
      },
    );
  }
}

class _LoadingFeedSkeleton extends StatelessWidget {
  const _LoadingFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 6, 24, 112),
      child: Column(
        children: [
          _SkeletonHero(),
          SizedBox(height: 24),
          _SkeletonEventCard(),
          SizedBox(height: 14),
          _SkeletonEventCard(),
        ],
      ),
    );
  }
}

class _SkeletonHero extends StatelessWidget {
  const _SkeletonHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
    );
  }
}

class _SkeletonEventCard extends StatelessWidget {
  const _SkeletonEventCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 164,
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 118,
            decoration: const BoxDecoration(color: AppColors.espresso),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonLine(width: double.infinity, height: 17),
                  const SizedBox(height: 8),
                  const _SkeletonLine(width: 160, height: 11),
                  const SizedBox(height: 7),
                  const _SkeletonLine(width: 130, height: 11),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(child: _SkeletonLine(width: 90, height: 34)),
                      SizedBox(width: 8),
                      Expanded(child: _SkeletonLine(width: 76, height: 34)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.goldWash,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _InlineEmptyFilterState extends StatelessWidget {
  const _InlineEmptyFilterState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 112),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.goldBorder, width: 1),
        ),
        child: Column(
          children: [
            Icon(
              Icons.nightlife,
              color: AppColors.champagne.withValues(alpha: 0.5),
              size: 34,
            ),
            const SizedBox(height: 14),
            // Playfair title + tracked caption (design empty state).
            Text(
              title,
              style: AppTypography.headlineMedium.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textCaption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date filter — thin-line action button (keeps existing selector flow) ──────

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final ValueChanged<_DateFilterOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DateFilterOption>(
      tooltip: tooltip,
      onSelected: onSelected,
      color: AppColors.surfaceEspresso,
      itemBuilder: (context) => _DateFilterOption.values
          .map(
            (option) => PopupMenuItem<_DateFilterOption>(
              value: option,
              child: Text(option.label),
            ),
          )
          .toList(),
      child: Container(
        height: 34,
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.goldBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.champagne),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.14 * 10,
                  color: AppColors.textBody,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

String _heroBadgeLabel(NightlifeEvent event) {
  final now = DateTime.now();
  final tonight =
      event.dateTime.year == now.year &&
      event.dateTime.month == now.month &&
      event.dateTime.day == now.day;
  if (tonight) return 'Tonight';

  final price = event.priceText.trim().toLowerCase();
  final free =
      price.isEmpty ||
      price.contains('free') ||
      price.contains('guest') ||
      price == '0' ||
      price.contains('rs 0') ||
      price.contains('inr 0');
  if (free) return 'Guestlist';
  return 'Trending';
}

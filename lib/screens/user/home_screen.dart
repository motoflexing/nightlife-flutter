import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/event_card.dart';
import '../../widgets/state_views.dart';
import 'event_details_screen.dart';
import 'map_view_screen.dart';

enum _LocationFilter {
  nearby('Nearby'),
  within5('Within 5 km'),
  within10('Within 10 km'),
  sameCity('Same city'),
  trending('Trending nearby');

  const _LocationFilter(this.label);

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
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _nearbyEnabled = false;
  bool _nearbyExpanded = false;
  double? _userLatitude;
  double? _userLongitude;
  String? _userCity;
  String? _locationMessage;
  _LocationFilter _filter = _LocationFilter.nearby;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    _loadFirstPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
      _events.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadPage(isFirstPage: true);
  }

  Future<void> _loadUserLocation() async {
    final permission = await LocationService.instance.requestPermission();
    if (!permission.isGranted) {
      if (!mounted) return;
      setState(() {
        _nearbyEnabled = false;
        _userLatitude = null;
        _userLongitude = null;
        _locationMessage = '${permission.message} Showing city-based events.';
        final fallbackCity = widget.currentUser.lastKnownCity.trim();
        if (fallbackCity.isNotEmpty &&
            AppConstants.cities.contains(fallbackCity)) {
          _city = fallbackCity;
        }
      });
      if (!_loading) _loadFirstPage();
      return;
    }

    try {
      final snapshot = await LocationService.instance.getUserLocationSnapshot();
      await FirestoreService.instance.updateUserLastKnownLocation(
        userId: widget.currentUser.uid,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        city: snapshot.city,
        fullAddress: snapshot.fullAddress,
      );
      if (!mounted) return;
      setState(() {
        _nearbyEnabled = true;
        _userLatitude = snapshot.latitude;
        _userLongitude = snapshot.longitude;
        _userCity = snapshot.city.isEmpty ? null : snapshot.city;
        _locationMessage = snapshot.fullAddress.isEmpty
            ? 'Using your current GPS location'
            : 'Using your current location';
        _sortEventsByDistance();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nearbyEnabled = false;
        _userLatitude = null;
        _userLongitude = null;
        _locationMessage =
            'Location is unavailable right now. Showing city-based events.';
      });
    }
  }

  Future<void> _loadPage({bool isFirstPage = false}) async {
    if (!_hasMore && !isFirstPage) return;
    if (!isFirstPage) setState(() => _loadingMore = true);
    try {
      final page = await FirestoreService.instance.fetchEvents(
        city: _city,
        startAfter: isFirstPage ? null : _lastDocument,
      );
      if (!mounted) return;
      setState(() {
        _events.addAll(page.events);
        _sortEventsByDistance();
        _lastDocument = page.lastDocument;
        _hasMore = page.lastDocument != null;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_loadingMore || _loading || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 360) {
      _loadPage();
    }
  }

  double? _distanceFor(NightlifeEvent event) {
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
    if (_userLatitude == null || _userLongitude == null) return;
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
    final events = List<NightlifeEvent>.of(_events);
    final cityEvents = _city == 'All'
        ? events
        : events.where((event) => event.city == _city).toList();
    return cityEvents..sort((a, b) {
      final cityCompare = a.city.compareTo(b.city);
      if (_city != 'All' && cityCompare != 0) return cityCompare;
      return a.dateTime.compareTo(b.dateTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleEvents = _visibleEvents;
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              currentUser: widget.currentUser,
              city: _userCity,
              nearbyEnabled: _nearbyEnabled,
              locationMessage: _locationMessage,
              onLocate: _loadUserLocation,
              onOpenMap: _eventsWithCoordinates.isEmpty
                  ? null
                  : () => _openMap(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _city,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_on_outlined),
                        labelText: 'City',
                      ),
                      items: AppConstants.cities
                          .map(
                            (city) => DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _city = value);
                        _loadFirstPage();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 17),
                        SizedBox(width: 8),
                        Text(
                          'Today',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: LoadingView(message: 'Finding nights'),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: ErrorStateView(message: _error!, onRetry: _loadFirstPage),
            )
          else
            SliverToBoxAdapter(
              child: _EventsContent(
                events: visibleEvents,
                loadingMore: _loadingMore,
                distanceFor: _distanceFor,
                onOpen: (event) => _openEvent(context, event),
              ),
            ),
          SliverToBoxAdapter(
            child: _NearbyEventsSection(
              loading: _loading,
              events: _nearbySectionEvents,
              expanded: _nearbyExpanded,
              nearbyEnabled: _nearbyEnabled,
              locationMessage: _locationMessage,
              filter: _filter,
              onToggle: () {
                setState(() => _nearbyExpanded = !_nearbyExpanded);
              },
              onFilterChanged: (filter) => setState(() => _filter = filter),
              distanceFor: _distanceFor,
              onOpen: (event) => _openEvent(context, event),
            ),
          ),
        ],
      ),
    );
  }

  List<NightlifeEvent> get _eventsWithCoordinates {
    return _events
        .where((event) => event.latitude != null && event.longitude != null)
        .toList();
  }

  List<NightlifeEvent> get _nearbySectionEvents {
    final events = List<NightlifeEvent>.of(_events);

    bool sameCity(NightlifeEvent event) {
      final userCity = _userCity ?? (_city == 'All' ? '' : _city);
      return userCity.isNotEmpty &&
          event.city.toLowerCase() == userCity.toLowerCase();
    }

    bool within(NightlifeEvent event, double maxKm) {
      final distance = _distanceFor(event);
      return distance != null && distance <= maxKm;
    }

    final filtered = switch (_filter) {
      _LocationFilter.nearby => events.where(
        (event) => _distanceFor(event) != null,
      ),
      _LocationFilter.within5 => events.where((event) => within(event, 5)),
      _LocationFilter.within10 => events.where((event) => within(event, 10)),
      _LocationFilter.sameCity => events.where(sameCity),
      _LocationFilter.trending => events.where(
        (event) => event.isActive && within(event, 10),
      ),
    };

    return filtered.toList()..sort((a, b) {
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

  void _openEvent(BuildContext context, NightlifeEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EventDetailsScreen(event: event, currentUser: widget.currentUser),
      ),
    );
  }

  void _openMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapViewScreen(
          events: _eventsWithCoordinates,
          currentUser: widget.currentUser,
          userLatitude: _userLatitude,
          userLongitude: _userLongitude,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.currentUser,
    required this.city,
    required this.nearbyEnabled,
    required this.locationMessage,
    required this.onLocate,
    required this.onOpenMap,
  });

  final AppUser currentUser;
  final String? city;
  final bool nearbyEnabled;
  final String? locationMessage;
  final VoidCallback onLocate;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tonight, ${currentUser.name.split(' ').first}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find guestlists, secret drops, and ticketed nights near you.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.elevated.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Row(
              children: [
                Icon(
                  nearbyEnabled ? Icons.near_me : Icons.location_searching,
                  color: nearbyEnabled ? AppTheme.neonLime : AppTheme.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city == null || city!.isEmpty
                            ? 'Location-aware feed'
                            : city!,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        locationMessage ??
                            (nearbyEnabled
                                ? 'Using your location'
                                : 'Tap locate to find events near you'),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Locate me',
                  onPressed: onLocate,
                  icon: const Icon(Icons.gps_fixed),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Map view',
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyEventsSection extends StatelessWidget {
  const _NearbyEventsSection({
    required this.loading,
    required this.events,
    required this.expanded,
    required this.nearbyEnabled,
    required this.locationMessage,
    required this.filter,
    required this.onToggle,
    required this.onFilterChanged,
    required this.distanceFor,
    required this.onOpen,
  });

  final bool loading;
  final List<NightlifeEvent> events;
  final bool expanded;
  final bool nearbyEnabled;
  final String? locationMessage;
  final _LocationFilter filter;
  final VoidCallback onToggle;
  final ValueChanged<_LocationFilter> onFilterChanged;
  final double? Function(NightlifeEvent event) distanceFor;
  final ValueChanged<NightlifeEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    final previewEvents = events.take(6).toList();
    final status = nearbyEnabled
        ? 'Sorted from your current location'
        : locationMessage ??
              'Location permission is off. Showing city-based events.';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    nearbyEnabled
                        ? Icons.near_me_outlined
                        : Icons.location_city,
                    color: nearbyEnabled
                        ? AppTheme.neonLime
                        : AppTheme.neonCyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nearby Events',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          expanded ? status : 'Tap to view events near you',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                DropdownButtonFormField<_LocationFilter>(
                  initialValue: filter,
                  decoration: const InputDecoration(
                    labelText: 'Nearby filter',
                    prefixIcon: Icon(Icons.tune),
                  ),
                  items: _LocationFilter.values
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onFilterChanged(value);
                  },
                ),
                const SizedBox(height: 12),
                if (loading)
                  const LinearProgressIndicator(minHeight: 3)
                else if (previewEvents.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.elevated.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: const Text(
                      'No nearby events found. Try increasing the distance range.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final mobile = constraints.maxWidth < 520;
                      if (mobile) {
                        return Column(
                          children: [
                            for (var i = 0; i < previewEvents.length; i++) ...[
                              _NearbyPreviewTile(
                                event: previewEvents[i],
                                distanceKm: distanceFor(previewEvents[i]),
                                onTap: () => onOpen(previewEvents[i]),
                              ),
                              if (i != previewEvents.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Swipe to explore more nearby events',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 118,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: previewEvents.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final event = previewEvents[index];
                                return SizedBox(
                                  width: 250,
                                  child: _NearbyPreviewTile(
                                    event: event,
                                    distanceKm: distanceFor(event),
                                    onTap: () => onOpen(event),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _NearbyPreviewTile extends StatelessWidget {
  const _NearbyPreviewTile({
    required this.event,
    required this.distanceKm,
    required this.onTap,
  });

  final NightlifeEvent event;
  final double? distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLocation = event.latitude != null && event.longitude != null;
    final locationLabel = !hasLocation
        ? 'Location not added'
        : distanceKm == null
        ? event.city
        : LocationService.instance.formatDistance(distanceKm!);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: AppTheme.elevated.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${event.venueName} - ${event.city}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 136),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryViolet.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.neonViolet.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Text(
                    locationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsContent extends StatelessWidget {
  const _EventsContent({
    required this.events,
    required this.loadingMore,
    required this.distanceFor,
    required this.onOpen,
  });

  final List<NightlifeEvent> events;
  final bool loadingMore;
  final double? Function(NightlifeEvent event) distanceFor;
  final ValueChanged<NightlifeEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final hasEvents = events.isNotEmpty;
        final isMobile = width < 600;
        final isTablet = width >= 600 && width < 1024;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasEvents && !isMobile && !isTablet)
              _FeaturedEventsCarousel(
                events: events.take(6).toList(),
                distanceFor: distanceFor,
                onOpen: onOpen,
              ),
            _EventsHeader(
              title: 'Events Around You',
              summary: events.isEmpty
                  ? 'No events match this city yet'
                  : '${events.length} events sorted by city and time',
              eventsLength: events.length,
              topPadding: hasEvents && !isMobile && !isTablet ? 20 : 4,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: hasEvents
                  ? isMobile
                        ? _VerticalEventsList(
                            key: ValueKey(
                              'mobile-events-${events.map((event) => event.id).join('|')}',
                            ),
                            events: events,
                            loadingMore: loadingMore,
                            distanceFor: distanceFor,
                            onOpen: onOpen,
                          )
                        : _ResponsiveEventsGrid(
                            key: ValueKey(
                              'grid-events-${events.map((event) => event.id).join('|')}',
                            ),
                            events: events,
                            loadingMore: loadingMore,
                            columns: isTablet ? 2 : 3,
                            distanceFor: distanceFor,
                            onOpen: onOpen,
                          )
                  : _InlineEmptyFilterState(
                      key: const ValueKey('empty-events'),
                      title: 'No events found',
                      message: 'Try another city or check back soon.',
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FeaturedEventsCarousel extends StatefulWidget {
  const _FeaturedEventsCarousel({
    required this.events,
    required this.distanceFor,
    required this.onOpen,
  });

  final List<NightlifeEvent> events;
  final double? Function(NightlifeEvent event) distanceFor;
  final ValueChanged<NightlifeEvent> onOpen;

  @override
  State<_FeaturedEventsCarousel> createState() =>
      _FeaturedEventsCarouselState();
}

class _FeaturedEventsCarouselState extends State<_FeaturedEventsCarousel> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollBy(double offset) {
    if (!_controller.hasClients) return;
    final next = (_controller.offset + offset).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Featured Nights',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Previous events',
                onPressed: () => _scrollBy(-304),
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Next events',
                onPressed: () => _scrollBy(304),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Swipe to explore more events',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 382,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.events.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final event = widget.events[index];
                return SizedBox(
                  width: 276,
                  child: EventCard(
                    event: event,
                    compact: true,
                    distanceKm: widget.distanceFor(event),
                    onTap: () => widget.onOpen(event),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsHeader extends StatelessWidget {
  const _EventsHeader({
    required this.title,
    required this.summary,
    required this.eventsLength,
    required this.topPadding,
  });

  final String title;
  final String summary;
  final int eventsLength;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              key: ValueKey('event-count-$eventsLength'),
              summary,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalEventsList extends StatelessWidget {
  const _VerticalEventsList({
    super.key,
    required this.events,
    required this.loadingMore,
    required this.distanceFor,
    required this.onOpen,
  });

  final List<NightlifeEvent> events;
  final bool loadingMore;
  final double? Function(NightlifeEvent event) distanceFor;
  final ValueChanged<NightlifeEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      itemCount: events.length + (loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index == events.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final event = events[index];
        return EventCard(
          event: event,
          distanceKm: distanceFor(event),
          onTap: () => onOpen(event),
        );
      },
    );
  }
}

class _ResponsiveEventsGrid extends StatelessWidget {
  const _ResponsiveEventsGrid({
    super.key,
    required this.events,
    required this.loadingMore,
    required this.columns,
    required this.distanceFor,
    required this.onOpen,
  });

  final List<NightlifeEvent> events;
  final bool loadingMore;
  final int columns;
  final double? Function(NightlifeEvent event) distanceFor;
  final ValueChanged<NightlifeEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    final itemCount = events.length + (loadingMore ? 1 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: columns == 2 ? 390 : 382,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        if (index == events.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final event = events[index];
        return EventCard(
          event: event,
          compact: true,
          distanceKm: distanceFor(event),
          onTap: () => onOpen(event),
        );
      },
    );
  }
}

class _InlineEmptyFilterState extends StatelessWidget {
  const _InlineEmptyFilterState({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.elevated.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.glassBorder),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neonCyan.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.search_off_outlined, color: AppTheme.neonCyan),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(color: AppTheme.textMuted, height: 1.35),
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.neonCyan.withValues(alpha: 0.48),
                    AppTheme.neonViolet.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

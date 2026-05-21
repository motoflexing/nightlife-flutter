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
    if (!permission.isGranted) return;

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
        _locationMessage = 'Using your location';
        _sortEventsByDistance();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nearbyEnabled = false;
        _locationMessage = permission.message;
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
    if (!_nearbyEnabled) {
      return events..sort((a, b) {
        final cityCompare = a.city.compareTo(b.city);
        if (_city != 'All' && cityCompare != 0) return cityCompare;
        return a.dateTime.compareTo(b.dateTime);
      });
    }

    bool within(NightlifeEvent event, double maxKm) {
      final distance = _distanceFor(event);
      return distance != null && distance <= maxKm;
    }

    final filtered = switch (_filter) {
      _LocationFilter.within5 => events.where((event) => within(event, 5)),
      _LocationFilter.within10 => events.where((event) => within(event, 10)),
      _LocationFilter.sameCity => events.where(
        (event) =>
            _userCity == null ||
            event.city.toLowerCase() == _userCity!.toLowerCase(),
      ),
      _LocationFilter.trending => events.where(
        (event) => within(event, 10) && event.isActive,
      ),
      _LocationFilter.nearby => events,
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
          const SliverToBoxAdapter(child: _PromoBanner()),
          if (_loading)
            const SliverFillRemaining(
              child: LoadingView(message: 'Finding nights'),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: ErrorStateView(message: _error!, onRetry: _loadFirstPage),
            )
          else if (visibleEvents.isEmpty)
            const SliverFillRemaining(
              child: EmptyView(
                title: 'No nearby events',
                message: 'Try a wider distance filter or switch city filters.',
              ),
            )
          else
            SliverToBoxAdapter(
              child: _EventsContent(
                events: visibleEvents,
                loadingMore: _loadingMore,
                nearbyEnabled: _nearbyEnabled,
                filter: _filter,
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

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.premiumGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPink.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'Access Hidden Parties & Exclusive Deals',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
          ),
          Icon(Icons.local_fire_department, size: 34),
        ],
      ),
    );
  }
}

class _EventsContent extends StatelessWidget {
  const _EventsContent({
    required this.events,
    required this.loadingMore,
    required this.nearbyEnabled,
    required this.filter,
    required this.onFilterChanged,
    required this.distanceFor,
    required this.onOpen,
  });

  final List<NightlifeEvent> events;
  final bool loadingMore;
  final bool nearbyEnabled;
  final _LocationFilter filter;
  final ValueChanged<_LocationFilter> onFilterChanged;
  final double? Function(NightlifeEvent event) distanceFor;
  final ValueChanged<NightlifeEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    final featured = events.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 420,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: featured.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final event = featured[index];
              return SizedBox(
                width: 230,
                child: EventCard(
                  event: event,
                  compact: true,
                  distanceKm: distanceFor(event),
                  onTap: () => onOpen(event),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nearbyEnabled ? 'Near You' : 'Events Around You',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                nearbyEnabled
                    ? '${events.length} events sorted by distance'
                    : '${events.length} events sorted by city and time',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final option in _LocationFilter.values) ...[
                      ChoiceChip(
                        label: Text(option.label),
                        selected: filter == option,
                        onSelected:
                            nearbyEnabled || option == _LocationFilter.sameCity
                            ? (_) => onFilterChanged(option)
                            : null,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: events.length + (loadingMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            if (index == events.length) {
              return const Center(child: CircularProgressIndicator());
            }
            final event = events[index];
            return EventCard(
              event: event,
              distanceKm: distanceFor(event),
              onTap: () => onOpen(event),
            );
          },
        ),
      ],
    );
  }
}

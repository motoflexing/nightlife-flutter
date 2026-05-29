import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/app_preferences_service.dart';
import '../../services/event_discovery_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/event_card.dart';
import '../../widgets/event_poster.dart';
import '../../widgets/premium_loader.dart';
import '../../widgets/state_views.dart';
import 'event_details_screen.dart';
import 'nightlife_pass_screen.dart';

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

    final permission = await LocationService.instance.requestPermission();
    if (!permission.isGranted) {
      if (!mounted) return;
      setState(() {
        _nearbyEnabled = false;
        _loadingNearby = false;
        _userLatitude = null;
        _userLongitude = null;
        _locationMessage = permission.message;
      });
      _showLocationMessage(permission.message);
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

      final page = await FirestoreService.instance.fetchEvents(city: 'All');
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
    }
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
            child: _HomeHeroSection(onOpen: () => _openPremiumPass(context)),
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
    setState(() {
      _filter = filter;
      if (filter == _DiscoveryFilter.tonight) {
        _selectedDate = DateTime.now();
        _dateFilter = _DateFilterOption.manualDate;
      }
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

  void _openPremiumPass(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NightlifePassScreen()),
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.elevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.nightlife,
              size: 19,
              color: AppTheme.accentPink,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nightlife',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                Text(
                  city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _CompactSelector<String>(
            tooltip: 'Select city',
            icon: Icons.location_on_outlined,
            label: selectedCity,
            values: AppConstants.cities,
            labelFor: (value) => value,
            onSelected: onCityChanged,
          ),
          const SizedBox(width: 8),
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

class _HomeHeroSection extends StatelessWidget {
  const _HomeHeroSection({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accentPink.withValues(alpha: 0.16),
                AppTheme.neonViolet.withValues(alpha: 0.08),
                AppTheme.surface.withValues(alpha: 0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.accentPink.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accentPink.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: AppTheme.accentPink,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unlock Premium Parties Before Anyone Else',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Guestlists | VIP Access | Private Nights',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.accentPink,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _FeaturedEventCard extends StatelessWidget {
  const _FeaturedEventCard({required this.event, required this.onOpen});

  final NightlifeEvent event;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final venue = event.venueName.trim().isEmpty ? event.city : event.venueName;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onOpen,
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          color: AppTheme.elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            EventPoster(event: event, borderRadius: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: _SmallHeroBadge(label: _heroBadgeLabel(event)),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title.trim().isEmpty
                              ? 'Featured Night'
                              : event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 13,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                venue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const _HeroArrow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.city});

  final String city;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppTheme.accentPink, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              city == 'All'
                  ? 'Choose a city or filter to find tonight\'s mood.'
                  : 'Fresh nights in $city will appear here.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallHeroBadge extends StatelessWidget {
  const _SmallHeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.premiumGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HeroArrow extends StatelessWidget {
  const _HeroArrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
    );
  }
}

class _CompactSelector<T> extends StatelessWidget {
  const _CompactSelector({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.values,
    required this.labelFor,
    required this.onSelected,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onSelected,
      color: AppTheme.elevated,
      itemBuilder: (context) {
        return values
            .map(
              (value) =>
                  PopupMenuItem<T>(value: value, child: Text(labelFor(value))),
            )
            .toList();
      },
      child: Container(
        height: 32,
        constraints: const BoxConstraints(maxWidth: 100),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      color: AppTheme.elevated,
      itemBuilder: (context) => _DateFilterOption.values
          .map(
            (option) => PopupMenuItem<_DateFilterOption>(
              value: option,
              child: Text(option.label),
            ),
          )
          .toList(),
      child: Container(
        height: 32,
        constraints: const BoxConstraints(maxWidth: 132),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 15,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
              const SizedBox(width: 10),
              PopupMenuButton<_DiscoveryFilter>(
                tooltip: 'Filter events',
                onSelected: onFilterSelected,
                color: AppTheme.elevated,
                itemBuilder: (context) => _DiscoveryFilter.values
                    .map(
                      (filter) => PopupMenuItem<_DiscoveryFilter>(
                        value: filter,
                        child: Text(filter.label),
                      ),
                    )
                    .toList(),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 16, color: AppTheme.textMuted),
                      SizedBox(width: 6),
                      Text(
                        'Filters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 31,
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
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 31,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentPink
              : AppTheme.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppTheme.accentPink
                : Colors.white.withValues(alpha: 0.08),
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
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
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
        title: 'No events found',
        message: 'Try changing your filters or city.',
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
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      itemCount: events.length + (loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == events.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Center(
              child: PremiumLoader(message: 'Curating more nights...'),
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 214,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
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
      padding: EdgeInsets.fromLTRB(16, 6, 16, 112),
      child: Column(
        children: [
          _SkeletonEventCard(),
          SizedBox(height: 12),
          _SkeletonEventCard(),
          SizedBox(height: 18),
          PremiumLoader(message: 'Curating your night...'),
        ],
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
        color: AppTheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 118,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
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
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.glassSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.search_off_outlined, color: AppTheme.accentPink),
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

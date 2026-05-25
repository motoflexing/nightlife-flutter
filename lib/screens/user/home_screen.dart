import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/app_preferences_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/event_card.dart';
import '../../widgets/state_views.dart';
import 'event_details_screen.dart';

enum _DiscoveryFilter {
  all('All'),
  tonight('Tonight'),
  nearby('Nearby'),
  freeEntry('Free Entry'),
  paid('Paid'),
  dj('DJ'),
  techno('Techno'),
  house('House');

  const _DiscoveryFilter(this.label);

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
    final uniqueEvents = <String, NightlifeEvent>{};
    for (final event in events) {
      final id = event.id.trim();
      final key = id.isEmpty
          ? '${event.title}|${event.venueName}|${event.dateTime.toIso8601String()}'
          : id;
      uniqueEvents.putIfAbsent(key, () => event);
    }
    return uniqueEvents.values.toList();
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
    final selectedDate = _selectedDate;
    if (selectedDate == null) return true;
    return _sameDay(event.dateTime, selectedDate);
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
      _DiscoveryFilter.dj => haystack.contains('dj'),
      _DiscoveryFilter.techno => haystack.contains('techno'),
      _DiscoveryFilter.house => haystack.contains('house'),
    };
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
              dateLabel: _dateLabel(_selectedDate),
              onCityChanged: _changeCity,
              onDateTap: _pickDate,
            ),
          ),
          SliverToBoxAdapter(
            child: _PremiumHeroBanner(
              eventCount: visibleEvents.length,
              locationMessage: _filter == _DiscoveryFilter.nearby
                  ? _locationMessage
                  : null,
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
    setState(() {
      _filter = filter;
      if (filter == _DiscoveryFilter.tonight) {
        _selectedDate = DateTime.now();
      }
    });
  }

  String _sectionTitle(int count) {
    if (_filter == _DiscoveryFilter.nearby) return 'Nearby Events';
    if (_filter == _DiscoveryFilter.tonight ||
        (_selectedDate != null && _sameDay(_selectedDate!, DateTime.now()))) {
      return "Tonight's Events";
    }
    return 'Events Found';
  }

  String _sectionSubtitle(int count) {
    if (_filter == _DiscoveryFilter.nearby) {
      return _nearbyEnabled
          ? '$count nights sorted by distance'
          : 'Tap Nearby to enable location';
    }
    final city = _city == 'All' ? 'all cities' : _city;
    return count == 1
        ? '1 curated night in $city'
        : '$count curated nights in $city';
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
    setState(() => _selectedDate = picked);
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'All Dates';
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

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.city,
    required this.selectedCity,
    required this.dateLabel,
    required this.onCityChanged,
    required this.onDateTap,
  });

  final String city;
  final String selectedCity;
  final String dateLabel;
  final ValueChanged<String> onCityChanged;
  final VoidCallback onDateTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppTheme.premiumGradient,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPink.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.nightlife, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 10),
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
            onTap: onDateTap,
          ),
        ],
      ),
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
        height: 34,
        constraints: const BoxConstraints(maxWidth: 104),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: AppTheme.glassSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.accentPink),
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
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 34,
          constraints: const BoxConstraints(maxWidth: 104),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: AppTheme.glassSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppTheme.accentPink),
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
      ),
    );
  }
}

class _PremiumHeroBanner extends StatelessWidget {
  const _PremiumHeroBanner({
    required this.eventCount,
    required this.locationMessage,
  });

  final int eventCount;
  final String? locationMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17101D), Color(0xFF250B19), Color(0xFF08090F)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPink.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HeroLinePainter())),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Unlock premium parties before everyone else',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      locationMessage ??
                          'Curated guestlists, tickets, and late-night drops',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accentPink.withValues(alpha: 0.38),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$eventCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: AppTheme.accentPink,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }

    final glow = Paint()
      ..color = AppTheme.accentPink.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.08), 56, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    const SizedBox(height: 2),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.glassSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: const Icon(Icons.tune, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
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
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentPink.withValues(alpha: 0.18)
              : AppTheme.glassSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppTheme.accentPink.withValues(alpha: 0.7)
                : AppTheme.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textMuted,
                fontSize: 12,
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
        message: 'Try another city, date, or filter.',
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
            child: Center(child: CircularProgressIndicator()),
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
          return const Center(child: CircularProgressIndicator());
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      child: Column(
        children: [
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 12),
          for (var i = 0; i < 4; i++) ...[
            const _SkeletonCard(),
            if (i != 3) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 146,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.glassSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 96,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SkeletonLine(widthFactor: 0.72),
                const SizedBox(height: 10),
                _SkeletonLine(widthFactor: 0.54),
                const SizedBox(height: 10),
                _SkeletonLine(widthFactor: 0.62),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Expanded(child: _SkeletonPill()),
                    SizedBox(width: 8),
                    Expanded(child: _SkeletonPill()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
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
          border: Border.all(color: AppTheme.glassBorder),
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

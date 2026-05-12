import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/firestore_service.dart';
import '../../widgets/event_card.dart';
import '../../widgets/state_views.dart';
import 'event_details_screen.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
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
        _lastDocument = page.lastDocument;
        _hasMore = page.events.length == AppConstants.eventPageSize;
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _Header(currentUser: widget.currentUser)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SegmentedButton<String>(
                segments: AppConstants.cities
                    .map((city) => ButtonSegment(value: city, label: Text(city)))
                    .toList(),
                selected: {_city},
                onSelectionChanged: (value) {
                  setState(() => _city = value.first);
                  _loadFirstPage();
                },
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: LoadingView(message: 'Finding nights'))
          else if (_error != null)
            SliverFillRemaining(
              child: ErrorStateView(message: _error!, onRetry: _loadFirstPage),
            )
          else if (_events.isEmpty)
            const SliverFillRemaining(
              child: EmptyView(
                title: 'No active events',
                message: 'Switch city filters or check back when the next drop goes live.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final columns = width > 1100 ? 3 : width > 720 ? 2 : 1;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: columns == 1 ? 0.88 : 0.8,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _events.length) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final event = _events[index];
                        return EventCard(
                          event: event,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => EventDetailsScreen(
                                  event: event,
                                  currentUser: widget.currentUser,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: _events.length + (_loadingMore ? 1 : 0),
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

class _Header extends StatelessWidget {
  const _Header({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tonight, ${currentUser.name.split(' ').first}',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Discover RSVP-led nightlife drops across Guwahati and Delhi.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

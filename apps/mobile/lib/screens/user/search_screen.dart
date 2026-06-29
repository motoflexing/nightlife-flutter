import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/analytics_service.dart';
import '../../services/event_discovery_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/compact_ui.dart';
import '../../widgets/event_card.dart';
import '../../widgets/state_views.dart';
import 'event_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  String? _category;

  static const _categories = [
    'Rave',
    'Psytrance',
    'Pool Party',
    'House Party',
    'Bollywood Night',
    'Live Music',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NightlifeEvent>>(
      stream: FirestoreService.instance.activeEventsStream(),
      builder: (context, snapshot) {
        final events = EventDiscoveryService.instance.filterEvents(
          events: snapshot.data ?? [],
          query: _query,
          category: _category,
        );
        return ListView(
          padding: compactScreenPadding(context),
          children: [
            TextField(
              controller: _controller,
              onChanged: (value) {
                final trimmed = value.trim();
                setState(() => _query = trimmed);
                if (trimmed.isNotEmpty) {
                  AnalyticsService.instance.logSearch(trimmed);
                }
              },
              decoration: InputDecoration(
                hintText: 'Search parties, clubs, artists',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? const Icon(Icons.tune)
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories
                  .map(
                    (category) => FilterChip(
                      selected: _category == category,
                      label: Text(category),
                      onSelected: (_) => setState(() {
                        _category = _category == category ? null : category;
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            Text(
              'Events',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LoadingView(message: 'Searching events')
            else if (snapshot.hasError)
              ErrorStateView(
                message: ErrorStateView.sanitizeError(snapshot.error),
                onRetry: () {},
              )
            else if (events.isEmpty)
              EmptyView(
                title: 'No events found',
                message: _query.isEmpty && _category == null
                    ? 'Try another city or category.'
                    : 'No compact results match your search yet.',
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

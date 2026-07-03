import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/analytics_service.dart';
import '../../services/event_discovery_service.dart';
import '../../services/firestore_service.dart';
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
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            // Playfair screen title.
            Text(
              'Search',
              style: AppTypography.displayMedium.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 24),

            // Thin-line underline search field (gold focus via theme).
            TextField(
              controller: _controller,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textHigh,
              ),
              onChanged: (value) {
                final trimmed = value.trim();
                setState(() => _query = trimmed);
                if (trimmed.isNotEmpty) {
                  AnalyticsService.instance.logSearch(trimmed);
                }
              },
              decoration: InputDecoration(
                hintText: 'Search venues, sounds, cities',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.champagne,
                  size: 20,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Category chips (gold pills → filterEvents category) ────────
            const _FilterGroupLabel('Filter'),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: _categories.map((category) {
                return _GoldPillChip(
                  label: category,
                  selected: _category == category,
                  onTap: () => setState(() {
                    _category = _category == category ? null : category;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // ── Results ────────────────────────────────────────────────────
            if (snapshot.connectionState == ConnectionState.waiting)
              const LoadingView(message: 'Searching events')
            else if (snapshot.hasError)
              ErrorStateView(
                message: ErrorStateView.sanitizeError(snapshot.error),
                onRetry: () {},
              )
            else ...[
              _SectionEyebrow(
                events.length == 1
                    ? '1 Night Found'
                    : '${events.length} Nights Found',
              ),
              if (events.isEmpty)
                EmptyView(
                  title: 'Nothing yet',
                  message: _query.isEmpty && _category == null
                      ? 'Search a venue, sound, or city to begin.'
                      : 'No nights match your search yet.',
                  icon: Icons.search_off_outlined,
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
          ],
        );
      },
    );
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

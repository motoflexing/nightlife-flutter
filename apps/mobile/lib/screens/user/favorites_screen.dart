import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../models/saved_collection.dart';
import '../../services/explore_filter_request.dart';
import '../../services/firestore_service.dart';
import '../../widgets/event_card.dart';
import 'event_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    required this.currentUser,
    required this.onExplore,
  });

  final AppUser currentUser;
  final VoidCallback onExplore;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

enum _SavedTab { events, collections, clubs }

class _FavoritesScreenState extends State<FavoritesScreen> {
  _SavedTab _tab = _SavedTab.events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Playfair screen title.
              Text(
                'Saved',
                style: AppTypography.displayMedium.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 18),
              // Three-tab underline selector (champagne-active).
              _TabSelector(
                current: _tab,
                onSelect: (tab) => setState(() => _tab = tab),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_tab) {
            _SavedTab.events => _SavedEventsTab(currentUser: widget.currentUser),
            _SavedTab.collections => _SavedCollectionsTab(
              onExplore: widget.onExplore,
            ),
            _SavedTab.clubs => const _SavedClubsTab(),
          },
        ),
      ],
    );
  }
}

// ─── Tab selector ──────────────────────────────────────────────────────────────

class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.current, required this.onSelect});

  final _SavedTab current;
  final ValueChanged<_SavedTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.goldBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          _TabItem(
            label: 'Events',
            selected: current == _SavedTab.events,
            onTap: () => onSelect(_SavedTab.events),
          ),
          const SizedBox(width: 26),
          _TabItem(
            label: 'Collections',
            selected: current == _SavedTab.collections,
            onTap: () => onSelect(_SavedTab.collections),
          ),
          const SizedBox(width: 26),
          _TabItem(
            label: 'Clubs',
            selected: current == _SavedTab.clubs,
            onTap: () => onSelect(_SavedTab.clubs),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.champagne : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            fontSize: 11,
            letterSpacing: 0.1 * 11,
            color: selected ? AppColors.textHigh : AppColors.textCaption,
          ),
        ),
      ),
    );
  }
}

// ─── Saved events tab (live stream, EventCard) ─────────────────────────────────

class _SavedEventsTab extends StatelessWidget {
  const _SavedEventsTab({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NightlifeEvent>>(
      stream: FirestoreService.instance.savedEventsStream(),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <NightlifeEvent>[];
        if (events.isEmpty) {
          return const _EmptyTab(
            eyebrow: 'No saved events yet',
            title: 'Your nights,\nremembered.',
            message:
                'Tap the heart on any event to keep it here for the night '
                'you decide to go.',
          );
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final event = events[index];
            // EventCard owns the unsave (heart toggle) + tap navigation is here.
            return EventCard(
              event: event,
              compact: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EventDetailsScreen(
                    event: event,
                    currentUser: currentUser,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Saved collections tab (live stream, tap → re-apply in Explore) ────────────

class _SavedCollectionsTab extends StatelessWidget {
  const _SavedCollectionsTab({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedCollection>>(
      stream: FirestoreService.instance.savedCollectionsStream(),
      builder: (context, snapshot) {
        final collections = snapshot.data ?? const <SavedCollection>[];
        if (collections.isEmpty) {
          return _EmptyTab(
            eyebrow: 'No collections yet',
            title: 'Save a search,\nname the mood.',
            message:
                'Turn a filter — say "Techno Nights" or "Rooftops in July" — '
                'into a living collection that updates itself.',
            actionLabel: 'Start a collection',
            onAction: onExplore,
          );
        }
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          children: [
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final collection in collections)
                  _CollectionChip(
                    collection: collection,
                    onOpen: () => _open(context, collection),
                    onRemove: () => FirestoreService.instance.unsaveCollection(
                      collection.id,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _open(BuildContext context, SavedCollection collection) {
    // Tap-to-reapply: route back into Explore and apply this filter once.
    ExploreFilterRequest.instance.request(
      ExploreFilter(genre: collection.genre, shortcut: collection.shortcut),
    );
    onExplore();
  }
}

class _CollectionChip extends StatelessWidget {
  const _CollectionChip({
    required this.collection,
    required this.onOpen,
    required this.onRemove,
  });

  final SavedCollection collection;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.goldWash,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        splashColor: AppColors.goldWash,
        highlightColor: AppColors.goldWash,
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.champagne, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bookmark,
                size: 14,
                color: AppColors.champagne,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  collection.label.trim().isEmpty
                      ? 'Saved filter'
                      : collection.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.12 * 11,
                    color: AppColors.champagne,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.textSecondary,
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

// ─── Saved clubs tab (real stream; honest empty state — no club UI exists) ─────

class _SavedClubsTab extends StatelessWidget {
  const _SavedClubsTab();

  @override
  Widget build(BuildContext context) {
    // Wired to the REAL saved-clubs stream. There is no club-browsing surface in
    // the app yet, and the service only exposes saved-club IDs (no club model),
    // so in normal use this is empty. We never fabricate club cards: when IDs
    // exist we honestly report the count; otherwise the honest empty state.
    return StreamBuilder<Set<String>>(
      stream: FirestoreService.instance.savedClubIdsStream(),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        if (count == 0) {
          return const _EmptyTab(
            eyebrow: 'No clubs yet',
            title: 'The houses\nyou favour.',
            message:
                'Clubs you save will gather here. Club profiles are opening '
                'soon.',
          );
        }
        // Real data present but no club profile surface to render into — report
        // honestly rather than inventing club names/photos.
        return _EmptyTab(
          eyebrow: count == 1 ? '1 saved club' : '$count saved clubs',
          title: 'The houses\nyou favour.',
          message:
              'Your saved clubs are held safely. Full club profiles are '
              'opening soon.',
        );
      },
    );
  }
}

// ─── Honest empty / centered state (design empty treatment) ────────────────────

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.eyebrow,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String eyebrow;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thin gold ring medallion.
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.champagne.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.favorite_border,
                size: 28,
                color: AppColors.champagne.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              eyebrow.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.labelLarge.copyWith(
                letterSpacing: 0.28 * 14,
                color: AppColors.champagne,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.displayMedium.copyWith(
                fontSize: 26,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textBodyDim,
                height: 1.7,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 30),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!.toUpperCase()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

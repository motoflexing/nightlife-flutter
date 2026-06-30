import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../models/saved_collection.dart';
import '../../services/explore_filter_request.dart';
import '../../services/firestore_service.dart';
import '../../widgets/event_card.dart';
import 'event_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.currentUser,
    required this.onExplore,
  });

  final AppUser currentUser;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.glassSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppTheme.premiumGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.favorite_border),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Saved nightlife, clubs, and collections will appear here.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SavedEventsSection(
          currentUser: currentUser,
          onExplore: onExplore,
        ),
        const SizedBox(height: 14),
        const _FavoriteSection(
          title: 'Liked Clubs',
          icon: Icons.storefront_outlined,
          message: 'Favorite venues will be listed here.',
        ),
        const SizedBox(height: 14),
        _SavedCollectionsSection(onExplore: onExplore),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onExplore,
          icon: const Icon(Icons.explore_outlined),
          label: const Text('Explore events'),
        ),
      ],
    );
  }
}

// ─── Saved events (live) ──────────────────────────────────────────────────────

class _SavedEventsSection extends StatelessWidget {
  const _SavedEventsSection({
    required this.currentUser,
    required this.onExplore,
  });

  final AppUser currentUser;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NightlifeEvent>>(
      stream: FirestoreService.instance.savedEventsStream(),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <NightlifeEvent>[];
        return _SectionShell(
          title: 'Saved Events',
          icon: Icons.local_activity_outlined,
          count: events.isEmpty ? null : events.length,
          child: events.isEmpty
              ? const _SectionEmpty(message: 'No saved events yet.')
              : Column(
                  children: [
                    for (final event in events)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: EventCard(
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
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

// ─── Saved collections (live) ─────────────────────────────────────────────────

class _SavedCollectionsSection extends StatelessWidget {
  const _SavedCollectionsSection({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedCollection>>(
      stream: FirestoreService.instance.savedCollectionsStream(),
      builder: (context, snapshot) {
        final collections = snapshot.data ?? const <SavedCollection>[];
        return _SectionShell(
          title: 'Saved Collections',
          icon: Icons.grid_view_outlined,
          count: collections.isEmpty ? null : collections.length,
          child: collections.isEmpty
              ? const _SectionEmpty(
                  message:
                      'Save categories like techno nights or guestlist deals '
                      'from Explore.',
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final collection in collections)
                        _CollectionChip(
                          collection: collection,
                          onOpen: () => _open(context, collection),
                          onRemove: () => FirestoreService.instance
                              .unsaveCollection(collection.id),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  void _open(BuildContext context, SavedCollection collection) {
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
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryViolet.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppTheme.accentPink.withValues(alpha: 0.34),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bookmark, size: 14, color: AppTheme.neonLime),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  collection.label.trim().isEmpty
                      ? 'Saved filter'
                      : collection.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: AppTheme.textMuted,
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

// ─── Section building blocks ──────────────────────────────────────────────────

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.icon,
    required this.child,
    this.count,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.accentPink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryViolet.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppTheme.accentPink.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.textMuted),
      ),
    );
  }
}

class _FavoriteSection extends StatelessWidget {
  const _FavoriteSection({
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentPink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

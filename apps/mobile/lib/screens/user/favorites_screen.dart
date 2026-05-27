import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.onExplore});

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
        const _FavoriteSection(
          title: 'Saved Events',
          icon: Icons.local_activity_outlined,
          message: 'No saved events yet.',
        ),
        const SizedBox(height: 14),
        const _FavoriteSection(
          title: 'Liked Clubs',
          icon: Icons.storefront_outlined,
          message: 'Favorite venues will be listed here.',
        ),
        const SizedBox(height: 14),
        const _FavoriteSection(
          title: 'Saved Collections',
          icon: Icons.grid_view_outlined,
          message: 'Save categories like techno nights or guestlist deals.',
        ),
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

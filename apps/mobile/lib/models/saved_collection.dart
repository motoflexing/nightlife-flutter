import 'package:cloud_firestore/cloud_firestore.dart';

/// A saved discovery filter — the user bookmarks a category/shortcut (e.g.
/// "Techno", "Late Night") from Explore so they can re-open it later.
///
/// Either [genre] or [shortcut] identifies which filter to re-apply; both may
/// be null for a legacy/empty doc, in which case opening it just clears filters.
class SavedCollection {
  const SavedCollection({
    required this.id,
    required this.label,
    this.genre,
    this.shortcut,
  });

  final String id;
  final String label;
  final String? genre;
  final String? shortcut;

  factory SavedCollection.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SavedCollection(
      id: (data['collectionId'] as String?)?.trim().isNotEmpty == true
          ? (data['collectionId'] as String).trim()
          : doc.id,
      label: data['label'] as String? ?? '',
      genre: _nonEmpty(data['genre']),
      shortcut: _nonEmpty(data['shortcut']),
    );
  }

  static String? _nonEmpty(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

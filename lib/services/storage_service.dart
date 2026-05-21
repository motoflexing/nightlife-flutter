import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  StorageService._();

  static final instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadEventPoster({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final path =
        'event_posters/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = _storage.ref(path);
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return task.ref.getDownloadURL();
  }

  Future<String> uploadValidId({
    required Uint8List bytes,
    required String userId,
    required String fileName,
    required String contentType,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    final safeExtension = {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? extension
        : 'jpg';
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final path =
        'valid_ids/$safeUserId/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    debugPrint('ID upload started: $path');
    final ref = _storage.ref(path);
    final task = await ref
        .putData(bytes, SettableMetadata(contentType: contentType))
        .timeout(const Duration(seconds: 20));
    debugPrint('ID upload completed: $path');
    final url = await task.ref.getDownloadURL();
    debugPrint('ID download URL received: $url');
    return url;
  }
}

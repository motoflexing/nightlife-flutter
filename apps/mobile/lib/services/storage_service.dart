import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'profile_photo_uploader_stub.dart'
    if (dart.library.io) 'profile_photo_uploader_io.dart'
    if (dart.library.html) 'profile_photo_uploader_web.dart';

class StorageService {
  StorageService._();

  static final instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  void configureRetryLimits() {
    _storage.setMaxUploadRetryTime(const Duration(minutes: 2));
    _storage.setMaxOperationRetryTime(const Duration(minutes: 1));
    _storage.setMaxDownloadRetryTime(const Duration(minutes: 1));
  }

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
    return task.ref.getDownloadURL().timeout(const Duration(seconds: 20));
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
    final ref = _storage.ref(path);
    final task = await ref
        .putData(bytes, SettableMetadata(contentType: contentType))
        .timeout(const Duration(seconds: 20));
    final url = await task.ref.getDownloadURL().timeout(
      const Duration(seconds: 20),
    );
    return url;
  }

  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String userId,
    required String fileName,
    required String contentType,
    String filePath = '',
    ValueChanged<double>? onProgress,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    final safeExtension = _imageExtension(extension, contentType);
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'invalid-user',
        message: 'User id is required to upload a profile photo.',
      );
    }
    final normalizedContentType = _imageContentType(contentType, safeExtension);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'profile_photos/$cleanUserId/avatar_$timestamp.$safeExtension';
    final ref = _storage.ref(path);
    final metadata = SettableMetadata(
      contentType: normalizedContentType,
      customMetadata: {'uid': cleanUserId, 'kind': 'profile_picture'},
    );
    final uploadTask = startProfilePhotoUpload(
      ref: ref,
      bytes: bytes,
      filePath: filePath,
      metadata: metadata,
    );

    try {
      final snapshot = await _waitForUpload(
        uploadTask,
        path: path,
        onProgress: onProgress,
      );
      final url = await snapshot.ref.getDownloadURL().timeout(
        const Duration(seconds: 30),
      );
      return url;
    } on FirebaseException catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<String> uploadVenueMedia({
    required Uint8List bytes,
    required String userId,
    required String fileName,
    required String contentType,
    required String kind,
    String filePath = '',
    ValueChanged<double>? onProgress,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    final safeExtension = _imageExtension(extension, contentType);
    final cleanUserId = userId.trim();
    final cleanKind = kind.trim() == 'cover' ? 'cover' : 'profile';
    if (cleanUserId.isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'invalid-user',
        message: 'User id is required to upload venue media.',
      );
    }
    final normalizedContentType = _imageContentType(contentType, safeExtension);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        'profile_photos/$cleanUserId/venue_${cleanKind}_$timestamp.$safeExtension';
    final ref = _storage.ref(path);
    final metadata = SettableMetadata(
      contentType: normalizedContentType,
      customMetadata: {'uid': cleanUserId, 'kind': 'venue_$cleanKind'},
    );
    final uploadTask = startProfilePhotoUpload(
      ref: ref,
      bytes: bytes,
      filePath: filePath,
      metadata: metadata,
    );

    try {
      final snapshot = await _waitForUpload(
        uploadTask,
        path: path,
        onProgress: onProgress,
      );
      return snapshot.ref.getDownloadURL().timeout(const Duration(seconds: 30));
    } on FirebaseException catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Best-effort removal of every Storage object owned by [userId] (profile
  /// photos and valid IDs). Used by account deletion.
  ///
  /// This MUST NOT throw: Storage is not enabled yet (pending Blaze), and even
  /// once enabled a missing object or a permission gap must not block account
  /// deletion. Every failure — unconfigured bucket, permission-denied,
  /// object-not-found, timeout — is swallowed so the caller can proceed.
  Future<void> deleteAllUserAssets(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return;
    final safeUserId = cleanUserId.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');

    // Folders the app uploads user-owned assets into. Both the raw uid and the
    // sanitized variant are covered because uploads sanitize the id.
    final folders = <String>{
      'profile_photos/$cleanUserId',
      'profile_photos/$safeUserId',
      'valid_ids/$cleanUserId',
      'valid_ids/$safeUserId',
    };

    for (final folder in folders) {
      try {
        final listing = await _storage
            .ref(folder)
            .listAll()
            .timeout(const Duration(seconds: 20));
        for (final item in listing.items) {
          try {
            await item.delete().timeout(const Duration(seconds: 20));
          } catch (_) {
            // Per-object failure is non-fatal; continue deleting the rest.
          }
        }
      } catch (_) {
        // listAll can fail if Storage is unavailable / not configured / the
        // folder doesn't exist. Treat as a no-op so deletion still completes.
      }
    }
  }

  Future<TaskSnapshot> _waitForUpload(
    UploadTask uploadTask, {
    required String path,
    ValueChanged<double>? onProgress,
  }) async {
    final completer = Completer<TaskSnapshot>();
    late final StreamSubscription<TaskSnapshot> subscription;

    subscription = uploadTask.snapshotEvents.listen(
      (snapshot) {
        final total = snapshot.totalBytes;
        if (total > 0) {
          final progress = (snapshot.bytesTransferred / total).clamp(0.0, 1.0);
          onProgress?.call(progress);
        }
        if (snapshot.state == TaskState.success && !completer.isCompleted) {
          completer.complete(snapshot);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
      cancelOnError: true,
    );

    try {
      return await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          unawaited(uploadTask.cancel());
          throw TimeoutException('Profile photo upload timed out.');
        },
      );
    } finally {
      await subscription.cancel();
    }
  }

  String _imageExtension(String extension, String contentType) {
    if ({'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      return extension == 'jpeg' ? 'jpg' : extension;
    }
    final normalized = contentType.trim().toLowerCase();
    if (normalized == 'image/png') return 'png';
    if (normalized == 'image/webp') return 'webp';
    return 'jpg';
  }

  String _imageContentType(String contentType, String extension) {
    final normalized = contentType.trim().toLowerCase();
    if (normalized.startsWith('image/')) return normalized;
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}

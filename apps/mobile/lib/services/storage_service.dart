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
    debugPrint('Firebase Storage retry limits configured.');
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
    debugPrint('ID upload started: $path');
    final ref = _storage.ref(path);
    final task = await ref
        .putData(bytes, SettableMetadata(contentType: contentType))
        .timeout(const Duration(seconds: 20));
    debugPrint('ID upload completed: $path');
    final url = await task.ref.getDownloadURL().timeout(
      const Duration(seconds: 20),
    );
    debugPrint('ID download URL received: $url');
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
    debugPrint(
      'Profile photo upload started: path=$path uid=$cleanUserId '
      'bytes=${bytes.lengthInBytes} kIsWeb=$kIsWeb contentType=$normalizedContentType',
    );
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
      debugPrint(
        'Profile photo upload success: path=$path state=${snapshot.state}',
      );
      final url = await snapshot.ref.getDownloadURL().timeout(
        const Duration(seconds: 30),
      );
      debugPrint('Profile photo download URL received: $url');
      return url;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Profile photo upload FirebaseException: '
        'code=${error.code} message=${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('Profile photo upload timeout: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
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
          debugPrint(
            'Profile photo upload progress: path=$path '
            '${(progress * 100).toStringAsFixed(0)}%',
          );
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
          debugPrint('Profile photo upload timeout: path=$path');
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

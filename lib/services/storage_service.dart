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
    _storage.setMaxUploadRetryTime(const Duration(seconds: 15));
    _storage.setMaxOperationRetryTime(const Duration(seconds: 15));
    _storage.setMaxDownloadRetryTime(const Duration(seconds: 15));
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
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    final safeExtension = _imageExtension(extension, contentType);
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final normalizedContentType = _imageContentType(contentType, safeExtension);
    final path = 'users/$safeUserId/profile/profile.$safeExtension';
    debugPrint(
      'Profile photo upload started: path=$path uid=$safeUserId '
      'bytes=${bytes.lengthInBytes} kIsWeb=$kIsWeb contentType=$normalizedContentType',
    );
    final ref = _storage.ref(path);
    final metadata = SettableMetadata(
      contentType: normalizedContentType,
      customMetadata: {'uid': safeUserId, 'kind': 'profile_picture'},
    );
    final uploadTask = startProfilePhotoUpload(
      ref: ref,
      bytes: bytes,
      filePath: filePath,
      metadata: metadata,
    );
    final task = await _waitForProfilePhotoUpload(uploadTask, path);
    final url = await task.ref.getDownloadURL().timeout(
      const Duration(seconds: 20),
    );
    debugPrint('Profile photo download URL received: $url');
    return url;
  }

  Future<TaskSnapshot> _waitForProfilePhotoUpload(
    UploadTask uploadTask,
    String path,
  ) async {
    final completer = Completer<TaskSnapshot>();

    void completeWithSnapshot(TaskSnapshot snapshot) {
      if (!completer.isCompleted) completer.complete(snapshot);
    }

    void completeWithError(Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }

    final subscription = uploadTask.snapshotEvents.listen(
      (snapshot) {
        final total = snapshot.totalBytes;
        final transferred = snapshot.bytesTransferred;
        final percent = total <= 0
            ? 0
            : ((transferred / total) * 100).clamp(0, 100).round();
        debugPrint(
          'Profile photo upload progress: path=$path '
          '$transferred/$total bytes ($percent%) state=${snapshot.state}',
        );
        if (snapshot.state == TaskState.success) {
          completeWithSnapshot(snapshot);
        } else if (snapshot.state == TaskState.canceled ||
            snapshot.state == TaskState.error) {
          completeWithError(
            StateError(
              'Profile photo upload ended with state ${snapshot.state}.',
            ),
            StackTrace.current,
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Profile photo upload progress error: $error');
        debugPrintStack(stackTrace: stackTrace);
        completeWithError(error, stackTrace);
      },
    );

    unawaited(
      uploadTask.then(
        completeWithSnapshot,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Profile photo upload task failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          completeWithError(error, stackTrace);
        },
      ),
    );

    try {
      final task = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('Profile photo upload timeout: path=$path');
          unawaited(uploadTask.cancel());
          throw TimeoutException('Profile photo upload timed out.');
        },
      );
      debugPrint(
        'Profile photo upload success: path=$path state=${task.state}',
      );
      return task;
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

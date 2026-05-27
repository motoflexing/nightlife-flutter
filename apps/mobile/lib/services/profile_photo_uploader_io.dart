import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

UploadTask startProfilePhotoUpload({
  required Reference ref,
  required Uint8List bytes,
  required String filePath,
  required SettableMetadata metadata,
}) {
  final cleanPath = filePath.trim();
  if (cleanPath.isNotEmpty) {
    final file = File(cleanPath);
    if (file.existsSync()) {
      return ref.putFile(file, metadata);
    }
  }
  return ref.putData(bytes, metadata);
}

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

UploadTask startProfilePhotoUpload({
  required Reference ref,
  required Uint8List bytes,
  required String filePath,
  required SettableMetadata metadata,
}) {
  return ref.putData(bytes, metadata);
}

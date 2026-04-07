import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, debugPrint, TargetPlatform;
import 'dart:io' as io; // Use alias to avoid conflicts and allow kIsWeb guards
import 'dart:typed_data';

class MediaService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Picks an image from the gallery
  Future<XFile?> pickImage() async {
    return await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
  }

  /// Saves an XFile to local app storage and returns the local path
  Future<String?> saveToLocal(XFile image, String tenantId) async {
    if (kIsWeb) {
      // Browsers handle XFile paths as blob URLs; no direct local filesystem saving in this context.
      return image.path; 
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = io.Directory(p.join(appDir.path, 'tenants', tenantId, 'media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final fileName = '${const Uuid().v4()}${p.extension(image.path).isEmpty ? ".jpg" : p.extension(image.path)}';
      final localPath = p.join(mediaDir.path, fileName);
      
      await io.File(image.path).copy(localPath);
      return localPath;
    } catch (e) {
      debugPrint('Local Save Error: $e');
      return null;
    }
  }

  /// Uploads a file (XFile or io.File path) to Firebase Storage
  Future<String?> uploadFile(dynamic fileSource, String tenantId, String folder) async {
    try {
      final String filePath = fileSource is XFile ? fileSource.path : (fileSource is io.File ? fileSource.path : fileSource.toString());
      final String fileName = '${const Uuid().v4()}${p.extension(filePath)}';
      final ref = _storage.ref().child('tenants').child(tenantId).child(folder).child(fileName);
      
      final Uint8List bytes = fileSource is XFile ? await fileSource.readAsBytes() : await (fileSource as io.File).readAsBytes();
      
      TaskSnapshot? uploadTask;
      try {
        uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } catch (e) {
        final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
        if (isWindows && e.toString().contains('object-not-found')) {
          // [WINDOWS WORKAROUND]
          final bucket = _storage.bucket;
          final path = Uri.encodeComponent(ref.fullPath);
          return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$path?alt=media';
        } else {
          rethrow;
        }
      }

      if (uploadTask.state == TaskState.success) {
        // [WINDOWS WORKAROUND]: The FlutterFire C++ Desktop plugin frequently resolves the uploadTask 
        // Future prematurely before the file is fully committed to the backend, causing getDownloadURL 
        // to throw 'object-not-found'. We retry fetching the URL to give the background thread time to finish.
        for (int i = 0; i < 30; i++) {
          try {
            return await ref.getDownloadURL();
          } catch (e) {
            if (e.toString().contains('object-not-found')) {
              await Future.delayed(const Duration(seconds: 1));
            } else {
              print('Firebase Storage URL Error: $e');
              break;
            }
          }
        }
        
        // Fallback if getDownloadURL still fails
        final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
        if (isWindows) {
          final bucket = _storage.bucket;
          final path = Uri.encodeComponent(ref.fullPath);
          return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$path?alt=media';
        }
      }
      return null;
    } catch (e) {
      debugPrint('Firebase Storage Error: $e');
      return null;
    }
  }

  /// Checks if a path is local or a network URL
  bool isLocalPath(String path) {
    return !path.startsWith('http') && !path.startsWith('https');
  }

  /// Direct pick and upload
  Future<String?> pickAndUploadImage(String tenantId, String folder) async {
    final XFile? image = await pickImage();
    if (image == null) return null;
    return await uploadFile(image, tenantId, folder);
  }
}

final mediaServiceProvider = Provider((ref) => MediaService());

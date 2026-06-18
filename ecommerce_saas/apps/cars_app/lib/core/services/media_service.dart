import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, debugPrint, TargetPlatform;
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MediaService {
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

  /// Uploads a file to Firebase Storage via REST API (Standardized for Windows stability)
  Future<String?> uploadFile(dynamic fileSource, String tenantId, String folder) async {
    try {
      final String filePath = fileSource is XFile ? fileSource.path : (fileSource is io.File ? fileSource.path : fileSource.toString());
      final String fileName = '${const Uuid().v4()}${p.extension(filePath)}';
      final String fullPath = 'tenants/$tenantId/$folder/$fileName';
      
      final Uint8List bytes = fileSource is XFile ? await fileSource.readAsBytes() : await (fileSource as io.File).readAsBytes();
      
      // REST Upload Configuration
      const bucket = 'my-store-b0723.firebasestorage.app';
      final uploadUrl = Uri.parse('https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=${Uri.encodeComponent(fullPath)}');

      final response = await http.post(
        uploadUrl,
        headers: {
          'Content-Type': 'image/jpeg',
        },
        body: bytes,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final name = decoded['name'] as String;
        // Construct public download URL
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(name)}?alt=media';
      } else {
        debugPrint('REST Storage Upload Failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Media Service Error: $e');
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

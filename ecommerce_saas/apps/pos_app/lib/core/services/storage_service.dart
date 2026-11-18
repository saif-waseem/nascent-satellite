import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'media_service.dart';
import 'service_config_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class StorageService {
  final ServiceConfig config;
  final MediaService mediaService;

  StorageService(this.config, this.mediaService);

  Future<String?> pickAndUploadImage({required String tenantId, String folder = 'products'}) async {
    try {
      if (config.imageService == 'imgbb' && config.imageApiKey.isNotEmpty) {
        final image = await mediaService.pickImage();
        if (image == null) return null;
        final url = await _uploadToImgBB(image);
        if (url == null) print('STORAGE WARNING: ImgBB returned null for $folder upload');
        return url;
      }

      // Fallback to Firebase Storage if ImgBB is not configured
      final url = await mediaService.pickAndUploadImage(tenantId, folder);
      if (url == null) {
        print('STORAGE WARNING: MediaService returned null for $folder upload');
      }
      return url;
    } catch (e) {
      print('CRITICAL STORAGE ERROR in $folder: $e');
      return null;
    }
  }

  Future<String?> _uploadToImgBB(XFile image) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload'));
      request.fields['key'] = config.imageApiKey;
      final bytes = await image.readAsBytes();
      // Clean filename for Windows paths (ImgBB rejects raw paths)
      final cleanName = image.name.split(RegExp(r'[/\\]')).last;
      request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: cleanName));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['url'] as String;
      }
      print('ImgBB Upload Failed: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('ImgBB Exception: $e');
    }
    return null;
  }

  Future<String?> pickAndUploadVideo({required String tenantId, String folder = 'products_videos'}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;
      final file = result.files.single;

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        final f = File(file.path!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('تعذر قراءة ملف الفيديو من الجهاز');
      }

      final cleanName = file.name.split(RegExp(r'[/\\]')).last.replaceAll(' ', '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uploadPath = '$tenantId/videos/${timestamp}_$cleanName';

      // 1. Supabase Storage
      try {
        await Supabase.instance.client.storage.from('product-media').uploadBinary(
          uploadPath,
          bytes,
          fileOptions: const FileOptions(contentType: 'video/mp4', upsert: true),
        );
        final publicUrl = Supabase.instance.client.storage.from('product-media').getPublicUrl(uploadPath);
        if (publicUrl.isNotEmpty) return publicUrl;
      } catch (supabaseError) {
        print('Supabase storage upload note: $supabaseError');
      }

      // 2. Fallback to Firebase Storage
      try {
        final fileName = '${timestamp}_$cleanName';
        final ref = FirebaseStorage.instance.ref().child(folder).child(fileName);
        final uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: 'video/mp4'),
        );
        return await uploadTask.ref.getDownloadURL();
      } catch (firebaseError) {
        print('Firebase storage upload note: $firebaseError');
      }

      throw Exception('فشل رفع الفيديو إلى السحابة. يمكنك لصق رابط الفيديو المباشر في الخانة.');
    } catch (e) {
      print('CRITICAL VIDEO ERROR: $e');
      rethrow;
    }
  }
}

final storageServiceProvider = Provider((ref) {
  final configAsync = ref.watch(serviceConfigProvider);
  
  final config = configAsync.value ?? ServiceConfig(
    imageService: 'imgbb',
    imageApiKey: '4c2a2e4993d69bf3fe8bf8d09d1a2520',
    videoService: 'disabled',
    videoLibraryId: '',
    videoApiKey: '',
  );
  
  final mediaService = ref.watch(mediaServiceProvider);
  
  return StorageService(config, mediaService);
});

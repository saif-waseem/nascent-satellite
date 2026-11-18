import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'service_config_service.dart';

class StorageService {
  final ServiceConfig config;
  final ImagePicker _picker = ImagePicker();

  StorageService(this.config);

  Future<String?> pickAndUploadImage(String folder) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return null;

      if (config.imageService == 'imgbb') {
        return _uploadToImgBB(image);
      }
      
      return null;
    } catch (e) {
      print('CRITICAL STORAGE ERROR: $e');
      rethrow;
    }
  }

  Future<String?> _uploadToImgBB(XFile image) async {
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
    return null;
  }

  Future<List<String>> pickAndUploadMultipleImages(String folder) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 70);
      if (images.isEmpty) return [];

      final List<String> urls = [];
      for (var image in images) {
        String? url;
        if (config.imageService == 'imgbb') {
          url = await _uploadToImgBB(image);
        }
        if (url != null) urls.add(url);
      }
      return urls;
    } catch (e) {
      print('CRITICAL STORAGE ERROR: $e');
      rethrow;
    }
  }

  /// Picks a video file reliably across all platforms (Windows, Android, iOS, macOS)
  /// and uploads it to Supabase Storage or Firebase Storage
  Future<String?> pickAndUploadVideo({String folder = 'products_videos', String tenantId = 'store'}) async {
    try {
      // 1. Pick video using FilePicker (Cross-platform Windows Desktop & Mobile support)
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
        throw Exception('تعذر قراءة ملف الفيديو من الجهاز، يرجى المحاولة مع ملف آخر');
      }

      final cleanName = file.name.split(RegExp(r'[/\\]')).last.replaceAll(' ', '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uploadPath = '$tenantId/videos/${timestamp}_$cleanName';

      // 2. First priority: Supabase Storage (Works flawlessly in Iraq via Cloudflare Global CDN)
      try {
        await Supabase.instance.client.storage.from('product-media').uploadBinary(
          uploadPath,
          bytes,
          fileOptions: const FileOptions(contentType: 'video/mp4', upsert: true),
        );
        final publicUrl = Supabase.instance.client.storage.from('product-media').getPublicUrl(uploadPath);
        if (publicUrl.isNotEmpty) {
          return publicUrl;
        }
      } catch (supabaseError) {
        print('Supabase storage upload note: $supabaseError');
      }

      // 3. Optional Bunny CDN video service
      if (config.videoService == 'bunny' && config.videoApiKey.isNotEmpty) {
        final bunnyUrl = await _uploadBytesToBunny(cleanName, bytes);
        if (bunnyUrl != null) return bunnyUrl;
      }
      
      // 4. Fallback: Firebase Storage
      try {
        final fileName = '${timestamp}_$cleanName';
        final ref = FirebaseStorage.instance.ref().child(folder).child(fileName);
        final uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: 'video/mp4'),
        );
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        return downloadUrl;
      } catch (firebaseError) {
        print('Firebase storage upload note: $firebaseError');
      }

      throw Exception('فشل رفع الفيديو إلى السحابة. يمكنك لصق رابط الفيديو المباشر في الخانة المخصصة.');
    } catch (e) {
      print('CRITICAL VIDEO ERROR: $e');
      rethrow;
    }
  }

  Future<String?> _uploadBytesToBunny(String title, Uint8List bytes) async {
    try {
      final createUrl = 'https://video.bunnycdn.com/library/${config.videoLibraryId}/videos';
      final createResponse = await http.post(
        Uri.parse(createUrl),
        headers: {
          'AccessKey': config.videoApiKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({'title': title}),
      );

      if (createResponse.statusCode != 200) return null;
      final videoId = json.decode(createResponse.body)['guid'];

      final uploadUrl = 'https://video.bunnycdn.com/library/${config.videoLibraryId}/videos/$videoId';
      final uploadResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {'AccessKey': config.videoApiKey},
        body: bytes,
      );

      if (uploadResponse.statusCode == 200) {
        return 'https://iframe.mediadelivery.net/play/${config.videoLibraryId}/$videoId';
      }
    } catch (e) {
      print('Bunny upload error: $e');
    }
    return null;
  }
}

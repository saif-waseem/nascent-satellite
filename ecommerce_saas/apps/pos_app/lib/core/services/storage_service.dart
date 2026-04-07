import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
}

final storageServiceProvider = Provider((ref) {
  final configAsync = ref.watch(serviceConfigProvider);
  
  // If we have a value, use it. Otherwise use a fallback config with hardcoded ImgBB key
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

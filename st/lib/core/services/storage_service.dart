import 'package:image_picker/image_picker.dart';
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
      
      // Future providers (S3, Cloudinary) can be added here
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

  Future<String?> pickAndUploadVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return null;

      if (config.videoService == 'bunny') {
        return _uploadToBunny(video);
      }
      return null;
    } catch (e) {
      print('CRITICAL VIDEO ERROR: $e');
      rethrow;
    }
  }

  Future<String?> _uploadToBunny(XFile video) async {
    // 1. Create Placeholder
    final createUrl = 'https://video.bunnycdn.com/library/${config.videoLibraryId}/videos';
    final createResponse = await http.post(
      Uri.parse(createUrl),
      headers: {
        'AccessKey': config.videoApiKey,
        'Content-Type': 'application/json',
      },
      body: json.encode({'title': video.name}),
    );

    if (createResponse.statusCode != 200) return null;
    final videoId = json.decode(createResponse.body)['guid'];

    // 2. Upload Content
    final uploadUrl = 'https://video.bunnycdn.com/library/${config.videoLibraryId}/videos/$videoId';
    final bytes = await video.readAsBytes();
    
    final uploadResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: {'AccessKey': config.videoApiKey},
      body: bytes,
    );

    if (uploadResponse.statusCode == 200) {
      return 'https://iframe.mediadelivery.net/play/${config.videoLibraryId}/$videoId';
    }
    return null;
  }
}

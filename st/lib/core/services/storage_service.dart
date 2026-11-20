import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final String tenantId;
  final _picker = ImagePicker();
  StorageService(this.tenantId);

  Future<String> _upload(
    String folder,
    Uint8List bytes,
    String extension,
    String mime,
  ) async {
    if (tenantId.isEmpty || bytes.isEmpty) {
      throw StateError('تعذر تحديد المتجر أو قراءة الملف');
    }
    final path =
        '$tenantId/$folder/${DateTime.now().microsecondsSinceEpoch}.$extension';
    final bucket = Supabase.instance.client.storage.from('product-media');
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime),
    );
    return bucket.getPublicUrl(path);
  }

  Future<String> _image(String folder, XFile file) async {
    final ext = file.name.split('.').last.toLowerCase();
    final mime =
        file.mimeType ??
        const {
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'webp': 'image/webp',
          'gif': 'image/gif',
          'heic': 'image/heic',
          'heif': 'image/heif',
        }[ext];
    if (mime == null || !mime.startsWith('image/'))
      throw FormatException('صيغة الصورة غير مدعومة');
    return _upload(
      folder,
      await file.readAsBytes(),
      mime.split('/').last,
      mime,
    );
  }

  Future<String?> pickAndUploadImage(String folder) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (file == null) return null;
    return _image(folder, file);
  }

  Future<List<String>> pickAndUploadMultipleImages(String folder) async {
    final files = await _picker.pickMultiImage(imageQuality: 70);
    return [for (final file in files) await _image(folder, file)];
  }

  Future<String?> pickAndUploadVideo() async {
    const types = {
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'webm': 'video/webm',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      '3gp': 'video/3gpp',
    };
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: types.keys.toList(),
      withData: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    final ext = file.name.split('.').last.toLowerCase();
    final mime = types[ext];
    if (mime == null) throw FormatException('صيغة الفيديو غير مدعومة');
    return _upload(
      'videos',
      file.bytes ?? await file.xFile.readAsBytes(),
      ext,
      mime,
    );
  }
}

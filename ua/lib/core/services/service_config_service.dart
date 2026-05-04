import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ServiceConfig {
  final String imageService; // e.g., 'imgbb', 'cloudinary', 's3'
  final String imageApiKey;
  final String videoService; // e.g., 'bunny', 'mux', 'cloudinary'
  final String videoLibraryId;
  final String videoApiKey;
  final Map<String, dynamic> extra;

  ServiceConfig({
    required this.imageService,
    required this.imageApiKey,
    required this.videoService,
    required this.videoLibraryId,
    required this.videoApiKey,
    this.extra = const {},
  });

  factory ServiceConfig.fromJson(Map<String, dynamic> json) {
    return ServiceConfig(
      imageService: json['imageService'] ?? 'imgbb',
      imageApiKey: json['imageApiKey'] ?? '',
      videoService: json['videoService'] ?? 'bunny',
      videoLibraryId: json['videoLibraryId'] ?? '',
      videoApiKey: json['videoApiKey'] ?? '',
      extra: json['extra'] ?? {},
    );
  }
}

class ServiceConfigService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<ServiceConfig> watchConfig() {
    return _db.collection('system_config').doc('services').snapshots().map((snapshot) {
      if (!snapshot.exists) {
        // Default values if document doesn't exist
        return ServiceConfig(
          imageService: 'imgbb',
          imageApiKey: '4c2a2e4993d69bf3fe8bf8d09d1a2520',
          videoService: 'disabled',
          videoLibraryId: '',
          videoApiKey: '',
        );
      }
      return ServiceConfig.fromJson(snapshot.data()!);
    });
  }

  Future<void> updateConfig(ServiceConfig config) async {
    await _db.collection('system_config').doc('services').set({
      'imageService': config.imageService,
      'imageApiKey': config.imageApiKey,
      'videoService': config.videoService,
      'videoLibraryId': config.videoLibraryId,
      'videoApiKey': config.videoApiKey,
      'extra': config.extra,
    });
  }
}

final serviceConfigServiceProvider = Provider((ref) => ServiceConfigService());
final serviceConfigProvider = StreamProvider<ServiceConfig>((ref) {
  return ref.watch(serviceConfigServiceProvider).watchConfig();
});

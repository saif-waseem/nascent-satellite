import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ServiceConfig {
  final String imageService;
  final String imageApiKey;
  final String videoService;
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
      videoService: json['videoService'] ?? 'disabled',
      videoLibraryId: json['videoLibraryId'] ?? '',
      videoApiKey: json['videoApiKey'] ?? '',
      extra: json['extra'] ?? {},
    );
  }
}

class ServiceConfigService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<ServiceConfig> watchConfig() async* {
    while (true) {
      try {
        final snapshot = await _db.collection('system_config').doc('services').get();
        if (!snapshot.exists) {
          yield ServiceConfig(
            imageService: 'imgbb',
            imageApiKey: '4c2a2e4993d69bf3fe8bf8d09d1a2520',
            videoService: 'disabled',
            videoLibraryId: '',
            videoApiKey: '',
          );
        } else {
          yield ServiceConfig.fromJson(snapshot.data()!);
        }
      } catch (e) {
        yield ServiceConfig(
          imageService: 'imgbb',
          imageApiKey: '4c2a2e4993d69bf3fe8bf8d09d1a2520',
          videoService: 'disabled',
          videoLibraryId: '',
          videoApiKey: '',
        );
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }
}

final serviceConfigServiceProvider = Provider((ref) => ServiceConfigService());
final serviceConfigProvider = StreamProvider<ServiceConfig>((ref) {
  return ref.watch(serviceConfigServiceProvider).watchConfig();
});

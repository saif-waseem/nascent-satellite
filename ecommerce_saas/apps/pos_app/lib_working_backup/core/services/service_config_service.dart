import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'firestore_rest_service.dart';

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
  final FirestoreRestService _restService;

  ServiceConfigService(this._restService);

  Future<ServiceConfig> getConfig() async {
    final data = await _restService.getDocument('system_config/services');
    if (data == null) {
      return ServiceConfig(
        imageService: 'imgbb',
        imageApiKey: '4c2a2e4993d69bf3fe8bf8d09d1a2520',
        videoService: 'disabled',
        videoLibraryId: '',
        videoApiKey: '',
      );
    }
    return ServiceConfig.fromJson(data);
  }
}

final serviceConfigServiceProvider = Provider((ref) => ServiceConfigService(ref.watch(firestoreRestServiceProvider)));

final serviceConfigProvider = StreamProvider<ServiceConfig>((ref) {
  return Stream.fromFuture(ref.watch(serviceConfigServiceProvider).getConfig());
});

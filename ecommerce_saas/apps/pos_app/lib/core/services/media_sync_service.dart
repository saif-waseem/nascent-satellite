import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:io' as io;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'media_service.dart';
import '../../features/products/data/product_repository.dart';
import '../providers/tenant_provider.dart';
import '../providers/tenant_repository.dart';

class MediaSyncState {
  final bool isSyncing;
  final int totalToSync;
  final int syncedCount;
  final String? lastError;

  MediaSyncState({
    this.isSyncing = false,
    this.totalToSync = 0,
    this.syncedCount = 0,
    this.lastError,
  });

  MediaSyncState copyWith({
    bool? isSyncing,
    int? totalToSync,
    int? syncedCount,
    String? lastError,
  }) {
    return MediaSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      totalToSync: totalToSync ?? this.totalToSync,
      syncedCount: syncedCount ?? this.syncedCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

class MediaSyncNotifier extends Notifier<MediaSyncState> {
  StreamSubscription? _connectivitySub;
  Timer? _periodicTimer;

  @override
  MediaSyncState build() {
    _init();
    return MediaSyncState();
  }

  void _init() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncAll();
      }
    });

    _periodicTimer = Timer.periodic(const Duration(minutes: 15), (_) => syncAll());
    
    // Auto-dispose logic via ref.onDispose
    ref.onDispose(() {
      _connectivitySub?.cancel();
      _periodicTimer?.cancel();
    });
  }

  Future<void> syncAll() async {
    // 1. Skip on Web: Web storage handles XFiles directly, no local filesystem background sync needed.
    if (kIsWeb) return;
    
    // 2. Skip on Windows (Native): C++ Desktop plugin threading crashes in background.
    if (defaultTargetPlatform == TargetPlatform.windows) return;
    
    if (state.isSyncing) return;

    final tenantId = ref.read(tenantIdProvider);
    if (tenantId.isEmpty) return;

    state = state.copyWith(isSyncing: true, lastError: null, syncedCount: 0, totalToSync: 0);

    try {
      final repo = ref.read(productRepositoryProvider);
      final mediaService = ref.read(mediaServiceProvider);
      
      final products = await repo.getProducts(tenantId);
      final productsToSync = products.where((p) => p.images.any((img) => mediaService.isLocalPath(img))).toList();

      if (productsToSync.isEmpty) {
        state = state.copyWith(isSyncing: false);
        return;
      }

      state = state.copyWith(totalToSync: productsToSync.length);

      for (var product in productsToSync) {
        final List<String> newImages = [];
        bool changed = false;

        for (var img in product.images) {
          if (mediaService.isLocalPath(img)) {
            final file = io.File(img);
            if (await file.exists()) {
              final url = await mediaService.uploadFile(file, tenantId, 'products');
              if (url != null) {
                newImages.add(url);
                changed = true;
              } else {
                newImages.add(img); // Keep local for retry
              }
            } else {
              // File missing, remove reference to avoid repeated errors
              changed = true;
            }
          } else {
            newImages.add(img);
          }
        }

        if (changed) {
          await repo.saveProduct(tenantId, product.copyWith(images: newImages));
        }
        
        state = state.copyWith(syncedCount: state.syncedCount + 1);
      }

      // Sync Tenant Logo
      final tenantRepo = ref.read(tenantRepositoryProvider);
      final tenant = ref.read(tenantProvider).value;
      if (tenant != null && tenant.logoUrl != null && mediaService.isLocalPath(tenant.logoUrl!)) {
        final file = io.File(tenant.logoUrl!);
        if (await file.exists()) {
          final url = await mediaService.uploadFile(file, tenantId, 'logos');
          if (url != null) {
            await tenantRepo.updateTenant(tenant.copyWith(logoUrl: url));
          }
        }
      }
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }
}

final mediaSyncProvider = NotifierProvider<MediaSyncNotifier, MediaSyncState>(MediaSyncNotifier.new);

import '../services/cashier_stock_service.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../services/local_db_service.dart';
import '../services/firestore_rest_service.dart';
import '../models/sync_queue_item.dart';
import '../services/firebase_rest_auth_service.dart';
import 'tenant_provider.dart';
import '../../features/common/data/app_settings_repository.dart';

enum SyncState { synced, syncing, offline, localOnly, error }

class SyncStatus {
  final SyncState syncState;
  final bool isOnline;
  final bool isCloudAllowed;
  final int pendingWritesCount;

  SyncStatus({
    required this.syncState,
    required this.isOnline,
    this.isCloudAllowed = false,
    this.pendingWritesCount = 0,
  });

  SyncStatus copyWith({
    SyncState? syncState,
    bool? isOnline,
    bool? isCloudAllowed,
    int? pendingWritesCount,
  }) {
    return SyncStatus(
      syncState: syncState ?? this.syncState,
      isOnline: isOnline ?? this.isOnline,
      isCloudAllowed: isCloudAllowed ?? this.isCloudAllowed,
      pendingWritesCount: pendingWritesCount ?? this.pendingWritesCount,
    );
  }
}

class SyncStatusNotifier extends Notifier<SyncStatus> {
  StreamSubscription? _connectivitySub;
  StreamSubscription? _queueSub;
  bool _running = false;
  bool _needsAnotherPass = false;
  Timer? _retry;

  bool get _canCloudSync {
    final tenant = ref.read(tenantProvider).value;
    final settings = ref.read(appSettingsProvider).value;
    if (tenant == null || !tenant.isPosCloudAllowed) return false;
    if (settings != null && !settings.isCloudSyncEnabled) return false;
    return true;
  }

  @override
  SyncStatus build() {
    this.ref.onDispose(() {
      _connectivitySub?.cancel();
      _queueSub?.cancel();
      _retry?.cancel();
    });

    final tenant = ref.watch(tenantProvider).value;
    final settings = ref.watch(appSettingsProvider).value;
    final cloudAllowed = tenant?.isPosCloudAllowed ?? false;
    final canSync = cloudAllowed && (settings?.isCloudSyncEnabled ?? true);

    ref.listen(firestoreRestServiceProvider, (_, service) {
      if (service.authToken != null && _canCloudSync) {
        scheduleMicrotask(syncPending);
      }
    });
    _init();

    return SyncStatus(
      syncState: canSync ? SyncState.synced : SyncState.localOnly,
      isOnline: true,
      isCloudAllowed: cloudAllowed,
      pendingWritesCount: LocalDbService.getBox<SyncQueueItem>(
        'sync_queue',
      ).length,
    );
  }

  void _init() {
    final box = LocalDbService.getBox<SyncQueueItem>('sync_queue');

    // Watch queue changes
    _queueSub = box.watch().listen((_) {
      state = state.copyWith(pendingWritesCount: box.length);
      if (state.isOnline && _canCloudSync) {
        syncPending();
      }
      _updateSyncState();
    });

    // Connectivity
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      state = state.copyWith(isOnline: isOnline);
      if (isOnline && _canCloudSync) {
        syncPending();
      }
      _updateSyncState();
    });
  }

  void _updateSyncState() {
    final tenant = ref.read(tenantProvider).value;
    final cloudAllowed = tenant?.isPosCloudAllowed ?? false;
    if (!_canCloudSync) {
      state = state.copyWith(
        syncState: SyncState.localOnly,
        isCloudAllowed: cloudAllowed,
      );
      return;
    }
    if (!state.isOnline) {
      state = state.copyWith(syncState: SyncState.offline, isCloudAllowed: true);
    } else if (state.pendingWritesCount > 0) {
      state = state.copyWith(syncState: SyncState.syncing, isCloudAllowed: true);
    } else {
      state = state.copyWith(syncState: SyncState.synced, isCloudAllowed: true);
    }
  }

  Future<void> syncPending() async {
    if (!_canCloudSync) {
      _updateSyncState();
      return;
    }
    if (!state.isOnline || state.pendingWritesCount == 0) return;
    if (_running) {
      _needsAnotherPass = true;
      return;
    }

    _running = true;
    try {
      do {
        _needsAnotherPass = false;
        state = state.copyWith(syncState: SyncState.syncing);
        final box = LocalDbService.getBox<SyncQueueItem>('sync_queue');
        if (box.isEmpty) break;

        final items = box.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        for(final item in items) {
          if(item.data['_primaryDone']==true)continue;
          final isCatalog=item.collectionPath.startsWith('catalog/');
          final movements=item.data['_stockMovements'];
          if(!isCatalog && !(movements is List && item.collectionPath.startsWith('sales_invoices/')))continue;
          try{
            final service=ref.read(cashierStockProvider);
            if(isCatalog){await service.writeProduct(item.id,item.data);}
            else{await service.submit(item.data['tenantId'] as String,movements as List);}
            item.data['_primaryDone']=true;
            await item.save();
          }catch(e){
            debugPrint('Supabase sync warning for ${item.collectionPath}: $e');
            // Proceed to Firestore backup to ensure products are never lost
          }
        }
        if (!await ref.read(authRestServiceProvider.notifier).ensureSession()) return;
        final backupService=ref.read(firestoreRestServiceProvider);
        for (final item in items) {
          try {
            if(item.collectionPath.startsWith('catalog/')){
              final snapshot=item.data['backup'];
              if(snapshot==null){await backupService.deleteDocument('products/${item.id}');}
              else{await backupService.setDocument('products/${item.id}',Map<String,dynamic>.from(snapshot as Map),isUpdate:true);}
              await box.delete(item.key);continue;
            }
            if (item.action == SyncAction.create ||
                item.action == SyncAction.update) {
              final data = Map<String, dynamic>.from(item.data);
              final movements = data.remove('_stockMovements');
              data.remove('_primaryDone');
              await backupService.setDocument(
                item.collectionPath,
                data,
                isUpdate:
                    movements != null || item.action == SyncAction.update ||
                    item.collectionPath.startsWith('products/'),
              );
            } else if (item.action == SyncAction.delete) {
              await backupService.deleteDocument(item.collectionPath);
            }
            await box.delete(item.key);
          } catch (e) {
            debugPrint('Sync failed for item ${item.id}: $e');
            state = state.copyWith(syncState: SyncState.error);
            return; // Stop sync on first error to preserve order
          }
        }
      } while (_needsAnotherPass && state.isOnline);

      _updateSyncState();
    } finally {
      _running = false;
      _retry?.cancel();
      if (ref.mounted &&
          _canCloudSync &&
          LocalDbService.getBox<SyncQueueItem>('sync_queue').isNotEmpty) {
        _retry = Timer(const Duration(seconds: 15), syncPending);
      }
    }
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

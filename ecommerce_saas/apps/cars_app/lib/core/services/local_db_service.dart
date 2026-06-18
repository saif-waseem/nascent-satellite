import 'package:hive_ce_flutter/hive_ce_flutter.dart';
export 'package:hive_ce/hive.dart';
import 'package:shared_models/shared_models.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sync_queue_item.dart';

class LocalDbService {
  static Future<void> init() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocDir.path);

    // Register Adapters
    Hive.registerAdapter(TenantModelAdapter());
    Hive.registerAdapter(CarContractModelAdapter());
    Hive.registerAdapter(SyncActionAdapter());
    Hive.registerAdapter(SyncQueueItemAdapter());
    
    // Open Boxes
    await Hive.openBox<TenantModel>('tenants');
    await Hive.openBox<CarContractModel>('car_contracts');
    await Hive.openBox<SyncQueueItem>('sync_queue');
  }

  static Box<T> getBox<T>(String name) => Hive.box<T>(name);

  static Future<void> addToSyncQueue({
    required String collectionPath,
    required Map<String, dynamic> data,
    required SyncAction action,
  }) async {
    final box = getBox<SyncQueueItem>('sync_queue');
    final id = data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    await box.add(SyncQueueItem(
      id: id,
      collectionPath: collectionPath,
      data: data,
      action: action,
      createdAt: DateTime.now(),
    ));
  }
}

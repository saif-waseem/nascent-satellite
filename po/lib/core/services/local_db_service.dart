import 'package:hive_ce_flutter/hive_ce_flutter.dart';
export 'package:hive_ce/hive.dart';
import 'package:shared_models/shared_models.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sync_queue_item.dart';

class LocalDbService {
  static Future<void> init() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocDir.path);

    // Register All Adapters from shared_models
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ProductVariantAdapter());
    Hive.registerAdapter(ProductStorageLocationAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(TenantModelAdapter());
    Hive.registerAdapter(UserModelAdapter());

    Hive.registerAdapter(SalesInvoiceModelAdapter());
    Hive.registerAdapter(SalesItemAdapter());
    Hive.registerAdapter(SalesInvoiceStatusAdapter());
    Hive.registerAdapter(PurchaseInvoiceModelAdapter());
    Hive.registerAdapter(InvoiceItemAdapter());
    Hive.registerAdapter(PurchaseInvoiceStatusAdapter());

    Hive.registerAdapter(CustomerModelAdapter());
    Hive.registerAdapter(ExpenseModelAdapter());
    Hive.registerAdapter(SupplierModelAdapter());
    Hive.registerAdapter(StaffMemberModelAdapter());
    Hive.registerAdapter(PosRoleModelAdapter());
    Hive.registerAdapter(AttendanceModelAdapter());

    // Sync Queue
    Hive.registerAdapter(SyncActionAdapter());
    Hive.registerAdapter(SyncQueueItemAdapter());
    
    // Open Common Boxes
    await Hive.openBox<ProductModel>('products');
    await Hive.openBox<CategoryModel>('categories');
    await Hive.openBox<SalesInvoiceModel>('sales');
    await Hive.openBox<PurchaseInvoiceModel>('purchases');
    await Hive.openBox<SupplierModel>('suppliers');
    await Hive.openBox<CustomerModel>('customers');
    await Hive.openBox<ExpenseModel>('expenses');
    await Hive.openBox<StaffMemberModel>('staff');
    await Hive.openBox<TenantModel>('tenants');
    await Hive.openBox<SyncQueueItem>('sync_queue');

  }

  // Helper methods to interact with boxes
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

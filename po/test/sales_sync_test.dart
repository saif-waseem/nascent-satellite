import 'dart:io';
import 'package:pos_app/features/reports/data/report_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_app/core/services/cashier_stock_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:pos_app/core/services/local_db_service.dart';
import 'package:pos_app/core/models/sync_queue_item.dart';
import 'package:pos_app/features/sales/data/sales_repository.dart';
import 'package:pos_app/core/services/firestore_rest_service.dart';
import 'package:pos_app/core/providers/tenant_provider.dart';

// Mock PathProvider for Hive
class MockPathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '.';
}

// Mock REST Service to simulate offline or background processing
class MockFirestoreRestService extends FirestoreRestService {
  MockFirestoreRestService() : super(projectId: 'test', apiKey: 'test');
  
  bool failNextRequest = false;
  
  @override
  Future<void> setDocument(String path, Map<String, dynamic> data, {bool isUpdate = false}) async {
    if (failNextRequest) {
      throw Exception('Network Error: Simulated offline mode');
    }
    // Simulate successful save
  }
}

class MockTenantIdNotifier extends TenantIdNotifier {
  @override
  String build() => 'tenant_1';
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'stock_linked_tenant_1': true});
    PathProviderPlatform.instance = MockPathProviderPlatform();
    // Initialize Hive for testing
    final directory = await Directory.systemTemp.createTemp('pos-sales-test-');
    Hive.init(directory.path);
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    
    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ProductVariantAdapter());
    Hive.registerAdapter(ProductStorageLocationAdapter());
    Hive.registerAdapter(CustomerModelAdapter());
    Hive.registerAdapter(TenantModelAdapter());
    Hive.registerAdapter(SalesInvoiceModelAdapter());
    Hive.registerAdapter(SalesItemAdapter());
    Hive.registerAdapter(SalesInvoiceStatusAdapter());
    Hive.registerAdapter(SyncActionAdapter());
    Hive.registerAdapter(SyncQueueItemAdapter());

    Hive.registerAdapter(PurchaseInvoiceModelAdapter());
    Hive.registerAdapter(PurchaseInvoiceStatusAdapter());
    await Hive.openBox<ExpenseModel>('expenses');
    await Hive.openBox<PurchaseInvoiceModel>('purchases');
    await Hive.openBox<CategoryModel>('categories');
    // Open required boxes
    await Hive.openBox<ProductModel>('products');
    await Hive.openBox<CustomerModel>('customers');
    await Hive.openBox<TenantModel>('tenants');
    await Hive.openBox<SalesInvoiceModel>('sales');
    await Hive.openBox<SyncQueueItem>('sync_queue');
  });

  tearDown(() async {
    await Hive.box<ProductModel>('products').clear();
    await Hive.box<CustomerModel>('customers').clear();
    await Hive.box<TenantModel>('tenants').clear();
    await Hive.box<SalesInvoiceModel>('sales').clear();
    await Hive.box<SyncQueueItem>('sync_queue').clear();
  });

  test('report reconciles partial refunds and discounts through the last millisecond', () async {
    final day = DateTime(2026, 11, 20);
    final sales = Hive.box<SalesInvoiceModel>('sales');
    await Hive.box<ProductModel>('products').put('p', const ProductModel(id:'p',tenantId:'test',name:'Shirt',description:'',category:'Clothes',price:100,purchasePrice:40,stockQuantity:10));
    final invoice = SalesInvoiceModel(id:'sale',receiptNumber:'1',tenantId:'test',date:day,sessionName:'online',totalAmount:190,paidAmount:150,items:const [SalesItem(productId:'p',productName:'Shirt',quantity:2,unitPrice:100)]);
    await sales.put('sale', invoice);
    await sales.put('refund', invoice.copyWith(isReturned:true,totalAmount:95,paidAmount:95,date:DateTime(2026,11,20,23,59,59,999),items:const [SalesItem(productId:'p',productName:'Shirt',quantity:1,unitPrice:100)]));
    await sales.put('draft', invoice.copyWith(status:SalesInvoiceStatus.draft));
    await sales.put('tomorrow', invoice.copyWith(date:DateTime(2026,11,21)));
    final purchases = Hive.box<PurchaseInvoiceModel>('purchases');
    final purchase = PurchaseInvoiceModel(id:'purchase',tenantId:'test',supplierId:'s',items:[],totalAmount:100,paidAmount:35,date:day);
    await purchases.put('purchase',purchase);
    await purchases.put('draft',purchase.copyWith(status:PurchaseInvoiceStatus.draft));
    final result=await ReportRepository(MockFirestoreRestService()).getFinancialReport('test',start:day,end:day);
    expect(result.salesCount,1);
    expect(result.totalSales,95);
    expect(result.salesPayments,55);
    expect(result.totalPurchases,100);
    expect(result.purchasePayments,35);
    expect(result.onlineSales,95);
    expect(result.grossProfit,55);
    expect(result.profitByProduct['Shirt'],55);
    expect(result.salesTrend.values.single,95);
    expect(result.profitTrend.values.single,55);
    expect(result.salesByProduct['Shirt'],1);
  });

  test('Sales Invoice creation adds data to local box and Sync Queue', () async {
    // Setup initial data
    final productBox = Hive.box<ProductModel>('products');
    final customerBox = Hive.box<CustomerModel>('customers');
    final tenantBox = Hive.box<TenantModel>('tenants');
    
    await productBox.put('prod_1', ProductModel(
      id: 'prod_1',
      name: 'Test Product',
      barcode: '123',
      price: 1000,
      stockQuantity: 10,
      category: 'General',
      description: 'Test Description',
      tenantId: 'tenant_1',
    ));

    await customerBox.put('cust_1', CustomerModel(
      id: 'cust_1',
      name: 'Test Customer',
      phoneNumber: '07700000000',
      tenantId: 'tenant_1',
      createdAt: DateTime.now(),
    ));

    await tenantBox.put('tenant_1', TenantModel(
      id: 'tenant_1',
      name: 'Test Tenant',
      adminIds: const ['admin_1'],
      createdAt: DateTime.now(),
    ));

    // Setup ProviderContainer with Mock
    final container = ProviderContainer(
      overrides: [
        firestoreRestServiceProvider.overrideWithValue(MockFirestoreRestService()),
        tenantIdProvider.overrideWith(() => MockTenantIdNotifier()),
      ],
    );

    final salesRepository = container.read(salesRepositoryProvider);

    // Create a new Invoice
    final newInvoice = SalesInvoiceModel(
      id: '', // Empty ID, should be generated
      receiptNumber: '',
      tenantId: 'tenant_1',
      addedById: 'staff_1',
      sessionName: 'shift_1',
      customerId: 'cust_1',
      items: const [
        SalesItem(
          productId: 'prod_1',
          productName: 'Test Product',
          quantity: 2,
          unitPrice: 1000,
        ),
      ],
      totalAmount: 2000,
      paidAmount: 2000,
      date: DateTime.now(),
      status: SalesInvoiceStatus.finalized,
    );

    // Act
    await salesRepository.saveInvoice('tenant_1', newInvoice);

    // Assert: Local Sales Box
    final salesBox = Hive.box<SalesInvoiceModel>('sales');
    expect(salesBox.length, 1, reason: 'Invoice should be saved locally');
    
    final savedInvoice = salesBox.values.first;
    expect(savedInvoice.totalAmount, 2000);

    // Assert: Local Product Box updated (Stock deduced)
    final updatedProduct = productBox.get('prod_1');
    expect(updatedProduct!.stockQuantity, 8, reason: 'Stock should be reduced from 10 to 8');

    // Assert: Sync Queue
    final syncQueueBox = Hive.box<SyncQueueItem>('sync_queue');
    
    // We expect 3 items in the sync queue:
    // 1. The Sales Invoice
    // 2. The Updated Product
    // 3. The Updated Customer
    expect(syncQueueBox.length, 3, reason: 'Sync queue should have Invoice, Product, and Customer updates');

    final queueItems = syncQueueBox.values.toList();
    final invoiceSyncItem = queueItems.firstWhere((item) => item.collectionPath.startsWith('sales_invoices/'));
    final movements = invoiceSyncItem.data['_stockMovements'] as List;
    expect(movements.single['product'], 'prod_1');
    expect(movements.single['delta'], -2);
    expect(movements.single['operation'], CashierStockService.movements(savedInvoice, (id) => productBox.get(id)).single['operation']);
    expect(invoiceSyncItem.action, SyncAction.create);
    expect(invoiceSyncItem.data['totalAmount'], 2000);

    final productSyncItem = queueItems.firstWhere((item) => item.collectionPath.startsWith('products/'));
    expect(productSyncItem.action, SyncAction.update);
    expect(productSyncItem.data['stockQuantity'], 8);

    print('✅ Test Passed: Invoice successfully created locally and queued for synchronization.');
  });
}

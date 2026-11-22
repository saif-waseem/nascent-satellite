import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../core/services/cashier_stock_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/models/sync_queue_item.dart';
import '../../../core/providers/sync_status_provider.dart';

final productRepositoryProvider = Provider((ref) => ProductRepository(ref));

final productStockVersionProvider = NotifierProvider<ProductStockVersionNotifier, int>(ProductStockVersionNotifier.new);

class ProductStockVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state++;
  }
}

class ProductRepository {
  final Ref _ref;
  FirestoreRestService get _restService => _ref.read(firestoreRestServiceProvider);

  ProductRepository(this._ref);
  Box<ProductModel> get box => _box;
  Box<ProductModel> get _box => LocalDbService.getBox<ProductModel>('products');

  static bool _hasRepairedIntegrity = false;

  void _notifyStockChanged() {
    _ref.read(productStockVersionProvider.notifier).increment();
  }

  Future<List<ProductModel>> getProducts(String tenantId, {int limit = 50}) async {
    // Perform self-healing once per session
    if (!_hasRepairedIntegrity) {
      _hasRepairedIntegrity = true;
      repairAllProductsIntegrity();
    }

    // 1. Return cached products first for immediate UI update
    final cached = _box.values.where((p) => p.tenantId == tenantId && !p.isArchived).toList();
    cached.sort((a, b) => a.name.compareTo(b.name));
    
    if (tenantId == 'local_default') return cached;

    // Immediately return local cache if offline to avoid overwriting from old HTTP query cache
    final isOnline = _ref.read(syncStatusProvider).isOnline;
    if (!isOnline) {
      return cached;
    }

    // 2. Fetch from remote in background (if online)
    try {
      List<ProductModel> remoteProducts;
      bool primary=true;
      try{remoteProducts=await ProductCatalog.read(tenantId);}catch(_){primary=false;
      final query = {
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'tenantId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': tenantId}
                }
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'isArchived'},
                  'op': 'EQUAL',
                  'value': {'booleanValue': false}
                }
              }
            ]
          }
        },
        'limit': 500, // Fetch more for caching
      };

      final results = await _restService.runQuery('products', query);
      remoteProducts = results.map(ProductModel.fromJson).toList();
      }
      
      // Update cache (Merge strategy)
      final syncQueueBox = LocalDbService.getBox<SyncQueueItem>('sync_queue');
      final pending = <String>{for(final item in syncQueueBox.values)
        if(item.collectionPath.startsWith('products/') || item.collectionPath.startsWith('catalog/')) item.collectionPath.split('/').last,
        for(final item in syncQueueBox.values) if(item.data['_stockMovements'] is List)
          for(final movement in item.data['_stockMovements'] as List) movement['product'] as String};
      if(primary){
        final ids=remoteProducts.map((p)=>p.id).toSet();
        for(final p in _box.values.where((p)=>p.tenantId==tenantId && !ids.contains(p.id) && !pending.contains(p.id)).toList()){
          await _box.delete(p.id);
        }
      }
      for (var p in remoteProducts) {
        if(pending.contains(p.id)){
          continue;
        }

        final local = _box.get(p.id);
        if (local == null || local.toJson().toString() != p.toJson().toString()) {
          await _box.put(p.id, p);
        }
      }
      
      // Cleanup locally deleted products that still exist in Firestore (optional but usually handled by archiving)
      
      remoteProducts.sort((a, b) => a.name.compareTo(b.name));
      return _box.values.where((p)=>p.tenantId==tenantId&&!p.isArchived).toList()..sort((a,b)=>a.name.compareTo(b.name));
    } catch (e) {
      debugPrint('Offline/Error fetching products: $e');
      return cached;
    }
  }

  Future<List<ProductModel>> _sharedBalances(String tenant, List<ProductModel> products) async {
    if (tenant == 'local_default' || products.isEmpty) return products;
    final service = _ref.read(cashierStockProvider);
    if (!await service.linked(tenant)) return products;
    try {
      final balances = await service.balances(tenant, products.where((p) => p.variants.isEmpty).map((p) => p.id));
      final pending = <String>{};
      for (final item in LocalDbService.getBox<SyncQueueItem>('sync_queue').values) {
        final lines = item.data['_stockMovements'];
        if (lines is List && item.data['tenantId'] == tenant) {
          for (final line in lines) { pending.add(line['product'] as String); }
        }
      }
      final merged = <ProductModel>[];
      for (final p in products) {
        final local = _box.get(p.id) ?? p;
        final quantity = balances[p.id];
        if (pending.contains(p.id) || quantity == null || local.variants.isNotEmpty) {
          merged.add(local);
        } else {
          final updated = local.copyWith(stockQuantity: quantity, inStock: quantity > 0);
          if (local.stockQuantity != quantity || local.inStock != updated.inStock) await _box.put(p.id, updated);
          merged.add(updated);
        }
      }
      return merged;
    } catch (e) {
      debugPrint('Stock balance refresh: $e');
      return products;
    }
  }

  /// Recalculates total stock based on variants and storage locations to ensure integrity
  ProductModel _ensureDataIntegrity(ProductModel product) {
    List<ProductVariant> updatedVariants = List.from(product.variants);
    
    for (int i = 0; i < updatedVariants.length; i++) {
      final v = updatedVariants[i];
      
      // SELF-HEALING: If variant has stock but NO storage locations, create a default one
      if (v.stock > 0 && v.storageLocations.isEmpty) {
        updatedVariants[i] = v.copyWith(
          storageLocations: [ProductStorageLocation(warehouseName: 'المخزن الرئيسي', quantity: v.stock)],
        );
      }
      
      // Recalculate based on locations
      final currentV = updatedVariants[i];
      if (currentV.storageLocations.isNotEmpty) {
        final calculatedVStock = currentV.storageLocations.fold(0, (sum, loc) => sum + loc.quantity);
        updatedVariants[i] = currentV.copyWith(stock: calculatedVStock);
      }
    }
    
    // Sum up all variants for total stock
    final calculatedTotalStock = updatedVariants.isEmpty ? product.stockQuantity : updatedVariants.fold(0, (sum, v) => sum + v.stock);
    
    return product.copyWith(
      stockQuantity: calculatedTotalStock,
      variants: updatedVariants,
      inStock: calculatedTotalStock > 0,
    );
  }

  final undo = const CatalogUndo('cashier');
  Future<void> undoEntry(String tenant,Map<String,dynamic> entry) async {
    final current=_box.get(entry['id']);
    if(current==null || current.tenantId!=tenant) throw StateError('الصنف غير متاح');
    final row=CatalogUndo.restore(ProductCatalog.encode(current),entry);
    await saveProduct(tenant,ProductCatalog.decode(row),recordUndo:false,undoExpected:Map<String,dynamic>.from(entry['expected'] as Map));
  }
  Future<void> saveProduct(String tenantId, ProductModel product,{String? batchId,bool recordUndo=true,Map<String,dynamic>? undoExpected}) async {
    final productId = product.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : product.id;
    
    // Force integrity before saving
    final productWithIntegrity = _ensureDataIntegrity(product);
    
    final updatedProduct = productWithIntegrity.copyWith(
      id: productId,
      tenantId: tenantId,
    );
    
    final previous = _box.get(productId);
    if(tenantId!='local_default') await _queueCatalog(tenantId,productId,previous,updatedProduct,undoExpected:undoExpected);
    // Always save to local first
    await _box.put(productId, updatedProduct);
    if(recordUndo) await undo.record(tenantId,previous,updatedProduct,batchId);

    // Notify UI of local update
    _notifyStockChanged();

    if (tenantId == 'local_default') return;
    unawaited(_ref.read(syncStatusProvider.notifier).syncPending());
  }

  Future<void> _queueCatalog(String tenant,String id,ProductModel? before,ProductModel? after,{Map<String,dynamic>? undoExpected}) async {
    final previous=before==null?<String,dynamic>{}:ProductCatalog.encode(before);
    final next=after==null?<String,dynamic>{}:ProductCatalog.encode(after);
    final patch={for(final e in next.entries)
      if(!{'id','tenant_id','rating','sales_count'}.contains(e.key) && (before==null || jsonEncode(previous[e.key])!=jsonEncode(e.value))) e.key:e.value};
    if(after!=null && before!=null && patch.isEmpty)return;
    await LocalDbService.addToSyncQueue(collectionPath:'catalog/$id',action:SyncAction.update,data:{
      'id':id,'tenantId':tenant,'operation':const Uuid().v4(),'action':after==null?'delete':before==null?'create':'patch',
      'patch':patch,'before':{...?undoExpected,if(before!=null)for(final key in patch.keys)key:previous[key]},
      'backup':after?.toJson(),
    });
  }

  /// Recalculates total stock based on variants and storage locations to ensure integrity
  ProductModel recalculateIntegrity(ProductModel product) {
    return _ensureDataIntegrity(product);
  }

  /// Utility to fix all products in the box
  Future<void> repairAllProductsIntegrity() async {
    final allProducts = _box.values.toList();
    int fixedCount = 0;
    
    for (var p in allProducts) {
      final repaired = _ensureDataIntegrity(p);
      if (repaired.stockQuantity != p.stockQuantity || repaired.variants != p.variants) {
        await _box.put(p.id, repaired);
        fixedCount++;
      }
    }
    debugPrint('Data Integrity: Repaired $fixedCount products.');
  }

  Future<void> deleteProduct(String tenantId, String productId, {bool permanent = false}) async {
    final previous=_box.get(productId);
    if(previous==null || previous.tenantId!=tenantId)return;
    if(tenantId!='local_default')await _queueCatalog(tenantId,productId,previous,permanent?null:previous.copyWith(isArchived:true));
    // Local delete
    if (permanent) {
      await _box.delete(productId);
    } else {
      final p = _box.get(productId);
      if (p != null) await _box.put(productId, p.copyWith(isArchived: true));
    }

    // Notify UI of local update
    _notifyStockChanged();

    if (tenantId == 'local_default') return;
    unawaited(_ref.read(syncStatusProvider.notifier).syncPending());
  }

  Future<ProductModel?> getProductByBarcode(String tenantId, String barcode) async {
    // 1. Absolute Priority: Local Search
    try {
      final localMatch = _box.values.where((p) => p.tenantId==tenantId && p.barcode == barcode && !p.isArchived).firstOrNull;
      if (localMatch != null) {
        return _ensureDataIntegrity(localMatch);
      }
    } catch (e) {
      debugPrint('Local Barcode Lookup Error: $e');
    }

    if (tenantId == 'local_default') return null;
      
    try {return (await ProductCatalog.read(tenantId,barcode:barcode)).where((p)=>!p.isArchived).firstOrNull;}catch(_){}
    try {
      final query = {
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {'fieldFilter': {'field': {'fieldPath': 'tenantId'}, 'op': 'EQUAL', 'value': {'stringValue': tenantId}}},
              {'fieldFilter': {'field': {'fieldPath': 'barcode'}, 'op': 'EQUAL', 'value': {'stringValue': barcode}}},
              {'fieldFilter': {'field': {'fieldPath': 'isArchived'}, 'op': 'EQUAL', 'value': {'booleanValue': false}}}
            ]
          }
        },
        'limit': 1,
      };
      final results = await _restService.runQuery('products', query);
      if (results.isEmpty) return null;
      final p = ProductModel.fromJson(results.first);
      final withIntegrity = _ensureDataIntegrity(p);
      await _box.put(p.id, withIntegrity);
      return withIntegrity;
    } catch (e) {
      debugPrint('Remote Barcode Lookup Failed (Offline?): $e');
      return null;
    }
  }

  Future<void> updateProduct(String tenantId, String productId, ProductModel updatedProduct) async {
    await saveProduct(tenantId,updatedProduct.copyWith(id:productId));
  }

  Future<void> updateStock(String tenantId, String productId, int adjustment, {bool invoiceMovement=false,String? color, String? size, String? warehouseName, double? priceOverride}) async {
    final product = _box.get(productId);
    if (product == null) return;

    List<ProductVariant> updatedVariants = List.from(product.variants);
    bool variantFound = false;

    if (color != null || size != null) {
      for (int i = 0; i < updatedVariants.length; i++) {
        final v = updatedVariants[i];
        if (v.color == (color ?? 'Default') && v.size == (size ?? 'Default')) {
          variantFound = true;
          List<ProductStorageLocation> updatedLocs = List.from(v.storageLocations);
          
          if (updatedLocs.isEmpty) {
            updatedLocs.add(ProductStorageLocation(
              warehouseName: warehouseName ?? 'المخزن الرئيسي', 
              quantity: adjustment,
              priceOverride: priceOverride,
            ));
          } else {
            // Find specific warehouse if provided
            int locIdx = 0;
            if (warehouseName != null) {
              locIdx = updatedLocs.indexWhere((l) => l.warehouseName == warehouseName);
              if (locIdx == -1) {
                updatedLocs.add(ProductStorageLocation(warehouseName: warehouseName, quantity: 0));
                locIdx = updatedLocs.length - 1;
              }
            }
            
            final target = updatedLocs[locIdx];
            updatedLocs[locIdx] = target.copyWith(
              quantity: (target.quantity + adjustment).clamp(0, 999999),
              priceOverride: priceOverride ?? target.priceOverride,
            );
          }

          final newVStock = updatedLocs.fold(0, (sum, loc) => sum + loc.quantity);
          updatedVariants[i] = v.copyWith(
            stock: newVStock,
            storageLocations: updatedLocs,
          );
          break;
        }
      }
    }

    // If no specific variant found but adjustment is needed
    if (!variantFound && updatedVariants.isNotEmpty) {
        final v = updatedVariants[0];
        List<ProductStorageLocation> updatedLocs = List.from(v.storageLocations);
        int locIdx = 0;
        if (warehouseName != null) {
          locIdx = updatedLocs.indexWhere((l) => l.warehouseName == warehouseName);
          if (locIdx == -1) {
            updatedLocs.add(ProductStorageLocation(warehouseName: warehouseName, quantity: 0));
            locIdx = updatedLocs.length - 1;
          }
        } else if (updatedLocs.isEmpty) {
           updatedLocs.add(ProductStorageLocation(warehouseName: 'المخزن الرئيسي', quantity: 0));
        }

        final target = updatedLocs[locIdx];
        updatedLocs[locIdx] = target.copyWith(
          quantity: (target.quantity + adjustment).clamp(0, 999999),
          priceOverride: priceOverride ?? target.priceOverride,
        );
        
        final newVStock = updatedLocs.fold(0, (sum, loc) => sum + loc.quantity);
        updatedVariants[0] = v.copyWith(stock: newVStock, storageLocations: updatedLocs);
    }

    final newTotalStock = updatedVariants.isEmpty ? (product.stockQuantity + adjustment).clamp(0, 999999).toInt() : updatedVariants.fold(0, (sum, v) => sum + v.stock);

    final updatedProduct = product.copyWith(
      stockQuantity: newTotalStock,
      inStock: newTotalStock > 0,
      variants: updatedVariants,
    );
    
    if(tenantId!='local_default' && (!invoiceMovement || product.variants.isNotEmpty)){
      await _queueCatalog(tenantId,productId,product,updatedProduct);
      await _box.put(productId,updatedProduct);
      _notifyStockChanged();return;
    }
    await _box.put(productId, updatedProduct);
    _notifyStockChanged();
    if (tenantId == 'local_default') return;
    try {
      await _restService.setDocument('products/$productId', updatedProduct.toJson(), isUpdate: true);
    } catch (e) {
      await LocalDbService.addToSyncQueue(
        collectionPath: 'products/$productId', 
        data: updatedProduct.toJson(), 
        action: SyncAction.update
      );
    }
  }

  Future<void> returnStock(String tenantId, String productId, int quantity, {String? color, String? size, String? warehouseName}) async {
    // Simply use updateStock with positive adjustment
    await updateStock(tenantId, productId, quantity, invoiceMovement:true, color: color, size: size, warehouseName: warehouseName);
  }

  Future<List<ProductModel>> searchProducts(String tenantId, String query) async {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return _box.values
        .where((p) => p.tenantId == tenantId && !p.isArchived && 
                 (p.name.toLowerCase().contains(q) || 
                  (p.barcode?.toLowerCase().contains(q) ?? false) ||
                  (p.category.toLowerCase().contains(q))))
        .toList();
  }

  Future<int> getProductCount(String tenantId) async {
    return _box.values.where((p) => p.tenantId == tenantId && !p.isArchived).length;
  }

  Future<({List<ProductModel> products, String? lastDocId})> getProductsPaginated(String tenantId, {int limit = 50, String? lastDocId}) async {
    if(lastDocId==null && tenantId!='local_default') await getProducts(tenantId);
    final allProducts = _box.values.where((p) => p.tenantId == tenantId && !p.isArchived).toList();
    allProducts.sort((a, b) => a.id.compareTo(b.id));

    int startIndex = 0;
    if (lastDocId != null) {
      final idx = allProducts.indexWhere((p) => p.id == lastDocId);
      if (idx != -1) startIndex = idx + 1;
    }

    final chunk = allProducts.skip(startIndex).take(limit).toList();
    final nextLastDocId = chunk.isNotEmpty ? chunk.last.id : null;

    return (products: await _sharedBalances(tenantId, chunk), lastDocId: nextLastDocId);
  }

  Future<void> emptyArchive(String tenantId) async {
    final archived = _box.values.where((p) => p.tenantId == tenantId && p.isArchived).toList();
    for(final p in archived){await deleteProduct(tenantId,p.id,permanent:true); }

    // Notify UI of local update
    _notifyStockChanged();
  }

  Future<void> updateProductFields(String tenantId, String productId, Map<String, dynamic> fields) async {
    final product = _box.get(productId);
    if (product == null) return;
    
    // This is a bit tricky with copyWith, but we can use the model's toJson/fromJson if needed
    // or just handle common fields. For now, let's assume it's for stock/status.
    final json = product.toJson();
    json.addAll(fields);
    final updated = ProductModel.fromJson(json);
    await updateProduct(tenantId, productId, updated);
  }
}


import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/models/sync_queue_item.dart';

final productRepositoryProvider = Provider((ref) => ProductRepository(ref));

class ProductRepository {
  final Ref _ref;
  FirestoreRestService get _restService => _ref.read(firestoreRestServiceProvider);

  ProductRepository(this._ref);
  Box<ProductModel> get box => _box;
  Box<ProductModel> get _box => LocalDbService.getBox<ProductModel>('products');

  Future<List<ProductModel>> getProducts(String tenantId, {int limit = 50}) async {
    // 1. Return cached products first for immediate UI update
    final cached = _box.values.where((p) => p.tenantId == tenantId && !p.isArchived).toList();
    cached.sort((a, b) => a.name.compareTo(b.name));
    
    if (tenantId == 'local_default') return cached;

    // 2. Fetch from remote in background (if online)
    try {
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
      final remoteProducts = results.map((data) => ProductModel.fromJson(data)).toList();
      
      // Update cache (Merge strategy)
      for (var p in remoteProducts) {
        final local = _box.get(p.id);
        if (local == null || local.toJson().toString() != p.toJson().toString()) {
          await _box.put(p.id, p);
        }
      }
      
      // Cleanup locally deleted products that still exist in Firestore (optional but usually handled by archiving)
      
      remoteProducts.sort((a, b) => a.name.compareTo(b.name));
      return remoteProducts;
    } catch (e) {
      debugPrint('Offline/Error fetching products: $e');
      return cached;
    }
  }

  Future<void> saveProduct(String tenantId, ProductModel product) async {
    final productId = product.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : product.id;
    final updatedProduct = product.copyWith(
      id: productId,
      tenantId: tenantId,
    );
    
    // Always save to local first
    await _box.put(productId, updatedProduct);

    if (tenantId == 'local_default') return;

    // Push to remote or queue
    try {
      await _restService.setDocument('products/$productId', updatedProduct.toJson(), isUpdate: product.id.isNotEmpty);
    } catch (e) {
      debugPrint('Queuing product save: $e');
      await LocalDbService.addToSyncQueue(
        collectionPath: 'products/$productId', 
        data: updatedProduct.toJson(), 
        action: product.id.isNotEmpty ? SyncAction.update : SyncAction.create
      );
    }
  }

  Future<void> deleteProduct(String tenantId, String productId, {bool permanent = false}) async {
    // Local delete
    if (permanent) {
      await _box.delete(productId);
    } else {
      final p = _box.get(productId);
      if (p != null) await _box.put(productId, p.copyWith(isArchived: true));
    }

    if (tenantId == 'local_default') return;

    // Remote
    try {
      if (permanent) {
        await _restService.deleteDocument('products/$productId');
      } else {
        await _restService.setDocument('products/$productId', {'isArchived': true}, isUpdate: true);
      }
    } catch (e) {
      await LocalDbService.addToSyncQueue(
        collectionPath: 'products/$productId', 
        data: {'isArchived': true, 'id': productId}, 
        action: permanent ? SyncAction.delete : SyncAction.update
      );
    }
  }

  Future<ProductModel?> getProductByBarcode(String tenantId, String barcode) async {
    // Check local first
    try {
      return _box.values.firstWhere((p) => p.barcode == barcode && !p.isArchived);
    } catch (_) {
      if (tenantId == 'local_default') return null;
      
      // If not in cache and online, try remote
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
        await _box.put(p.id, p);
        return p;
      } catch (e) {
        return null;
      }
    }
  }

  Future<void> updateProduct(String tenantId, String productId, ProductModel updatedProduct) async {
    await _box.put(productId, updatedProduct);
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

  Future<void> updateStock(String tenantId, String productId, int adjustment, {String? color, String? size, String? warehouseName, double? priceOverride}) async {
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

    final newTotalStock = updatedVariants.fold(0, (sum, v) => sum + v.stock);

    final updatedProduct = product.copyWith(
      stockQuantity: newTotalStock,
      inStock: newTotalStock > 0,
      variants: updatedVariants,
    );
    
    await _box.put(productId, updatedProduct);

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
    final allProducts = _box.values.where((p) => p.tenantId == tenantId && !p.isArchived).toList();
    allProducts.sort((a, b) => a.id.compareTo(b.id));

    int startIndex = 0;
    if (lastDocId != null) {
      final idx = allProducts.indexWhere((p) => p.id == lastDocId);
      if (idx != -1) startIndex = idx + 1;
    }

    final chunk = allProducts.skip(startIndex).take(limit).toList();
    final nextLastDocId = chunk.isNotEmpty ? chunk.last.id : null;

    return (products: chunk, lastDocId: nextLastDocId);
  }

  Future<void> emptyArchive(String tenantId) async {
    final archived = _box.values.where((p) => p.tenantId == tenantId && p.isArchived).toList();
    for (var p in archived) {
      await _box.delete(p.id);
      if (tenantId != 'local_default') {
        await LocalDbService.addToSyncQueue(
          collectionPath: 'products/${p.id}', 
          data: {}, 
          action: SyncAction.delete
        );
      }
    }
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


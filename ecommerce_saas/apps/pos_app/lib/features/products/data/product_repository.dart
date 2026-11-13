import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/services/pos_supabase_service.dart';

final productRepositoryProvider = Provider((ref) => ProductRepository(
  FirebaseFirestore.instance,
  ref.watch(posSupabaseServiceProvider),
));

class ProductRepository {
  final FirebaseFirestore _firestore;
  final PosSupabaseService _supabaseService;

  ProductRepository(this._firestore, this._supabaseService);

  // --- Tenant-scoped path ---
  CollectionReference<ProductModel> _productBase(String tenantId) =>
      _firestore
          .collection('products')
          .withConverter<ProductModel>(
            fromFirestore: (snapshot, _) =>
                ProductModel.fromJson({...snapshot.data()!, 'id': snapshot.id}),
            toFirestore: (model, options) => model.toJson(),
          );

  Stream<List<ProductModel>> watchProducts(String tenantId) async* {
    if (tenantId.isEmpty) {
      yield [];
      return;
    }

    // 1. Instant initial load from Supabase SQL (Fast & Iraq friendly)
    try {
      final initialProducts = await _supabaseService.getProducts(tenantId);
      if (initialProducts.isNotEmpty) {
        yield initialProducts;
      }
    } catch (_) {}

    // 2. Stream from Supabase SQL Realtime
    try {
      await for (final products in _supabaseService.getProductsStream(tenantId)) {
        if (products.isNotEmpty) {
          yield products;
        }
      }
    } catch (_) {
      // 3. Fallback to Firestore stream if Supabase stream fails
      yield* _productBase(tenantId)
          .where('tenantId', isEqualTo: tenantId)
          .snapshots()
          .map((snapshot) {
            final list = snapshot.docs.map((doc) => doc.data()).toList();
            list.sort((a, b) => a.name.compareTo(b.name));
            return list;
          });
    }
  }

  Future<List<ProductModel>> getProducts(String tenantId) async {
    // 1. Try Supabase SQL first
    try {
      final sqlProducts = await _supabaseService.getProducts(tenantId);
      if (sqlProducts.isNotEmpty) {
        return sqlProducts;
      }
    } catch (_) {}

    // 2. Fallback to Firestore SDK
    try {
      final snapshot = await _productBase(tenantId)
          .where('tenantId', isEqualTo: tenantId)
          .get();
      final list = snapshot.docs.map((doc) => doc.data()).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProduct(String tenantId, ProductModel product) async {
    final colRef = _productBase(tenantId);
    final docRef = product.id.isEmpty ? colRef.doc() : colRef.doc(product.id);
    final updatedProduct = product.copyWith(
      id: docRef.id,
      tenantId: tenantId,
    );

    // 1. Save to Supabase SQL Database (Primary)
    try {
      await _supabaseService.saveProduct(updatedProduct, tenantId);
    } catch (_) {}

    // 2. Save to Firestore (Fallback)
    try {
      await docRef.set(updatedProduct);
    } catch (_) {}
  }

  Future<void> deleteProduct(String tenantId, String productId, {bool permanent = false}) async {
    // 1. Delete in Supabase SQL (Primary)
    try {
      await _supabaseService.deleteProduct(productId);
    } catch (_) {}

    // 2. Delete in Firestore (Fallback)
    try {
      if (permanent) {
        await _productBase(tenantId).doc(productId).delete();
      } else {
        await _productBase(tenantId).doc(productId).update({'isArchived': true});
      }
    } catch (_) {}
  }

  Future<void> emptyArchive(String tenantId) async {
    try {
      final snapshot = await _productBase(tenantId)
          .where('tenantId', isEqualTo: tenantId)
          .where('isArchived', isEqualTo: true)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<ProductModel?> getProductByBarcode(String tenantId, String barcode) async {
    // 1. Try Supabase SQL first
    try {
      final product = await _supabaseService.getProductByBarcode(tenantId, barcode);
      if (product != null) return product;
    } catch (_) {}

    // 2. Fallback to Firestore
    try {
      final snapshot = await _productBase(tenantId)
          .where('tenantId', isEqualTo: tenantId)
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data();
    } catch (_) {
      return null;
    }
  }

  Future<void> updateStock(
    String tenantId,
    String productId,
    int adjustment, {
    String? color,
    String? size,
  }) async {
    // 1. Update in Supabase SQL (Primary)
    try {
      await _supabaseService.updateStock(
        tenantId,
        productId,
        adjustment,
        color: color,
        size: size,
      );
    } catch (_) {}

    // 2. Update in Firestore (Fallback)
    try {
      final docRef = _firestore.collection('products').doc(productId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final currentTotalStock = (data['stockQuantity'] as num?)?.toInt() ?? 0;
      final newTotalStock = (currentTotalStock + adjustment).clamp(0, 999999);
      
      final updates = <String, dynamic>{
        'stockQuantity': newTotalStock,
        'inStock': newTotalStock > 0,
      };

      final variantsJson = data['variants'] as List? ?? [];
      if (variantsJson.isNotEmpty) {
        final targetColor = color ?? 'Default';
        final targetSize = size ?? 'Default';
        
        bool variantFound = false;
        final updatedVariants = variantsJson.map((v) {
          if (v is! Map) return v;
          final vMap = Map<String, dynamic>.from(v);
          if (vMap['color'] == targetColor && vMap['size'] == targetSize) {
            variantFound = true;
            final vStock = (vMap['stock'] as num?)?.toInt() ?? 0;
            vMap['stock'] = (vStock + adjustment).clamp(0, 999999);
          }
          return vMap;
        }).toList();

        if (variantFound) {
          updates['variants'] = updatedVariants;
        }
      }

      await docRef.update(updates);
    } catch (_) {}
  }

  Future<List<ProductModel>> searchProducts(String tenantId, String query) async {
    if (query.isEmpty) return [];
    final normalizedQuery = query.toLowerCase();
    
    final allProducts = await getProducts(tenantId);
    return allProducts.where((product) {
      final name = product.name.toLowerCase();
      final barcode = product.barcode?.toLowerCase() ?? '';
      final category = product.category.toLowerCase();
      return name.contains(normalizedQuery) ||
             barcode.contains(normalizedQuery) ||
             category.contains(normalizedQuery);
    }).take(20).toList();
  }

  Future<void> updateProductFields(String tenantId, String productId, Map<String, dynamic> fields) async {
    try {
      await _firestore.collection('products').doc(productId).update(fields);
    } catch (_) {}
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final productRepositoryProvider = Provider((ref) => ProductRepository(FirebaseFirestore.instance));

class ProductRepository {
  final FirebaseFirestore _firestore;

  ProductRepository(this._firestore);

  // --- Tenant-scoped path ---
  CollectionReference<ProductModel> _productBase(String tenantId) =>
      _firestore
          .collection('products')
          .withConverter<ProductModel>(
            fromFirestore: (snapshot, _) =>
                ProductModel.fromJson({...snapshot.data()!, 'id': snapshot.id}),
            toFirestore: (model, options) => model.toJson(),
          );

  Future<List<ProductModel>> getProducts(String tenantId) async {
    final snapshot = await _productBase(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .get();
    final list = snapshot.docs.map((doc) => doc.data()).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> saveProduct(String tenantId, ProductModel product) async {
    final colRef = _productBase(tenantId);
    final docRef = product.id.isEmpty ? colRef.doc() : colRef.doc(product.id);
    final updatedProduct = product.copyWith(
      id: docRef.id,
      tenantId: tenantId,
    );
    await docRef.set(updatedProduct);
  }

  Future<void> deleteProduct(String tenantId, String productId, {bool permanent = false}) async {
    if (permanent) {
      await _productBase(tenantId).doc(productId).delete();
    } else {
      await _productBase(tenantId).doc(productId).update({'isArchived': true});
    }
  }

  Future<void> emptyArchive(String tenantId) async {
    final snapshot = await _productBase(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .where('isArchived', isEqualTo: true)
        .get();
    
    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<ProductModel?> getProductByBarcode(String tenantId, String barcode) async {
    final snapshot =
        await _productBase(tenantId)
            .where('tenantId', isEqualTo: tenantId)
            .where('barcode', isEqualTo: barcode)
            .limit(1)
            .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data();
  }

  Stream<List<ProductModel>> watchProducts(String tenantId) {

    return _productBase(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .snapshots()
        .map(
      (snapshot) {
        final list = snapshot.docs.map((doc) => doc.data()).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      },
    );
  }

  Future<void> updateStock(String tenantId, String productId, int adjustment, {String? color, String? size}) async {
    final docRef = _firestore.collection('products').doc(productId);
    
    // Read the document once (Removed runTransaction to prevent Windows native crashes)
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

    // Handle variants if present
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
  }

  Future<List<ProductModel>> searchProducts(String tenantId, String query) async {
    if (query.isEmpty) return [];
    final normalizedQuery = query.toLowerCase();
    
    // Fetch products for this tenant and filter in memory for case-insensitivity
    final snapshot = await _productBase(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .get();
    
    return snapshot.docs.map((doc) => doc.data()).where((product) {
      final name = product.name.toLowerCase();
      final barcode = product.barcode?.toLowerCase() ?? '';
      return name.contains(normalizedQuery) || barcode.contains(normalizedQuery);
    }).take(20).toList();
  }

  Future<void> updateProductFields(String tenantId, String productId, Map<String, dynamic> fields) async {
    await _firestore.collection('products').doc(productId).update(fields);
  }
}

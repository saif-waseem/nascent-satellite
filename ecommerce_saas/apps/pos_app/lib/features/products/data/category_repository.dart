import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final categoryRepositoryProvider = Provider((ref) => CategoryRepository(FirebaseFirestore.instance));

class CategoryRepository {
  final FirebaseFirestore _firestore;

  CategoryRepository(this._firestore);

  CollectionReference<CategoryModel> _categoryBase(String tenantId) =>
      _firestore
          .collection('categories')
          .withConverter<CategoryModel>(
            fromFirestore: (snapshot, _) =>
                CategoryModel.fromJson(snapshot.data()!..['id'] = snapshot.id ..putIfAbsent('icon', () => 'folder')),
            toFirestore: (model, options) => model.toJson(),
          );

  Future<void> addCategory(String tenantId, CategoryModel category) async {
    final ref = _categoryBase(tenantId).doc();
    await ref.set(category.copyWith(id: ref.id));
  }

  Future<void> updateCategory(String tenantId, CategoryModel category) async {
    await _categoryBase(tenantId).doc(category.id).set(category);
  }

  Future<void> deleteCategory(String tenantId, String categoryId) async {
    await _categoryBase(tenantId).doc(categoryId).delete();
  }

  Future<List<CategoryModel>> getCategories(String tenantId) async {
    final snapshot = await _categoryBase(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .get();
    final list = snapshot.docs.map((d) => d.data()).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Stream<List<CategoryModel>> watchCategories(String tenantId) {
    return _categoryBase(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .snapshots()
        .map(
      (s) {
        final list = s.docs.map((d) => d.data()).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      },
    );
  }
}

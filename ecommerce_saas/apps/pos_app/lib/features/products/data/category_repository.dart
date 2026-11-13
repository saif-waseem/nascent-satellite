import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/services/pos_supabase_service.dart';

final categoryRepositoryProvider = Provider((ref) => CategoryRepository(
  FirebaseFirestore.instance,
  ref.watch(posSupabaseServiceProvider),
));

class CategoryRepository {
  final FirebaseFirestore _firestore;
  final PosSupabaseService _supabaseService;

  CategoryRepository(this._firestore, this._supabaseService);

  CollectionReference<CategoryModel> _categoryBase(String tenantId) =>
      _firestore
          .collection('categories')
          .withConverter<CategoryModel>(
            fromFirestore: (snapshot, _) =>
                CategoryModel.fromJson({...snapshot.data()!, 'id': snapshot.id}..putIfAbsent('icon', () => 'folder')),
            toFirestore: (model, options) => model.toJson(),
          );

  Future<void> addCategory(String tenantId, CategoryModel category) async {
    final ref = _categoryBase(tenantId).doc();
    final newCategory = category.copyWith(id: category.id.isNotEmpty ? category.id : ref.id);

    // 1. Save to Supabase SQL (Primary)
    try {
      await _supabaseService.saveCategory(newCategory, tenantId);
    } catch (_) {}

    // 2. Save to Firestore (Fallback)
    try {
      await ref.set(newCategory);
    } catch (_) {}
  }

  Future<void> updateCategory(String tenantId, CategoryModel category) async {
    // 1. Update in Supabase SQL (Primary)
    try {
      await _supabaseService.saveCategory(category, tenantId);
    } catch (_) {}

    // 2. Update in Firestore (Fallback)
    try {
      await _categoryBase(tenantId).doc(category.id).set(category);
    } catch (_) {}
  }

  Future<void> deleteCategory(String tenantId, String categoryId) async {
    // 1. Delete in Supabase SQL (Primary)
    try {
      await _supabaseService.deleteCategory(categoryId);
    } catch (_) {}

    // 2. Delete in Firestore (Fallback)
    try {
      await _categoryBase(tenantId).doc(categoryId).delete();
    } catch (_) {}
  }

  Future<List<CategoryModel>> getCategories(String tenantId) async {
    // 1. Try Supabase SQL first
    try {
      final sqlCategories = await _supabaseService.getCategories(tenantId);
      if (sqlCategories.isNotEmpty) {
        return sqlCategories;
      }
    } catch (_) {}

    // 2. Fallback to Firestore
    try {
      final snapshot = await _categoryBase(tenantId)
          .where('tenantId', isEqualTo: tenantId)
          .get();
      final list = snapshot.docs.map((d) => d.data()).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (_) {
      return [];
    }
  }

  Stream<List<CategoryModel>> watchCategories(String tenantId) async* {
    if (tenantId.isEmpty) {
      yield [];
      return;
    }

    // 1. Immediate initial load from Supabase SQL (0ms latency)
    try {
      final initial = await _supabaseService.getCategories(tenantId);
      if (initial.isNotEmpty) {
        yield initial;
      }
    } catch (_) {}

    // 2. Stream from Supabase SQL Realtime
    try {
      await for (final categories in _supabaseService.getCategoriesStream(tenantId)) {
        if (categories.isNotEmpty) {
          yield categories;
        }
      }
    } catch (_) {
      // 3. Fallback to Firestore stream
      yield* _categoryBase(tenantId)
          .where('tenantId', isEqualTo: tenantId)
          .snapshots()
          .map((s) {
            final list = s.docs.map((d) => d.data()).toList();
            list.sort((a, b) => a.name.compareTo(b.name));
            return list;
          });
    }
  }
}

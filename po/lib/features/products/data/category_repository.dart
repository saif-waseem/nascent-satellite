import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';

class CategoryRepository {
  final FirestoreRestService _restService;

  CategoryRepository(this._restService);

  Future<void> addCategory(String tenantId, CategoryModel category) async {
    final id = category.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : category.id;
    await _restService.setDocument('categories/$id', category.copyWith(id: id).toJson());
  }

  Future<void> updateCategory(String tenantId, CategoryModel category) async {
    await _restService.setDocument('categories/${category.id}', category.toJson(), isUpdate: true);
  }

  Future<void> deleteCategory(String tenantId, String categoryId) async {
    await _restService.deleteDocument('categories/$categoryId');
  }

  Future<List<CategoryModel>> getCategories(String tenantId) async {
    final query = {
      'where': {
        'fieldFilter': {
          'field': {'fieldPath': 'tenantId'},
          'op': 'EQUAL',
          'value': {'stringValue': tenantId}
        }
      }
    };
    final results = await _restService.runQuery('categories', query);
    final list = results.map((data) => CategoryModel.fromJson(data..putIfAbsent('icon', () => 'folder'))).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Stream<List<CategoryModel>> watchCategories(String tenantId) {
    return Stream.fromFuture(getCategories(tenantId));
  }
}

final categoryRepositoryProvider = Provider((ref) => CategoryRepository(ref.watch(firestoreRestServiceProvider)));

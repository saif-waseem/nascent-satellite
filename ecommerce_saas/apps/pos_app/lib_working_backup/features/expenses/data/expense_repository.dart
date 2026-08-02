import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/models/sync_queue_item.dart';

final expenseRepositoryProvider = Provider((ref) => ExpenseRepository(ref));

class ExpenseRepository {
  final Ref _ref;
  FirestoreRestService get _restService => _ref.read(firestoreRestServiceProvider);

  ExpenseRepository(this._ref);

  Box<ExpenseModel> get _expenseBox => LocalDbService.getBox<ExpenseModel>('expenses');

  Future<List<ExpenseModel>> getExpenses(String tenantId) async {
    final cached = _expenseBox.values.where((e) => e.tenantId == tenantId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    
    if (tenantId == 'local_default') return cached;

    // Background fetch
    _fetchExpensesRemote(tenantId);
    
    return cached;
  }

  Future<void> _fetchExpensesRemote(String tenantId) async {
    try {
      final query = {
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'tenantId'},
            'op': 'EQUAL',
            'value': {'stringValue': tenantId}
          }
        },
      };
      final results = await _restService.runQuery('expenses', query);
      final list = results.map((data) => ExpenseModel.fromJson(data)).toList();
      for (var e in list) {
        await _expenseBox.put(e.id, e);
      }
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
    }
  }

  Future<void> addExpense(String tenantId, ExpenseModel expense) async {
    final id = expense.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : expense.id;
    final finalExpense = expense.copyWith(id: id, tenantId: tenantId);
    
    await _expenseBox.put(id, finalExpense);

    if (tenantId == 'local_default') return;

    await LocalDbService.addToSyncQueue(
      collectionPath: 'expenses/$id', 
      data: finalExpense.toJson(), 
      action: expense.id.isNotEmpty ? SyncAction.update : SyncAction.create
    );
  }

  Future<void> deleteExpense(String tenantId, String expenseId) async {
    await _expenseBox.delete(expenseId);

    if (tenantId == 'local_default') return;

    await LocalDbService.addToSyncQueue(
      collectionPath: 'expenses/$expenseId', 
      data: {}, 
      action: SyncAction.delete
    );
  }
}


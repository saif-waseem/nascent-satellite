import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore;

  ExpenseRepository(this._firestore);

  CollectionReference<ExpenseModel> _expenseBase(String tenantId) =>
      _firestore
          .collection('expenses')
          .withConverter<ExpenseModel>(
            fromFirestore: (snapshot, _) => ExpenseModel.fromJson(snapshot.data() ?? {}),
            toFirestore: (model, _) => model.toJson(),
          );

  Query<ExpenseModel> _expensesRef(String tenantId) =>
      _expenseBase(tenantId).where('tenantId', isEqualTo: tenantId);

  Stream<List<ExpenseModel>> watchExpenses(String tenantId) {
    return _expensesRef(tenantId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> addExpense(String tenantId, ExpenseModel expense) async {
    final ref = _expenseBase(tenantId).doc(expense.id.isEmpty ? null : expense.id);
    final finalExpense = expense.copyWith(id: ref.id, tenantId: tenantId);
    await ref.set(finalExpense);
  }

  Future<void> deleteExpense(String tenantId, String expenseId) async {
    await _expenseBase(tenantId).doc(expenseId).delete();
  }
}

final expenseRepositoryProvider = Provider((ref) => ExpenseRepository(FirebaseFirestore.instance));

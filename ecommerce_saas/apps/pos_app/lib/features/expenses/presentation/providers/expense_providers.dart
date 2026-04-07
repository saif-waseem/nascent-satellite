import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../data/expense_repository.dart';
import '../../../../core/providers/tenant_provider.dart';

final expensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  return ref.watch(expenseRepositoryProvider).watchExpenses(tenantId);
});

final totalExpensesProvider = Provider<double>((ref) {
  final expenses = ref.watch(expensesStreamProvider).value ?? [];
  return expenses.fold(0.0, (sum, item) => sum + item.amount);
});

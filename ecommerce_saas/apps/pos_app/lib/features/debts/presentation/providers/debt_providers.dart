import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/debt_repository.dart';
import '../../../../core/providers/tenant_provider.dart';

final customerDebtsProvider = StreamProvider.autoDispose((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  return ref.watch(debtRepositoryProvider).watchCustomers(tenantId);
});

final supplierDebtsProvider = StreamProvider.autoDispose((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  return ref.watch(debtRepositoryProvider).watchSuppliers(tenantId);
});

final customerTransactionsProvider = StreamProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, customerId) {
  return ref.watch(debtRepositoryProvider).watchCustomerTransactions(customerId);
});

final supplierTransactionsProvider = StreamProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, supplierId) {
  return ref.watch(debtRepositoryProvider).watchSupplierTransactions(supplierId);
});

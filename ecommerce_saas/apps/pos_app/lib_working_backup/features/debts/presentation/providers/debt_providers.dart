import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../data/debt_repository.dart';
import '../../../../core/providers/tenant_provider.dart';

final customerDebtsProvider = FutureProvider.autoDispose<List<CustomerModel>>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  return await ref.watch(debtRepositoryProvider).getCustomersWithDebts(tenantId);
});

final supplierDebtsProvider = FutureProvider.autoDispose<List<SupplierModel>>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  return await ref.watch(debtRepositoryProvider).getSuppliers(tenantId);
});

final customerTransactionsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, customerId) async {
  return await ref.watch(debtRepositoryProvider).getCustomerTransactions(customerId);
});

final supplierTransactionsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, supplierId) async {
  return await ref.watch(debtRepositoryProvider).getSupplierTransactions(supplierId);
});

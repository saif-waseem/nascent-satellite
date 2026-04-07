import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../data/customer_repository.dart';
import '../../../../core/providers/tenant_provider.dart';

final customersListProvider = StreamProvider.autoDispose<List<CustomerModel>>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  final repo = ref.watch(customerRepositoryProvider);
  return repo.watchAllCustomers(tenantId);
});

final customerSearchProvider = NotifierProvider<CustomerSearch, String>(CustomerSearch.new);

class CustomerSearch extends Notifier<String> {
  @override
  String build() => '';
  void set(String val) => state = val;
}

final filteredCustomersProvider = Provider.autoDispose<List<CustomerModel>>((ref) {
  final customers = ref.watch(customersListProvider).value ?? [];
  final search = ref.watch(customerSearchProvider).toLowerCase();
  
  if (search.isEmpty) return customers;
  
  return customers.where((c) => 
    c.name.toLowerCase().contains(search) || 
    c.phoneNumber.contains(search)
  ).toList();
});

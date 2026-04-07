import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/supplier_repository.dart';

final suppliersStreamProvider = StreamProvider.family.autoDispose((ref, String tenantId) {
  return ref.watch(supplierRepositoryProvider).watchSuppliers(tenantId);
});

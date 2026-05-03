import 'package:shared_models/shared_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supplier_repository.dart';
import '../../../../core/providers/tenant_provider.dart';

final suppliersFutureProvider = FutureProvider.autoDispose<List<SupplierModel>>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  if (tenantId.isEmpty) return [];
  return ref.watch(supplierRepositoryProvider).getSuppliers(tenantId);
});

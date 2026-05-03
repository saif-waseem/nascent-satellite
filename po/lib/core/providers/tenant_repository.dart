import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../services/firestore_rest_service.dart';

class TenantRepository {
  final FirestoreRestService _restService;

  TenantRepository(this._restService);

  Future<void> updateTenant(TenantModel tenant) async {
    await _restService.setDocument('tenants/${tenant.id}', tenant.toJson(), isUpdate: true);
  }
}

final tenantRepositoryProvider = Provider((ref) => TenantRepository(ref.watch(firestoreRestServiceProvider)));

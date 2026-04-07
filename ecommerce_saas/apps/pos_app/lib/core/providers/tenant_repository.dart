import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';

final tenantRepositoryProvider = Provider((ref) => TenantRepository());

class TenantRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateTenant(TenantModel tenant) async {
    await _firestore
        .collection('tenants')
        .doc(tenant.id)
        .set(tenant.toJson());
  }
}

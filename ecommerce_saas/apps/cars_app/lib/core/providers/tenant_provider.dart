import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../services/local_db_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart');
});

class TenantIdNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString('tenant_id') ?? '';
  }

  Future<void> setTenantId(String id) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('tenant_id', id);
    state = id;
  }

  Future<void> clearTenantId() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('tenant_id');
    state = '';
  }
}

final tenantIdProvider = NotifierProvider<TenantIdNotifier, String>(TenantIdNotifier.new);

final tenantProvider = FutureProvider<TenantModel?>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  if (tenantId.isEmpty) return null;

  // Local first
  final box = LocalDbService.getBox<TenantModel>('tenants');
  final localTenant = box.get(tenantId);

  if (localTenant != null) {
    _updateTenantFromNetwork(tenantId, box);
    return localTenant;
  }

  // Fetch from Firestore SDK
  try {
    final doc = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).get();
    if (!doc.exists) return null;
    final t = TenantModel.fromJson({'id': doc.id, ...doc.data()!});
    await box.put(t.id, t);
    return t;
  } catch (e) {
    debugPrint('Error fetching TenantModel: $e');
    return null;
  }
});

Future<void> _updateTenantFromNetwork(String tenantId, Box<TenantModel> box) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).get();
    if (doc.exists) {
      final t = TenantModel.fromJson({'id': doc.id, ...doc.data()!});
      await box.put(t.id, t);
    }
  } catch (_) {}
}

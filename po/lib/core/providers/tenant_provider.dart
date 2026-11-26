import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_models/shared_models.dart';
import '../services/firestore_rest_service.dart';
import '../services/local_db_service.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

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
  if (tenantId == 'local_default') {
    return TenantModel(
      id: 'local_default',
      name: 'العمل المحلي (بدون سيرفر)',
      adminIds: const [],
      description: 'وضع العمل المحلي',
      createdAt: DateTime(2026),
      isActive: true,
      isPosEnabled: true,
      isStoreEnabled: true,
    );
  }

  // Local first
  final box = LocalDbService.getBox<TenantModel>('tenants');
  final localTenant = box.get(tenantId);
  
  if (localTenant != null) {
    // Background update
    _updateTenantFromNetwork(ref, tenantId, box);
    return localTenant;
  }

  // If not local, must fetch from network
  final restService = ref.watch(firestoreRestServiceProvider);
  try {
    final data = await restService.getDocument('tenants/$tenantId');
    if (data == null) return null;
    final t = TenantModel.fromJson(data);
    await box.put(t.id, t);
    return t;
  } catch (e) {
    debugPrint('Error fetching TenantModel: $e');
    return null;
  }
});

Future<void> _updateTenantFromNetwork(Ref ref, String tenantId, Box<TenantModel> box) async {
  try {
    final local = box.get(tenantId);
    final restService = ref.read(firestoreRestServiceProvider);
    final data = await restService.getDocument('tenants/$tenantId');
    if (data != null) {
      final t = TenantModel.fromJson(data);
      await box.put(t.id, t);
      if (local != t && ref.mounted) {
        ref.invalidate(tenantProvider);
      }
    }
  } catch (e) {
    // Ignore offline errors
  }
}

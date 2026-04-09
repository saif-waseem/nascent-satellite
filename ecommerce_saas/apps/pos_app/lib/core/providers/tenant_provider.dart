import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final tenantProvider = StreamProvider<TenantModel?>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  if (tenantId.isEmpty) return Stream.value(null);
  
  return FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenantId)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists) return null;
        return TenantModel.fromJson(snapshot.data()!);
      });
});

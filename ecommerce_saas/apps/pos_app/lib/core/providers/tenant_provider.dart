import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pos_supabase_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart');
});

final posSupabaseServiceProvider = Provider<PosSupabaseService>((ref) {
  return PosSupabaseService();
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

final tenantProvider = StreamProvider<TenantModel?>((ref) async* {
  final tenantId = ref.watch(tenantIdProvider);
  if (tenantId.isEmpty) {
    yield null;
    return;
  }

  // Handle local offline / free store mode
  if (tenantId == 'local_store' || tenantId == 'demo') {
    yield TenantModel(
      id: tenantId,
      name: 'متجر الكاشير (وضع محلي)',
      adminIds: const ['admin'],
      isActive: true,
      isPosEnabled: true,
      createdAt: DateTime.now(),
      posTier: 'A',
      posExcelEnabled: true,
    );
    return;
  }

  // 1. First immediate yield from Supabase SQL (New Architecture)
  final supabaseService = ref.read(posSupabaseServiceProvider);
  try {
    final sqlTenant = await supabaseService.getTenant(tenantId);
    if (sqlTenant != null) {
      yield sqlTenant;
    }
  } catch (e) {
    debugPrint('Supabase tenant initial fetch note: $e');
  }

  // 2. Real-time updates via Firestore
  try {
    yield* FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) return null;
          return TenantModel.fromJson({'id': snapshot.id, ...snapshot.data()!});
        });
  } catch (e) {
    debugPrint('Firestore tenant stream note: $e');
  }
});

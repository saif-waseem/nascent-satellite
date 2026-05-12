import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:super_admin/core/services/super_admin_firestore_service.dart';
import 'package:shared_models/shared_models.dart';

// --- Services ---
final superAdminFirestoreServiceProvider = Provider((ref) => SuperAdminFirestoreService());

// --- Tenants ---
final allTenantsProvider = StreamProvider<List<TenantModel>>((ref) {
  return ref.watch(superAdminFirestoreServiceProvider).getTenants();
});

// --- Search State ---
final tenantSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredTenantsProvider = Provider<List<TenantModel>>((ref) {
  final tenants = ref.watch(allTenantsProvider).value ?? [];
  final query = ref.watch(tenantSearchQueryProvider).toLowerCase();
  
  if (query.isEmpty) return tenants;
  
  return tenants.where((t) => 
    t.name.toLowerCase().contains(query) || 
    t.id.toLowerCase().contains(query)
  ).toList();
});

// --- App Updates ---
final appUpdatesProvider = StreamProvider<List<AppUpdateModel>>((ref) {
  return ref.watch(superAdminFirestoreServiceProvider).getAppUpdates();
});

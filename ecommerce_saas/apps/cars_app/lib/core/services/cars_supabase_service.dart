import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/shared_models.dart';
import 'supabase_config.dart';

class CarsSupabaseService {
  final SupabaseClient? _client;

  CarsSupabaseService([this._client]);

  SupabaseClient? get client {
    try {
      return _client ?? SupabaseConfig.safeClient;
    } catch (_) {
      return null;
    }
  }

  bool get isConnected => client != null;

  // ==================== 1. Tenant Verification ====================

  /// Fetch tenant from Supabase SQL database
  Future<TenantModel?> getTenant(String tenantId) async {
    final c = client;
    if (c == null) return null;

    try {
      final response = await c
          .from('tenants')
          .select()
          .eq('id', tenantId)
          .maybeSingle();

      if (response == null) return null;
      return TenantModel.fromJson(response);
    } catch (e) {
      debugPrint('CarsSupabaseService.getTenant error: $e');
      return null;
    }
  }

  /// Find tenant by car activation code in Supabase
  Future<TenantModel?> findTenantByActivationCode(String code) async {
    final c = client;
    if (c == null) return null;

    try {
      // Check cars_activation_code first
      var response = await c
          .from('tenants')
          .select()
          .eq('cars_activation_code', code)
          .limit(1)
          .maybeSingle();

      // Fallback: check activation_code
      if (response == null) {
        response = await c
            .from('tenants')
            .select()
            .eq('activation_code', code)
            .limit(1)
            .maybeSingle();
      }

      // Fallback: check tenant ID
      if (response == null) {
        response = await c
            .from('tenants')
            .select()
            .eq('id', code)
            .limit(1)
            .maybeSingle();
      }

      if (response == null) return null;
      return TenantModel.fromJson(response);
    } catch (e) {
      debugPrint('CarsSupabaseService.findTenantByActivationCode error: $e');
      return null;
    }
  }

  // ==================== 2. Car Contracts SQL ====================

  /// Stream contracts from Supabase SQL table
  Stream<List<CarContractModel>> getContractsStream(String tenantId) {
    final c = client;
    if (c == null) return const Stream.empty();

    try {
      return c
          .from('car_contracts')
          .stream(primaryKey: ['id'])
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false)
          .map((rows) => rows.map((r) => CarContractModel.fromJson(r)).toList());
    } catch (e) {
      debugPrint('CarsSupabaseService.getContractsStream error: $e');
      return const Stream.empty();
    }
  }

  /// Fetch all contracts for tenant
  Future<List<CarContractModel>> getContracts(String tenantId) async {
    final c = client;
    if (c == null) return [];

    try {
      final response = await c
          .from('car_contracts')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((r) => CarContractModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('CarsSupabaseService.getContracts error: $e');
      return [];
    }
  }

  /// Insert or update contract in Supabase SQL table
  Future<bool> upsertContract(CarContractModel contract) async {
    final c = client;
    if (c == null) return false;

    try {
      await c.from('car_contracts').upsert(contract.toRow());
      return true;
    } catch (e) {
      debugPrint('CarsSupabaseService.upsertContract error: $e');
      return false;
    }
  }

  /// Bulk insert contracts (used in Excel import)
  Future<int> batchUpsertContracts(List<CarContractModel> contracts) async {
    final c = client;
    if (c == null || contracts.isEmpty) return 0;

    try {
      final rows = contracts.map((c) => c.toRow()).toList();
      await c.from('car_contracts').upsert(rows);
      return contracts.length;
    } catch (e) {
      debugPrint('CarsSupabaseService.batchUpsertContracts error: $e');
      return 0;
    }
  }

  /// Delete contract by ID from Supabase
  Future<bool> deleteContract(String contractId) async {
    final c = client;
    if (c == null) return false;

    try {
      await c.from('car_contracts').delete().eq('id', contractId);
      return true;
    } catch (e) {
      debugPrint('CarsSupabaseService.deleteContract error: $e');
      return false;
    }
  }
}

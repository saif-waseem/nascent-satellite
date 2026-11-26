import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/shared_models.dart';

class SuperAdminSupabaseService {
  final SupabaseClient? _client;

  SuperAdminSupabaseService([this._client]);

  SupabaseClient get client => _client ?? Supabase.instance.client;

  // --- Tenants Realtime Stream from SQL ---
  Stream<List<TenantModel>> getTenantsStream() {
    return client
        .from('tenants')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((records) => records.map((json) => TenantModel.fromJson(json)).toList());
  }

  // --- Fetch All Tenants ---
  Future<List<TenantModel>> getTenants() async {
    final response = await client
        .from('tenants')
        .select()
        .order('created_at', ascending: false);
    return (response as List<dynamic>)
        .map((e) => TenantModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Save or Upsert Tenant in SQL ---
  Future<void> upsertTenant(TenantModel tenant) async {
    await client.from('tenants').upsert(tenant.toJson());
  }

  // --- Configure POS Tier & Device Limit ---
  Future<void> setPosTier({
    required String tenantId,
    required String tier, // 'A', 'B', 'C', 'D'
    required int deviceLimit,
    bool? lanSync,
    bool? cloudBackup,
    bool? remoteDash,
    bool? excel,
    bool? multiBranch,
    bool? videoGen,
    int? dailyVideoQuota,
  }) async {
    final updateData = <String, dynamic>{
      'posTier': tier,
      'posDeviceLimit': deviceLimit,
    };

    if (lanSync != null) updateData['posLanSyncEnabled'] = lanSync;
    if (cloudBackup != null) updateData['posCloudBackupEnabled'] = cloudBackup;
    if (remoteDash != null) updateData['posRemoteDashEnabled'] = remoteDash;
    if (excel != null) updateData['posExcelEnabled'] = excel;
    if (multiBranch != null) updateData['posMultiBranchEnabled'] = multiBranch;
    if (videoGen != null) updateData['posVideoGenEnabled'] = videoGen;
    if (dailyVideoQuota != null) updateData['posDailyVideoQuota'] = dailyVideoQuota;

    await client.from('tenants').update(updateData).eq('id', tenantId);

    // Log the change
    await client.from('tenant_subscriptions_log').insert({
      'tenant_id': tenantId,
      'app_type': 'pos',
      'action_type': 'tier_change',
      'tier': tier,
    });
  }

  // --- Grant Free Trial (المدة المجانية) ---
  Future<void> grantFreeTrial({
    required String tenantId,
    required int trialDays, // e.g. 7, 14, 30 days
    required String tier,   // usually Tier C or B for trial
  }) async {
    final now = DateTime.now();
    final trialEnd = now.add(Duration(days: trialDays));

    await client.from('tenants').update({
      'isTrialActive': true,
      'trialStartDate': now.toIso8601String(),
      'trialEndDate': trialEnd.toIso8601String(),
      'isPosEnabled': true,
      'posTier': tier,
      'posExpiryDate': trialEnd.toIso8601String(),
    }).eq('id', tenantId);

    await client.from('tenant_subscriptions_log').insert({
      'tenant_id': tenantId,
      'app_type': 'pos',
      'action_type': 'trial_grant',
      'tier': tier,
      'days': trialDays,
    });
  }

  // --- End or Cancel Free Trial ---
  Future<void> endFreeTrial(String tenantId) async {
    await client.from('tenants').update({
      'isTrialActive': false,
      'posTier': 'A', // Demote to Free Tier A
      'posDeviceLimit': 1,
      'posLanSyncEnabled': false,
      'posCloudBackupEnabled': false,
      'posRemoteDashEnabled': false,
      'posExcelEnabled': false,
      'posMultiBranchEnabled': false,
      'posVideoGenEnabled': false,
    }).eq('id', tenantId);
  }

  // --- Update Grace Period (أيام السماح) ---
  Future<void> updateGraceDays(String tenantId, int graceDays) async {
    await client.from('tenants').update({
      'posGraceDays': graceDays,
    }).eq('id', tenantId);
  }

  // --- Activate or Renew Subscription ---
  Future<void> activateSubscription({
    required String tenantId,
    required String appType, // 'pos', 'store', 'cars'
    required int months,
    required String code,
    String? tier,
  }) async {
    final response = await client.from('tenants').select().eq('id', tenantId).single();
    final tenant = TenantModel.fromJson(response);

    final now = DateTime.now();
    DateTime baseDate = now;

    if (appType == 'pos') {
      if (tenant.posExpiryDate != null && tenant.posExpiryDate!.isAfter(now)) {
        baseDate = tenant.posExpiryDate!;
      }
      final newExpiry = baseDate.add(Duration(days: months * 30));

      final updateMap = <String, dynamic>{
        'isPosEnabled': true,
        'posExpiryDate': newExpiry.toIso8601String(),
        'posActivationCode': code,
        'isTrialActive': false,
      };
      if (tier != null) updateMap['posTier'] = tier;

      await client.from('tenants').update(updateMap).eq('id', tenantId);
    } else if (appType == 'store') {
      if (tenant.expiryDate != null && tenant.expiryDate!.isAfter(now)) {
        baseDate = tenant.expiryDate!;
      }
      final newExpiry = baseDate.add(Duration(days: months * 30));

      await client.from('tenants').update({
        'isStoreEnabled': true,
        'expiryDate': newExpiry.toIso8601String(),
        'activationCode': code,
      }).eq('id', tenantId);
    }

    // Log the transaction
    await client.from('tenant_subscriptions_log').insert({
      'tenant_id': tenantId,
      'app_type': appType,
      'action_type': 'renew',
      'months': months,
      'tier': tier ?? tenant.posTier,
      'activation_code': code,
    });
  }

  // --- Delete Tenant ---
  Future<void> deleteTenant(String tenantId) async {
    await client.from('tenants').delete().eq('id', tenantId);
  }
}

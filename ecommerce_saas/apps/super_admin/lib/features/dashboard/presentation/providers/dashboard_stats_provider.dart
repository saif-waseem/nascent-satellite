import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:super_admin/features/shared/providers.dart';

class DashboardStats {
  final int totalTenants;
  final int activeTenants;
  final int expiredTenants;
  final int totalSubscribers;
  final Map<String, int> subscribersPerTenant;

  DashboardStats({
    required this.totalTenants,
    required this.activeTenants,
    required this.expiredTenants,
    required this.totalSubscribers,
    required this.subscribersPerTenant,
  });
}

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final tenants = ref.watch(allTenantsProvider).value ?? [];
  final now = DateTime.now();

  int active = 0;
  int expired = 0;
  int totalSubs = 0;
  Map<String, int> subMap = {};

  for (var tenant in tenants) {
    if (tenant.isActive && tenant.expiryDate != null && tenant.expiryDate!.isAfter(now)) {
      active++;
    } else {
      expired++;
    }
    totalSubs += tenant.subscriberCount;
    subMap[tenant.name] = tenant.subscriberCount;
  }

  return DashboardStats(
    totalTenants: tenants.length,
    activeTenants: active,
    expiredTenants: expired,
    totalSubscribers: totalSubs,
    subscribersPerTenant: subMap,
  );
});

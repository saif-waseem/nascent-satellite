import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';

class TierBadgeWidget extends HookConsumerWidget {
  final bool compact;
  const TierBadgeWidget({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(tenantProvider);

    return tenantAsync.when(
      data: (tenant) {
        if (tenant == null) return const SizedBox.shrink();

        final tier = tenant.effectivePosTier;
        final tierColor = _getTierColor(tier);
        final tierLabel = _getTierLabel(tier);
        final tierIcon = _getTierIcon(tier);

        return InkWell(
          onTap: () => _showSubscriptionDetails(context, ref, tenant),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 4 : 6),
            decoration: BoxDecoration(
              color: tierColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tierColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tierIcon, style: TextStyle(fontSize: compact ? 12 : 14)),
                const SizedBox(width: 6),
                Text(
                  tierLabel,
                  style: TextStyle(
                    color: tierColor,
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'D':
        return const Color(0xFF6A1B9A); // Deep Purple
      case 'C':
        return const Color(0xFF00695C); // Teal
      case 'B':
        return const Color(0xFF0277BD); // Light Blue
      case 'A':
      default:
        return const Color(0xFF2E7D32); // Green
    }
  }

  String _getTierLabel(String tier) {
    switch (tier.toUpperCase()) {
      case 'D':
        return 'الباقة D • مؤسسات';
      case 'C':
        return 'الباقة C • سحابية';
      case 'B':
        return 'الباقة B • شبكة محلية';
      case 'A':
      default:
        return 'الباقة A • مجانية';
    }
  }

  String _getTierIcon(String tier) {
    switch (tier.toUpperCase()) {
      case 'D':
        return '👑';
      case 'C':
        return '💎';
      case 'B':
        return '⚡';
      case 'A':
      default:
        return '🟢';
    }
  }

  void _showSubscriptionDetails(BuildContext context, WidgetRef ref, TenantModel tenant) {
    final tier = tenant.effectivePosTier;
    final tierColor = _getTierColor(tier);

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tierColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_getTierIcon(tier), style: const TextStyle(fontSize: 26)),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tenant.name.isNotEmpty ? tenant.name : 'نظام نقطة البيع (POS)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              _getTierLabel(tier),
                              style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Device limit info card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.devices, size: 20, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text(
                            tenant.posDeviceLimit == -1 
                                ? 'الأجهزة: غير محدود' 
                                : 'الأجهزة المسموحة: ${tenant.posDeviceLimit}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tenant.isActive ? 'مُفعّل ومحمي ✅' : 'يحتاج تجديد ⚠️',
                          style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Feature Checklist
                const Text('الميزات المشمولة في باقتك:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                _featureItem('نقطة البيع الكاشير وإصدار الفواتير', true),
                _featureItem('إدارة المنتجات والمخزون والعملاء', true),
                _featureItem('قاعدة بيانات أوفلاين تعمل 100% بدون إنترنت', true),
                _featureItem('استيراد وتصدير إكسل (CSV)', tenant.isPosExcelAllowed),
                _featureItem('مزامنة الشبكة المحلية (LAN Sync)', tenant.isPosLanAllowed),
                _featureItem('المزامنة السحابية وقواعد Supabase SQL', tenant.isPosCloudAllowed),
                _featureItem('فروع متعددة وأجهزة غير محدودة', tier == 'D'),

                const SizedBox(height: 20),

                // Expiry info
                if (tenant.posExpiryDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('تاريخ انتهاء الاشتراك:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        Text(
                          '${tenant.posExpiryDate!.year}-${tenant.posExpiryDate!.month.toString().padLeft(2, '0')}-${tenant.posExpiryDate!.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('حسناً', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureItem(String text, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: active ? Colors.green : Colors.black26,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: active ? Colors.black87 : Colors.black38,
                decoration: active ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

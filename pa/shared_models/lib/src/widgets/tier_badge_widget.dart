import 'package:flutter/material.dart';
import '../models/tenant_model.dart';

void showTierLockedMessage(
  BuildContext context, {
  required TenantModel? tenant,
  required String featureName,
  required String minimumTier,
}) {
  final currentTier = tenant?.effectivePosTier ?? 'A';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.orange.shade800,
      content: Text(
        'ميزة "$featureName" غير متاحة في الباقة $currentTier. تتطلب الباقة $minimumTier أو تفعيلها من السوبر أدمن.',
      ),
    ),
  );
}

class TierBadgeWidget extends StatelessWidget {
  final TenantModel? tenant;
  final bool compact;
  const TierBadgeWidget({
    super.key,
    required this.tenant,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = tenant;
    if (t == null) return const SizedBox.shrink();

    final tier = t.effectivePosTier;
    final tierColor = _getTierColor(tier);
    final tierLabel = _getTierLabel(tier);

    return InkWell(
      onTap: () => showSubscriptionDetailsDialog(context, t),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: tierColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tierColor.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getTierIconData(tier),
              size: compact ? 14 : 16,
              color: tierColor,
            ),
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
  }

  static Color _getTierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'D':
        return const Color(0xFF6A1B9A);
      case 'C':
        return const Color(0xFF00695C);
      case 'B':
        return const Color(0xFF0277BD);
      case 'A':
      default:
        return const Color(0xFF2E7D32);
    }
  }

  static String _getTierLabel(String tier) {
    switch (tier.toUpperCase()) {
      case 'D':
        return 'الباقة D • مؤسسات';
      case 'C':
        return 'الباقة C • سحابية';
      case 'B':
        return 'الباقة B • شبكة محلية';
      case 'A':
      default:
        return 'الباقة A • محلية';
    }
  }

  static IconData _getTierIconData(String tier) {
    switch (tier.toUpperCase()) {
      case 'D':
        return Icons.workspace_premium_rounded;
      case 'C':
        return Icons.cloud_done_rounded;
      case 'B':
        return Icons.lan_rounded;
      case 'A':
      default:
        return Icons.computer_rounded;
    }
  }

  static void showSubscriptionDetailsDialog(
    BuildContext context,
    TenantModel tenant,
  ) {
    final tier = tenant.effectivePosTier;
    final tierColor = _getTierColor(tier);
    final devLimit = tenant.effectivePosDeviceLimit;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getTierIconData(tier),
                              color: tierColor,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tenant.name.isNotEmpty
                                    ? tenant.name
                                    : 'نظام نقطة البيع',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _getTierLabel(tier),
                                style: TextStyle(
                                  color: tierColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                              devLimit == -1
                                  ? 'الأجهزة: غير محدود'
                                  : 'الأجهزة المسموحة: $devLimit',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          tenant.isPosSubscriptionExpiredBeyondGrace
                              ? 'منتهي الاشتراك ⚠️'
                              : (tenant.isActive ? 'مُفعّل ✅' : 'غير مفعل'),
                          style: TextStyle(
                            color: tenant.isPosSubscriptionExpiredBeyondGrace
                                ? Colors.red.shade700
                                : Colors.green.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'الميزات المشمولة في باقتك:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _featureRow('نقطة البيع والعمل أوفلاين بالكامل (تخزين محلي)', true),
                  _featureRow('مزامنة الشبكة المحلية (LAN Sync)', tenant.isPosLanAllowed),
                  _featureRow('الخزن والمزامنة السحابية والنسخ الاحتياطي', tenant.isPosCloudAllowed),
                  _featureRow('استيراد وتصدير إكسل (Excel/CSV)', tenant.isPosExcelAllowed),
                  _featureRow('توليد إعلانات الفيديو بالذكاء الاصطناعي', tenant.isPosVideoGenAllowed),
                  _featureRow('لوحة المراقبة عن بعد', tenant.isPosRemoteDashAllowed),
                  _featureRow('تعدد الفروع والمخازن', tenant.isPosMultiBranchAllowed),
                  if (tenant.posExpiryDate != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'تاريخ انتهاء اشتراك الكاشير:',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          Text(
                            '${tenant.posExpiryDate!.year}-${tenant.posExpiryDate!.month.toString().padLeft(2, '0')}-${tenant.posExpiryDate!.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('حسناً'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _featureRow(String text, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.lock_outline,
            size: 16,
            color: active ? Colors.green : Colors.black38,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: active ? Colors.black87 : Colors.black45,
                decoration: active ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

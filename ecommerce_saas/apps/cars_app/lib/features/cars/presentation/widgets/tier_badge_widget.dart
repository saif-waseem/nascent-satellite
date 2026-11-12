import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/theme/app_theme.dart';
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

        final tier = tenant.effectiveCarsTier;
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
                  style: GoogleFonts.cairo(
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
        return const Color(0xFF00695C); // Teal Gold
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
    final tier = tenant.effectiveCarsTier;
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
                              tenant.name,
                              style: GoogleFonts.amiri(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.lapis),
                            ),
                            Text(
                              'معرّف المعرض: ${tenant.id}',
                              style: GoogleFonts.cairo(fontSize: 11, color: Colors.black45),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black38),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: AppColors.clayDark, height: 28),

                // Current Tier Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tierColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tierColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('خطة الاشتراك الحالية', style: GoogleFonts.cairo(fontSize: 11, color: Colors.black54)),
                          Text(
                            _getTierLabel(tier),
                            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: tierColor),
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
                          tenant.isActive ? 'مفعل ومحمي ✅' : 'يحتاج تجديد ⚠️',
                          style: GoogleFonts.cairo(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Feature Checklist
                Text('الميزات المشمولة في باقتك:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.lapis)),
                const SizedBox(height: 8),
                _featureItem('تسجيل وعرض وطباعة العقود بالكامل', true),
                _featureItem('قاعدة بيانات محلية تعمل 100% بدون إنترنت', true),
                _featureItem('استيراد وتصدير إكسل (CSV)', tenant.isCarsExcelAllowed),
                _featureItem('المزامنة السحابية وقواعد Supabase SQL', tier == 'C' || tier == 'D'),
                _featureItem('النسخ الاحتياطي السحابي التلقائي', tier == 'C' || tier == 'D'),
                _featureItem('فروع متعددة وأجهزة غير محدودة', tier == 'D'),

                const SizedBox(height: 20),

                // Expiry info
                if (tenant.carsExpiryDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.clay.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('تاريخ انتهاء الاشتراك:', style: GoogleFonts.cairo(fontSize: 12, color: Colors.black54)),
                        Text(
                          '${tenant.carsExpiryDate!.year}-${tenant.carsExpiryDate!.month.toString().padLeft(2, '0')}-${tenant.carsExpiryDate!.day.toString().padLeft(2, '0')}',
                          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.lapis),
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
                      backgroundColor: AppColors.lapis,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text('حسناً', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
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
              style: GoogleFonts.cairo(
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

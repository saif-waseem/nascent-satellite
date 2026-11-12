import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/services/local_db_service.dart';
import '../../../../core/services/cars_supabase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/cars/presentation/screens/cars_dashboard_screen.dart';

class ActivationScreen extends HookConsumerWidget {
  const ActivationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeController = useTextEditingController();
    final isLoading = useState(false);

    Future<void> activateWithTenant(TenantModel tenant) async {
      await LocalDbService.getBox<TenantModel>('tenants').put(tenant.id, tenant);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tenant_id', tenant.id);
      ref.read(tenantIdProvider.notifier).setTenantId(tenant.id);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CarsDashboardScreen()),
        );
      }
    }

    Future<void> activate() async {
      final code = codeController.text.trim();
      if (code.isEmpty) return;

      isLoading.value = true;
      try {
        // 1. Try Supabase SQL Database first (New Architecture)
        final supabaseService = CarsSupabaseService();
        final supabaseTenant = await supabaseService.findTenantByActivationCode(code);

        if (supabaseTenant != null) {
          if (!supabaseTenant.isCarsEnabled && supabaseTenant.posTier == 'A') {
            // Auto-enable for Tier A / Offline
            final activeTenant = supabaseTenant.copyWith(isCarsEnabled: true);
            await activateWithTenant(activeTenant);
            return;
          } else if (supabaseTenant.isCarsEnabled) {
            await activateWithTenant(supabaseTenant);
            return;
          }
        }

        // 2. Fallback: Firebase Firestore SDK
        try {
          final query = await FirebaseFirestore.instance
              .collection('tenants')
              .where('carsActivationCode', isEqualTo: code)
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            final doc = query.docs.first;
            final tenantData = {'id': doc.id, ...doc.data()};
            final tenant = TenantModel.fromJson(tenantData);

            if (tenant.isCarsEnabled) {
              await activateWithTenant(tenant);
              return;
            }
          }
        } catch (_) {}

        // 3. Fallback: Check if local demo or direct tenant ID match
        if (code == 'demo' || code == 'free' || code == 'mahmodcar') {
          final demoTenant = TenantModel(
            id: code == 'demo' ? 'local_default' : code,
            name: code == 'mahmodcar' ? 'معرض محمود للسيارات' : 'معرض السيارات التجريبي',
            adminIds: const ['admin'],
            isActive: true,
            isCarsEnabled: true,
            createdAt: DateTime.now(),
            posTier: 'C',
            carsTier: 'C',
            posExcelEnabled: true,
            carsExcelEnabled: true,
          );
          await activateWithTenant(demoTenant);
          return;
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('كود التفعيل غير صحيح أو الاشتراك غير مفعل'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في الاتصال: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> startFreeOffline() async {
      final offlineTenant = TenantModel(
        id: 'local_default',
        name: 'معرض السيارات (محلي)',
        adminIds: const ['admin'],
        isActive: true,
        isCarsEnabled: true,
        createdAt: DateTime.now(),
        posTier: 'A',
        carsTier: 'A',
        posExcelEnabled: true,
        carsExcelEnabled: true,
      );
      await activateWithTenant(offlineTenant);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.clay,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5)),
                ],
                border: const Border(top: BorderSide(color: AppColors.gold, width: 4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.lapis.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Text('🚗', style: TextStyle(fontSize: 38))),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'برنامج عقود السيارات',
                    style: GoogleFonts.amiri(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lapis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'القواعد السحابية الجديدة • نظام التيرات والإكسل',
                    style: GoogleFonts.cairo(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: codeController,
                    style: GoogleFonts.cairo(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'كود تفعيل المعرض أو المعرّف',
                      labelStyle: GoogleFonts.cairo(color: AppColors.lapis),
                      prefixIcon: const Icon(Icons.vpn_key, color: AppColors.gold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.gold, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.clay.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading.value ? null : activate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lapis,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: isLoading.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'تفعيل وتسجيل الدخول',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: startFreeOffline,
                    icon: const Icon(Icons.offline_pin, size: 18, color: AppColors.terracotta),
                    label: Text(
                      'الدخول بالباقة المجانية (بدون إنترنت - Tier A)',
                      style: GoogleFonts.cairo(fontSize: 13, color: AppColors.terracotta, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

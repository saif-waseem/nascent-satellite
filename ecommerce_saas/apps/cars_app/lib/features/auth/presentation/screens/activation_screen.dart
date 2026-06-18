import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/services/firestore_rest_service.dart';
import '../../../../core/services/local_db_service.dart';
import '../../../../features/cars/presentation/screens/cars_dashboard_screen.dart';

class ActivationScreen extends HookConsumerWidget {
  const ActivationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeController = useTextEditingController();
    final isLoading = useState(false);

    Future<void> activate() async {
      final code = codeController.text.trim();
      if (code.isEmpty) return;

      isLoading.value = true;
      try {
        final restService = ref.read(firestoreRestServiceProvider);
        final results = await restService.runQuery('tenants', {
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'carsActivationCode'},
              'op': 'EQUAL',
              'value': {'stringValue': code}
            }
          },
          'limit': 1
        });

        if (results.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('كود التفعيل غير صحيح')),
            );
          }
          isLoading.value = false;
          return;
        }

        final tenantData = results.first;
        final tenant = TenantModel.fromJson(tenantData);

        if (!tenant.isCarsEnabled) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('قسم السيارات غير مفعل لهذا الحساب')),
            );
          }
          isLoading.value = false;
          return;
        }

        // Save tenant locally + store tenant_id in prefs
        await LocalDbService.getBox<TenantModel>('tenants').put(tenant.id, tenant);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tenant_id', tenant.id);
        // Update provider
        ref.read(tenantIdProvider.notifier).setTenantId(tenant.id);

        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CarsDashboardScreen()),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في الاتصال: $e')),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: const Color(0xFF1B2A3B),
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car_filled, size: 72, color: Color(0xFF4FC3F7)),
                  const SizedBox(height: 16),
                  const Text(
                    'برنامج عقود سيارات',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'أدخل كود التفعيل للدخول',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: codeController,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'كود التفعيل',
                      labelStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF4FC3F7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
                      ),
                      prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF4FC3F7)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isLoading.value ? null : activate,
                      icon: isLoading.value
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login),
                      label: const Text('تفعيل الدخول', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4FC3F7),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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

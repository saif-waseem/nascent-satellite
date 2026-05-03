import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/services/firestore_rest_service.dart';

class ActivationScreen extends HookConsumerWidget {
  const ActivationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeIdController = useTextEditingController();
    final isLoading = useState(false);

    Future<void> _activate() async {
      final code = storeIdController.text.trim();
      if (code.isEmpty) return;
      
      isLoading.value = true;
      try {
        final restService = ref.read(firestoreRestServiceProvider);
        
        // Check posActivationCode
        final query1 = {
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'posActivationCode'},
              'op': 'EQUAL',
              'value': {'stringValue': code}
            }
          },
          'limit': 1
        };
        final results1 = await restService.runQuery('tenants', query1);

        if (results1.isNotEmpty) {
          await ref.read(tenantIdProvider.notifier).setTenantId(results1.first['id']);
          return;
        }

        // Check activationCode
        final query2 = {
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'activationCode'},
              'op': 'EQUAL',
              'value': {'stringValue': code}
            }
          },
          'limit': 1
        };
        final results2 = await restService.runQuery('tenants', query2);
        
        if (results2.isNotEmpty) {
          await ref.read(tenantIdProvider.notifier).setTenantId(results2.first['id']);
          return;
        }

        // Check direct ID
        final doc = await restService.getDocument('tenants/$code');
        if (doc != null) {
          await ref.read(tenantIdProvider.notifier).setTenantId(code);
          return;
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('رمز التفعيل غير صحيح أو المتجر غير موجود')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ: $e')),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront, size: 64, color: Colors.blue.shade600),
                const SizedBox(height: 24),
                const Text(
                  'تفعيل نقطة البيع',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أدخل رمز التفعيل الخاص بك للمتابعة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: storeIdController,
                  decoration: InputDecoration(
                    labelText: 'رمز التفعيل',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.key),
                  ),
                  onSubmitted: (_) => _activate(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: isLoading.value ? null : _activate,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading.value
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'تفعيل',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(tenantIdProvider.notifier).setTenantId('local_default');
                  },
                  icon: const Icon(Icons.cloud_off),
                  label: const Text('العمل محلياً فقط (بدون سيرفر)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

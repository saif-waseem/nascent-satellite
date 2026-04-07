import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../../core/providers/tenant_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

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
        final query1 = await FirebaseFirestore.instance
            .collection('tenants')
            .where('posActivationCode', isEqualTo: code)
            .limit(1)
            .get();

        if (query1.docs.isNotEmpty) {
          await ref.read(tenantIdProvider.notifier).setTenantId(query1.docs.first.id);
          return;
        }

        final query2 = await FirebaseFirestore.instance
            .collection('tenants')
            .where('activationCode', isEqualTo: code)
            .limit(1)
            .get();
        
        if (query2.docs.isNotEmpty) {
          await ref.read(tenantIdProvider.notifier).setTenantId(query2.docs.first.id);
          return;
        }

        final doc = await FirebaseFirestore.instance.collection('tenants').doc(code).get();
        if (doc.exists) {
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

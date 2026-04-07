import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/providers/tenant_repository.dart';
import '../../../../core/services/media_sync_service.dart';
import '../../../../core/services/storage_service.dart';

class ShopInfoTab extends HookConsumerWidget {
  const ShopInfoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(tenantProvider);

    return tenantAsync.when(
      data: (tenant) {
        if (tenant == null) return const Center(child: Text('Tenant not found'));
        return _ShopInfoForm(tenant: tenant);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _ShopInfoForm extends HookConsumerWidget {
  final TenantModel tenant;
  const _ShopInfoForm({required this.tenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController(text: tenant.name);
    final phoneController = useTextEditingController(text: tenant.whatsappNumber);
    final descController = useTextEditingController(text: tenant.description);
    final currencyController = useTextEditingController(text: tenant.currencyUnit);
    final logoController = useTextEditingController(text: tenant.logoUrl ?? '');

    final isLoading = useState(false);

    Future<void> saveChanges() async {
      isLoading.value = true;
      try {
        final updatedTenant = tenant.copyWith(
          name: nameController.text,
          whatsappNumber: phoneController.text,
          description: descController.text,
          currencyUnit: currencyController.text,
          logoUrl: logoController.text.trim().isEmpty ? null : logoController.text.trim(),
        );
        await ref.read(tenantRepositoryProvider).updateTenant(updatedTenant);
        // Trigger immediate sync
        ref.read(mediaSyncProvider.notifier).syncAll();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ البيانات بنجاح'), backgroundColor: Colors.green),
          );
          ref.invalidate(tenantProvider);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('بيانات المتجر الأساسية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المحل / المتجر',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (واتساب)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'وصف المحل',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: currencyController,
              decoration: const InputDecoration(
                labelText: 'العملة المستخدمة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // --- Logo Section ---
            const Divider(),
            const SizedBox(height: 8),
            const Text('شعار المتجر (للفواتير)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'أدخل رابط صورة الشعار (URL). يجب أن تكون الصورة متاحة على الإنترنت (مثل Firebase Storage أو Imgur).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: logoController,
                    decoration: const InputDecoration(
                      labelText: 'رابط الشعار (https://...)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: isLoading.value ? null : () async {
                    isLoading.value = true;
                    try {
                      final storage = ref.read(storageServiceProvider);
                      final url = await storage.pickAndUploadImage(
                        tenantId: tenant.id, 
                        folder: 'logos'
                      );
                      if (url != null) {
                        logoController.text = url;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم رفع الشعار بنجاح'))
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل الرفع: $e'), backgroundColor: Colors.red)
                        );
                      }
                    } finally {
                      isLoading.value = false;
                    }
                  },
                  icon: const Icon(Icons.upload),
                  tooltip: 'رفع صورة من الجهاز',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Preview current logo
            // Preview current logo reactively
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: logoController,
              builder: (context, value, child) {
                final logoString = value.text.trim();
                if (logoString.isEmpty) return const SizedBox();
                return Container(
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      logoString,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        if (kIsWeb) return const Center(child: Text('⚠️ تعذر تحميل الصورة', style: TextStyle(color: Colors.red)));
                        final file = io.File(logoString);
                        if (file.existsSync()) {
                          return Image.file(file, fit: BoxFit.contain);
                        }
                        return const Center(child: Text('⚠️ تعذر تحميل الصورة', style: TextStyle(color: Colors.red)));
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: isLoading.value ? null : saveChanges,
                icon: isLoading.value 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('حفظ التعديلات'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

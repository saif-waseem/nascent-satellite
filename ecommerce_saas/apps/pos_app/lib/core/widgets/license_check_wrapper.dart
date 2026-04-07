import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../providers/tenant_provider.dart';

class LicenseCheckWrapper extends ConsumerWidget {
  final Widget child;
  const LicenseCheckWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(tenantProvider);

    return tenantAsync.when(
      data: (tenant) {
        if (tenant == null) {
          final tenantId = ref.read(tenantIdProvider);
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.amber, size: 48),
                  const SizedBox(height: 16),
                  const Text('عذراً، لم يتم العثور على بيانات هذا المتجر'),
                  Text('Tenant ID: $tenantId', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => ref.refresh(tenantProvider), 
                    child: const Text('إعادة المحاولة'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.read(tenantIdProvider.notifier).clearTenantId(),
                    child: const Text('العودة لصفحة التفعيل', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          );
        }

        if (!tenant.isPosEnabled) {
          return _ActivationScreen(tenantId: tenant.id);
        }

        return child;
      },
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('جاري تحميل بيانات النظام...'),
              const SizedBox(height: 12),
              const Text(
                'إذا استغرق هذا وقتاً طويلاً، يرجى التحقق من اتصال الإنترنت',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                   // Force a rebuild or show current config
                },
                child: const Text('Tenant ID: landan'),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('فشل الاتصال بالسيرفر: $err', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.refresh(tenantProvider), 
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivationScreen extends StatefulWidget {
  final String tenantId;
  const _ActivationScreen({required this.tenantId});

  @override
  State<_ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<_ActivationScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'تفعيل نسخة المبيعات (POS)',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'يرجى إدخال كود التفعيل الدائمي الخاص بك',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'كود التفعيل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _handleActivation,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('تفعيل الآن'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // TODO: Link to support or copy tenant ID
                },
                child: Text('Tenant ID: ${widget.tenantId}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleActivation() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyActivationCode');
      await callable.call({
        'tenantId': widget.tenantId,
        'code': code,
        'appType': 'pos',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم التفعيل بنجاح!'), backgroundColor: Colors.green),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.code == 'permission-denied' 
              ? 'كود التفعيل غير صحيح. تحقق من الكود وحاول مجدداً.'
              : 'فشل التفعيل: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

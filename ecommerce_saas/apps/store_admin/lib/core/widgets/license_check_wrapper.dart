import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:store_admin/features/shared/providers.dart';

class LicenseCheckWrapper extends ConsumerWidget {
  final Widget child;
  const LicenseCheckWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(tenantProvider);

    return tenantAsync.when(
      data: (tenant) {
        if (tenant == null) {
          return const Scaffold(
            body: Center(child: Text('Tenant Profile Not Found.')),
          );
        }

        // Store App activation check
        if (!tenant.isStoreEnabled) {
          return _ActivationScreen(tenantId: tenant.id, currentCode: tenant.activationCode);
        }

        return child;
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Error checking license: $err')),
      ),
    );
  }
}

class _ActivationScreen extends StatefulWidget {
  final String tenantId;
  final String? currentCode;
  const _ActivationScreen({required this.tenantId, this.currentCode});

  @override
  State<_ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<_ActivationScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, size: 80, color: Colors.indigo),
              const SizedBox(height: 24),
              const Text(
                'تفعيل لوحة التحكم (Store Admin)',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              const SizedBox(height: 12),
              const Text(
                'يرجى إدخال كود التفعيل الخاص بمتجرك للاستمرار',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'كود التفعيل',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton(
                  onPressed: _isLoading ? null : _handleActivation,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('تفعيل متجري الآن', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Tenant ID: ${widget.tenantId}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
        'appType': 'store',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تفعيل المتجر بنجاح!'), backgroundColor: Colors.green),
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

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:store_admin/features/shared/providers.dart';

class LicenseCheckWrapper extends ConsumerWidget {
  final Widget child;
  const LicenseCheckWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentTenantAuthProvider);
    if (authState.status == TenantAuthStatus.unauthenticated || authState.tenantId.isEmpty) {
      return child;
    }

    final tenantAsync = ref.watch(tenantProvider);

    return tenantAsync.when(
      data: (tenant) {
        if (tenant == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 56),
                    const SizedBox(height: 16),
                    const Text('عذراً، لم يتم العثور على بيانات المتجر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(tenantProvider),
                      child: const Text('إعادة المحاولة'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => ref.read(currentTenantAuthProvider.notifier).clearTenant(),
                      icon: const Icon(Icons.arrow_back, color: Colors.red),
                      label: const Text('العودة لصفحة التفعيل', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final isExpired = tenant.expiryDate != null && tenant.expiryDate!.isBefore(DateTime.now());

        // Store App activation check
        if (!tenant.isStoreEnabled || isExpired) {
          return _ActivationScreen(tenantId: tenant.id, currentCode: tenant.activationCode, isExpired: isExpired);
        }

        return child;
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 56),
                const SizedBox(height: 16),
                Text('فشل التحقق من الترخيص: $err', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(tenantProvider),
                  child: const Text('إعادة المحاولة'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => ref.read(currentTenantAuthProvider.notifier).clearTenant(),
                  icon: const Icon(Icons.arrow_back, color: Colors.red),
                  label: const Text('العودة لصفحة التفعيل', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivationScreen extends ConsumerStatefulWidget {
  final String tenantId;
  final String? currentCode;
  final bool isExpired;
  const _ActivationScreen({required this.tenantId, this.currentCode, this.isExpired = false});

  @override
  ConsumerState<_ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<_ActivationScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isExpired ? Icons.hourglass_disabled_rounded : Icons.stars_rounded, 
                  size: 80, 
                  color: widget.isExpired ? Colors.red : Colors.indigo
                ),
                const SizedBox(height: 24),
                Text(
                  widget.isExpired ? 'انتهت صلاحية اشتراك لوحة التحكم' : 'تفعيل لوحة التحكم (Store Admin)',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isExpired 
                      ? 'انتهت فترة اشتراك متجرك. يرجى تجديد الاشتراك للاستمرار.'
                      : 'يرجى إدخال كود التفعيل الخاص بمتجرك للاستمرار',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
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
                    errorText: _errorMessage,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
                  onChanged: (_) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                  onSubmitted: (_) => _isLoading ? null : _handleActivation(),
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
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Tenant ID: ${widget.tenantId}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => ref.read(currentTenantAuthProvider.notifier).clearTenant(),
                  icon: const Icon(Icons.arrow_back, color: Colors.red),
                  label: const Text('العودة لصفحة التفعيل / تغيير المتجر', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleActivation() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال كود التفعيل');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
        ref.invalidate(tenantProvider);
      }
    } on FirebaseFunctionsException catch (e) {
      final msg = e.code == 'permission-denied'
          ? 'كود التفعيل غير صحيح. تحقق من الكود وحاول مجدداً.'
          : 'فشل التفعيل: ${e.message}';
      if (mounted) {
        setState(() => _errorMessage = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      final msg = 'خطأ: $e';
      if (mounted) {
        setState(() => _errorMessage = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

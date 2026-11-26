import '../services/pos_activation_service.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/tenant_provider.dart';

class LicenseCheckWrapper extends ConsumerWidget {
  final Widget child;
  const LicenseCheckWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('Building LicenseCheckWrapper...');
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

        final isExpired = tenant.posExpiryDate != null && tenant.posExpiryDate!.isBefore(DateTime.now());
        
        if (!tenant.isActive || !tenant.isPosEnabled || isExpired) {
          return _ActivationScreen(tenantId: tenant.id, isExpired: isExpired);
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
              TextButton.icon(
                onPressed: () => ref.read(tenantIdProvider.notifier).clearTenantId(),
                icon: const Icon(Icons.arrow_back, color: Colors.red),
                label: const Text('العودة لصفحة التفعيل', style: TextStyle(color: Colors.red)),
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
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => ref.read(tenantIdProvider.notifier).clearTenantId(),
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
  final bool isExpired;
  const _ActivationScreen({required this.tenantId, this.isExpired = false});

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
      backgroundColor: Colors.blueGrey[900],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                Text(
                  widget.isExpired ? 'انتهت صلاحية اشتراك المبيعات' : 'تفعيل نسخة المبيعات (POS)',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isExpired 
                      ? 'يرجى تجديد الاشتراك للتمكن من استخدام النظام مجدداً'
                      : 'يرجى إدخال كود التفعيل الخاص بك لنسخة المبيعات',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'كود التفعيل',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.vpn_key),
                    errorText: _errorMessage,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                  onSubmitted: (_) => _isLoading ? null : _handleActivation(),
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
                const Text(
                  'سيتم تفعيل النظام تلقائياً بعد إدخال الكود الصحيح والتحقق منه.',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => ref.read(tenantIdProvider.notifier).clearTenantId(),
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
      await activateCashier(ref, code, expectedTenant: widget.tenantId);
    } catch (e) {
      final msg = e is FormatException ? e.message : 'تعذّر الاتصال لخدمة التفعيل';
      if (mounted) {
        setState(() => _errorMessage = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}


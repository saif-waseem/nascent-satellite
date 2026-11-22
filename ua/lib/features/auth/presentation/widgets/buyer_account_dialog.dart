import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers.dart';

class BuyerAccountDialog extends ConsumerStatefulWidget {
  const BuyerAccountDialog({super.key, this.phone, this.restore = false});
  final String? phone;
  final bool restore;
  @override
  ConsumerState<BuyerAccountDialog> createState() => _BuyerAccountDialogState();
}

class _BuyerAccountDialogState extends ConsumerState<BuyerAccountDialog> {
  bool busy = false;

  Future<void> _handleDelete() async {
    setState(() => busy = true);
    try {
      final userPhone = widget.phone ?? ref.read(userPhoneProvider) ?? '';
      await ref.read(userActionsProvider).deleteAccount(userPhone);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف حسابك بنجاح من المتجر.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف الحساب: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPhone = widget.phone ?? ref.watch(userPhoneProvider) ?? '';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text('حذف الحساب نهائياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'هل أنت متأكد من رغبتك في حذف حسابك؟',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            'سيتم حذف جميع بياناتك الشخصية وعناوين التوصيل المسجلة فوراً وتسجيل خروجك من التطبيق.',
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          if (currentPhone.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_android, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'رقم الحساب: $currentPhone',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: busy ? null : _handleDelete,
          icon: busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.delete_forever, size: 18),
          label: const Text('تأكيد الحذف'),
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
        ),
      ],
    );
  }
}

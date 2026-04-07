import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/tenant_provider.dart';

class OnlineOrdersListenerWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const OnlineOrdersListenerWrapper({super.key, required this.child});

  @override
  ConsumerState<OnlineOrdersListenerWrapper> createState() => _OnlineOrdersListenerWrapperState();
}

class _OnlineOrdersListenerWrapperState extends ConsumerState<OnlineOrdersListenerWrapper> {
  int _orderCount = 0;
  bool _isInitialLoad = true;

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(tenantIdProvider);
    
    if (tenantId.isNotEmpty) {
      ref.listen<AsyncValue<QuerySnapshot>>(
        _ordersProvider(tenantId),
        (previous, next) {
          next.whenData((QuerySnapshot snapshot) {
            if (_isInitialLoad) {
              _isInitialLoad = false;
              _orderCount = snapshot.docs.length;
              return;
            }
            
            final currentCount = snapshot.docs.length;
            if (currentCount > _orderCount) {
               // New order received!
               _showNotificationSnackbar();
            }
            // Update count so it tracks future additions
            _orderCount = currentCount;
          });
        },
      );
    }

    return widget.child;
  }

  void _showNotificationSnackbar() {
    if (!mounted) return;
    
    // Ensure we are showing on the root scaffold messenger
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.shopping_bag, color: Colors.white, size: 28),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'طلب أونلاين جديد! يرجى مراجعة شاشة الطلبات.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
    );
  }
}

final _ordersProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, tenantId) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('tenantId', isEqualTo: tenantId)
      .where('status', isEqualTo: 'active')
      .where('tracking', isEqualTo: 'Pending')
      .snapshots();
});

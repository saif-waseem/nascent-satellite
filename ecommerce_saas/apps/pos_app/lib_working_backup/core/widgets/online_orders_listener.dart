import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/tenant_provider.dart';
import '../services/firestore_rest_service.dart';

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
      ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
        _ordersProvider(tenantId),
        (previous, next) {
          next.whenData((docs) {
            if (_isInitialLoad) {
              _isInitialLoad = false;
              _orderCount = docs.length;
              return;
            }
            
            final currentCount = docs.length;
            if (currentCount > _orderCount) {
               _showNotificationSnackbar();
            }
            _orderCount = currentCount;
          });
        },
      );
    }

    return widget.child;
  }

  void _showNotificationSnackbar() {
    if (!mounted) return;
    
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

final _ordersProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, tenantId) {
  final restService = ref.watch(firestoreRestServiceProvider);
  
  // Create a polling stream for Windows since REST doesn't support push notifications
  final controller = StreamController<List<Map<String, dynamic>>>();
  
  Timer? timer;
  
  Future<void> fetch() async {
    try {
      final query = {
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'tenantId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': tenantId}
                }
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'status'},
                  'op': 'EQUAL',
                  'value': {'stringValue': 'active'}
                }
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'tracking'},
                  'op': 'EQUAL',
                  'value': {'stringValue': 'Pending'}
                }
              }
            ]
          }
        }
      };
      final results = await restService.runQuery('orders', query);
      if (!controller.isClosed) {
        controller.add(results);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  fetch(); // Initial fetch
  timer = Timer.periodic(const Duration(minutes: 2), (_) => fetch());

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

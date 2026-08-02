import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class ConnectivityStatusBar extends HookConsumerWidget {
  const ConnectivityStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (defaultTargetPlatform == TargetPlatform.windows) return const SizedBox.shrink();

    final connectivity = useMemoized(() => Connectivity().onConnectivityChanged);
    final status = useStream(connectivity);

    final isOffline = status.hasData && status.data!.contains(ConnectivityResult.none);

    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.orange.shade800,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.white, size: 14),
          SizedBox(width: 8),
          Text(
            'وضع عدم الاتصال نشط - سيتم حفظ البيانات محلياً ومزامنتها عند عودة الإنترنت',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

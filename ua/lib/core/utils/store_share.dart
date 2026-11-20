import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareStoreRoute(BuildContext context, String route, String message) async {
  const configured = String.fromEnvironment('STORE_WEB_URL',
    defaultValue: 'https://saif-waseem.github.io/store/');
  final base = kIsWeb ? Uri.base : Uri.parse(configured);
  final url = base.replace(fragment: route);
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(text: '$message\n$url',
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size));
}
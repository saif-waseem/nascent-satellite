import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_models/shared_models.dart';
import '../providers/tenant_provider.dart';
import 'firestore_rest_service.dart';

class WarmupStatus {
  final bool isComplete;
  final double progress;
  final String stage;

  WarmupStatus({this.isComplete = false, this.progress = 0, this.stage = ''});
}

class DataWarmupNotifier extends Notifier<WarmupStatus> {
  @override
  WarmupStatus build() => WarmupStatus();

  void _updateProgress(WarmupStatus s) {
    state = s;
  }

  Future<void> startWarmup() async {
    final tenantId = ref.read(tenantIdProvider);
    if (tenantId.isEmpty) return;
    
    final restService = ref.read(firestoreRestServiceProvider);

    try {
      // PHASE 1: TEXT DATA (In REST, we just fetch to ensure connectivity and "warm up" the service)
      _updateProgress(WarmupStatus(stage: 'جاري مزامنة البيانات الأساسية...', progress: 0.1));
      
      final collections = ['products', 'customers', 'categories', 'tenants'];
      for (var i = 0; i < collections.length; i++) {
        final col = collections[i];
        _updateProgress(WarmupStatus(stage: 'تحقق من $col...', progress: 0.1 + (i * 0.1)));
        
        if (col == 'tenants') {
          await restService.getDocument('tenants/$tenantId');
        } else {
          await restService.runQuery(col, {
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': 'tenantId'},
                'op': 'EQUAL',
                'value': {'stringValue': tenantId}
              }
            },
            'limit': 1
          });
        }
      }

      _updateProgress(WarmupStatus(stage: 'اكتملت البيانات النصية ✅', progress: 0.5));

      // PHASE 2: IMAGE DATA
      final productResults = await restService.runQuery('products', {
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'tenantId'},
            'op': 'EQUAL',
            'value': {'stringValue': tenantId}
          }
        }
      });
       
      final productsWithImages = productResults
          .map((data) => ProductModel.fromJson(data))
          .where((p) => p.imageUrl != null && p.imageUrl!.isNotEmpty)
          .toList();

      if (productsWithImages.isEmpty) {
        _updateProgress(WarmupStatus(isComplete: true, stage: 'اكتملت المزامنة تماماً ✅', progress: 1.0));
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/product_images');
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

      int downloaded = 0;
      for (final product in productsWithImages) {
        final fileName = product.imageUrl!.split('/').last;
        final file = File('${cacheDir.path}/$fileName');
        
        if (!await file.exists()) {
          try {
            final response = await http.get(Uri.parse(product.imageUrl!));
            if (response.statusCode == 200) {
              await file.writeAsBytes(response.bodyBytes);
            }
          } catch (e) {
            debugPrint('Image download failed for ${product.name}: $e');
          }
        }
        downloaded++;
        _updateProgress(WarmupStatus(
          stage: 'جاري تحميل الصور ($downloaded/${productsWithImages.length})', 
          progress: 0.5 + (downloaded / productsWithImages.length * 0.5)
        ));
      }
      
      _updateProgress(WarmupStatus(isComplete: true, stage: 'المزامنة مكتملة 100% 🚀', progress: 1.0));
    } catch (e) {
      debugPrint('WARMUP ERROR: $e');
      _updateProgress(WarmupStatus(isComplete: true, stage: 'فشلت المزامنة الكاملة، سيعمل النظام بما هو متوفر.', progress: 1.0));
    }
  }
}

final dataWarmupProvider = NotifierProvider<DataWarmupNotifier, WarmupStatus>(DataWarmupNotifier.new);

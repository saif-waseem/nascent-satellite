import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_firestore_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/shared_models.dart';
import 'package:image_picker/image_picker.dart';

class AdminSupabaseService {
  final SupabaseClient? _customClient;

  final AdminFirestoreService? backup;
  Timer? _retry;
  bool _working=false;
  AdminSupabaseService([this._customClient,this.backup]){
    if(backup!=null){
      _retry=Timer.periodic(const Duration(seconds:30),(_)=>_flushBackup());
      unawaited(_flushBackup());
    }
  }
  void dispose()=>_retry?.cancel();

  Future<void> _markBackup(String tenant,String id)async {
    if(backup==null)return;
    final prefs=await SharedPreferences.getInstance();
    final key='catalog_backup:'+jsonEncode([tenant,id]);
    if(!await prefs.setString(key,DateTime.now().microsecondsSinceEpoch.toString()))throw StateError('تعذّر تسجيل النسخ الاحتياطي');
  }

  Future<void> _flushBackup()async {
    if(_working||backup==null)return;
    _working=true;
    try{
      final prefs=await SharedPreferences.getInstance();
      for(final k in prefs.getKeys().where((v)=>v.startsWith('catalog_backup:')).toList()){
        final version=prefs.getString(k);
        try{
          final parts=jsonDecode(k.substring('catalog_backup:'.length)) as List;
          final tenant=parts[0] as String,id=parts[1] as String;
          final row=await client.from('products').select().eq('tenant_id',tenant).eq('id',id).maybeSingle();
          if(row==null){await backup!.deleteProduct(id,tenant).timeout(const Duration(seconds:12));}
          else{await backup!.updateProduct(ProductCatalog.decode(row),tenant).timeout(const Duration(seconds:12));}
          if(prefs.getString(k)==version)await prefs.remove(k);
        }catch(_){continue;}
      }
    }finally{_working=false;}
  }

  SupabaseClient get client {
    try {
      return _customClient ?? Supabase.instance.client;
    } catch (_) {
      // Fallback instance if not yet initialized in main
      return SupabaseClient('https://placeholder.supabase.co', 'placeholder');
    }
  }

  static const String productMediaBucket = 'product-media';

  // ==================== 1. Products Management (SQL) ====================

  Stream<List<ProductModel>> getProductsStream(String tenantId) {
    return client
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_mapRowToProduct).where((p)=>!p.isArchived).toList());
  }

  Future<List<ProductModel>> getProducts(String tenantId) async {
    final products = <ProductModel>[];
    String? after;
    while (true) {
      var query = client.from('products').select().eq('tenant_id',tenantId);
      if (after != null) query = query.gt('id',after);
      final rows = await query.order('id').limit(250);
      products.addAll(rows.map(_mapRowToProduct));
      if (rows.length < 250) return products;
      after = products.last.id;
    }
  }

  Future<void> saveProduct(ProductModel product, String tenantId, {int? previousStock}) async {
    final row = _mapProductToRow(product, tenantId);
    if (previousStock == null) {
      await client.from('products').insert(row);
      await _markBackup(tenantId,product.id);unawaited(_flushBackup());return;
    }
    final updated = await client.from('products').update(row)
        .eq('id', product.id).eq('tenant_id', tenantId)
        .eq('stock_quantity', previousStock).select('id').maybeSingle();
    if (updated == null) {
      throw StateError('تغيّر رصيد الصنف أو لم يعد موجوداً. أعد فتحه ثم احفظ التعديل.');
    }
    await _markBackup(tenantId,product.id);unawaited(_flushBackup());
  }

  Future<void> addProduct(ProductModel product, String tenantId) async {
    await saveProduct(product, tenantId);
  }

  Future<void> updateProductPrice(String productId,double price,String tenantId) async {
    await client.from('products').update({'price':price,'old_price':null}).eq('tenant_id',tenantId).eq('id',productId);
    await _markBackup(tenantId,productId);unawaited(_flushBackup());
  }

  Future<void> deleteProduct(String productId,String tenantId) async {
    await client.from('products').delete().eq('tenant_id',tenantId).eq('id', productId);
    await _markBackup(tenantId,productId);unawaited(_flushBackup());
  }

  Future<ProductModel?> getProductByBarcode(String tenantId, String barcode) async {
    final response = await client
        .from('products')
        .select()
        .eq('tenant_id', tenantId)
        .eq('barcode', barcode)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return _mapRowToProduct(response);
  }

  // ==================== 2. Categories Management (SQL) ====================

  Stream<List<CategoryModel>> getCategoriesStream(String tenantId) {
    return client
        .from('categories')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('name')
        .map((rows) => rows.map((r) => CategoryModel(
              id: r['id'] as String,
              name: r['name'] as String,
              icon: r['icon'] as String? ?? 'folder',
            )).toList());
  }

  Future<void> saveCategory(CategoryModel category, String tenantId) async {
    await client.from('categories').upsert({
      'id': category.id.isNotEmpty ? category.id : DateTime.now().millisecondsSinceEpoch.toString(),
      'tenant_id': tenantId,
      'name': category.name,
      'icon': category.icon,
    });
  }

  Future<void> deleteCategory(String categoryId) async {
    await client.from('categories').delete().eq('id', categoryId);
  }

  // ==================== 3. POS Cashier Invoices Sync (SQL) ====================

  Stream<List<SalesInvoiceModel>> getSalesInvoicesStream(String tenantId) {
    return client
        .from('sales_invoices')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => SalesInvoiceModel.fromJson(r)).toList());
  }

  // ==================== 4. Video & Media Upload (Supabase Storage - Cloudflare CDN) ====================

  /// Uploads video directly to Supabase Storage Bucket, working flawlessly in Iraq via Cloudflare CDN
  Future<String?> uploadVideoFile(XFile videoFile, {required String tenantId}) async {
    try {
      final cleanName = videoFile.name.split(RegExp(r'[/\\]')).last;
      final path = '$tenantId/videos/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      final bytes = await videoFile.readAsBytes();

      await client.storage.from(productMediaBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              upsert: true,
            ),
          );

      final publicUrl = client.storage.from(productMediaBucket).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('SUPABASE VIDEO UPLOAD ERROR: $e');
      rethrow;
    }
  }

  /// Uploads product image to Supabase Storage
  Future<String?> uploadImageFile(XFile imageFile, {required String tenantId}) async {
    try {
      final cleanName = imageFile.name.split(RegExp(r'[/\\]')).last;
      final path = '$tenantId/images/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      final bytes = await imageFile.readAsBytes();

      await client.storage.from(productMediaBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      return client.storage.from(productMediaBucket).getPublicUrl(path);
    } catch (e) {
      print('SUPABASE IMAGE UPLOAD ERROR: $e');
      rethrow;
    }
  }

  // --- Helpers for SQL Mapping ---
  Map<String,dynamic> _mapProductToRow(ProductModel product,String tenantId) =>
    {...ProductCatalog.encode(product),'tenant_id':tenantId,'updated_at':DateTime.now().toUtc().toIso8601String()};
  ProductModel _mapRowToProduct(Map<String,dynamic> row)=>ProductCatalog.decode(row);
}

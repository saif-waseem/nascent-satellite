import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/shared_models.dart';
import 'package:image_picker/image_picker.dart';

class AdminSupabaseService {
  final SupabaseClient? _customClient;

  AdminSupabaseService([this._customClient]);

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
        .map((rows) => rows.map((r) => _mapRowToProduct(r)).toList());
  }

  Future<List<ProductModel>> getProducts(String tenantId) async {
    final response = await client
        .from('products')
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((r) => _mapRowToProduct(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProduct(ProductModel product, String tenantId, {int? previousStock}) async {
    final row = _mapProductToRow(product, tenantId);
    if (previousStock == null) {
      await client.from('products').upsert(row);
      return;
    }
    final updated = await client.from('products').update(row)
        .eq('id', product.id).eq('tenant_id', tenantId)
        .eq('stock_quantity', previousStock).select('id').maybeSingle();
    if (updated == null) {
      throw StateError('تغيّر رصيد الصنف أو لم يعد موجوداً. أعد فتحه ثم احفظ التعديل.');
    }
  }

  Future<void> addProduct(ProductModel product, String tenantId) async {
    await saveProduct(product, tenantId);
  }

  Future<void> deleteProduct(String productId) async {
    await client.from('products').delete().eq('id', productId);
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
  Map<String, dynamic> _mapProductToRow(ProductModel p, String tenantId) {
    return {
      'id': p.id.isNotEmpty ? p.id : DateTime.now().millisecondsSinceEpoch.toString(),
      'tenant_id': tenantId,
      'name': p.name,
      'category': p.category,
      'description': p.description,
      'price': p.price,
      'purchase_price': p.purchasePrice ?? 0.0,
      'wholesale_price': p.wholesalePrice ?? 0.0,
      'stock_quantity': p.stockQuantity,
      'min_stock_level': p.minStockLevel ?? 5,
      'unit': p.unit ?? 'قطعة',
      'barcode': p.barcode,
      'images': p.images,
      'video_url': p.videoUrl,
      'rating': p.rating,
      'sales_count': p.salesCount,
      'in_stock': p.inStock,
      'is_offer': p.isOffer,
      'is_featured_deal': p.isFeaturedDeal,
      'is_daily_starred': p.isDailyStarred,
      'variants': p.variants.map((v) => v.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  ProductModel _mapRowToProduct(Map<String, dynamic> r) {
    return ProductModel(
      id: r['id'] as String? ?? '',
      tenantId: r['tenant_id'] as String? ?? '',
      name: r['name'] as String? ?? '',
      category: r['category'] as String? ?? 'عام',
      description: r['description'] as String? ?? '',
      price: (r['price'] as num? ?? 0.0).toDouble(),
      purchasePrice: (r['purchase_price'] as num? ?? 0.0).toDouble(),
      wholesalePrice: (r['wholesale_price'] as num? ?? 0.0).toDouble(),
      stockQuantity: r['stock_quantity'] as int? ?? 0,
      minStockLevel: r['min_stock_level'] as int? ?? 5,
      unit: r['unit'] as String? ?? 'قطعة',
      barcode: r['barcode'] as String?,
      images: (r['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      videoUrl: r['video_url'] as String?,
      rating: (r['rating'] as num? ?? 5.0).toDouble(),
      salesCount: r['sales_count'] as int? ?? 0,
      inStock: r['in_stock'] as bool? ?? true,
      isOffer: r['is_offer'] as bool? ?? false,
      isFeaturedDeal: r['is_featured_deal'] as bool? ?? false,
      isDailyStarred: r['is_daily_starred'] as bool? ?? false,
      sizes: const [],
      colors: const [],
      variants: (r['variants'] as List<dynamic>?)
              ?.map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

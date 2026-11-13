import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_models/shared_models.dart';
import 'supabase_config.dart';

class PosSupabaseService {
  SupabaseClient? get _client => SupabaseConfig.safeClient;

  // ==================== 1. Tenant Lookup (SQL) ====================

  Future<TenantModel?> getTenant(String tenantId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('tenants')
          .select()
          .eq('id', tenantId)
          .maybeSingle();

      if (response == null) return null;
      return _mapRowToTenant(response);
    } catch (e) {
      debugPrint('Supabase getTenant note: $e');
      return null;
    }
  }

  Future<TenantModel?> getTenantByActivationCode(String code) async {
    final client = _client;
    if (client == null) return null;

    try {
      // Check pos_activation_code first
      var response = await client
          .from('tenants')
          .select()
          .eq('pos_activation_code', code)
          .maybeSingle();

      // Fallback to activation_code
      if (response == null) {
        response = await client
            .from('tenants')
            .select()
            .eq('activation_code', code)
            .maybeSingle();
      }

      // Fallback to id
      if (response == null) {
        response = await client
            .from('tenants')
            .select()
            .eq('id', code)
            .maybeSingle();
      }

      if (response == null) return null;
      return _mapRowToTenant(response);
    } catch (e) {
      debugPrint('Supabase getTenantByActivationCode note: $e');
      return null;
    }
  }

  // ==================== 2. Products Management (SQL) ====================

  Future<List<ProductModel>> getProducts(String tenantId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('products')
          .select()
          .eq('tenant_id', tenantId)
          .order('name');

      return (response as List<dynamic>)
          .map((r) => _mapRowToProduct(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Supabase getProducts note: $e');
      return [];
    }
  }

  Future<void> saveProduct(ProductModel product, String tenantId) async {
    final client = _client;
    if (client == null) return;

    try {
      final row = _mapProductToRow(product, tenantId);
      await client.from('products').upsert(row);
    } catch (e) {
      debugPrint('Supabase saveProduct note: $e');
    }
  }

  Future<void> saveProductsBatch(List<ProductModel> products, String tenantId) async {
    final client = _client;
    if (client == null || products.isEmpty) return;

    try {
      final rows = products.map((p) => _mapProductToRow(p, tenantId)).toList();
      await client.from('products').upsert(rows);
    } catch (e) {
      debugPrint('Supabase saveProductsBatch note: $e');
    }
  }

  // ==================== 3. Invoices Management (SQL) ====================

  Future<void> saveInvoice(SalesInvoiceModel invoice, String tenantId) async {
    final client = _client;
    if (client == null) return;

    try {
      final remainingAmount = invoice.totalAmount - invoice.discountAmount - invoice.paidAmount;
      final row = {
        'id': invoice.id,
        'tenant_id': tenantId,
        'receipt_number': invoice.receiptNumber,
        'customer_id': invoice.customerId,
        'total_amount': invoice.totalAmount,
        'discount_amount': invoice.discountAmount,
        'paid_amount': invoice.paidAmount,
        'remaining_amount': remainingAmount > 0 ? remainingAmount : 0.0,
        'payment_method': 'cash',
        'items': invoice.items.map((e) => e.toJson()).toList(),
        'date': invoice.date.toIso8601String(),
        'cashier_id': invoice.addedById,
        'cashier_name': invoice.addedBy,
        'is_returned': invoice.isReturned,
        'notes': invoice.sessionName,
        'created_at': invoice.date.toIso8601String(),
      };
      await client.from('sales_invoices').upsert(row);
    } catch (e) {
      debugPrint('Supabase saveInvoice note: $e');
    }
  }

  // ==================== 4. Helpers for SQL Mapping ====================

  TenantModel _mapRowToTenant(Map<String, dynamic> r) {
    return TenantModel(
      id: r['id'] as String? ?? '',
      name: r['name'] as String? ?? '',
      adminIds: (r['admin_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      logoUrl: r['logo_url'] as String?,
      description: r['description'] as String? ?? '',
      whatsappNumber: r['whatsapp_number'] as String? ?? '',
      primaryColor: r['primary_color'] as String? ?? '#000000',
      isActive: r['is_active'] as bool? ?? false,
      createdAt: r['created_at'] != null ? DateTime.tryParse(r['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      expiryDate: r['expiry_date'] != null ? DateTime.tryParse(r['expiry_date'].toString()) : null,
      activationCode: r['activation_code'] as String?,
      subscriberCount: r['subscriber_count'] as int? ?? 0,
      managerName: r['manager_name'] as String?,
      managerPhone: r['manager_phone'] as String?,
      isStoreEnabled: r['is_store_enabled'] as bool? ?? false,
      isPosEnabled: r['is_pos_enabled'] as bool? ?? true,
      posExpiryDate: r['pos_expiry_date'] != null ? DateTime.tryParse(r['pos_expiry_date'].toString()) : null,
      posActivationCode: r['pos_activation_code'] as String?,
      isCarsEnabled: r['is_cars_enabled'] as bool? ?? false,
      carsExpiryDate: r['cars_expiry_date'] != null ? DateTime.tryParse(r['cars_expiry_date'].toString()) : null,
      carsActivationCode: r['cars_activation_code'] as String?,
      currencyUnit: r['currency_unit'] as String? ?? 'IQD',
      shippingCost: (r['shipping_cost'] as num? ?? 5000.0).toDouble(),
      posTier: r['pos_tier'] as String? ?? 'A',
      posDeviceLimit: r['pos_device_limit'] as int? ?? 1,
      isTrialActive: r['is_trial_active'] as bool? ?? false,
      trialStartDate: r['trial_start_date'] != null ? DateTime.tryParse(r['trial_start_date'].toString()) : null,
      trialEndDate: r['trial_end_date'] != null ? DateTime.tryParse(r['trial_end_date'].toString()) : null,
      posGraceDays: r['pos_grace_days'] as int? ?? 14,
      posLanSyncEnabled: r['pos_lan_sync_enabled'] as bool? ?? false,
      posCloudBackupEnabled: r['pos_cloud_backup_enabled'] as bool? ?? false,
      posRemoteDashEnabled: r['pos_remote_dash_enabled'] as bool? ?? false,
      posExcelEnabled: r['pos_excel_enabled'] as bool? ?? false,
      posMultiBranchEnabled: r['pos_multi_branch_enabled'] as bool? ?? false,
      posVideoGenEnabled: r['pos_video_gen_enabled'] as bool? ?? false,
      posDailyVideoQuota: r['pos_daily_video_quota'] as int? ?? 0,
    );
  }

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
      inStock: r['in_stock'] as bool? ?? true,
      videoUrl: r['video_url'] as String?,
      rating: (r['rating'] as num? ?? 0.0).toDouble(),
      salesCount: r['sales_count'] as int? ?? 0,
      isOffer: r['is_offer'] as bool? ?? false,
      isFeaturedDeal: r['is_featured_deal'] as bool? ?? false,
      isDailyStarred: r['is_daily_starred'] as bool? ?? false,
    );
  }
}

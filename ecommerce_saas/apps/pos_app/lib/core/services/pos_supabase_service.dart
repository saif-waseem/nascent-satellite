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
      // 1. Check pos_activation_code first
      var response = await client
          .from('tenants')
          .select()
          .eq('pos_activation_code', code)
          .maybeSingle();

      // 2. Fallback to activation_code
      if (response == null) {
        response = await client
            .from('tenants')
            .select()
            .eq('activation_code', code)
            .maybeSingle();
      }

      // 3. Fallback to id
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

  Stream<List<ProductModel>> getProductsStream(String tenantId) {
    final client = _client;
    if (client == null) return Stream.value([]);

    return client
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('name')
        .map((rows) => rows.map((r) => _mapRowToProduct(r)).toList());
  }

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

  Future<ProductModel?> getProductByBarcode(String tenantId, String barcode) async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('products')
          .select()
          .eq('tenant_id', tenantId)
          .eq('barcode', barcode)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return _mapRowToProduct(response);
    } catch (e) {
      debugPrint('Supabase getProductByBarcode note: $e');
      return null;
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

  Future<void> deleteProduct(String productId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('products').delete().eq('id', productId);
    } catch (e) {
      debugPrint('Supabase deleteProduct note: $e');
    }
  }

  Future<void> updateStock(
    String tenantId,
    String productId,
    int adjustment, {
    String? color,
    String? size,
  }) async {
    final client = _client;
    if (client == null) return;

    try {
      final existing = await client
          .from('products')
          .select()
          .eq('id', productId)
          .eq('tenant_id', tenantId)
          .maybeSingle();

      if (existing == null) return;
      final currentStock = (existing['stock_quantity'] as num?)?.toInt() ?? 0;
      final newStock = (currentStock + adjustment).clamp(0, 999999);

      final updates = <String, dynamic>{
        'stock_quantity': newStock,
        'in_stock': newStock > 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final variantsRaw = existing['variants'] as List<dynamic>? ?? [];
      if (variantsRaw.isNotEmpty && (color != null || size != null)) {
        final targetColor = color ?? 'Default';
        final targetSize = size ?? 'Default';
        final updatedVariants = variantsRaw.map((v) {
          if (v is! Map) return v;
          final vMap = Map<String, dynamic>.from(v);
          if (vMap['color'] == targetColor && vMap['size'] == targetSize) {
            final vStock = (vMap['stock'] as num?)?.toInt() ?? 0;
            vMap['stock'] = (vStock + adjustment).clamp(0, 999999);
          }
          return vMap;
        }).toList();
        updates['variants'] = updatedVariants;
      }

      await client.from('products').update(updates).eq('id', productId);
    } catch (e) {
      debugPrint('Supabase updateStock note: $e');
    }
  }

  // ==================== 3. Categories Management (SQL) ====================

  Stream<List<CategoryModel>> getCategoriesStream(String tenantId) {
    final client = _client;
    if (client == null) return Stream.value([]);

    return client
        .from('categories')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('name')
        .map((rows) => rows.map((r) => _mapRowToCategory(r)).toList());
  }

  Future<List<CategoryModel>> getCategories(String tenantId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('categories')
          .select()
          .eq('tenant_id', tenantId)
          .order('name');

      return (response as List<dynamic>)
          .map((r) => _mapRowToCategory(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Supabase getCategories note: $e');
      return [];
    }
  }

  Future<void> saveCategory(CategoryModel category, String tenantId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('categories').upsert(_mapCategoryToRow(category, tenantId));
    } catch (e) {
      debugPrint('Supabase saveCategory note: $e');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('categories').delete().eq('id', categoryId);
    } catch (e) {
      debugPrint('Supabase deleteCategory note: $e');
    }
  }

  // ==================== 4. Invoices Management (SQL) ====================

  Stream<List<SalesInvoiceModel>> getSalesInvoicesStream(String tenantId) {
    final client = _client;
    if (client == null) return Stream.value([]);

    return client
        .from('sales_invoices')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => _mapRowToInvoice(r)).toList());
  }

  Future<List<SalesInvoiceModel>> getRecentSales(String tenantId, {int limit = 50}) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('sales_invoices')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((r) => _mapRowToInvoice(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Supabase getRecentSales note: $e');
      return [];
    }
  }

  Future<List<SalesInvoiceModel>> getSalesByDateRange(
    String tenantId,
    DateTime start,
    DateTime end,
  ) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('sales_invoices')
          .select()
          .eq('tenant_id', tenantId)
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((r) => _mapRowToInvoice(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Supabase getSalesByDateRange note: $e');
      return [];
    }
  }

  Future<SalesInvoiceModel?> getInvoiceByReceiptNumber(
    String tenantId,
    String receiptNumber,
  ) async {
    final client = _client;
    if (client == null) return null;

    try {
      var response = await client
          .from('sales_invoices')
          .select()
          .eq('tenant_id', tenantId)
          .eq('invoice_number', receiptNumber)
          .maybeSingle();

      if (response == null) {
        response = await client
            .from('sales_invoices')
            .select()
            .eq('tenant_id', tenantId)
            .eq('receipt_number', receiptNumber)
            .maybeSingle();
      }

      if (response == null) return null;
      return _mapRowToInvoice(response);
    } catch (e) {
      debugPrint('Supabase getInvoiceByReceiptNumber note: $e');
      return null;
    }
  }

  Future<void> saveInvoice(SalesInvoiceModel invoice, String tenantId) async {
    final client = _client;
    if (client == null) return;

    try {
      final remainingAmount = invoice.totalAmount - invoice.discountAmount - invoice.paidAmount;
      final receiptNum = invoice.receiptNumber.isNotEmpty
          ? invoice.receiptNumber
          : DateTime.now().millisecondsSinceEpoch.toString();

      final row = {
        'id': invoice.id.isNotEmpty ? invoice.id : DateTime.now().millisecondsSinceEpoch.toString(),
        'tenant_id': tenantId,
        'invoice_number': receiptNum,
        'customer_id': invoice.customerId,
        'customer_name': invoice.customerName,
        'cashier_id': invoice.addedById,
        'cashier_name': invoice.addedBy,
        'subtotal': invoice.totalAmount,
        'total': invoice.totalAmount,
        'discount': invoice.discountAmount,
        'paid_amount': invoice.paidAmount,
        'remaining_amount': remainingAmount > 0 ? remainingAmount : 0.0,
        'payment_method': 'cash',
        'items': invoice.items.map((e) => e.toJson()).toList(),
        'status': invoice.isReturned ? 'returned' : 'completed',
        'notes': invoice.sessionName ?? '',
        'created_at': invoice.date.toIso8601String(),
      };
      await client.from('sales_invoices').upsert(row);

      // Automatically deduct stock in Supabase products table
      for (final item in invoice.items) {
        if (item.productId.isNotEmpty) {
          final delta = invoice.isReturned ? item.quantity : -item.quantity;
          await updateStock(
            tenantId,
            item.productId,
            delta,
            color: item.variantColor,
            size: item.variantSize,
          );
        }
      }
    } catch (e) {
      debugPrint('Supabase saveInvoice note: $e');
    }
  }

  // ==================== 5. Customers Management (SQL) ====================

  Stream<List<CustomerModel>> getCustomersStream(String tenantId) {
    final client = _client;
    if (client == null) return Stream.value([]);

    return client
        .from('customers')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('name')
        .map((rows) => rows.map((r) => _mapRowToCustomer(r)).toList());
  }

  Future<List<CustomerModel>> getCustomers(String tenantId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('customers')
          .select()
          .eq('tenant_id', tenantId)
          .order('name');

      return (response as List<dynamic>)
          .map((r) => _mapRowToCustomer(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Supabase getCustomers note: $e');
      return [];
    }
  }

  Future<CustomerModel?> getCustomerById(String tenantId, String customerId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('customers')
          .select()
          .eq('tenant_id', tenantId)
          .eq('id', customerId)
          .maybeSingle();

      if (response == null) return null;
      return _mapRowToCustomer(response);
    } catch (e) {
      debugPrint('Supabase getCustomerById note: $e');
      return null;
    }
  }

  Future<void> saveCustomer(CustomerModel customer, String tenantId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('customers').upsert(_mapCustomerToRow(customer, tenantId));
    } catch (e) {
      debugPrint('Supabase saveCustomer note: $e');
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.from('customers').delete().eq('id', customerId);
    } catch (e) {
      debugPrint('Supabase deleteCustomer note: $e');
    }
  }

  // ==================== 6. Helpers for SQL Mapping ====================

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
      rating: (r['rating'] as num? ?? 5.0).toDouble(),
      salesCount: r['sales_count'] as int? ?? 0,
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

  Map<String, dynamic> _mapCategoryToRow(CategoryModel c, String tenantId) {
    return {
      'id': c.id.isNotEmpty ? c.id : DateTime.now().millisecondsSinceEpoch.toString(),
      'tenant_id': tenantId,
      'name': c.name,
      'icon_code': c.icon,
    };
  }

  CategoryModel _mapRowToCategory(Map<String, dynamic> r) {
    return CategoryModel(
      id: r['id'] as String? ?? '',
      name: r['name'] as String? ?? 'عام',
      icon: r['icon_code'] as String? ?? r['icon'] as String? ?? 'folder',
    );
  }

  SalesInvoiceModel _mapRowToInvoice(Map<String, dynamic> r) {
    final dateStr = r['created_at'] ?? r['date'];
    final date = dateStr != null ? DateTime.tryParse(dateStr.toString()) ?? DateTime.now() : DateTime.now();
    final itemsRaw = r['items'];
    List<SalesItem> items = [];
    if (itemsRaw is List) {
      items = itemsRaw.map((e) => SalesItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
    return SalesInvoiceModel(
      id: r['id'] as String? ?? '',
      tenantId: r['tenant_id'] as String? ?? r['tenantId'] as String? ?? '',
      receiptNumber: r['invoice_number'] as String? ?? r['receipt_number'] as String? ?? r['receiptNumber'] as String? ?? '',
      items: items,
      totalAmount: (r['total'] as num? ?? r['total_amount'] as num? ?? r['subtotal'] as num? ?? 0.0).toDouble(),
      discountAmount: (r['discount'] as num? ?? r['discount_amount'] as num? ?? 0.0).toDouble(),
      date: date,
      customerId: r['customer_id'] as String? ?? r['customerId'] as String?,
      customerName: r['customer_name'] as String? ?? r['customerName'] as String?,
      isReturned: r['is_returned'] as bool? ?? r['status'] == 'returned',
      status: r['status'] == 'draft' ? SalesInvoiceStatus.draft : SalesInvoiceStatus.finalized,
      sessionName: r['notes'] as String? ?? r['sessionName'] as String?,
      pointsRedeemed: (r['points_redeemed'] as num? ?? 0).toInt(),
      paidAmount: (r['paid_amount'] as num? ?? 0.0).toDouble(),
      addedBy: r['cashier_name'] as String? ?? r['addedBy'] as String?,
      addedById: r['cashier_id'] as String? ?? r['addedById'] as String?,
    );
  }

  Map<String, dynamic> _mapCustomerToRow(CustomerModel c, String tenantId) {
    return {
      'id': c.id.isNotEmpty ? c.id : DateTime.now().millisecondsSinceEpoch.toString(),
      'tenant_id': tenantId,
      'name': c.name,
      'phone_number': c.phoneNumber,
      'balance': c.balance,
      'address': c.address ?? '',
      'created_at': c.createdAt.toIso8601String(),
    };
  }

  CustomerModel _mapRowToCustomer(Map<String, dynamic> r) {
    final createdStr = r['created_at'] ?? r['createdAt'];
    return CustomerModel(
      id: r['id'] as String? ?? '',
      tenantId: r['tenant_id'] as String? ?? r['tenantId'] as String? ?? '',
      name: r['name'] as String? ?? '',
      phoneNumber: r['phone_number'] as String? ?? r['phoneNumber'] as String? ?? '',
      balance: (r['balance'] as num? ?? 0.0).toDouble(),
      createdAt: createdStr != null ? DateTime.tryParse(createdStr.toString()) ?? DateTime.now() : DateTime.now(),
      address: r['address'] as String?,
      loyaltyPoints: (r['loyalty_points'] as num? ?? 0).toInt(),
    );
  }
}

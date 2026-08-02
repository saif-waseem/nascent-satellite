import 'dart:convert';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/sales_repository.dart';
import '../../../products/data/product_repository.dart';
import '../../../../../core/providers/tenant_provider.dart';

class SalesSessionState {
  final List<SalesInvoiceModel> sessions;
  final int activeIndex;

  SalesSessionState({required this.sessions, required this.activeIndex});

  SalesInvoiceModel get activeInvoice => sessions[activeIndex];

  SalesSessionState copyWith({List<SalesInvoiceModel>? sessions, int? activeIndex}) {
    return SalesSessionState(
      sessions: sessions ?? this.sessions,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

final salesSessionProvider = NotifierProvider<SalesSessionManager, SalesSessionState>(SalesSessionManager.new);

final selectedWarehouseProvider = NotifierProvider<SelectedWarehouse, String?>(SelectedWarehouse.new);

class SelectedWarehouse extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? val) => state = val;
}

final availableWarehousesProvider = FutureProvider<List<String>>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final products = await ref.watch(productRepositoryProvider).getProducts(tenantId);
  final warehouses = <String>{};
  for (var product in products) {
    for (var variant in product.variants) {
      for (var loc in variant.storageLocations) {
        warehouses.add(loc.warehouseName);
      }
    }
  }
  return warehouses.toList()..sort();
});

class SalesSessionManager extends Notifier<SalesSessionState> {
  @override
  SalesSessionState build() {
    final tenantId = ref.read(tenantIdProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    
    // Load persisted state if exists
    final savedJson = prefs.getString('pos_sessions_$tenantId');
    if (savedJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savedJson);
        final sessions = decoded.map((item) => SalesInvoiceModel.fromJson(item)).toList();
        final savedIndex = prefs.getInt('pos_active_index_$tenantId') ?? 0;
        
        if (sessions.isNotEmpty) {
           return SalesSessionState(
             sessions: sessions,
             activeIndex: savedIndex < sessions.length ? savedIndex : 0,
           );
        }
      } catch (e) {
        // Fallback on error
      }
    }

    return SalesSessionState(
      sessions: [_createNewInvoice("وصل 1", tenantId)],
      activeIndex: 0,
    );
  }

  void _persist() {
    final tenantId = ref.read(tenantIdProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final json = jsonEncode(state.sessions.map((s) => s.toJson()).toList());
    prefs.setString('pos_sessions_$tenantId', json);
    prefs.setInt('pos_active_index_$tenantId', state.activeIndex);
  }

  static SalesInvoiceModel _createNewInvoice(String name, String tenantId) {
    return SalesInvoiceModel(
      id: const Uuid().v4(),
      tenantId: tenantId,
      receiptNumber: '',
      items: const [],
      totalAmount: 0.0,
      date: DateTime.now(),
      status: SalesInvoiceStatus.draft,
      sessionName: name,
    );
  }

  void addSession() {
    final tenantId = ref.read(tenantIdProvider);
    final nextNumber = state.sessions.length + 1;
    final newSession = _createNewInvoice("وصل $nextNumber", tenantId);
    state = state.copyWith(
      sessions: [...state.sessions, newSession],
      activeIndex: state.sessions.length,
    );
    _persist();
  }

  void setActiveIndex(int index) {
    state = state.copyWith(activeIndex: index);
    _persist();
  }

  void closeSession(int index) {
    if (state.sessions.length <= 1) {
      final tenantId = ref.read(tenantIdProvider);
      state = SalesSessionState(sessions: [_createNewInvoice("وصل 1", tenantId)], activeIndex: 0);
      return;
    }
    final newSessions = [...state.sessions]..removeAt(index);
    int nextActive = state.activeIndex;
    if (nextActive >= newSessions.length) {
      nextActive = newSessions.length - 1;
    }
    state = state.copyWith(sessions: newSessions, activeIndex: nextActive);
    _persist();
  }

  void updateActiveInvoice(SalesInvoiceModel invoice) {
    final newSessions = [...state.sessions];
    newSessions[state.activeIndex] = invoice;
    state = state.copyWith(sessions: newSessions);
    _persist();
  }

  void addItemToActive(SalesItem item) {
    final warehouse = ref.read(selectedWarehouseProvider);
    final invoice = state.activeInvoice;
    // Match by ID AND variants (color/size) AND warehouse
    final existingIndex = invoice.items.indexWhere((i) => 
      i.productId == item.productId && 
      i.variantColor == item.variantColor && 
      i.variantSize == item.variantSize &&
      i.warehouseName == (item.warehouseName ?? warehouse)
    );
    
    final itemWithWarehouse = item.warehouseName == null ? SalesItem(
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      discount: item.discount,
      category: item.category,
      variantColor: item.variantColor,
      variantSize: item.variantSize,
      warehouseName: warehouse,
      shelf: item.shelf,
      box: item.box,
    ) : item;
    
    List<SalesItem> newItems;
    if (existingIndex >= 0) {
      newItems = [...invoice.items];
      final existing = newItems[existingIndex];
      newItems[existingIndex] = SalesItem(
        productId: existing.productId,
        productName: existing.productName,
        quantity: existing.quantity + item.quantity,
        unitPrice: item.unitPrice,
        discount: existing.discount + item.discount,
        category: item.category,
        variantColor: existing.variantColor,
        variantSize: existing.variantSize,
        warehouseName: existing.warehouseName,
        shelf: existing.shelf,
        box: existing.box,
      );
    } else {
      newItems = [...invoice.items, itemWithWarehouse];
    }

    final newTotal = newItems.fold(0.0, (sum, i) => sum + i.totalPrice);
    updateActiveInvoice(invoice.copyWith(items: newItems, totalAmount: newTotal));
  }

  void updateItemDiscount(int index, double discountAmount) {
    final invoice = state.activeInvoice;
    if (index < 0 || index >= invoice.items.length) return;

    final newItems = [...invoice.items];
    final item = newItems[index];

    newItems[index] = SalesItem(
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      discount: discountAmount,
      category: item.category,
      variantColor: item.variantColor,
      variantSize: item.variantSize,
      warehouseName: item.warehouseName,
    );

    final newTotal = newItems.fold(0.0, (sum, i) => sum + i.totalPrice);
    updateActiveInvoice(invoice.copyWith(items: newItems, totalAmount: newTotal));
  }

  void removeItemFromActive(int index) {
    final invoice = state.activeInvoice;
    final newItems = [...invoice.items]..removeAt(index);
    final newTotal = newItems.fold(0.0, (sum, i) => sum + i.totalPrice);
    updateActiveInvoice(invoice.copyWith(items: newItems, totalAmount: newTotal));
  }

  void clearActive() {
    final invoice = state.activeInvoice;
    updateActiveInvoice(invoice.copyWith(items: [], totalAmount: 0, discountAmount: 0));
  }

  void setCustomer(String? id, String? name) {
    updateActiveInvoice(state.activeInvoice.copyWith(
      customerId: id,
      customerName: name,
    ));
  }

  void setDiscount(double amount) {
    updateActiveInvoice(state.activeInvoice.copyWith(
      discountAmount: amount,
    ));
  }

  void setLoyaltyPoints(int points, double value) {
     updateActiveInvoice(state.activeInvoice.copyWith(
       pointsRedeemed: points,
       // We'll subtract the value of points from the total or just track it
       // Usually, the totalAmount in the model should be the FINAL amount.
     ));
  }
}

final salesListProvider = FutureProvider<List<SalesInvoiceModel>>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  return await ref.watch(salesRepositoryProvider).getRecentSales(tenantId);
});

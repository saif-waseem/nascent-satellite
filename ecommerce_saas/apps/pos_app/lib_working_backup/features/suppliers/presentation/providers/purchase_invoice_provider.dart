import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';

final purchaseSessionProvider = NotifierProvider<PurchaseSessionManager, PurchaseSessionState>(PurchaseSessionManager.new);

class PurchaseSessionState {
  final List<PurchaseInvoiceModel> sessions;
  final int activeIndex;

  PurchaseSessionState({required this.sessions, required this.activeIndex});

  PurchaseInvoiceModel get activeInvoice => sessions[activeIndex];

  PurchaseSessionState copyWith({List<PurchaseInvoiceModel>? sessions, int? activeIndex}) {
    return PurchaseSessionState(
      sessions: sessions ?? this.sessions,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

class PurchaseSessionManager extends Notifier<PurchaseSessionState> {
  @override
  PurchaseSessionState build() {
    // Use ref.read (not watch) to avoid state reset when tenant stream re-emits
    final tenantId = ref.read(tenantIdProvider);
    return PurchaseSessionState(
      sessions: [_createNewInvoice("الفاتورة 1", tenantId)],
      activeIndex: 0,
    );
  }

  static PurchaseInvoiceModel _createNewInvoice(String name, String tenantId) {
    final now = DateTime.now();
    return PurchaseInvoiceModel(
      id: '', // Will be assigned on save
      tenantId: tenantId, 
      supplierId: '',
      items: const [],
      totalAmount: 0.0,
      paidAmount: 0.0,
      date: now,
      status: PurchaseInvoiceStatus.draft,
      totalDiscount: 0.0,
      sessionName: name,
    );
  }

  void addSession() {
    final nextNumber = state.sessions.length + 1;
    final tenantId = ref.read(tenantIdProvider);
    final newSession = _createNewInvoice("الفاتورة $nextNumber", tenantId);
    state = state.copyWith(
      sessions: [...state.sessions, newSession],
      activeIndex: state.sessions.length,
    );
  }

  void setActiveIndex(int index) {
    state = state.copyWith(activeIndex: index);
  }

  void closeSession(int index) {
    if (state.sessions.length <= 1) return;
    final newSessions = [...state.sessions]..removeAt(index);
    int nextActive = state.activeIndex;
    if (nextActive >= newSessions.length) {
      nextActive = newSessions.length - 1;
    }
    state = state.copyWith(sessions: newSessions, activeIndex: nextActive);
  }

  void updateActiveInvoice(PurchaseInvoiceModel invoice) {
    final newSessions = [...state.sessions];
    newSessions[state.activeIndex] = invoice;
    state = state.copyWith(sessions: newSessions);
  }

  void addItemToActive(InvoiceItem item) {
    final invoice = state.activeInvoice;
    final existingIndex = invoice.items.indexWhere((i) => i.productId == item.productId);
    
    List<InvoiceItem> newItems;
    if (existingIndex >= 0) {
      newItems = [...invoice.items];
      final existingItem = newItems[existingIndex];
      newItems[existingIndex] = InvoiceItem(
        productId: item.productId,
        productName: item.productName,
        quantity: existingItem.quantity + item.quantity,
        unitCost: item.unitCost, // Update with latest cost
        discount: existingItem.discount + item.discount,
      );
    } else {
      newItems = [...invoice.items, item];
    }

    final total = newItems.fold(0.0, (sum, i) => sum + i.totalCost);
    updateActiveInvoice(invoice.copyWithManual(items: newItems, totalAmount: total));
  }

  void removeItemFromActive(int index) {
    final invoice = state.activeInvoice;
    final newItems = [...invoice.items]..removeAt(index);
    final total = newItems.fold(0.0, (sum, i) => sum + i.totalCost);
    updateActiveInvoice(invoice.copyWithManual(items: newItems, totalAmount: total));
  }

  void resetActive() {
    final tenantId = ref.read(tenantIdProvider);
    final newInvoice = _createNewInvoice(state.activeInvoice.sessionName ?? "الفاتورة", tenantId);
    updateActiveInvoice(newInvoice);
  }

  void updateActiveSupplier(String id, String name) {
    updateActiveInvoice(state.activeInvoice.copyWithManual(
      supplierId: id,
      supplierName: name,
    ));
  }
}

// Manual copyWith because generator might not be ready
extension PurchaseInvoiceModelExtension on PurchaseInvoiceModel {
  PurchaseInvoiceModel copyWithManual({
    List<InvoiceItem>? items,
    double? totalAmount,
    double? paidAmount,
    PurchaseInvoiceStatus? status,
    double? totalDiscount,
    String? supplierId,
    String? supplierName,
  }) {
    return PurchaseInvoiceModel(
      id: id,
      tenantId: tenantId,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      date: date,
      status: status ?? this.status,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      sessionName: sessionName,
    );
  }
}

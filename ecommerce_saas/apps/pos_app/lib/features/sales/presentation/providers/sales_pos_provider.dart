import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:uuid/uuid.dart';
import '../../data/sales_repository.dart';
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

class SalesSessionManager extends Notifier<SalesSessionState> {
  @override
  SalesSessionState build() {
    final tenantId = ref.read(tenantIdProvider);
    return SalesSessionState(
      sessions: [_createNewInvoice("وصل 1", tenantId)],
      activeIndex: 0,
    );
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
  }

  void setActiveIndex(int index) {
    state = state.copyWith(activeIndex: index);
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
  }

  void updateActiveInvoice(SalesInvoiceModel invoice) {
    final newSessions = [...state.sessions];
    newSessions[state.activeIndex] = invoice;
    state = state.copyWith(sessions: newSessions);
  }

  void addItemToActive(SalesItem item) {
    final invoice = state.activeInvoice;
    // Match by ID AND variants (color/size)
    final existingIndex = invoice.items.indexWhere((i) => 
      i.productId == item.productId && 
      i.variantColor == item.variantColor && 
      i.variantSize == item.variantSize
    );
    
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
      );
    } else {
      newItems = [...invoice.items, item];
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

final salesListProvider = StreamProvider<List<SalesInvoiceModel>>((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  return ref.watch(salesRepositoryProvider).watchSales(tenantId);
});


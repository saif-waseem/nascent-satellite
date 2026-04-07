import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart';

final purchaseRepositoryProvider = Provider((ref) => PurchaseRepository(FirebaseFirestore.instance));

class PurchaseRepository {
  final FirebaseFirestore _firestore;

  PurchaseRepository(this._firestore);

  // --- Root collection reference (consistent with Firestore rules) ---
  CollectionReference<PurchaseInvoiceModel> get _invoiceCol =>
      _firestore
          .collection('purchase_invoices')
          .withConverter<PurchaseInvoiceModel>(
            fromFirestore: (snapshot, _) =>
                PurchaseInvoiceModel.fromJson(snapshot.data()!..['id'] = snapshot.id),
            toFirestore: (model, _) => model.toJson(),
          );

  Future<void> saveInvoice(String tenantId, PurchaseInvoiceModel invoice) async {
    final batch = _firestore.batch();

    final invoiceDoc = invoice.id.isEmpty ? _invoiceCol.doc() : _invoiceCol.doc(invoice.id);
    final updatedInvoice = invoice.copyWith(
      id: invoice.id.isEmpty ? invoiceDoc.id : invoice.id, 
      tenantId: tenantId,
      status: invoice.status,
    );
    debugPrint('SAVING PURCHASE INVOICE: id=${updatedInvoice.id}, status=${updatedInvoice.status.name}, items=${updatedInvoice.items.length}');
    batch.set(invoiceDoc, updatedInvoice);

    // Only update stock and supplier balance if finalized
    if (updatedInvoice.status == PurchaseInvoiceStatus.finalized) {
      // Update supplier balance — root 'suppliers' collection
      if (updatedInvoice.supplierId.isNotEmpty) {
        final supplierRef = _firestore
            .collection('suppliers')
            .doc(updatedInvoice.supplierId);
        final diff = updatedInvoice.remainingAmount;
        if (diff != 0) {
          batch.update(supplierRef, {'balance': FieldValue.increment(diff)});
        }
      }

      // Update product stock — root 'products' collection
      for (final item in updatedInvoice.items) {
        if (item.productId.isNotEmpty) {
          final productRef = _firestore
              .collection('products')
              .doc(item.productId);
          batch.update(productRef, {
            'stockQuantity': FieldValue.increment(item.quantity),
            'lastSupplierId': updatedInvoice.supplierId,
          });
        }
      }
    }

    await batch.commit();
  }

  Stream<List<PurchaseInvoiceModel>> watchSupplierInvoices(String tenantId, String supplierId) {
    return _invoiceCol
        .where('tenantId', isEqualTo: tenantId)
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => doc.data()).toList();
          // Sort by date descending in memory (avoids composite index requirement)
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  Stream<List<PurchaseInvoiceModel>> watchAllInvoices(String tenantId) {
    return _invoiceCol
        .where('tenantId', isEqualTo: tenantId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => doc.data()).toList();
          // Sort by date descending in memory
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }
}

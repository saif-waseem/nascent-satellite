import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DebtRepository {
  final FirebaseFirestore _firestore;

  DebtRepository(this._firestore);

  CollectionReference<CustomerModel> _customerBase() =>
      _firestore.collection('customers').withConverter<CustomerModel>(
            fromFirestore: (snapshot, _) => CustomerModel.fromJson({...snapshot.data()!, 'id': snapshot.id}),
            toFirestore: (model, _) => model.toJson(),
          );

  CollectionReference<SupplierModel> _supplierBase() =>
      _firestore.collection('suppliers').withConverter<SupplierModel>(
            fromFirestore: (snapshot, _) => SupplierModel.fromJson({...snapshot.data()!, 'id': snapshot.id}),
            toFirestore: (model, _) => model.toJson(),
          );

  // --- Customer Debts ---
  
  Stream<List<CustomerModel>> watchCustomers(String tenantId) {
    // Watch POS-only customers
    final posStream = _customerBase()
        .where('tenantId', isEqualTo: tenantId)
        .snapshots();
        
    // Watch Store-registered users
    final storeStream = _firestore.collection('users')
        .where('tenantId', isEqualTo: tenantId)
        .snapshots();

    final controller = StreamController<List<CustomerModel>>();
    
    List<CustomerModel> posList = [];
    List<CustomerModel> storeList = [];

    void update() {
      if (!controller.isClosed) {
        final combined = [...posList, ...storeList];
        // Sort by name
        combined.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        controller.add(combined);
      }
    }

    final posSub = posStream.listen((s) {
      posList = s.docs.map((d) => d.data()).toList();
      update();
    });

    final storeSub = storeStream.listen((s) {
      storeList = s.docs.map((d) {
        final data = d.data();
        return CustomerModel(
          id: d.id,
          tenantId: tenantId,
          name: data['name'] ?? (data['email'] != null ? (data['email'] as String).split('@')[0] : d.id),
          phoneNumber: data['phone'] ?? '',
          balance: (data['balance'] as num? ?? 0.0).toDouble(),
          createdAt: _parseDate(data['createdAt']),
          loyaltyPoints: data['loyaltyPoints'] as int? ?? 0,
        );
      }).toList();
      update();
    });

    controller.onCancel = () {
      posSub.cancel();
      storeSub.cancel();
    };

    return controller.stream;
  }

  static DateTime _parseDate(dynamic val) {
    if (val is DateTime) return val;
    if (val is String) return DateTime.parse(val);
    if (val is Timestamp) return val.toDate();
    return DateTime.now();
  }

  Future<void> recordCustomerPayment(String tenantId, String customerId, double amount, {String? note, String? customerName}) async {
    final isStoreUser = customerId.startsWith('user_');
    final collection = isStoreUser ? 'users' : 'customers';
    final docRef = _firestore.collection(collection).doc(customerId);
    
    final snapshot = await docRef.get();
    final batch = _firestore.batch();
    
    if (!snapshot.exists) {
      if (isStoreUser) throw Exception('Store user not found');
      // Create new POS customer
      batch.set(docRef, CustomerModel(
        id: customerId,
        name: customerName ?? 'User $customerId',
        phoneNumber: '',
        balance: -amount,
        tenantId: tenantId,
        createdAt: DateTime.now(),
      ).toJson());
    } else {
      batch.update(docRef, {
        'balance': FieldValue.increment(-amount),
        'tenantId': tenantId,
      });
    }
    
    final transRef = docRef.collection('transactions').doc();
    batch.set(transRef, {
      'amount': amount,
      'type': 'payment',
      'date': FieldValue.serverTimestamp(),
      'note': note ?? 'تسديد وصل',
      'tenantId': tenantId,
    });
    
    await batch.commit();
  }

  Future<void> recordCustomerDebt(String tenantId, String customerId, double amount, {String? note, String? customerName}) async {
    final isStoreUser = customerId.startsWith('user_');
    final collection = isStoreUser ? 'users' : 'customers';
    final docRef = _firestore.collection(collection).doc(customerId);
    
    final snapshot = await docRef.get();
    final batch = _firestore.batch();
    
    if (!snapshot.exists) {
      if (isStoreUser) throw Exception('Store user not found');
      batch.set(docRef, CustomerModel(
        id: customerId,
        name: customerName ?? 'User $customerId',
        phoneNumber: '',
        balance: amount,
        tenantId: tenantId,
        createdAt: DateTime.now(),
      ).toJson());
    } else {
      batch.update(docRef, {
        'balance': FieldValue.increment(amount),
        'tenantId': tenantId,
      });
    }
    
    final transRef = docRef.collection('transactions').doc();
    batch.set(transRef, {
      'amount': amount,
      'type': 'debt',
      'date': FieldValue.serverTimestamp(),
      'note': note ?? 'إضافة دين يدوي',
      'tenantId': tenantId,
    });
    
    await batch.commit();
  }

  // --- Supplier Debts ---

  Stream<List<SupplierModel>> watchSuppliers(String tenantId) {
    return _supplierBase().where('tenantId', isEqualTo: tenantId).snapshots().map((s) {
      final list = s.docs.map((d) => d.data()).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<void> recordSupplierPayment(String tenantId, String supplierId, double amount, {String? note}) async {
    final docRef = _supplierBase().doc(supplierId);
    
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;
    
    final batch = _firestore.batch();
    batch.update(docRef, {'balance': FieldValue.increment(-amount)});
    
    final transRef = docRef.collection('transactions').doc();
    batch.set(transRef, {
      'amount': amount,
      'type': 'payment',
      'date': FieldValue.serverTimestamp(),
      'note': note ?? 'تسديد دفع للمورد',
      'tenantId': tenantId,
    });
    
    await batch.commit();
  }

  Future<void> recordSupplierDebt(String tenantId, String supplierId, double amount, {String? note}) async {
    final docRef = _supplierBase().doc(supplierId);
    
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;
    
    final batch = _firestore.batch();
    batch.update(docRef, {'balance': FieldValue.increment(amount)});
    
    final transRef = docRef.collection('transactions').doc();
    batch.set(transRef, {
      'amount': amount,
      'type': 'debt',
      'date': FieldValue.serverTimestamp(),
      'note': note ?? 'إضافة دين يدوي (للمورد)',
      'tenantId': tenantId,
    });
    
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> watchCustomerTransactions(String customerId) {
    final isStoreUser = customerId.startsWith('user_');
    final collection = isStoreUser ? 'users' : 'customers';
    
    return _firestore.collection(collection)
        .doc(customerId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Stream<List<Map<String, dynamic>>> watchSupplierTransactions(String supplierId) {
    return _supplierBase()
        .doc(supplierId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}

final debtRepositoryProvider = Provider((ref) => DebtRepository(FirebaseFirestore.instance));

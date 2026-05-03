import 'dart:async';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';

class DebtRepository {
  final FirestoreRestService _restService;

  DebtRepository(this._restService);

  // --- Customer Debts ---
  
  Future<List<CustomerModel>> getCustomersWithDebts(String tenantId) async {
    // Fetch POS-only customers
    final customerQuery = {
      'where': {
        'fieldFilter': {
          'field': {'fieldPath': 'tenantId'},
          'op': 'EQUAL',
          'value': {'stringValue': tenantId}
        }
      }
    };
    final posResults = await _restService.runQuery('customers', customerQuery);
    final posList = posResults.map((data) => CustomerModel.fromJson(data)).toList();
        
    // Fetch Store-registered users
    final userQuery = {
      'where': {
        'fieldFilter': {
          'field': {'fieldPath': 'tenantId'},
          'op': 'EQUAL',
          'value': {'stringValue': tenantId}
        }
      }
    };
    final appResults = await _restService.runQuery('users', userQuery);
    final storeList = appResults.map((data) {
      final user = UserModel.fromJson(data);
      return CustomerModel(
        id: 'user_${user.id}',
        tenantId: tenantId,
        name: user.name ?? user.email.split('@').first,
        phoneNumber: user.phone ?? user.email,
        balance: user.balance,
        createdAt: user.createdAt,
        loyaltyPoints: user.loyaltyPoints,
      );
    }).toList();

    final combined = [...posList, ...storeList];
    combined.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return combined;
  }

  Future<void> recordCustomerPayment(String tenantId, String customerId, double amount, {String? note, String? customerName}) async {
    final isStoreUser = customerId.startsWith('user_');
    final collection = isStoreUser ? 'users' : 'customers';
    final docId = isStoreUser ? customerId.replaceFirst('user_', '') : customerId;
    
    final data = await _restService.getDocument('$collection/$docId');
    
    if (data == null) {
      if (isStoreUser) throw Exception('Store user not found');
      // Create new POS customer
      final newCustomer = CustomerModel(
        id: customerId,
        name: customerName ?? 'User $customerId',
        phoneNumber: '',
        balance: -amount,
        tenantId: tenantId,
        createdAt: DateTime.now(),
      );
      await _restService.setDocument('customers/$customerId', newCustomer.toJson());
    } else {
      final currentBalance = (data['balance'] as num? ?? 0.0).toDouble();
      await _restService.setDocument('$collection/$docId', {
        'balance': currentBalance - amount,
        'tenantId': tenantId,
      }, isUpdate: true);
    }
    
    // Add transaction to subcollection
    final transId = DateTime.now().millisecondsSinceEpoch.toString();
    await _restService.setDocument('$collection/$docId/transactions/$transId', {
      'amount': amount,
      'type': 'payment',
      'date': DateTime.now().toIso8601String(),
      'note': note ?? 'تسديد وصل',
      'tenantId': tenantId,
    });
  }

  Future<void> recordCustomerDebt(String tenantId, String customerId, double amount, {String? note, String? customerName}) async {
    final isStoreUser = customerId.startsWith('user_');
    final collection = isStoreUser ? 'users' : 'customers';
    final docId = isStoreUser ? customerId.replaceFirst('user_', '') : customerId;
    
    final data = await _restService.getDocument('$collection/$docId');
    
    if (data == null) {
      if (isStoreUser) throw Exception('Store user not found');
      final newCustomer = CustomerModel(
        id: customerId,
        name: customerName ?? 'User $customerId',
        phoneNumber: '',
        balance: amount,
        tenantId: tenantId,
        createdAt: DateTime.now(),
      );
      await _restService.setDocument('customers/$customerId', newCustomer.toJson());
    } else {
      final currentBalance = (data['balance'] as num? ?? 0.0).toDouble();
      await _restService.setDocument('$collection/$docId', {
        'balance': currentBalance + amount,
        'tenantId': tenantId,
      }, isUpdate: true);
    }
    
    final transId = DateTime.now().millisecondsSinceEpoch.toString();
    await _restService.setDocument('$collection/$docId/transactions/$transId', {
      'amount': amount,
      'type': 'debt',
      'date': DateTime.now().toIso8601String(),
      'note': note ?? 'إضافة دين يدوي',
      'tenantId': tenantId,
    });
  }

  // --- Supplier Debts ---

  Future<List<SupplierModel>> getSuppliers(String tenantId) async {
    final query = {
      'where': {
        'fieldFilter': {
          'field': {'fieldPath': 'tenantId'},
          'op': 'EQUAL',
          'value': {'stringValue': tenantId}
        }
      }
    };
    final results = await _restService.runQuery('suppliers', query);
    final list = results.map((d) => SupplierModel.fromJson(d)).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> recordSupplierPayment(String tenantId, String supplierId, double amount, {String? note}) async {
    final data = await _restService.getDocument('suppliers/$supplierId');
    if (data == null) return;
    
    final currentBalance = (data['balance'] as num? ?? 0.0).toDouble();
    await _restService.setDocument('suppliers/$supplierId', {
      'balance': currentBalance - amount,
    }, isUpdate: true);
    
    final transId = DateTime.now().millisecondsSinceEpoch.toString();
    await _restService.setDocument('suppliers/$supplierId/transactions/$transId', {
      'amount': amount,
      'type': 'payment',
      'date': DateTime.now().toIso8601String(),
      'note': note ?? 'تسديد دفع للمورد',
      'tenantId': tenantId,
    });
  }

  Future<void> recordSupplierDebt(String tenantId, String supplierId, double amount, {String? note}) async {
    final data = await _restService.getDocument('suppliers/$supplierId');
    if (data == null) return;
    
    final currentBalance = (data['balance'] as num? ?? 0.0).toDouble();
    await _restService.setDocument('suppliers/$supplierId', {
      'balance': currentBalance + amount,
    }, isUpdate: true);
    
    final transId = DateTime.now().millisecondsSinceEpoch.toString();
    await _restService.setDocument('suppliers/$supplierId/transactions/$transId', {
      'amount': amount,
      'type': 'debt',
      'date': DateTime.now().toIso8601String(),
      'note': note ?? 'إضافة دين يدوي (للمورد)',
      'tenantId': tenantId,
    });
  }

  Future<List<Map<String, dynamic>>> getCustomerTransactions(String customerId) async {
    final isStoreUser = customerId.startsWith('user_');
    final collection = isStoreUser ? 'users' : 'customers';
    final docId = isStoreUser ? customerId.replaceFirst('user_', '') : customerId;
    
    return await _restService.getCollection('$collection/$docId/transactions');
  }

  Future<List<Map<String, dynamic>>> getSupplierTransactions(String supplierId) async {
    return await _restService.getCollection('suppliers/$supplierId/transactions');
  }
}

final debtRepositoryProvider = Provider((ref) => DebtRepository(ref.watch(firestoreRestServiceProvider)));

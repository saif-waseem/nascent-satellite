import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/models/sync_queue_item.dart';

final customerRepositoryProvider = Provider((ref) => CustomerRepository(ref));

class CustomerRepository {
  final Ref _ref;
  FirestoreRestService get _restService => _ref.read(firestoreRestServiceProvider);

  CustomerRepository(this._ref);

  Box<CustomerModel> get _customerBox => LocalDbService.getBox<CustomerModel>('customers');

  Future<List<CustomerModel>> getAllCustomersFuture(String tenantId) async {
    final cached = _customerBox.values.where((c) => c.tenantId == tenantId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    
    if (tenantId == 'local_default') return cached;

    // Background fetch
    _fetchCustomersRemote(tenantId);
    
    return cached;
  }

  Future<void> _fetchCustomersRemote(String tenantId) async {
    try {
      // Fetch from 'customers'
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

      // Fetch from 'users'
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
      final appList = appResults.map((data) {
        final user = UserModel.fromJson(data);
        return CustomerModel(
          id: 'user_${user.id}',
          name: user.name ?? user.email.split('@').first,
          phoneNumber: user.phone ?? user.email,
          balance: user.balance,
          loyaltyPoints: user.loyaltyPoints,
          tenantId: tenantId,
          createdAt: user.createdAt,
        );
      }).toList();

      final combined = [...posList, ...appList];
      for (var c in combined) {
        await _customerBox.put(c.id, c);
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    }
  }

  Future<void> addCustomer(String tenantId, CustomerModel customer) async {
    final id = customer.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : customer.id;
    final finalCustomer = customer.copyWith(id: id, tenantId: tenantId, createdAt: DateTime.now());
    
    await _customerBox.put(id, finalCustomer);

    if (tenantId == 'local_default') return;

    await LocalDbService.addToSyncQueue(
      collectionPath: 'customers/$id', 
      data: finalCustomer.toJson(), 
      action: customer.id.isNotEmpty ? SyncAction.update : SyncAction.create
    );
  }

  Future<void> updateCustomer(String tenantId, CustomerModel customer) async {
    await _customerBox.put(customer.id, customer);

    if (tenantId == 'local_default') return;

    await LocalDbService.addToSyncQueue(
      collectionPath: 'customers/${customer.id}', 
      data: customer.toJson(), 
      action: SyncAction.update
    );
  }

  Future<void> updateCustomerPoints(String tenantId, String customerId, int newPoints) async {
    final customer = _customerBox.get(customerId);
    if (customer == null) return;

    final updated = customer.copyWith(loyaltyPoints: newPoints);
    await _customerBox.put(customerId, updated);

    if (tenantId == 'local_default') return;

    final collection = customerId.startsWith('user_') ? 'users' : 'customers';
    final docId = customerId.startsWith('user_') ? customerId.replaceFirst('user_', '') : customerId;

    try {
      await _restService.setDocument('$collection/$docId', {'loyaltyPoints': newPoints}, isUpdate: true);
    } catch (e) {
      await LocalDbService.addToSyncQueue(
        collectionPath: '$collection/$docId', 
        data: {'loyaltyPoints': newPoints, 'id': docId}, 
        action: SyncAction.update
      );
    }
  }

  Future<void> deleteCustomer(String tenantId, String customerId) async {
    await _customerBox.delete(customerId);

    if (tenantId == 'local_default') return;

    await LocalDbService.addToSyncQueue(
      collectionPath: 'customers/$customerId', 
      data: {}, 
      action: SyncAction.delete
    );
  }
}


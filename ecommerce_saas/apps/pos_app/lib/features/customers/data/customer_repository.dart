import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CustomerRepository {
  final FirebaseFirestore _firestore;

  CustomerRepository(this._firestore);

  CollectionReference<CustomerModel> _customerBase() =>
      _firestore.collection('customers').withConverter<CustomerModel>(
            fromFirestore: (snapshot, _) => CustomerModel.fromJson({...snapshot.data()!, 'id': snapshot.id}),
            toFirestore: (model, _) => model.toJson(),
          );

  Query<CustomerModel> _customersRef(String tenantId) =>
      _customerBase().where('tenantId', isEqualTo: tenantId);

  Future<List<CustomerModel>> getAllCustomersFuture(String tenantId) async {
    final posDocs = await _customersRef(tenantId).get();
    final appDocs = await _firestore
        .collection('users')
        .where('tenantId', isEqualTo: tenantId)
        .get();

    final List<CustomerModel> list = posDocs.docs.map((d) => d.data()).toList();
    
    list.addAll(appDocs.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
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
    }));

    // Deduplicate
    final unique = <String, CustomerModel>{};
    for (var c in list) {
      unique[c.id] = c;
    }
    final result = unique.values.toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  // New: Watch both 'customers' and 'users' (from store app)
  Stream<List<CustomerModel>> watchAllCustomers(String tenantId) {

    final posCustomers = _customersRef(tenantId).snapshots().map(
          (s) => s.docs.map((d) => d.data()).toList(),
        );

    final appUsers = _firestore
        .collection('users')
        .where('tenantId', isEqualTo: tenantId)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
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
            }).toList());

    // Combine streams
    return Stream.multi((controller) {
      List<CustomerModel> posList = [];
      List<CustomerModel> appList = [];

      void emit() {
        final combined = [...posList, ...appList];
        // Deduplicate by ID if necessary
        final unique = <String, CustomerModel>{};
        for (var c in combined) {
          unique[c.id] = c;
        }
        controller.add(unique.values.toList());
      }

      final sub1 = posCustomers.listen((list) {
        posList = list;
        emit();
      });
      final sub2 = appUsers.listen((list) {
        appList = list;
        emit();
      });

      controller.onCancel = () {
        sub1.cancel();
        sub2.cancel();
      };
    });
  }

  Future<void> addCustomer(String tenantId, CustomerModel customer) async {
    final ref = _customerBase().doc(customer.id.isEmpty ? null : customer.id);
    final finalCustomer = customer.copyWith(id: ref.id, tenantId: tenantId, createdAt: DateTime.now());
    await ref.set(finalCustomer);
  }

  Future<void> updateCustomer(String tenantId, CustomerModel customer) async {
    await _customerBase().doc(customer.id).set(customer);
  }

  Future<void> deleteCustomer(String tenantId, String customerId) async {
    await _customerBase().doc(customerId).delete();
  }
}

final customerRepositoryProvider = Provider((ref) => CustomerRepository(FirebaseFirestore.instance));

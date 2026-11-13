import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/services/pos_supabase_service.dart';

final customerRepositoryProvider = Provider((ref) => CustomerRepository(
  FirebaseFirestore.instance,
  ref.watch(posSupabaseServiceProvider),
));

class CustomerRepository {
  final FirebaseFirestore _firestore;
  final PosSupabaseService _supabaseService;

  CustomerRepository(this._firestore, this._supabaseService);

  CollectionReference<CustomerModel> _customerBase() =>
      _firestore.collection('customers').withConverter<CustomerModel>(
            fromFirestore: (snapshot, _) => CustomerModel.fromJson({...snapshot.data()!, 'id': snapshot.id}),
            toFirestore: (model, _) => model.toJson(),
          );

  Query<CustomerModel> _customersRef(String tenantId) =>
      _customerBase().where('tenantId', isEqualTo: tenantId);

  Future<List<CustomerModel>> getAllCustomersFuture(String tenantId) async {
    // 1. Try Supabase SQL first
    try {
      final sqlCustomers = await _supabaseService.getCustomers(tenantId);
      if (sqlCustomers.isNotEmpty) {
        return sqlCustomers;
      }
    } catch (_) {}

    // 2. Fallback to Firestore SDK
    try {
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
    } catch (_) {
      return [];
    }
  }

  Stream<List<CustomerModel>> watchAllCustomers(String tenantId) async* {
    if (tenantId.isEmpty) {
      yield [];
      return;
    }

    // 1. Instant initial load from Supabase SQL (Fast & offline-friendly)
    try {
      final initial = await _supabaseService.getCustomers(tenantId);
      if (initial.isNotEmpty) {
        yield initial;
      }
    } catch (_) {}

    // 2. Stream from Supabase SQL Realtime
    try {
      await for (final customers in _supabaseService.getCustomersStream(tenantId)) {
        if (customers.isNotEmpty) {
          yield customers;
        }
      }
    } catch (_) {
      // 3. Fallback to Firestore streams
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

      yield* Stream.multi((controller) {
        List<CustomerModel> posList = [];
        List<CustomerModel> appList = [];

        void emit() {
          final combined = [...posList, ...appList];
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
  }

  Future<void> addCustomer(String tenantId, CustomerModel customer) async {
    final ref = _customerBase().doc(customer.id.isEmpty ? null : customer.id);
    final finalCustomer = customer.copyWith(id: ref.id, tenantId: tenantId, createdAt: DateTime.now());

    // 1. Save to Supabase SQL (Primary)
    try {
      await _supabaseService.saveCustomer(finalCustomer, tenantId);
    } catch (_) {}

    // 2. Save to Firestore (Fallback)
    try {
      await ref.set(finalCustomer);
    } catch (_) {}
  }

  Future<void> updateCustomer(String tenantId, CustomerModel customer) async {
    // 1. Update in Supabase SQL (Primary)
    try {
      await _supabaseService.saveCustomer(customer, tenantId);
    } catch (_) {}

    // 2. Update in Firestore (Fallback)
    try {
      await _customerBase().doc(customer.id).set(customer);
    } catch (_) {}
  }

  Future<void> deleteCustomer(String tenantId, String customerId) async {
    // 1. Delete in Supabase SQL (Primary)
    try {
      await _supabaseService.deleteCustomer(customerId);
    } catch (_) {}

    // 2. Delete in Firestore (Fallback)
    try {
      await _customerBase().doc(customerId).delete();
    } catch (_) {}
  }
}

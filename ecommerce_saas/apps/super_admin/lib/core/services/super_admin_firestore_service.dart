import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';

class SuperAdminFirestoreService {
  final FirebaseFirestore _db;
  SuperAdminFirestoreService([FirebaseFirestore? firestore]) : _db = firestore ?? FirebaseFirestore.instance;

  // --- Tenants Management ---
  Stream<List<TenantModel>> getTenants() {
    return _db.collection('tenants').snapshots().map((snapshot) {
      print('DEBUG SUPER_ADMIN: Fetched ${snapshot.docs.length} tenant docs');
      final tenants = <TenantModel>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          print('DEBUG SUPER_ADMIN: Parsing tenant ${doc.id}');
          final tenant = TenantModel.fromJson(data);
          tenants.add(tenant);
        } catch (e) {
          print('DEBUG SUPER_ADMIN: FAILED to parse tenant ${doc.id}: $e');
        }
      }
      return tenants;
    });
  }

  Future<void> addTenant(TenantModel tenant) async {
    final docRef = _db.collection('tenants').doc(tenant.id);
    final doc = await docRef.get();
    
    if (doc.exists) {
      // If it exists, only update name, adminIds etc. Preserve isActive and expiryDate.
      await docRef.update({
        'name': tenant.name,
        'adminIds': tenant.adminIds,
        // specifically NOT updating isActive if it exists
      });
      print('DEBUG SUPER_ADMIN: Updated existing tenant ${tenant.id}, preserving activation status.');
    } else {
      // Truly new tenant
      await docRef.set(tenant.toJson());
      print('DEBUG SUPER_ADMIN: Created new tenant ${tenant.id}.');
    }
  }

  Future<void> updateTenant(TenantModel tenant) async {
    await _db.collection('tenants').doc(tenant.id).set(tenant.toJson(), SetOptions(merge: true));
  }

  Future<void> setTenantActiveStatus(String tenantId, bool isActive) async {
    await _db.collection('tenants').doc(tenantId).update({'isActive': isActive});
  }

  Future<void> deleteTenant(String tenantId) async {
    await _db.collection('tenants').doc(tenantId).delete();
  }

  Future<void> activateSubscription(String tenantId, int months, String code) async {
    try {
      final doc = await _db.collection('tenants').doc(tenantId).get();
      if (!doc.exists) return;
      
      final data = doc.data()!;
      data['id'] = doc.id;
      final tenant = TenantModel.fromJson(data);
      
      // Determine existing expiry or start fresh
      final now = DateTime.now();
      final currentExpiry = tenant.expiryDate;
      
      // If no expiry yet, or it's in the past, start from now.
      // Otherwise, add to the existing future expiry date.
      final startDate = (currentExpiry == null || currentExpiry.isBefore(now)) 
          ? now 
          : currentExpiry;
          
      final newExpiry = startDate.add(Duration(days: months * 30));
      
      // Also fetch latest subscriber count while we are at it
      final subscriberCount = await getTenantSubscriberCount(tenantId);
      
      final updated = tenant.copyWith(
        expiryDate: newExpiry,
        isActive: true,
        activationCode: code,
        subscriberCount: subscriberCount,
      );
      
      await updateTenant(updated);

      // Also log the activation
      await _db.collection('tenants').doc(tenantId).collection('activation_logs').add({
        'date': FieldValue.serverTimestamp(),
        'months': months,
        'code': code,
        'expiryAfter': newExpiry.toIso8601String(),
        'type': 'RENEWAL_OR_ACTIVATION',
      });
      
      print('DEBUG SUPER_ADMIN: Activation successful for $tenantId. New expiry: $newExpiry');
    } catch (e, stack) {
      print('CRITICAL ERROR during activateSubscription: $e');
      print(stack);
      rethrow;
    }
  }

  Future<void> activatePosSubscription(String tenantId, int months, String code) async {
    final issued=code.trim().toUpperCase();
    if(months<=0 || issued.isEmpty)throw ArgumentError('مدة التفعيل أو الكود غير صالح');
    final doc=_db.collection('tenants').doc(tenantId);
    final log=_db.collection('activation_logs').doc();
    await _db.runTransaction((tx) async{
      final snapshot=await tx.get(doc);
      if(!snapshot.exists)throw StateError('المتجر غير موجود');
      final tenant=TenantModel.fromJson({...snapshot.data()!,'id':tenantId});
      if(tenant.posActivationCode==issued && tenant.isPosEnabled)return;
      final now=DateTime.now().toUtc();
      final previous=tenant.posExpiryDate;
      final expiry=(previous!=null && previous.isAfter(now)?previous:now).add(Duration(days:months*30)).toUtc().toIso8601String();
      tx.update(doc,{'isActive':true,'isPosEnabled':true,'posActivationCode':issued,'posExpiryDate':expiry});
      tx.set(log,{'tenantId':tenantId,'type':'POS','expiryDate':expiry,'months':months,'timestamp':FieldValue.serverTimestamp()});
    });
  }

  Future<void> activateCarsModule(String tenantId, String code, int daysToAdd) async {
    try {
      final tenantDoc = await _db.collection('tenants').doc(tenantId).get();
      if (!tenantDoc.exists) throw Exception('Tenant not found');

      final data = tenantDoc.data()!;
      data['id'] = tenantDoc.id;
      final tenant = TenantModel.fromJson(data);

      DateTime baseDate = DateTime.now();
      if (tenant.carsExpiryDate != null && tenant.carsExpiryDate!.isAfter(baseDate)) {
        baseDate = tenant.carsExpiryDate!;
      }

      final newExpiry = baseDate.add(Duration(days: daysToAdd));

      await _db.collection('tenants').doc(tenantId).update({
        'isCarsEnabled': true,
        'carsExpiryDate': newExpiry.toIso8601String(),
        'carsActivationCode': code,
      });

      await _db.collection('tenants').doc(tenantId).collection('activation_logs').add({
        'activationCode': code,
        'expiryDate': newExpiry.toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'CARS_RENEWAL_OR_ACTIVATION',
      });

      print('DEBUG SUPER_ADMIN: Cars Activation successful for $tenantId. New expiry: $newExpiry');
    } catch (e, stack) {
      print('CRITICAL ERROR during activateCarsModule: $e');
      print(stack);
      rethrow;
    }
  }

  Future<int> getTenantSubscriberCount(String tenantId) async {
    try {
      // Use count() for efficiency
      final snapshot = await _db.collection('users')
          .where('tenantId', isEqualTo: tenantId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Warning: Failed to get subscriber count for $tenantId: $e');
      return 0;
    }
  }
  
  // Update all tenants with their subscriber counts
  Future<void> refreshSubscriberCounts() async {
    try {
      final tenants = await _db.collection('tenants').get();
      for (var doc in tenants.docs) {
        final tenantId = doc.id;
        final count = await getTenantSubscriberCount(tenantId);
        await _db.collection('tenants').doc(tenantId).update({'subscriberCount': count});
      }
      print('DEBUG SUPER_ADMIN: All subscriber counts refreshed.');
    } catch (e) {
      print('Error refreshing counts: $e');
    }
  }

  // --- App Updates Management ---
  Stream<List<AppUpdateModel>> getAppUpdates() {
    return _db.collection('app_updates').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AppUpdateModel.fromJson(doc.data())).toList();
    });
  }

  Future<void> saveAppUpdate(AppUpdateModel update) async {
    await _db.collection('app_updates').doc(update.id).set(update.toJson());
  }

  // --- Global Settings ---
  Stream<Map<String, dynamic>> getGlobalSettings() {
    return _db.collection('settings').doc('global').snapshots().map((doc) => doc.data() ?? {});
  }

  Future<void> updateGlobalSettings(Map<String, dynamic> settings) async {
    await _db.collection('settings').doc('global').set(settings, SetOptions(merge: true));
  }

  Future<void> enableIssuedPosCode(String tenantId,String issued) async {
    final doc=_db.collection('tenants').doc(tenantId);
    await _db.runTransaction((tx) async{
      final snapshot=await tx.get(doc);
      if(!snapshot.exists)throw StateError('المتجر غير موجود');
      final tenant=TenantModel.fromJson({...snapshot.data()!,'id':tenantId});
      if(!tenant.isActive || issued.trim().isEmpty || tenant.posActivationCode!=issued || tenant.posExpiryDate?.isAfter(DateTime.now())!=true)throw StateError('لا يوجد كود سارٍ قابل للتفعيل');
      tx.update(doc,{'isPosEnabled':true});
    });
  }
  Future<void> activatePosPermanently(String tenantId, String code) async {
    await _db.collection('tenants').doc(tenantId).update({
      'isPosEnabled': true,
      'posActivationCode': code,
      'posExpiryDate': null, // null means permanent
    });
    
    await _db.collection('tenants').doc(tenantId).collection('activation_logs').add({
      'date': FieldValue.serverTimestamp(),
      'type': 'POS_PERMANENT_ACTIVATION',
    });
  }

  Future<void> permanentlyActivateCars(String tenantId, String code) async {
    await _db.collection('tenants').doc(tenantId).update({
      'isCarsEnabled': true,
      'carsExpiryDate': null, // null means permanent
      'carsActivationCode': code,
    });

    // Also log the activation
    await _db.collection('tenants').doc(tenantId).collection('activation_logs').add({
      'activationCode': code,
      'expiryDate': 'PERMANENT',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'CARS_PERMANENT_ACTIVATION',
    });
  }

  Future<void> activateStorePermanently(String tenantId, String code) async {
    await _db.collection('tenants').doc(tenantId).update({
      'isStoreEnabled': true,
      'activationCode': code,
      'expiryDate': null, // null means permanent
    });

    await _db.collection('tenants').doc(tenantId).collection('activation_logs').add({
      'date': FieldValue.serverTimestamp(),
      'type': 'STORE_PERMANENT_ACTIVATION',
      'code': code,
    });
  }
}

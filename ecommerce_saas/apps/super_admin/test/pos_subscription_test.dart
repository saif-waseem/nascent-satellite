import 'dart:convert';
import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_admin/core/services/super_admin_firestore_service.dart';

void main() {
  test(
    'issuing a POS subscription is atomic and a repeated confirmation keeps the same expiry',
    () async {
      final db = FakeFirebaseFirestore();
      final tenant = db.collection('tenants').doc('fixture-shop');
      await tenant.set({
        'name': 'Demo',
        'isActive': true,
        'isPosEnabled': false,
      });
      final service = SuperAdminFirestoreService(db);
      await service.activatePosSubscription(tenant.id, 2, 'pos-demo-123');
      final issued = (await tenant.get()).data()!;
      expect(issued['posActivationCode'], 'POS-DEMO-123');
      expect(issued['isPosEnabled'], true);
      await service.activatePosSubscription(tenant.id, 2, 'pos-demo-123');
      expect(
        (await tenant.get()).data()!['posExpiryDate'],
        issued['posExpiryDate'],
      );
      expect((await tenant.collection('activation_logs').get()).docs.length, 1);
      await tenant.update({'isPosEnabled': false});
      await service.enableIssuedPosCode(tenant.id, 'POS-DEMO-123');
      final repaired = (await tenant.get()).data()!;
      expect(repaired['isPosEnabled'], true);
      expect(repaired['posExpiryDate'], issued['posExpiryDate']);
      final output = Platform.environment['POS_TEST_ISSUED_RECORD'];
      if (output != null)
        await File(
          output,
        ).writeAsString(jsonEncode({...repaired, 'id': tenant.id}));
    },
  );
}

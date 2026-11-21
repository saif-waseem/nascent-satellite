import 'dart:convert';
import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_admin/core/services/super_admin_firestore_service.dart';

void main() {
  test(
    'store renewal is atomic and does not overwrite or extend the POS licence',
    () async {
      final db = FakeFirebaseFirestore();
      final doc = db.collection('tenants').doc('test-shop');
      await doc.set({
        'name': 'Fixture',
        'posActivationCode': 'POS-EXISTING',
        'isPosEnabled': true,
        'posExpiryDate': '2099-01-01T00:00:00Z',
      });
      final service = SuperAdminFirestoreService(db);
      await service.activateSubscription(doc.id, 1, 'ACT-TEST');
      final first = (await doc.get()).data()!;
      await service.activateSubscription(doc.id, 1, 'ACT-TEST');
      final second = (await doc.get()).data()!;
      expect(second['activationCode'], 'ACT-TEST');
      expect(second['posActivationCode'], 'POS-EXISTING');
      expect(second['expiryDate'], first['expiryDate']);
      expect(second['posExpiryDate'], '2099-01-01T00:00:00Z');
      expect((await db.collection('activation_logs').get()).docs.length, 1);
    },
  );
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
      final log = (await db.collection('activation_logs').get()).docs.single;
      expect(log.data()['tenantId'], tenant.id);
      expect(log.data()['type'], 'POS');
      expect(log.data().containsKey('activationCode'), isFalse);
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

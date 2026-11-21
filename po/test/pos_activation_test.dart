import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/services/pos_activation_service.dart';
import 'package:pos_app/core/services/firestore_rest_service.dart';

class Issuer extends FirestoreRestService {
  Issuer(this.record) : super(projectId: 'test', apiKey: 'test');
  final Map<String, dynamic> record;
  @override
  Future<List<Map<String, dynamic>>> lookupPosCode(String code) async =>
      code == record['posActivationCode'] ? [record] : [];
}

void main() {
  final issued = {
    'id': 'test',
    'name': 'Store',
    'isActive': true,
    'isPosEnabled': true,
    'posActivationCode': 'POS-A123',
    'posExpiryDate': '2099-01-01T00:00:00Z',
  };
  test(
    'fresh install reads the POS issuer record over the verification transport',
    () async {
      final path = Platform.environment['POS_TEST_ISSUED_RECORD'];
      final record = path == null
          ? issued
          : Map<String, dynamic>.from(
              jsonDecode(await File(path).readAsString()) as Map,
            );
      final code = record['posActivationCode'] as String;
      await http.runWithClient(
        () async {
          final rest = FirestoreRestService(projectId: 'demo', apiKey: 'test');
          final result = await verifyPosCode(rest, code);
          expect(result.id, record['id']);
          expect(result.isPosEnabled, true);
        },
        () => MockClient((req) async {
          expect(req.url.path.endsWith('/documents:runQuery'), true);
          final filter = jsonDecode(
            req.body,
          )['structuredQuery']['where']['fieldFilter'];
          expect(filter['field']['fieldPath'], 'posActivationCode');
          expect(filter['value']['stringValue'], code);
          return http.Response(
            jsonEncode([
              {
                'document': {
                  'name':
                      'projects/demo/databases/(default)/documents/tenants/${record['id']}',
                  'fields': {
                    for (final e in record.entries)
                      if (e.key != 'id')
                        e.key: e.value is bool
                            ? {'booleanValue': e.value}
                            : {'stringValue': e.value},
                  },
                },
              },
            ]),
            200,
          );
        }),
      );
    },
  );
  test(
    'issued POS code normalizes keyboard and identifies the store',
    () async {
      final t = await verifyPosCode(Issuer(issued), ' pos–a١٢٣ ');
      expect(t.id, 'test');
      expect(t.isPosEnabled, isTrue);
    },
  );
  test('rejects wrong store, expired, disabled, and non-POS code', () async {
    for (final f in [
      () => verifyPosCode(Issuer(issued), 'POS-A123', expectedTenant: 'other'),
      () => verifyPosCode(
        Issuer({...issued, 'posExpiryDate': '2000-01-01'}),
        'POS-A123',
      ),
      () =>
          verifyPosCode(Issuer({...issued, 'isPosEnabled': false}), 'POS-A123'),
      () => verifyPosCode(Issuer(issued), 'test'),
    ]) {
      await expectLater(f(), throwsFormatException);
    }
  });
}

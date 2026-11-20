import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_models/src/widgets/stock_record_screen.dart';

void main() {
  testWidgets('cashier can read a balance and submit a stock count', (tester) async {
    int balance = 10;
    final calls = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body);
      expect(body['p_tenant'], 'tenant');
      expect(body['p_device_key'], 'demo');
      if (request.url.path.endsWith('/count_cashier_product')) {
        calls.add(Map<String,dynamic>.from(body));
        balance = body['p_counted'];
        return http.Response('$balance',200);
      }
      return http.Response(jsonEncode({'stock_quantity':balance,'history':[]}),200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StockRecordScreen(
        product: ProductModel(id:'p',tenantId:'tenant',name:'صنف',category:'',description:'',price:1),
        url:'https://example.test',publishableKey:'test',allowCount:true)));
      await tester.enterText(find.byType(TextField).first,'demo');
      await tester.tap(find.text('تحديث سجل المخزون'));
      await tester.pumpAndSettle();
      expect(find.text('الرصيد المسجل: 10'),findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1),'8');
      await tester.enterText(find.byType(TextField).at(2),'جرد');
      await tester.ensureVisible(find.text('اعتماد الجرد'));
      await tester.tap(find.text('اعتماد الجرد'));
      await tester.pumpAndSettle();
      expect(calls.single['p_expected'],10);
      expect(calls.single['p_counted'],8);
      expect(find.text('الرصيد المسجل: 8'),findsOneWidget);
    },()=>client);
  });
}
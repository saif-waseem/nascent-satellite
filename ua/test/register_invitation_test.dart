import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_app/features/auth/presentation/screens/register_screen.dart';

void main() {
  testWidgets('invitation code is editable on a narrow phone', (tester) async {
    SharedPreferences.setMockInitialValues({});

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(
      home: RegisterScreen(referral: 'TEST123'),
    )));
    final field = find.widgetWithText(TextField, 'TEST123');
    await tester.ensureVisible(field);
    expect(field, findsOneWidget);
    await tester.enterText(field, 'OTHER');
    expect(find.text('OTHER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/features/orders/presentation/screens/order_details_screen.dart';

void main(){
 for(final lang in ['ar','en']){
  for(final brightness in Brightness.values){
   testWidgets('Order timeline $lang $brightness at phone width',(tester)async{
    tester.view.physicalSize=const Size(320,640);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme:ThemeData(brightness:brightness),home:Scaffold(body:OrderTrackingTimeline(lang:lang,current:2))));
    await tester.pumpAndSettle();
    final first=tester.getCenter(find.byIcon(Icons.inventory_2_outlined));
    final last=tester.getCenter(find.byIcon(Icons.home_outlined));
    expect(first.dx>last.dx,lang=='ar');expect(tester.takeException(),isNull);
   });
  }
 }
}

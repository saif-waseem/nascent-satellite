import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'car_contract_form_screen.dart';
import 'car_contracts_list_screen.dart';

class CarsDashboardScreen extends HookConsumerWidget {
  const CarsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة السيارات / Cars Management'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add_card), text: 'عقد جديد'),
              Tab(icon: Icon(Icons.history), text: 'سجل العقود'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CarContractFormScreen(),
            CarContractsListScreen(),
          ],
        ),
      ),
    );
  }
}

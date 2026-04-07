import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:shared_models/shared_models.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final asyncCustomers = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('customers', lang))),
      body: asyncCustomers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(child: Text('No customers found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(customer.name?[0] ?? 'U')),
                  title: Text(customer.name ?? 'Guest User'),
                  subtitle: Text('${customer.email}\nPoints: ${customer.loyaltyPoints}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                        onPressed: () => _updatePoints(context, ref, customer, 10),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _updatePoints(context, ref, customer, -10),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _updatePoints(BuildContext context, WidgetRef ref, UserModel customer, int change) {
    final newPoints = (customer.loyaltyPoints + change).clamp(0, 999999);
    ref.read(adminFirestoreServiceProvider).updateUserPoints(customer.id, newPoints);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated points for ${customer.name ?? "User"}: $newPoints')),
    );
  }
}

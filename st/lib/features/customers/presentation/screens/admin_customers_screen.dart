import 'buyer_reviews_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_admin/features/shared/widgets/admin_drawer.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/utils/formatters.dart';
import 'package:shared_models/shared_models.dart';

class AdminCustomersScreen extends HookConsumerWidget {
  const AdminCustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final asyncCustomers = ref.watch(customerListProvider);
    final searchQuery = useState('');
    final showTopLoyal = useState(false);

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: Text(AppStrings.get('subscribers', lang)),
        actions: [
          IconButton(tooltip:'طلبات حذف الحسابات القديمة',icon:const Icon(Icons.person_remove_outlined),onPressed:()=>showDialog(context:context,builder:(_)=>BuyerReviewsDialog(ref.read(currentTenantIdProvider)))),
          IconButton(
            icon: Icon(showTopLoyal.value ? Icons.star : Icons.star_border, color: showTopLoyal.value ? Colors.amber : null),
            onPressed: () => showTopLoyal.value = !showTopLoyal.value,
            tooltip: 'Show Most Loyal',
          ),
        ],
      ),
      body: Column(
        children: [
          if (showTopLoyal.value)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.amber.withOpacity(0.1),
              child: Text(
                'Showing Most Loyal Customers (By Spending)',
                style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => searchQuery.value = v,
              decoration: InputDecoration(
                hintText: 'Search by Name or Phone',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: asyncCustomers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (customers) {
                var filteredCustomers = customers.where((u) {
                  final nameMatch = u.name?.toLowerCase().contains(searchQuery.value.toLowerCase()) ?? false;
                  final phoneMatch = u.id.contains(searchQuery.value);
                  return nameMatch || phoneMatch;
                }).toList();

                if (showTopLoyal.value) {
                  filteredCustomers.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
                  filteredCustomers = filteredCustomers.take(20).toList();
                }

                if (filteredCustomers.isEmpty) return const Center(child: Text('No customers found'));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredCustomers.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final user = filteredCustomers[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(user.name?[0] ?? 'U')),
                      title: Text(user.name ?? 'Guest'),
                      subtitle: Text('${user.id} • ${formatCurrency(user.totalSpent, lang: lang)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${user.loyaltyPoints} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                              Text('${user.purchaseCount} orders', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_note, color: Colors.blue),
                            onPressed: () => _showPointsDialog(context, ref, user, lang),
                          ),
                          IconButton(
                            icon: Icon(user.isBlocked ? Icons.block : Icons.check_circle_outline, 
                                  color: user.isBlocked ? Colors.red : Colors.green),
                            onPressed: () => ref.read(adminFirestoreServiceProvider).toggleUserBlock(user.id, !user.isBlocked),
                            tooltip: user.isBlocked ? 'Unblock User' : 'Block User',
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPointsDialog(BuildContext context, WidgetRef ref, UserModel user, String lang) {
    final controller = TextEditingController(text: user.loyaltyPoints.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${AppStrings.get('points', lang)}: ${user.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Total Points'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel', lang))),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) {
                ref.read(adminFirestoreServiceProvider).updateUserPoints(user.id, val);
                Navigator.pop(ctx);
              }
            },
            child: Text(AppStrings.get('save', lang)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';

class CartScreen extends HookConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelectionMode = useState(false);
    final selectedIndices = useState<Set<int>>({});
    final cart = ref.watch(cartProvider);
    final total = cart.fold(0.0, (sum, item) => sum + ((item['price'] as num) * (item['quantity'] ?? 1)));
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final tenant = ref.watch(tenantProvider).value;
    final currencyUnit = tenant?.currencyUnit;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectionMode.value 
          ? '${selectedIndices.value.length} ${AppStrings.get('selected', lang)}'
          : AppStrings.get('cart_title', lang)),
        leading: isSelectionMode.value 
          ? IconButton(icon: const Icon(Icons.close), onPressed: () {
              isSelectionMode.value = false;
              selectedIndices.value = {};
            })
          : null,
        actions: [
          if (isSelectionMode.value)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: selectedIndices.value.isEmpty ? null : () {
                 _shareSelected(context, ref, selectedIndices.value, lang, tenant);
              },
            ),
          if (cart.isNotEmpty && !isSelectionMode.value)
            IconButton(
              onPressed: () => isSelectionMode.value = true,
              icon: const Icon(Icons.checklist),
              tooltip: 'Select to Share',
            ),
          if (!isSelectionMode.value)
            IconButton(
              onPressed: () => _showImportDialog(context, ref, lang),
              icon: const Icon(Icons.input_outlined),
              tooltip: 'Import Cart',
            ),
        ],
      ),
      body: cart.isEmpty
        ? Center(child: Text(AppStrings.get('cart_empty', lang)))
        : Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    final name = item['name'] ?? 'Product';
                    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                    final quantity = item['quantity'] ?? 1;
                    
                    return ListTile(
                      onTap: isSelectionMode.value ? () {
                        final newSet = Set<int>.from(selectedIndices.value);
                        if (newSet.contains(index)) {
                          newSet.remove(index);
                        } else {
                          newSet.add(index);
                        }
                        selectedIndices.value = newSet;
                      } : null,
                      leading: isSelectionMode.value 
                        ? Checkbox(
                            value: selectedIndices.value.contains(index),
                            onChanged: (_) {
                              final newSet = Set<int>.from(selectedIndices.value);
                              if (newSet.contains(index)) {
                                newSet.remove(index);
                              } else {
                                newSet.add(index);
                              }
                              selectedIndices.value = newSet;
                            },
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.shopping_bag),
                          ),
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatCurrency(price, unitOverride: currencyUnit)),
                          Text('${AppStrings.get('qty', lang)}: $quantity', style: const TextStyle(fontSize: 12)),
                          if (item['size'] != null && item['size'] != 'Default' && item['size'] != 'none') Text('${AppStrings.get('size', lang)}: ${item['size']}', style: const TextStyle(fontSize: 12)),
                          if (item['color'] != null && item['color'] != 'Default' && item['color'] != 'none') Text('${AppStrings.get('color', lang)}: ${item['color']}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: isSelectionMode.value ? null : IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => ref.read(cartProvider.notifier).removeFromCart(index),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -4))] 
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${AppStrings.get('cart_total', lang)}:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(formatCurrency(total, unitOverride: currencyUnit), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            final user = ref.read(userProvider).value;
                            if (user == null) {
                              context.go('/login');
                            } else {
                              context.push('/checkout');
                            }
                          },
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: Text(AppStrings.get('checkout_btn', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _shareSelected(BuildContext context, WidgetRef ref, Set<int> indices, String lang, TenantModel? tenant) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final shareId = await ref.read(cartProvider.notifier).generatePartialCartLink(indices);
      if (context.mounted) Navigator.pop(context); // Close loading
      
      const baseUrl = 'https://saif-waseem.github.io/store'; 
      final shareUrl = '$baseUrl/#/share/$shareId';
      
      final msg = AppStrings.get('share_cart_msg', lang)
        .replaceFirst('{store}', tenant?.name ?? 'Store')
        .replaceFirst('{url}', shareUrl);
      
      await Share.share(msg);

      // Award share points
      final userData = ref.read(userProvider).value;
      if (userData != null && tenant != null) {
        final points = tenant.sharesRewardPoints;
        final limit = tenant.maxDailySharePoints;
        final awarded = await ref.read(firestoreServiceProvider).awardSharePoints(userData.id, points, limit);
        if (awarded > 0 && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppStrings.get('reward_points_msg', lang).replaceFirst('{points}', awarded.toString()))
          ));
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error generating link')));
      }
    }
  }

  void _showImportDialog(BuildContext context, WidgetRef ref, String lang) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('import_cart_title', lang)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: AppStrings.get('import_cart_hint', lang),
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel', lang))),
          FilledButton(
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                // Try to extract from URL if they pasted the whole link
                String data = val;
                if (val.contains('share/')) {
                  data = val.split('share/').last.split('?').first;
                } else if (val.contains('cart=')) {
                  data = val.split('cart=').last.split('&').first;
                }
                
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(child: CircularProgressIndicator()),
                );
                
                try {
                  await ref.read(cartProvider.notifier).loadFromSharedId(data);
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppStrings.get('cart_loaded_success', lang)))
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid link or ID')));
                  }
                }
              }
            },
            child: Text(AppStrings.get('import_btn', lang)),
          ),
        ],
      ),
    );
  }
}

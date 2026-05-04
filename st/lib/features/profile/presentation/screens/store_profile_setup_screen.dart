import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:store_admin/features/shared/providers.dart';

class StoreProfileSetupScreen extends HookConsumerWidget {
  const StoreProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeNameController = useTextEditingController();
    final logoController = useTextEditingController();
    final shippingController = useTextEditingController();
    final sharesRewardController = useTextEditingController();
    final reviewRewardController = useTextEditingController();
    final tenant = ref.watch(tenantProvider).value;
    
    useEffect(() {
      if (tenant != null) {
        storeNameController.text = tenant.name;
        logoController.text = tenant.logoUrl ?? '';
        shippingController.text = tenant.shippingCost.toString();
        sharesRewardController.text = tenant.sharesRewardPoints.toString();
        reviewRewardController.text = tenant.reviewRewardPoints.toString();
      }
      return null;
    }, [tenant]);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Your Store')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: logoController.text.isNotEmpty && int.tryParse(logoController.text) != null
                ? CircleAvatar(
                    radius: 50,
                    child: Icon(IconData(int.parse(logoController.text), fontFamily: 'MaterialIcons'), size: 40),
                  )
                : CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(Icons.store, size: 40, color: Colors.grey),
                  ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: logoController,
            decoration: const InputDecoration(
              labelText: 'Logo Icon Code (e.g. 58900)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.image),
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: storeNameController,
            decoration: const InputDecoration(
              labelText: 'Store Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.store),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: shippingController,
            decoration: const InputDecoration(
              labelText: 'Shipping Cost',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.local_shipping),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: sharesRewardController,
                  decoration: const InputDecoration(
                    labelText: 'Sharing Points',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.share),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: reviewRewardController,
                  decoration: const InputDecoration(
                    labelText: 'Review Points',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.comment),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () async {
               final currentTenant = ref.read(tenantProvider).value;
               if (currentTenant != null) {
                  final updated = currentTenant.copyWith(
                    name: storeNameController.text,
                    logoUrl: logoController.text,
                    shippingCost: double.tryParse(shippingController.text) ?? 5000.0,
                    sharesRewardPoints: int.tryParse(sharesRewardController.text) ?? currentTenant.sharesRewardPoints,
                    reviewRewardPoints: int.tryParse(reviewRewardController.text) ?? currentTenant.reviewRewardPoints,
                  );
                 await ref.read(adminFirestoreServiceProvider).updateTenant(updated);
               }
               if (context.mounted) context.go('/products');
            },
            child: const Text('Save & Open Store'),
          ),
        ],
      ),
    );
  }
}

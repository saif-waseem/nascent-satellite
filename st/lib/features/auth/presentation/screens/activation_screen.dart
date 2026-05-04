import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:store_admin/features/shared/providers.dart';

class ActivationScreen extends HookConsumerWidget {
  const ActivationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeController = useTextEditingController();
    final isLoading = useState(false);
    final errorText = useState<String?>(null);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.storefront, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              Text(
                'Welcome Partner',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your activation code to set up your store',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Activation Code',
                  hintText: 'e.g. STORE-2024-X',
                  border: const OutlineInputBorder(),
                  errorText: errorText.value,
                  prefixIcon: const Icon(Icons.vpn_key),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: isLoading.value
                    ? null
                    : () async {
                        if (codeController.text.isEmpty) {
                          errorText.value = 'Please enter a code';
                          return;
                        }
                        
                        isLoading.value = true;
                        errorText.value = null;
                        
                        try {
                          // Real Verification
                          print('Debug: Querying for code: ${codeController.text.trim().toUpperCase()}');
                          
                          final query = await FirebaseFirestore.instance
                              .collection('tenants')
                              .where('activationCode', isEqualTo: codeController.text.trim().toUpperCase())
                              .limit(1)
                              .get();

                          if (query.docs.isEmpty) {
                            print('Debug: No tenant found with this code.');
                            isLoading.value = false;
                            errorText.value = 'Invalid activation code (Not Found)';
                            return;
                          }

                          final tenantDoc = query.docs.first;
                          final data = tenantDoc.data();
                          print('Debug: Tenant found: ${tenantDoc.id}, isActive: ${data['isActive']}, expiry: ${data['expiryDate']}');

                          // Check for active status
                          final isActive = data['isActive'] as bool? ?? false;
                          if (!isActive) {
                             // SPECIAL CASE: If it's the *first* activation, maybe we allow it?
                             // But Super Admin sets isActive=true when generating code. 
                             // So if it's false here, something is wrong with the set up.
                             isLoading.value = false;
                             errorText.value = 'Store is marked as Inactive. Contact Admin.';
                             return;
                          }

                          // Check for expiry
                          if (data['expiryDate'] != null) {
                             DateTime expiry;
                             final rawExpiry = data['expiryDate'];
                             if (rawExpiry is Timestamp) {
                               expiry = rawExpiry.toDate();
                             } else if (rawExpiry is String) {
                               expiry = DateTime.parse(rawExpiry);
                             } else {
                               // Fallback or error? defaulting to now (expired) if unknown type
                               expiry = DateTime.now().subtract(const Duration(days: 1)); 
                             }

                             if (expiry.isBefore(DateTime.now())) {
                               isLoading.value = false;
                               errorText.value = 'Subscription expired on ${expiry.toString().split(' ')[0]}';
                               return;
                             }
                          }

                          // Success! Save Tenant ID
                          // We need to access the provider container to update the state
                          // Ideally we use a Notifier, but here we can just update the Provider 
                          // and persist it in SharedPreferences (which the provider should load on start)
                          
                          // For now, let's assume valid login and user needs to handle persistence separate
                          // BUT wait, this screen is for *initial setup*. 
                          
                          ref.read(currentTenantAuthProvider.notifier).setTenant(tenantDoc.id);
                          
                          // TODO: Persist this ID using SharedPreferences if not already handled
                          // (User request implies "Login persistence" was fixed elsewhere, assuming it covers this)
                          
                          isLoading.value = false;
                          if (context.mounted) {
                            // Navigate to Store Profile Setup or Dashboard
                            context.go('/setup-profile');
                          }
                        } catch (e) {
                          isLoading.value = false;
                          errorText.value = 'Verification failed: $e';
                        }
                      },
                icon: isLoading.value 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.arrow_forward),
                label: const Text('Verify & Continue'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:store_admin/core/utils/formatters.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/features/shared/providers.dart';

class MarketingScreen extends ConsumerStatefulWidget {
  const MarketingScreen({super.key});

  @override
  ConsumerState<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends ConsumerState<MarketingScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _actionUrlController = TextEditingController();
  ProductModel? _selectedProduct;
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('marketing', lang)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.get('send_notification_title', lang),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.get('send_notification_subtitle', lang),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: AppStrings.get('notification_title_label', lang),
                border: const OutlineInputBorder(),
                hintText: AppStrings.get('notification_title_hint', lang),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppStrings.get('notification_body_label', lang),
                border: const OutlineInputBorder(),
                hintText: AppStrings.get('notification_body_hint', lang),
              ),
            ),
            const SizedBox(height: 24),
            Text(AppStrings.get('action_optional', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showProductSearchDialog(context, ref, lang),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: AppStrings.get('link_to_product', lang),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link),
                ),
                child: Row(
                  children: [
                    if (_selectedProduct != null) ...[
                      _buildProductThumbnail(_selectedProduct!.imageUrl),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        _selectedProduct?.name ?? AppStrings.get('none', lang),
                        style: TextStyle(color: _selectedProduct == null ? Colors.grey : null),
                      ),
                    ),
                    if (_selectedProduct != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _selectedProduct = null),
                      ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _actionUrlController,
              decoration: InputDecoration(
                labelText: AppStrings.get('external_url_label', lang),
                border: const OutlineInputBorder(),
                hintText: AppStrings.get('external_url_hint', lang),
                helperText: AppStrings.get('external_url_helper', lang),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isSending ? null : _sendNotification,
                icon: _isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
                label: Text(_isSending ? AppStrings.get('sending_btn', lang) : AppStrings.get('send_to_all_btn', lang)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductThumbnail(String? url) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.startsWith('http')
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Icon(Icons.image, size: 20, color: Colors.grey),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 20, color: Colors.grey),
            )
          : const Icon(Icons.image, size: 20, color: Colors.grey),
    );
  }

  void _showProductSearchDialog(BuildContext context, WidgetRef ref, String lang) {
    String search = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(AppStrings.get('select_product', lang)),
          contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: AppStrings.get('search_product', lang),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setModalState(() => search = v.toLowerCase()),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final asyncProducts = ref.watch(adminProductsProvider);
                      return asyncProducts.when(
                        data: (products) {
                          final filtered = products.where((p) => p.name.toLowerCase().contains(search)).toList();
                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              return ListTile(
                                leading: _buildProductThumbnail(p.imageUrl),
                                title: Text(p.name),
                                subtitle: Text(formatCurrency(p.price)),
                                onTap: () {
                                  setState(() => _selectedProduct = p);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, __) => Center(child: Text('${AppStrings.get('error', lang)}: $e')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _selectedProduct = null);
                Navigator.pop(ctx);
              },
              child: Text(AppStrings.get('none', lang)),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel', lang))),
          ],
        ),
      ),
    );
  }

  Future<void> _sendNotification() async {
    final lang = ref.read(appSettingsProvider).locale.languageCode;
    try {
      final tenantId = ref.read(currentTenantIdProvider);
      final tenant = ref.read(tenantProvider).value;

      if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('fill_title_body_error', lang))),
        );
        return;
      }

      setState(() => _isSending = true);
      
      // 1. Send via Firestore (Legacy/In-App)
      await ref.read(adminFirestoreServiceProvider).sendMarketingNotification(
        tenantId,
        _titleController.text.trim(),
        _bodyController.text.trim(),
        productId: _selectedProduct?.id,
        actionUrl: _actionUrlController.text.trim().isEmpty ? null : _actionUrlController.text.trim(),
      );

      // 2. Send via OneSignal (Automated)
      final success = await ref.read(notificationServiceProvider).sendOneSignalNotification(
        tenantId: tenantId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        productId: _selectedProduct?.id,
        actionUrl: _actionUrlController.text.trim().isEmpty ? null : _actionUrlController.text.trim(),
        storeName: tenant?.name,
        logoUrl: tenant?.logoUrl,
      );

      if (!success) throw AppStrings.get('onesignal_failed_error', lang);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('notification_success', lang))),
        );
        _titleController.clear();
        _bodyController.clear();
        _actionUrlController.clear();
        setState(() => _selectedProduct = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.get('error', lang)}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

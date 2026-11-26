import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:store_admin/features/shared/widgets/admin_drawer.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/features/shared/icon_selector_dialog.dart';
import 'package:store_admin/features/shared/media_gallery_dialog.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'warehouses_screen.dart';

class AdminSettingsScreen extends HookConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final tenant = ref.watch(tenantProvider).value;
    
    final nameController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final whatsappController = useTextEditingController();
    final logoController = useTextEditingController();
    final currencyController = useTextEditingController();
    final shippingController = useTextEditingController();
    final regPointsController = useTextEditingController();
    final purchasePointsController = useTextEditingController();
    final ratioController = useTextEditingController();
    final logoUrl = useState('');
    final isUploading = useState(false);
    final selectedCountry = useState('iq');
    final selectedCurrency = useState('د.ع');

    useEffect(() {
      if (tenant != null) {
        nameController.text = tenant.name;
        descriptionController.text = tenant.description;
        whatsappController.text = tenant.whatsappNumber;
        logoController.text = tenant.logoUrl ?? '';
        selectedCountry.value = CurrencyDefaults.countries.any((c) => c.code == tenant.countryCode)
            ? tenant.countryCode
            : 'iq';
        selectedCurrency.value = CurrencyDefaults.normalizeCurrency(tenant.currencyUnit);
        currencyController.text = selectedCurrency.value;
        shippingController.text = tenant.shippingCost.toString();
        regPointsController.text = tenant.registrationPoints.toString();
        purchasePointsController.text = (tenant.purchasePointsPercent * 100).toString();
        ratioController.text = tenant.pointsToCurrencyRatio.toString();
        logoUrl.value = tenant.logoUrl ?? '';
      }
      return null;
    }, [tenant]);

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(title: Text(AppStrings.get('settings', lang))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader(AppStrings.get('language', lang)),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(AppStrings.get('lang_ar', lang)),
            trailing: lang == 'ar' ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () => ref.read(appSettingsProvider.notifier).setLocale('ar'),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(AppStrings.get('lang_en', lang)),
            trailing: lang == 'en' ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () => ref.read(appSettingsProvider.notifier).setLocale('en'),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(AppStrings.get('lang_ku', lang)),
            trailing: lang == 'ku' ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () => ref.read(appSettingsProvider.notifier).setLocale('ku'),
          ),
          const Divider(),
          _buildSectionHeader(AppStrings.get('store_name', lang)),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(AppStrings.get('description', lang)),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(AppStrings.get('whatsapp', lang)),
          TextField(
            controller: whatsappController,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '9647XXXXXXXXX'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(AppStrings.get('logo_label', lang)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: logoController..text = logoUrl.value,
                  onChanged: (v) => logoUrl.value = v,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(), 
                    hintText: 'Icon code (e.g. 58900) or https://...',
                    helperText: 'Icons: 58900 (Headphones), 58941 (Watch), 0xe190 (Store)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () async {
                  final code = await showDialog<String>(context: context, builder: (ctx) => const IconSelectorDialog());
                  if (code != null) logoController.text = code;
                },
                icon: const Icon(Icons.image_search),
                tooltip: 'Select Icon',
              ),
              IconButton.filled(
                onPressed: isUploading.value ? null : () async {
                  isUploading.value = true;
                  try {
                    final url = await ref.read(storageServiceProvider).pickAndUploadImage('logos');
                    if (url != null) logoUrl.value = url;
                  } catch (e) {
                     if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('upload_failed', lang).replaceFirst('{error}', e.toString())), backgroundColor: Colors.red));
                     }
                  } finally {
                    isUploading.value = false;
                  }
                },
                icon: isUploading.value 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload),
                tooltip: 'Upload Logo',
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () async {
                  final url = await showDialog<String>(context: context, builder: (ctx) => const MediaGalleryDialog());
                  if (url != null) logoController.text = url;
                },
                icon: const Icon(Icons.add_photo_alternate),
                tooltip: 'Pick Image',
              ),
            ],
          ),
          if (logoUrl.value.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 100,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)),
              child: Center(
                child: logoUrl.value.startsWith('http') 
                  ? Image.network(logoUrl.value, errorBuilder: (_, __, ___) => const Icon(Icons.error))
                  : Icon(IconData(int.tryParse(logoUrl.value) ?? 58900, fontFamily: 'MaterialIcons'), size: 50),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildSectionHeader(lang == 'ar' ? 'الدولة والعملة الافتراضية للمتجر' : 'Store Country & Default Currency'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedCountry.value,
                  decoration: InputDecoration(
                    labelText: lang == 'ar' ? 'الدولة' : 'Country',
                    border: const OutlineInputBorder(),
                  ),
                  items: CurrencyDefaults.countries
                      .map((c) => DropdownMenuItem(value: c.code, child: Text('${c.nameAr} (${c.currency})')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      selectedCountry.value = val;
                      final defCurr = CurrencyDefaults.forCountry(val);
                      selectedCurrency.value = defCurr;
                      currencyController.text = defCurr;
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: CurrencyDefaults.currencies.any((c) => c.code == selectedCurrency.value)
                      ? selectedCurrency.value
                      : null,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('currency_unit_label', lang),
                    border: const OutlineInputBorder(),
                  ),
                  items: CurrencyDefaults.currencies
                      .map((c) => DropdownMenuItem(value: c.code, child: Text(c.label)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      selectedCurrency.value = val;
                      currencyController.text = val;
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: currencyController,
            decoration: InputDecoration(
              labelText: lang == 'ar' ? 'رمز العملة المعتمد' : 'Currency Symbol',
              border: const OutlineInputBorder(),
              hintText: 'د.ع, \$, ...',
            ),
            onChanged: (v) => selectedCurrency.value = CurrencyDefaults.normalizeCurrency(v),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader(AppStrings.get('shipping_cost', lang)),
          TextField(
            controller: shippingController,
            decoration: InputDecoration(border: const OutlineInputBorder(), suffixText: selectedCurrency.value),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.warehouse_rounded, color: Colors.blue),
            title: Text(lang == 'ar' ? 'إدارة المخازن' : 'Warehouses Management'),
            subtitle: Text(lang == 'ar' ? 'إضافة وحذف أماكن التخزين' : 'Add/Remove storage locations'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehousesScreen())),
          ),
          const SizedBox(height: 24),
          const Divider(),
          _buildSectionHeader(AppStrings.get('loyalty_settings', lang)),
          Text(AppStrings.get('points_desc', lang), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: regPointsController,
                  decoration: InputDecoration(labelText: AppStrings.get('reg_bonus', lang), border: const OutlineInputBorder(), suffixText: AppStrings.get('points', lang)),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: purchasePointsController,
                  decoration: InputDecoration(labelText: AppStrings.get('purchase_reward', lang), border: const OutlineInputBorder(), suffixText: '%'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ratioController,
            decoration: InputDecoration(
              labelText: AppStrings.get('conversion_ratio', lang), 
              border: const OutlineInputBorder(), 
              helperText: AppStrings.get('example_conversion', lang),
              suffixText: AppStrings.get('points', lang)
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: () async {
                if (tenant == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('session_error', lang)), backgroundColor: Colors.red));
                  return;
                }
                final updated = tenant.copyWith(
                  name: nameController.text,
                  logoUrl: logoUrl.value,
                  description: descriptionController.text,
                  whatsappNumber: whatsappController.text,
                  countryCode: selectedCountry.value,
                  currencyUnit: CurrencyDefaults.normalizeCurrency(currencyController.text),
                  shippingCost: double.tryParse(shippingController.text) ?? 5000.0,
                  registrationPoints: int.tryParse(regPointsController.text) ?? 50,
                  purchasePointsPercent: (double.tryParse(purchasePointsController.text) ?? 5.0) / 100,
                  pointsToCurrencyRatio: double.tryParse(ratioController.text) ?? 1.0,
                );
                try {
                  await ref.read(adminFirestoreServiceProvider).updateTenant(updated);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('save_success', lang))));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'), 
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: Text(AppStrings.get('save', lang)),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          _buildSectionHeader(AppStrings.get('contact_support', lang)),
                  ... (ref.watch(globalSettingsProvider).maybeWhen(
                    data: (settings) {
                      final whatsapp = settings['developerWhatsapp'] as String? ?? '9647823438833'; // Fallback
                      final email = settings['developerEmail'] as String? ?? 'support@example.com'; 
                      
                      return [
                        ListTile(
                          leading: const Icon(Icons.support_agent, color: Colors.green),
                          title: Text(AppStrings.get('contact_dev_whatsapp', lang)),
                          subtitle: Text(whatsapp),
                          onTap: () async {
                            // Normalize number (remove +, spaces, etc)
                            final cleanNumber = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
                            final uri = Uri.parse('https://wa.me/$cleanNumber');
                            try {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch WhatsApp: $e')));
                              }
                            }
                          },
                        ),
                        if (email.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.email_outlined),
                            title: Text(AppStrings.get('contact_dev_email', lang)),
                            subtitle: Text(email),
                            onTap: () async {
                              final uri = Uri.parse('mailto:$email');
                              try {
                                await launchUrl(uri);
                              } catch (e) {
                                // ignore
                              }
                            },
                          ),
                      ];
                    },
                    orElse: () => [
                      ListTile(
                        leading: const Icon(Icons.support_agent, color: Colors.green),
                        title: Text(AppStrings.get('contact_dev_whatsapp', lang)),
                        subtitle: const Text('9647823438833'),
                        onTap: () async {
                          final uri = Uri.parse('https://wa.me/9647823438833');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                      ),
                    ],
                  )),
          const SizedBox(height: 48),
          Center(child: Text('Version 0.2.0', style: TextStyle(color: Colors.grey[400], fontSize: 12))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }
}

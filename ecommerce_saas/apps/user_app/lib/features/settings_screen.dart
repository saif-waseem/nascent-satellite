import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_settings_controller.dart';
import '../../core/localization/resources/app_strings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final lang = settings.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('settings', lang))),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(AppStrings.get('language', lang)),
            trailing: DropdownButton<String>(
              value: settings.locale.languageCode,
              items: [
                DropdownMenuItem(value: 'ar', child: Text(AppStrings.get('lang_ar', lang))),
                DropdownMenuItem(value: 'en', child: Text(AppStrings.get('lang_en', lang))),
                DropdownMenuItem(value: 'ku', child: Text(AppStrings.get('lang_ku', lang))),
              ],
              onChanged: (val) {
                if (val != null) notifier.setLocale(val);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: Text(AppStrings.get('currency', lang)),
            trailing: DropdownButton<String>(
              value: settings.currencyCode,
              items: [
                DropdownMenuItem(value: 'IQD', child: Text(AppStrings.get('curr_iqd', lang))),
                DropdownMenuItem(value: 'USD', child: Text(AppStrings.get('curr_usd', lang))),
              ],
              onChanged: (val) {
                if (val != null) notifier.setCurrency(val);
              },
            ),
          ),
          const Divider(),
          SwitchListTile(
            secondary: Icon(settings.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
            title: Text(AppStrings.get('theme', lang)),
            value: settings.themeMode == ThemeMode.dark,
            onChanged: (val) {
              notifier.toggleTheme();
            },
          ),
          const Divider(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              onPressed: () => _showDeleteConfirmation(context, lang),
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: Text(
                AppStrings.get('delete_account', lang),
                style: const TextStyle(color: Colors.red),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('delete_account', lang)),
        content: Text(AppStrings.get('delete_account_confirm', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get('cancel', lang)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse('https://saif-waseem.github.io/store/delete-account.html');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(AppStrings.get('yes', lang)),
          ),
        ],
      ),
    );
  }
}

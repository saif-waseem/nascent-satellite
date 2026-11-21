import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:country_picker/country_picker.dart';
import 'package:user_app/features/shared/providers.dart';

import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:user_app/core/utils/countries_data.dart';
import 'package:user_app/core/widgets/searchable_list_dialog.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String referral;
  const RegisterScreen({super.key, this.referral = ''});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  late final _referralController = TextEditingController(text: widget.referral);
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _governorateController = TextEditingController();
  final _locationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _landmarkController = TextEditingController(); 
  @override
  void dispose() {
    for (final controller in [_referralController, _phoneController, _nameController,
      _passwordController, _governorateController, _locationController, _landmarkController]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _selectedCountry = 'Iraq';
  String _selectedCountryCode = 'IQ';
  String _selectedPhoneCode = '964';

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    
    // Attempt to localize the country name
    String displayCountry = _selectedCountry;
    if (lang == 'ar') {
      final countryMatch = CountryData.allCountries.firstWhere(
        (c) => c['name'] == _selectedCountry || c['code'] == _selectedCountryCode, 
        orElse: () => {'ar': _selectedCountry}
      );
      displayCountry = countryMatch['ar'] ?? _selectedCountry;
    }
    
    // Attempt to localize the governorate name
    String displayGov = _governorateController.text;
    if (lang == 'ar' && displayGov.isNotEmpty) {
      final govs = CountryData.governorates[_selectedCountryCode] ?? [];
      try {
        final govMatch = govs.firstWhere((g) => g['en'] == displayGov, orElse: () => {});
        if (govMatch.isNotEmpty && govMatch['ar'] != null) {
          displayGov = govMatch['ar']!;
        }
      } catch (_) {}
    }
    
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('create_account', lang))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_add_outlined, size: 60, color: Colors.blue),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: AppStrings.get('full_name', lang), prefixIcon: const Icon(Icons.person), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
             TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: AppStrings.get('phone', lang), 
                prefixIcon: const Icon(Icons.phone), 
                prefixText: '+ $_selectedPhoneCode ',
                border: const OutlineInputBorder()
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                 showCountryPicker(
                  context: context,
                  countryListTheme: const CountryListThemeData(
                    textStyle: TextStyle(fontSize: 16),
                  ),
                  onSelect: (Country country) {
                    setState(() {
                      _selectedCountry = country.name;
                      _selectedCountryCode = country.countryCode;
                      _selectedPhoneCode = country.phoneCode;
                      _governorateController.clear();
                    });
                  },
                );
              },
              child: AbsorbPointer(
                child: TextField(
                  controller: TextEditingController(text: displayCountry.toUpperCase()),
                  decoration: InputDecoration(
                    labelText: AppStrings.get('country', lang),
                    prefixIcon: const Icon(Icons.public),
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                 final countryCode = _selectedCountryCode;
                
                final govList = CountryData.governorates[countryCode] ?? [];
                
                final result = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SearchableListDialog(
                    title: AppStrings.get('governorate', lang),
                    items: govList,
                    lang: lang,
                  ),
                );
                if (result != null) {
                  setState(() => _governorateController.text = result);
                }
              },
              child: AbsorbPointer(
                child: TextField(
                  controller: TextEditingController(text: displayGov),
                  decoration: InputDecoration(
                    labelText: AppStrings.get('governorate', lang),
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(labelText: AppStrings.get('location_details', lang), hintText: 'Street, Neighborhood, etc.', prefixIcon: const Icon(Icons.location_on), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: AppStrings.get('password', lang), prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _landmarkController,
              decoration: InputDecoration(labelText: AppStrings.get('landmark', lang), prefixIcon: const Icon(Icons.flag), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            TextField(controller: _referralController, decoration: const InputDecoration(
              labelText: 'رمز الدعوة (اختياري)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                final phone = _phoneController.text.trim();
                final gov = _governorateController.text.trim();
                final loc = _locationController.text.trim();
                final password = _passwordController.text.trim();

                if (name.isEmpty || phone.isEmpty || gov.isEmpty || loc.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('fill_fields', lang))));
                  return;
                }

                 // Country-specific phone validation (Anti-Fake)
                int minLen = 8;
                int maxLen = 15;
                if (_selectedPhoneCode == '964') {
                  minLen = 10;
                  maxLen = 11;
                } else if (['966', '971', '965', '974', '968', '973'].contains(_selectedPhoneCode)) {
                  minLen = 8;
                  maxLen = 10;
                }

                if (phone.length < minLen || phone.length > maxLen) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('invalid_phone', lang))));
                  return;
                }

                if (loc.length < 5) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('address_short_error', lang))));
                  return;
                }

                final fullAddress = '$displayCountry - $displayGov - $loc';
                
                try { await ref.read(userActionsProvider).register(
                  name: name,
                  phone: phone,
                  address: fullAddress,
                  landmark: _landmarkController.text.trim(),
                  password: password,
                  referredByCode: _referralController.text.trim(),
                );
                
                } catch (error) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                  return;
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('account_created', lang))));
                context.go('/home');
              },
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(AppStrings.get('create_account', lang)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:shared_models/shared_models.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:user_app/core/utils/countries_data.dart';
import 'package:country_picker/country_picker.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _draftId = FirebaseFirestore.instance.collection('orders').doc().id;
  int _currentStep = 0;
  String _selectedPayment = 'Direct Payment';
  String _address = '';
   String _selectedCountry = 'IQ'; 
   String _selectedCountryName = 'Iraq';
   String _selectedPhoneCode = '964';
   bool _isPredefinedCountry = true;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _governorateController = TextEditingController(); 
  final TextEditingController _locationController = TextEditingController();    
  final TextEditingController _landmarkController = TextEditingController(); // NEW
  final TextEditingController _discountCodeController = TextEditingController();
  
  final _countryData = {
    'iq': ['Baghdad', 'Basra', 'Nineveh', 'Erbil', 'Sulaymaniyah', 'Kirkuk', 'Anbar', 'Najaf', 'Duhok', 'Dhi Qar', 'Babil', 'Maysan', 'Karbala', 'Muthanna', 'Qadisiyah', 'Wasit', 'Salah al-Din', 'Halabja'],
    'sa': ['Riyadh', 'Jeddah', 'Mecca', 'Medina', 'Dammam', 'Khobar', 'Tabuk', 'Abha', 'Jazan', 'Buraidah'],
    'kw': ['Kuwait City', 'Al Ahmadi', 'Hawalli', 'Salwa', 'Sabah Al Salem', 'Farwaniya'],
    'ae': ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Ras Al Khaimah', 'Fujairah', 'Umm Al Quwain'],
    'qa': ['Doha', 'Al Rayyan', 'Al Wakrah', 'Al Khor'],
    'om': ['Muscat', 'Salalah', 'Sohar', 'Nizwa'],
    'bh': ['Manama', 'Riffa', 'Muharraq'],
    'jo': ['Amman', 'Zarqa', 'Irbid'],
    'eg': ['Cairo', 'Alexandria', 'Giza'],
  };

  static String getLocalizedCountry(String code, String fallback, String lang) {
    if (lang != 'ar') return fallback;
    const map = {
      'iq': 'العراق', 'sa': 'المملكة العربية السعودية', 'ae': 'الإمارات العربية المتحدة',
      'kw': 'الكويت', 'qa': 'قطر', 'om': 'سلطنة عمان', 'bh': 'البحرين',
      'eg': 'مصر', 'jo': 'الأردن', 'lb': 'لبنان', 'sy': 'سوريا',
      'ps': 'فلسطين', 'ye': 'اليمن', 'tr': 'تركيا', 'gb': 'المملكة المتحدة',
    };
    return map[code.toLowerCase()] ?? fallback;
  }

  String? _getMatchingGovernorateValue(String currentText, String countryCode, String lang) {
    if (currentText.isEmpty) return null;
    final list = _countryData[countryCode.toLowerCase()] ?? [];
    for (final g in list) {
      if (g.toLowerCase() == currentText.toLowerCase()) return g;
      final key = 'gov_${g.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_')}';
      final localized = AppStrings.get(key, lang);
      if (localized == currentText || localized.toLowerCase() == currentText.toLowerCase()) {
        return g;
      }
    }
    return list.contains(currentText) ? currentText : null;
  }

  Future<void> _persistAddressLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final full = '$_selectedCountryName - ${_governorateController.text.trim()} - ${_locationController.text.trim()}';
    await prefs.setString('user_address', full);
    await prefs.setString('user_country_code', _selectedCountry);
    await prefs.setString('user_country_name', _selectedCountryName);
    await prefs.setString('user_governorate', _governorateController.text.trim());
    await prefs.setString('user_location', _locationController.text.trim());
    await prefs.setString('user_landmark', _landmarkController.text.trim());
  }

  @override
  void initState() {
    super.initState();
    _loadStoredData();
    
    // Safety redirect: Enforce login only AFTER initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  void _checkAuth() {
    final isInitialized = ref.read(isAuthInitializedProvider);
    if (!isInitialized) {
      // Wait a bit more or retry
      Future.delayed(const Duration(milliseconds: 100), _checkAuth);
      return;
    }
    
    final phone = ref.read(userPhoneProvider);
    if (phone == null) {
      context.go('/login');
    }
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedPhone = prefs.getString('user_phone');
    final savedAddress = prefs.getString('user_address');
    final savedCountryCode = prefs.getString('user_country_code');
    final savedCountryName = prefs.getString('user_country_name');
    final savedGov = prefs.getString('user_governorate');
    final savedLoc = prefs.getString('user_location');
    final savedLandmark = prefs.getString('user_landmark');
    final savedPayment = prefs.getString('last_payment_method');

    final user = ref.read(userProvider).value;
    final effectiveAddress = savedAddress ?? user?.address;

    setState(() {
      if (savedPhone != null && savedPhone.isNotEmpty) {
        _phoneController.text = savedPhone.contains('_') ? savedPhone.split('_').last : savedPhone;
      }
      if (savedLandmark != null && savedLandmark.isNotEmpty) {
        _landmarkController.text = savedLandmark;
      } else if (user?.landmark != null && user!.landmark!.isNotEmpty) {
        _landmarkController.text = user.landmark!;
      }
      if (savedPayment != null) _selectedPayment = savedPayment;
      
      final lang = ref.read(appSettingsProvider).locale.languageCode;
      if (savedCountryName != null && savedCountryName.isNotEmpty) {
        _selectedCountry = (savedCountryCode ?? 'iq').toLowerCase();
        _selectedCountryName = getLocalizedCountry(_selectedCountry, savedCountryName, lang);
        if (savedGov != null && savedGov.isNotEmpty) _governorateController.text = savedGov;
        if (savedLoc != null && savedLoc.isNotEmpty) {
          _locationController.text = savedLoc;
        } else if (savedAddress != null && savedAddress.contains(' - ')) {
          _locationController.text = savedAddress.split(' - ').last;
        }
        _isPredefinedCountry = _countryData.containsKey(_selectedCountry);
      } else if (effectiveAddress != null && effectiveAddress.isNotEmpty) {
        _address = effectiveAddress;
        final parts = effectiveAddress.split(' - ');
        if (parts.length >= 3) {
          final nameToCode = {
            'Iraq': 'iq', 'العراق': 'iq',
            'Saudi Arabia': 'sa', 'المملكة العربية السعودية': 'sa', 'السعودية': 'sa',
            'United Arab Emirates': 'ae', 'الإمارات': 'ae',
            'Kuwait': 'kw', 'الكويت': 'kw',
            'Qatar': 'qa', 'قطر': 'qa',
            'Oman': 'om', 'عمان': 'om',
            'Bahrain': 'bh', 'البحرين': 'bh',
            'Egypt': 'eg', 'مصر': 'eg',
            'Jordan': 'jo', 'الأردن': 'jo',
            'Turkey': 'tr', 'تركيا': 'tr',
            'United Kingdom': 'gb', 'المملكة المتحدة': 'gb'
          };
          _selectedCountry = (nameToCode[parts[0]] ?? 'iq').toLowerCase();
          _selectedCountryName = getLocalizedCountry(_selectedCountry, parts[0], lang);
          _governorateController.text = parts[1];
          _locationController.text = parts.sublist(2).join(' - ');
          _isPredefinedCountry = _countryData.containsKey(_selectedCountry);
        } else if (parts.length == 2) {
          _governorateController.text = parts[0];
          _locationController.text = parts[1];
        } else {
          _locationController.text = effectiveAddress;
        }
      } else {
        _selectedCountry = 'iq';
        _selectedCountryName = getLocalizedCountry('iq', 'العراق', lang);
      }

      if (user != null) {
        final purePhone = user.id.contains('_') ? user.id.split('_').last : user.id;
        if (_phoneController.text.isEmpty && purePhone.isNotEmpty) {
          _phoneController.text = purePhone;
        }
      }
    });
  }
  int _pointsToRedeem = 0;
  double _discountAmount = 0;
  String? _appliedCouponId;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final cartItems = ref.watch(cartProvider);
    final asyncUser = ref.watch(userProvider);
    final asyncTenant = ref.watch(tenantProvider);
    
    // Attempt to localize the country name
    String displayCountry = _selectedCountryName;
    if (lang == 'ar' && _selectedCountry.isNotEmpty) {
      final countryMatch = CountryData.allCountries.firstWhere(
        (c) => c['name'] == _selectedCountryName || c['code'] == _selectedCountry.toUpperCase(), 
        orElse: () => {'ar': _selectedCountryName}
      );
      displayCountry = countryMatch['ar'] ?? _selectedCountryName;
    }
    
    // Attempt to localize the governorate name
    String displayGov = _governorateController.text;
    if (lang == 'ar' && displayGov.isNotEmpty && _selectedCountry.isNotEmpty) {
      final govs = CountryData.governorates[_selectedCountry.toUpperCase()] ?? [];
      try {
        final govMatch = govs.firstWhere((g) => g['en'] == displayGov, orElse: () => {});
        if (govMatch.isNotEmpty && govMatch['ar'] != null) {
          displayGov = govMatch['ar']!;
        }
      } catch (_) {}
    }
    
    final subtotal = cartItems.fold(0.0, (sum, item) => sum + ((item['price'] as num) * (item['quantity'] ?? 1)));
    
    final shipping = asyncTenant.maybeWhen(
      data: (t) => t?.shippingCost ?? 5000.0,
      orElse: () => 5000.0,
    );

    final pointsToCurrency = asyncTenant.maybeWhen(
      data: (t) => t?.pointsToCurrencyRatio ?? 100.0,
      orElse: () => 100.0,
    );
    
    final pointsDiscount = _pointsToRedeem * pointsToCurrency; 
    
    // First Order Discount Logic
    double firstOrderDiscount = 0;
    if (asyncTenant.hasValue && asyncTenant.value != null && asyncUser.hasValue && asyncUser.value != null) {
      final tenant = asyncTenant.value!;
      final user = asyncUser.value!;
      if (tenant.firstOrderDiscountEnabled && user.purchaseCount == 0) {
        if (tenant.firstOrderDiscountAmount > 0) {
          firstOrderDiscount = tenant.firstOrderDiscountAmount;
        } else {
          firstOrderDiscount = subtotal * tenant.firstOrderDiscountPercent;
        }
      }
    }

    final total = (subtotal + shipping - pointsDiscount - _discountAmount - firstOrderDiscount).clamp(0, double.infinity);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('checkout', lang)),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(AppStrings.get('step_address', lang), Icons.location_on_outlined),
                  _buildAddressSection(context, lang),
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader(AppStrings.get('step_payment', lang), Icons.payment_outlined),
                  _buildPaymentSection(lang),
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader(AppStrings.get('step_discount', lang), Icons.local_offer_outlined),
                  _buildDiscountSection(context, ref, lang, subtotal, shipping, pointsToCurrency),
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader(AppStrings.get('step_confirm', lang), Icons.receipt_long_outlined),
                  _buildSummarySection(lang, cartItems, subtotal, shipping, pointsDiscount, asyncTenant, asyncUser, total),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _buildBottomAction(context, ref, lang, total, cartItems, subtotal, shipping, pointsDiscount),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(BuildContext context, String lang) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                showCountryPicker(
                  context: context,
                  showPhoneCode: false,
                  countryListTheme: CountryListThemeData(
                    bottomSheetHeight: 520,
                    borderRadius: BorderRadius.circular(20),
                    inputDecoration: InputDecoration(
                      labelText: lang == 'ar' ? 'بحث عن دولة...' : 'Search country...',
                      hintText: lang == 'ar' ? 'اكتب اسم الدولة' : 'Type country name',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  onSelect: (Country country) {
                    setState(() {
                      _selectedCountry = country.countryCode.toLowerCase();
                      _selectedCountryName = getLocalizedCountry(_selectedCountry, country.name, lang);
                      _selectedPhoneCode = country.phoneCode;
                      _isPredefinedCountry = _countryData.containsKey(_selectedCountry);
                      _governorateController.clear();
                      _persistAddressLocally();
                    });
                  },
                );
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: AppStrings.get('country', lang),
                  prefixIcon: const Icon(Icons.public),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(getLocalizedCountry(_selectedCountry, _selectedCountryName, lang)),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isPredefinedCountry)
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppStrings.get('governorate', lang),
                  prefixIcon: const Icon(Icons.map_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                value: _getMatchingGovernorateValue(_governorateController.text, _selectedCountry, lang),
                items: (_countryData[_selectedCountry] ?? []).map((g) {
                  final key = 'gov_${g.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_')}';
                  return DropdownMenuItem(value: g, child: Text(AppStrings.get(key, lang)));
                }).toList(),
                onChanged: (v) {
                  setState(() => _governorateController.text = v ?? '');
                  _persistAddressLocally();
                },
              )
            else
              TextField(
                controller: _governorateController,
                decoration: InputDecoration(
                  labelText: AppStrings.get('governorate', lang),
                  prefixIcon: const Icon(Icons.map_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => _persistAddressLocally(),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: AppStrings.get('location_details', lang),
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => _persistAddressLocally(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _landmarkController,
              decoration: InputDecoration(
                labelText: AppStrings.get('landmark', lang),
                prefixIcon: const Icon(Icons.flag_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => _persistAddressLocally(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: AppStrings.get('phone', lang),
                prefixIcon: const Icon(Icons.phone_outlined),
                prefixText: '+$_selectedPhoneCode ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection(String lang) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: RadioListTile(
        title: Text(AppStrings.get('direct_payment', lang)),
        subtitle: Text(AppStrings.get('only_direct_payment', lang), style: const TextStyle(fontSize: 12)),
        value: 'Direct Payment',
        groupValue: _selectedPayment,
        onChanged: (v) => setState(() => _selectedPayment = v!),
        secondary: const Icon(Icons.money_off, color: Colors.green),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildDiscountSection(BuildContext context, WidgetRef ref, String lang, double subtotal, double shipping, double pointsToCurrency) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Consumer(
              builder: (context, ref, _) {
                final asyncUser = ref.watch(userProvider);
                return asyncUser.maybeWhen(
                  data: (user) => user != null ? Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppStrings.get('my_points', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${user.loyaltyPoints}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ) : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
            TextField(
              controller: _discountCodeController,
              decoration: InputDecoration(
                labelText: AppStrings.get('coupon_code', lang),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.blue),
                  onPressed: () async {
                    final code = _discountCodeController.text.trim();
                    if (code.isEmpty) return;
                    final tenant = ref.read(tenantProvider).value;
                    final tenantId = tenant?.id ?? 'main_store';
                    try {
                      final coupon = await ref.read(firestoreServiceProvider).verifyCoupon(tenantId, code);
                      if (coupon != null && coupon.isActive) {
                        if (coupon.usageCount >= coupon.maxUsage) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ ${AppStrings.get('coupon_limit_reached', lang)}')));
                          return;
                        }
                        setState(() {
                          _appliedCouponId = coupon.id;
                          _discountAmount = coupon.type == DiscountType.percentage ? subtotal * (coupon.value / 100) : coupon.value;
                        });
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${AppStrings.get('coupon_applied', lang)}: ${coupon.code}')));
                      } else {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ ${AppStrings.get('invalid_coupon', lang)}')));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e')));
                    }
                  },
                ),
              ),
            ),
            if (_discountAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('✅ -${formatCurrency(_discountAmount)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: AppStrings.get('points_redeem', lang),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final points = int.tryParse(v) ?? 0;
                      final userPoints = ref.read(userProvider).value?.loyaltyPoints ?? 0;
                      final maxPointsByCost = ((subtotal + shipping) / pointsToCurrency).floor();
                      final maxRedeemable = userPoints < maxPointsByCost ? userPoints : maxPointsByCost;
                      setState(() => _pointsToRedeem = points.clamp(0, maxRedeemable));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    final userPoints = ref.read(userProvider).value?.loyaltyPoints ?? 0;
                    final maxPointsByCost = ((subtotal + shipping) / pointsToCurrency).floor();
                    final maxRedeemable = userPoints < maxPointsByCost ? userPoints : maxPointsByCost;
                    setState(() => _pointsToRedeem = maxRedeemable);
                  },
                  child: Text(AppStrings.get('use_max', lang)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(String lang, List<Map<String, dynamic>> cartItems, double subtotal, double shipping, double pointsDiscount, AsyncValue asyncTenant, AsyncValue asyncUser, num total) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...cartItems.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${e['name']} x${e['quantity'] ?? 1}', style: const TextStyle(fontSize: 13)),
                  Text(formatCurrency(e['price'] * (e['quantity'] ?? 1)), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
            const Divider(height: 24),
            _summaryRow(AppStrings.get('subtotal_label', lang), formatCurrency(subtotal)),
            _summaryRow(AppStrings.get('shipping_label', lang), formatCurrency(shipping)),
            if (_pointsToRedeem > 0) _summaryRow(AppStrings.get('points_redeem', lang), '-${formatCurrency(pointsDiscount)}', isDiscount: true),
            if (_discountAmount > 0) _summaryRow(AppStrings.get('coupon_code', lang), '-${formatCurrency(_discountAmount)}', isDiscount: true),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppStrings.get('total_label', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: TextStyle(color: isDiscount ? Colors.green : null, fontWeight: isDiscount ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, WidgetRef ref, String lang, num total, List<Map<String, dynamic>> cartItems, double subtotal, double shipping, double pointsDiscount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: FilledButton(
          onPressed: () {
            if (_validateInputs(context, lang)) {
              _processPayment(context, ref, cartItems, total.toDouble(), subtotal, shipping, pointsDiscount);
            }
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            AppStrings.get('place_order_with_total', lang).replaceFirst('{total}', formatCurrency(total)),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  bool _validateInputs(BuildContext context, String lang) {
    final phone = _phoneController.text.trim();
    final location = _locationController.text.trim();
    final governorate = _governorateController.text.trim();

    if (governorate.isEmpty || location.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('fill_required_fields', lang)), backgroundColor: Colors.red));
      return false;
    }

    int minLen = 8;
    int maxLen = 15;
    if (_selectedPhoneCode == '964') { minLen = 10; maxLen = 11; }
    else if (['966', '971', '965', '974'].contains(_selectedPhoneCode)) { minLen = 8; maxLen = 10; }

    if (phone.length < minLen || phone.length > maxLen) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('invalid_phone', lang)), backgroundColor: Colors.red));
      return false;
    }

    return true;
  }

  void _processPayment(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> items, double total, double subtotal, double shipping, double pointsDiscount) async {
    final lang = ref.read(appSettingsProvider).locale.languageCode;
    // Validate phone
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('enter_phone_number', lang)))
      );
      setState(() => _currentStep = 0);
      return;
    }
    
    // 1. Loading Indicator
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      // 2. Simulate Delay (Network)
      await Future.delayed(const Duration(seconds: 2));
      
      // 3. Deduct redeemed points
      final user = ref.read(userProvider).value;
      final rawPhone = _phoneController.text.trim();
      final purePhone = rawPhone.contains('_') ? rawPhone.split('_').last : rawPhone;
      final userPhone = user?.id ?? purePhone;
      
      
      // 4. Calculate points to award (Awarding based on percentage of purchase)
      final tenant = ref.read(tenantProvider).value;
      final purchasePointsPercent = tenant?.purchasePointsPercent ?? 0.05;
      final maxDailyLimit = tenant?.maxDailyPurchasePoints ?? 1000;
      
      // Check current daily usage
      final dailyStats = await ref.read(firestoreServiceProvider).getDailyStats(userPhone);
      final currentDailyEarned = (dailyStats['purchasePointsAwarded'] as num? ?? 0).toInt();
      
      int pointsToAward = (subtotal * purchasePointsPercent).round();
      if (currentDailyEarned + pointsToAward > maxDailyLimit) {
        pointsToAward = (maxDailyLimit - currentDailyEarned).clamp(0, 999999);
      }
      
      final userName = user?.name ?? AppStrings.get('guest', lang);

      // 5. Place Order
      // Ensure items have necessary fields
      final orderItems = items.map((i) => {
        'id': i['id'],
        'name': i['name'],
        'price': i['price'],
        'quantity': i['quantity'],
        'color': i['color'] ?? 'Default',
        'size': i['size'] ?? 'Default',
        'imageUrl': i['imageUrl'],
      }).toList();
      
      // Calculate total discount (Coupon + First Order)
      double totalDiscount = _discountAmount;
      if (tenant != null && user != null && tenant.firstOrderDiscountEnabled && user.purchaseCount == 0) {
        if (tenant.firstOrderDiscountAmount > 0) {
          totalDiscount += tenant.firstOrderDiscountAmount;
        } else {
          totalDiscount += subtotal * tenant.firstOrderDiscountPercent;
        }
      }

      final editingOrderId = ref.read(editingOrderIdProvider);

      final fullAddress = '$_selectedCountryName - ${_governorateController.text.trim()} - ${_locationController.text.trim()}';

      final orderId = await ref.read(orderActionsProvider).placeOrder(
        items: orderItems,
        total: total,
        address: fullAddress, 
        userName: userName,
        userPhone: userPhone,
        pointsAwarded: pointsToAward,
        pointsRedeemed: _pointsToRedeem,
        discountAmount: totalDiscount,
        shippingCost: shipping,
        couponCode: _discountCodeController.text.trim().toUpperCase(),
        orderId: editingOrderId ?? _draftId,
        couponId: _appliedCouponId,
        landmark: _landmarkController.text.trim(),
      );

      // --- Stock deduction is now handled entirely inside OrderActions.placeOrder ---
      
      // Reset editing state
      ref.read(editingOrderIdProvider.notifier).set(null);
      
      // Save address, phone and landmark for next time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_address', fullAddress);
      await prefs.setString('user_country_code', _selectedCountry);
      await prefs.setString('user_country_name', _selectedCountryName);
      await prefs.setString('user_governorate', _governorateController.text.trim());
      await prefs.setString('user_location', _locationController.text.trim());
      await prefs.setString('user_phone', purePhone);
      await prefs.setString('user_landmark', _landmarkController.text.trim());
      await prefs.setString('last_payment_method', _selectedPayment);

      // Update user profile in Firestore
      if (user != null) {
        await ref.read(userActionsProvider).updateUserProfile(
          address: fullAddress,
          landmark: _landmarkController.text.trim(),
        );
      }

      // 9. Clear Cart
      ref.read(cartProvider.notifier).clear();
      
      if (mounted) {
        Navigator.pop(context); // Close Loader
        
        // Success Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(AppStrings.get('order_placed', lang)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text(AppStrings.get('order_placed_msg', lang).replaceFirst('{id}', orderId)),
                const SizedBox(height: 8),
                Text(AppStrings.get('paid_amount', lang).replaceFirst('{amount}', formatCurrency(total)), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  AppStrings.get('points_pending', lang).replaceFirst('{points}', formatNumber(pointsToAward)), 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)
                ),
                Text(AppStrings.get('points_confirmed_later', lang), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/orders');
                },
                child: Text(AppStrings.get('track_order', lang)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/home');
                },
                child: Text(AppStrings.get('continue', lang)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close Loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.get('error', lang)}: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _governorateController.dispose();
    _locationController.dispose();
    _landmarkController.dispose(); // NEW
    _discountCodeController.dispose();
    super.dispose();
  }
}

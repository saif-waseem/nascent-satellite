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
    final savedLandmark = prefs.getString('user_landmark');
    final savedPayment = prefs.getString('last_payment_method');

    setState(() {
      if (savedPhone != null && savedPhone.isNotEmpty) {
        _phoneController.text = savedPhone.contains('_') ? savedPhone.split('_').last : savedPhone;
      }
      if (savedLandmark != null) _landmarkController.text = savedLandmark;
      if (savedPayment != null) _selectedPayment = savedPayment;
      
      if (savedAddress != null) {
        _address = savedAddress;
        final parts = savedAddress.split(' - ');
        if (parts.length >= 3) {
          _selectedCountryName = parts[0];
          // Try to map name to code if possible, default to IQ
          final nameToCode = {
            'Iraq': 'iq', 'Saudi Arabia': 'sa', 'United Arab Emirates': 'ae',
            'Kuwait': 'kw', 'Qatar': 'qa', 'Oman': 'om', 'Bahrain': 'bh',
            'Egypt': 'eg', 'Jordan': 'jo', 'Turkey': 'tr', 'United Kingdom': 'gb'
          };
          _selectedCountry = nameToCode[parts[0]] ?? 'iq';
          _governorateController.text = parts[1];
          _locationController.text = parts.sublist(2).join(' - ');
          _isPredefinedCountry = _countryData.containsKey(_selectedCountry);
        } else if (parts.length == 2) {
          _governorateController.text = parts[0];
          _locationController.text = parts[1];
        } else {
          // Legacy format: Just a location, maybe?
          // Don't auto-fill governorate if we can't be sure
          _locationController.text = savedAddress;
          _governorateController.clear();
        }
      }
    });

    // Profile data takes precedence if logged in
    final user = ref.read(userProvider).value;
    if (user != null) {
      setState(() {
        final purePhone = user.id.contains('_') ? user.id.split('_').last : user.id;
        if (purePhone.isNotEmpty) _phoneController.text = purePhone;
        if (user.landmark != null && user.landmark!.isNotEmpty) {
          _landmarkController.text = user.landmark!;
        }
        // If profile address exists, it might override parts of the loaded address
      });
    }
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
      appBar: AppBar(title: Text(AppStrings.get('checkout', lang))),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
             // Country-specific phone validation
             final phone = _phoneController.text.trim();
             final location = _locationController.text.trim();
             final governorate = _governorateController.text.trim();

             if (governorate.isEmpty || location.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppStrings.get('fill_required_fields', lang)), backgroundColor: Colors.red)
                );
                return;
             }

             // Anti-fake: length patterns (generalized for common countries, fallback to 8-15)
             int minLen = 8;
             int maxLen = 15;
             if (_selectedPhoneCode == '964') { // Iraq
                minLen = 10;
                maxLen = 11;
             } else if (_selectedPhoneCode == '966' || _selectedPhoneCode == '971' || _selectedPhoneCode == '965' || _selectedPhoneCode == '974') { // GCC
                minLen = 8;
                maxLen = 10;
             }

             if (phone.length < minLen || phone.length > maxLen) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(AppStrings.get('invalid_phone', lang)), backgroundColor: Colors.red)
               );
               return;
             }

             if (location.length < 3) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(AppStrings.get('address_too_short', lang)), backgroundColor: Colors.red)
               );
               return;
             }

             // Update full address for display
             setState(() {
               _address = '$displayCountry - $displayGov - $location';
             });
          }

          if (_currentStep < 3) {
            setState(() => _currentStep += 1);
          } else {
            _processPayment(context, ref, cartItems, total.toDouble(), subtotal, shipping, pointsDiscount);
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep -= 1);
        },
        controlsBuilder: (context, details) {
           return Padding(
             padding: const EdgeInsets.only(top: 20),
             child: Row(
               children: [
                 if (_currentStep > 0) ...[
                   TextButton(
                     onPressed: details.onStepCancel,
                     child: Text(AppStrings.get('back', lang)),
                   ),
                   const SizedBox(width: 8),
                 ],
                 Expanded(
                   child: FilledButton(
                     onPressed: details.onStepContinue,
                     child: Text(
                       _currentStep == 3 
                         ? AppStrings.get('place_order_with_total', lang).replaceFirst('{total}', formatCurrency(total)) 
                         : AppStrings.get('continue', lang),
                       style: const TextStyle(fontWeight: FontWeight.bold),
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                 ),
               ],
             ),
           );
        },
        steps: [
          Step(
            title: Text(AppStrings.get('step_address', lang)),
            content: Column(
              children: [
                // Country Picker
                InkWell(
                  onTap: () {
                    showCountryPicker(
                      context: context,
                      showPhoneCode: false,
                      countryListTheme: const CountryListThemeData(
                        textStyle: TextStyle(fontSize: 16),
                      ),
                       onSelect: (Country country) {
                        setState(() {
                          _selectedCountry = country.countryCode.toLowerCase();
                          _selectedCountryName = country.name;
                          _selectedPhoneCode = country.phoneCode;
                          _isPredefinedCountry = _countryData.containsKey(_selectedCountry);
                          _governorateController.clear();
                        });
                      },
                    );
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: AppStrings.get('country', lang),
                      prefixIcon: const Icon(Icons.public),
                      border: const OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_selectedCountryName),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Dynamic City/Governorate Field
                if (_isPredefinedCountry)
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: AppStrings.get('governorate', lang),
                      prefixIcon: const Icon(Icons.map_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    initialValue: _governorateController.text.isEmpty ? null : _governorateController.text,
                    items: (_countryData[_selectedCountry] ?? []).map((g) {
                      final key = 'gov_${g.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_')}';
                      return DropdownMenuItem(
                        value: g,
                        child: Text(AppStrings.get(key, lang)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _governorateController.text = v ?? '';
                      });
                    },
                  )
                else
                  TextField(
                    controller: _governorateController,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('governorate', lang),
                      prefixIcon: const Icon(Icons.map_outlined),
                      border: const OutlineInputBorder(),
                      hintText: AppStrings.get('city_region_hint', lang),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(labelText: AppStrings.get('location_details', lang), hintText: AppStrings.get('location_hint', lang), prefixIcon: const Icon(Icons.location_on), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _landmarkController,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('landmark', lang),
                    prefixIcon: const Icon(Icons.flag_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(AppStrings.get('estimated_delivery', lang), style: const TextStyle(color: Colors.green)),
              ],
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: Text(AppStrings.get('step_payment', lang)),
            content: Column(
              children: [
                RadioListTile(
                  title: Text(AppStrings.get('direct_payment', lang)),
                  value: 'Direct Payment',
                  groupValue: _selectedPayment,
                  onChanged: (v) => setState(() => _selectedPayment = v!),
                  secondary: const Icon(Icons.money_off),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(AppStrings.get('only_direct_payment', lang), style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                ),
              ],
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: Text(AppStrings.get('step_discount', lang)),
            content: Column(
              children: [
                // Show user's points balance
                Consumer(
                  builder: (context, ref, _) {
                    final asyncUser = ref.watch(userProvider);
                    return asyncUser.maybeWhen(
                      data: (user) => user != null
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(AppStrings.get('my_points', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${user.loyaltyPoints}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    );
                  },
                ),
                TextField(
                  controller: _discountCodeController,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('coupon_code', lang),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () async {
                        final code = _discountCodeController.text.trim();
                        if (code.isEmpty) return;

                        // Get Tenant ID (assuming mock 'main_store' or from provider)
                        final tenant = ref.read(tenantProvider).value;
                        final tenantId = tenant?.id ?? 'main_store'; // Fallback

                        try {
                          final coupon = await ref.read(firestoreServiceProvider).verifyCoupon(tenantId, code);
                          if (coupon != null && coupon.isActive) {
                             if (coupon.usageCount >= coupon.maxUsage) {
                               if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ ${AppStrings.get('coupon_limit_reached', lang)}')));
                               return;
                             }
                             
                             setState(() {
                               _appliedCouponId = coupon.id;
                               if (coupon.type == DiscountType.percentage) {
                                 _discountAmount = subtotal * (coupon.value / 100);
                               } else {
                                 _discountAmount = coupon.value;
                               }
                             });
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${AppStrings.get('coupon_applied', lang)}: ${coupon.code}')));
                             }
                          } else {
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ ${AppStrings.get('invalid_coupon', lang)}')));
                             }
                          }
                        } catch (e) {
                          if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.get('error_prefix', lang)} $e')));
                          }
                        }
                      },
                    ),
                  ),
                ),
                if (_discountAmount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '✅ ${AppStrings.get('discount', lang)} ${AppStrings.get('apply_coupon', lang)}: -${formatCurrency(_discountAmount)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                asyncTenant.maybeWhen(
                  data: (t) => Text(
                    AppStrings.get('point_currency_ratio', lang).replaceFirst('{ratio}', (t?.pointsToCurrencyRatio ?? 100).toString()), 
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: asyncUser.maybeWhen(
                        data: (u) {
                          final userPoints = u?.loyaltyPoints ?? 0;
                          return TextField(
                            decoration: InputDecoration(
                              labelText: AppStrings.get('points_redeem', lang),
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final points = int.tryParse(v) ?? 0;
                              final maxPointsByCost = ((subtotal + shipping) / pointsToCurrency).floor();
                              final maxRedeemable = userPoints < maxPointsByCost ? userPoints : maxPointsByCost;
                              
                              setState(() => _pointsToRedeem = points.clamp(0, maxRedeemable));
                            },
                          );
                        },
                        orElse: () => const CircularProgressIndicator(),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                if (_pointsToRedeem > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${AppStrings.get('step_discount', lang)}: ${formatCurrency(pointsDiscount)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: Text(AppStrings.get('step_confirm', lang)),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.get('items_count', lang).replaceAll('{count}', cartItems.length.toString()), style: const TextStyle(fontWeight: FontWeight.bold)),
                ...cartItems.map((e) => Text('- ${e['name']} x${e['quantity'] ?? 1} (${formatCurrency(e['price'])})')),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppStrings.get('subtotal_label', lang)), Text(formatCurrency(subtotal))]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppStrings.get('shipping_label', lang)), Text(formatCurrency(shipping))]),
                if (_pointsToRedeem > 0)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(AppStrings.get('loyalty_points_discount', lang).replaceAll('{points}', _pointsToRedeem.toString())),
                    Text('-${formatCurrency(pointsDiscount)}', style: const TextStyle(color: Colors.green)),
                  ]),
                if (_discountAmount > 0)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(AppStrings.get('discount_code_label', lang)),
                    Text('-${formatCurrency(_discountAmount)}', style: const TextStyle(color: Colors.green)),
                  ]),
                
                // First Order Discount Display
                Builder(builder: (context) {
                  double fod = 0;
                  if (asyncTenant.hasValue && asyncTenant.value != null && asyncUser.hasValue && asyncUser.value != null) {
                    final t = asyncTenant.value!;
                    final u = asyncUser.value!;
                    if (t.firstOrderDiscountEnabled && u.purchaseCount == 0) {
                      if (t.firstOrderDiscountAmount > 0) {
                        fod = t.firstOrderDiscountAmount;
                      } else {
                        fod = subtotal * t.firstOrderDiscountPercent;
                      }
                    }
                  }
                  if (fod > 0) {
                    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(AppStrings.get('first_order_discount', lang)),
                      Text('-${formatCurrency(fod)}', style: const TextStyle(color: Colors.green)),
                    ]);
                  }
                  return const SizedBox.shrink();
                }),

                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppStrings.get('total_label', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(formatCurrency(total.toDouble()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('${AppStrings.get('payment_label', lang)} ${AppStrings.get(_selectedPayment == 'Direct Payment' ? 'direct_payment' : 'payment_method', lang)}'),
                Text('${AppStrings.get('phone_label', lang)} ${_phoneController.text.isEmpty ? AppStrings.get('not_provided', lang) : _phoneController.text}'),
                Text('${AppStrings.get('address_label', lang)} $_address'),
                if (_landmarkController.text.isNotEmpty)
                  Text('${AppStrings.get('landmark', lang)}: ${_landmarkController.text}'),
              ],
            ),
            isActive: _currentStep >= 3,
          ),
        ],
      ),
    );
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
      
      if (_pointsToRedeem > 0) {
        await ref.read(userActionsProvider).deductPoints(userPhone, _pointsToRedeem);
      }
      
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
        orderId: editingOrderId,
        landmark: _landmarkController.text.trim(),
      );

      // --- Stock deduction is now handled entirely inside OrderActions.placeOrder ---
      
      // Reset editing state
      ref.read(editingOrderIdProvider.notifier).set(null);
      
      // 6. Award Loyalty Points as PENDING (will be confirmed when order completes)
      await ref.read(userActionsProvider).addPendingPoints(userPhone, pointsToAward);
      
      // 7. Increment Coupon Usage if applied
      if (_appliedCouponId != null) {
        final tId = ref.read(tenantProvider).value?.id ?? 'main_store';
        await ref.read(firestoreServiceProvider).incrementCouponUsage(tId, _appliedCouponId!);
      }

      // Save address, phone and landmark for next time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_address', _address);
      await prefs.setString('user_phone', purePhone);
      await prefs.setString('user_landmark', _landmarkController.text.trim());
      await prefs.setString('last_payment_method', _selectedPayment);

      // Update user profile in Firestore
      if (user != null) {
        await ref.read(userActionsProvider).updateUserProfile(
          address: _address,
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

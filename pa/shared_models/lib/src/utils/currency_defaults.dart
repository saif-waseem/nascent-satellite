/// Default country-to-currency mappings and supported currencies across Admin, Cashier, and Store.
class CurrencyDefaults {
  static const List<({String code, String nameAr, String currency})> countries = [
    (code: 'iq', nameAr: 'العراق', currency: 'د.ع'),
    (code: 'sa', nameAr: 'السعودية', currency: 'ر.س'),
    (code: 'ae', nameAr: 'الإمارات', currency: 'د.إ'),
    (code: 'kw', nameAr: 'الكويت', currency: 'د.ك'),
    (code: 'qa', nameAr: 'قطر', currency: 'ر.ق'),
    (code: 'om', nameAr: 'عمان', currency: 'ر.ع'),
    (code: 'bh', nameAr: 'البحرين', currency: 'د.ب'),
    (code: 'jo', nameAr: 'الأردن', currency: 'د.أ'),
    (code: 'eg', nameAr: 'مصر', currency: 'ج.م'),
    (code: 'tr', nameAr: 'تركيا', currency: 'TL'),
    (code: 'us', nameAr: 'الولايات المتحدة', currency: '\$'),
    (code: 'gb', nameAr: 'المملكة المتحدة', currency: '£'),
    (code: 'eu', nameAr: 'الاتحاد الأوروبي', currency: '€'),
  ];

  static const List<({String code, String label})> currencies = [
    (code: 'د.ع', label: 'د.ع - دينار عراقي'),
    (code: '\$', label: '\$ - دولار أمريكي'),
    (code: 'ر.س', label: 'ر.س - ريال سعودي'),
    (code: 'د.إ', label: 'د.إ - درهم إماراتي'),
    (code: 'د.ك', label: 'د.ك - دينار كويتي'),
    (code: 'ج.م', label: 'ج.م - جنيه مصري'),
    (code: '€', label: '€ - يورو أوروبي'),
    (code: '£', label: '£ - جنيه إسترليني'),
    (code: 'TL', label: 'TL - ليرة تركية'),
    (code: 'ر.ق', label: 'ر.ق - ريال قطري'),
    (code: 'ر.ع', label: 'ر.ع - ريال عماني'),
    (code: 'د.ب', label: 'د.ب - دينار بحريني'),
    (code: 'د.أ', label: 'د.أ - دينار أردني'),
  ];

  static String normalizeCurrency(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'د.ع';
    switch (raw.trim().toUpperCase()) {
      case 'IQD':
        return 'د.ع';
      case 'USD':
        return '\$';
      case 'SAR':
        return 'ر.س';
      case 'AED':
        return 'د.إ';
      case 'KWD':
        return 'د.ك';
      case 'EGP':
        return 'ج.م';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'TRY':
      case 'TL':
        return 'TL';
      case 'QAR':
        return 'ر.ق';
      case 'OMR':
        return 'ر.ع';
      case 'BHD':
        return 'د.ب';
      case 'JOD':
        return 'د.أ';
      default:
        final trimmed = raw.trim();
        return currencies.any((c) => c.code == trimmed) ? trimmed : trimmed;
    }
  }

  static String forCountry(String? countryCode) {
    if (countryCode == null || countryCode.trim().isEmpty) return 'د.ع';
    final normalized = countryCode.trim().toLowerCase();
    for (final c in countries) {
      if (c.code == normalized) return c.currency;
    }
    return 'د.ع';
  }

  static String countryNameAr(String? countryCode) {
    if (countryCode == null || countryCode.trim().isEmpty) return 'العراق';
    final normalized = countryCode.trim().toLowerCase();
    for (final c in countries) {
      if (c.code == normalized) return c.nameAr;
    }
    return countryCode;
  }
}

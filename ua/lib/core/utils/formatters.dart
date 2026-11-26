import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

/// Format a number with thousand separators (e.g., 5000 → "5,000")
String formatNumber(num number) {
  final formatter = NumberFormat('#,##0', 'en_US');
  return formatter.format(number);
}

/// Format currency in normalized store/warehouse unit
String formatCurrency(num amount, {String lang = 'en', String? unitOverride}) {
  final unit = (unitOverride != null && unitOverride.trim().isNotEmpty)
      ? CurrencyDefaults.normalizeCurrency(unitOverride)
      : (lang == 'ar' ? 'د.ع' : 'IQD');
  if (amount % 1 == 0) {
    return '${formatNumber(amount.toInt())} $unit';
  }
  return '${formatNumber(amount)} $unit';
}

/// Format currency without the IQD suffix (for compact display)
String formatCurrencyCompact(num amount) {
  return formatNumber(amount);
}

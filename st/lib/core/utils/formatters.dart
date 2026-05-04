import 'package:intl/intl.dart';

String formatNumber(num number) {
  final formatter = NumberFormat('#,##0', 'en_US');
  return formatter.format(number);
}

String formatCurrency(num amount, {String lang = 'en'}) {
  final unit = lang == 'ar' ? 'د.ع' : 'IQD';
  if (amount % 1 == 0) {
    return '${formatNumber(amount.toInt())} $unit';
  }
  return '${formatNumber(amount)} $unit';
}

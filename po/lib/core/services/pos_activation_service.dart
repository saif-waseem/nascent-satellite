import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../providers/tenant_provider.dart';
import 'firestore_rest_service.dart';
import 'local_db_service.dart';

String normalizePosCode(String input) => input
    .trim()
    .replaceAll(RegExp('[\u200e\u200f\u061c\u200b\ufeff]'), '')
    .replaceAll(RegExp('[‐‑–—]'), '-')
    .replaceAllMapped(
      RegExp('[٠-٩۰-۹]'),
      (m) =>
          (m[0]!.codeUnitAt(0) - (m[0]!.codeUnitAt(0) >= 0x6f0 ? 0x6f0 : 0x660))
              .toString(),
    )
    .toUpperCase();

Future<TenantModel> verifyPosCode(
  FirestoreRestService service,
  String input, {
  String? expectedTenant,
}) async {
  final code = normalizePosCode(input);
  if (code.isEmpty) throw const FormatException('أدخل كود الكاشير');
  var rows = await service.lookupPosCode(code);
  if (rows.isEmpty && input.trim() != code)
    rows = await service.lookupPosCode(input.trim());
  if (rows.isEmpty) {
    if (code.startsWith('ACT-')) {
      throw const FormatException('هذا رمز المتجر. انسخ «كود الكاشير» من بطاقة المتجر في السوبر أدمن.');
    }
    throw const FormatException('كود الكاشير غير موجود. تأكّد من نجاح الإصدار وانسخ الكود مجددًا.');
  }
  if (rows.length > 1) {
    throw const FormatException('هذا الكود مرتبط بأكثر من متجر. أصدر كود كاشير جديدًا.');
  }
  final tenant = TenantModel.fromJson(rows.single);
  if (tenant.id.isEmpty ||
      normalizePosCode(tenant.posActivationCode ?? '') != code ||
      (expectedTenant != null && tenant.id != expectedTenant))
    throw const FormatException('الكود لا يخص هذا المتجر');
  if (!tenant.isActive || !tenant.isPosEnabled)
    throw const FormatException(
      'الكود موجود لكن اشتراك الكاشير غير مفعّل. جدّده من السوبر أدمن',
    );
  if (tenant.posExpiryDate?.isAfter(DateTime.now()) == false)
    throw const FormatException('انتهت مدة اشتراك الكاشير');
  return tenant;
}

Future<void> activateCashier(
  WidgetRef ref,
  String input, {
  String? expectedTenant,
}) async {
  final tenant = await verifyPosCode(
    ref.read(firestoreRestServiceProvider),
    input,
    expectedTenant: expectedTenant,
  );
  await LocalDbService.getBox<TenantModel>('tenants').put(tenant.id, tenant);
  if (!ref.context.mounted) return;
  await ref.read(tenantIdProvider.notifier).setTenantId(tenant.id);
  if (ref.context.mounted) ref.invalidate(tenantProvider);
}

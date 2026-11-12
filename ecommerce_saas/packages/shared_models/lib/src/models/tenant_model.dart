import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'tenant_model.g.dart';

@HiveType(typeId: 3)
class TenantModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final List<String> adminIds;
  @HiveField(3)
  final String? logoUrl;
  @HiveField(4)
  final String description;
  @HiveField(5)
  final String whatsappNumber;
  @HiveField(6)
  final String primaryColor;
  @HiveField(7)
  final bool isActive;
  @HiveField(8)
  final DateTime createdAt;
  @HiveField(9)
  final DateTime? expiryDate;
  @HiveField(10)
  final String? activationCode;
  @HiveField(11)
  final int subscriberCount;
  @HiveField(12)
  final String? managerName;
  @HiveField(13)
  final String? managerPhone;
  @HiveField(32)
  final bool isStoreEnabled;
  @HiveField(29)
  final bool isPosEnabled;
  @HiveField(30)
  final DateTime? posExpiryDate;
  @HiveField(31)
  final String? posActivationCode;
  @HiveField(34)
  final bool isCarsEnabled;
  @HiveField(35)
  final DateTime? carsExpiryDate;
  @HiveField(36)
  final String? carsActivationCode;
  
  // Loyalty Settings
  @HiveField(14)
  final int registrationPoints;
  @HiveField(15)
  final double purchasePointsPercent;
  @HiveField(16)
  final double pointsToCurrencyRatio;
  @HiveField(17)
  final int sharesRewardPoints;
  @HiveField(18)
  final int reviewRewardPoints;
  
  // Shipping Settings
  @HiveField(19)
  final String currencyUnit;
  @HiveField(20)
  final double shippingCost;

  // OneSignal Settings
  @HiveField(21)
  final String? oneSignalAppId;
  @HiveField(22)
  final String? oneSignalRestKey;
  @HiveField(23)
  final bool firstOrderDiscountEnabled;
  @HiveField(24)
  final double firstOrderDiscountPercent;
  @HiveField(25)
  final double firstOrderDiscountAmount;
  @HiveField(26)
  final int maxDailyReviewPoints;
  @HiveField(27)
  final int maxDailySharePoints;
  @HiveField(28)
  final int maxDailyPurchasePoints;

  // ==================== Tiers & Super Admin Controls ====================
  @HiveField(37)
  final String posTier; // 'A', 'B', 'C', 'D'
  @HiveField(38)
  final int posDeviceLimit; // 1 (Tier A), 5 (Tier B), 10 (Tier C), -1 (Unlimited Tier D)
  @HiveField(39)
  final bool isTrialActive; // هل المتجر حالياً في فترة مجانية تجريبية
  @HiveField(40)
  final DateTime? trialStartDate;
  @HiveField(41)
  final DateTime? trialEndDate;
  @HiveField(42)
  final int posGraceDays; // أيام السماح بعد انتهاء الاشتراك (افتراضياً 14)
  @HiveField(43)
  final bool posLanSyncEnabled; // مزامنة الشبكة المحلية بدون إنترنت
  @HiveField(44)
  final bool posCloudBackupEnabled; // النسخ الاحتياطي السحابي
  @HiveField(45)
  final bool posRemoteDashEnabled; // لوحة المراقبة عن بعد
  @HiveField(46)
  final bool posExcelEnabled; // استيراد وتصدير إكسل
  @HiveField(47)
  final bool posMultiBranchEnabled; // الفروع المتعددة
  @HiveField(48)
  final bool posVideoGenEnabled; // توليد فيديوهات المنتجات بالذكاء الاصطناعي
  @HiveField(49)
  final int posDailyVideoQuota; // عدد الفيديوهات المسموحة يومياً

  const TenantModel({
    required this.id,
    required this.name,
    required this.adminIds,
    this.logoUrl,
    this.description = '',
    this.whatsappNumber = '',
    this.primaryColor = '#000000',
    this.isActive = false,
    required this.createdAt,
    this.expiryDate,
    this.activationCode,
    this.subscriberCount = 0,
    this.managerName,
    this.managerPhone,
    this.registrationPoints = 50,
    this.purchasePointsPercent = 0.05,
    this.pointsToCurrencyRatio = 1.0,
    this.sharesRewardPoints = 10,
    this.reviewRewardPoints = 5,
    this.currencyUnit = 'IQD',
    this.shippingCost = 5000.0,
    this.oneSignalAppId,
    this.oneSignalRestKey,
    this.firstOrderDiscountEnabled = false,
    this.firstOrderDiscountPercent = 0.1,
    this.firstOrderDiscountAmount = 0.0,
    this.maxDailyReviewPoints = 50,
    this.maxDailySharePoints = 50,
    this.maxDailyPurchasePoints = 1000,
    this.isStoreEnabled = false,
    this.isPosEnabled = false,
    this.posExpiryDate,
    this.posActivationCode,
    this.isCarsEnabled = false,
    this.carsExpiryDate,
    this.carsActivationCode,
    // Tiers defaults
    this.posTier = 'A',
    this.posDeviceLimit = 1,
    this.isTrialActive = false,
    this.trialStartDate,
    this.trialEndDate,
    this.posGraceDays = 14,
    this.posLanSyncEnabled = false,
    this.posCloudBackupEnabled = false,
    this.posRemoteDashEnabled = false,
    this.posExcelEnabled = false,
    this.posMultiBranchEnabled = false,
    this.posVideoGenEnabled = false,
    this.posDailyVideoQuota = 0,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        adminIds,
        logoUrl,
        description,
        whatsappNumber,
        primaryColor,
        isActive,
        createdAt,
        expiryDate,
        activationCode,
        subscriberCount,
        managerName,
        managerPhone,
        registrationPoints,
        purchasePointsPercent,
        pointsToCurrencyRatio,
        sharesRewardPoints,
        reviewRewardPoints,
        currencyUnit,
        shippingCost,
        oneSignalAppId,
        oneSignalRestKey,
        firstOrderDiscountEnabled,
        firstOrderDiscountPercent,
        firstOrderDiscountAmount,
        maxDailyReviewPoints,
        maxDailySharePoints,
        maxDailyPurchasePoints,
        isStoreEnabled,
        isPosEnabled,
        posExpiryDate,
        posActivationCode,
        isCarsEnabled,
        carsExpiryDate,
        carsActivationCode,
        posTier,
        posDeviceLimit,
        isTrialActive,
        trialStartDate,
        trialEndDate,
        posGraceDays,
        posLanSyncEnabled,
        posCloudBackupEnabled,
        posRemoteDashEnabled,
        posExcelEnabled,
        posMultiBranchEnabled,
        posVideoGenEnabled,
        posDailyVideoQuota,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'adminIds': adminIds,
      'logoUrl': logoUrl,
      'description': description,
      'whatsappNumber': whatsappNumber,
      'primaryColor': primaryColor,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'activationCode': activationCode,
      'subscriberCount': subscriberCount,
      'managerName': managerName,
      'managerPhone': managerPhone,
      'registrationPoints': registrationPoints,
      'purchasePointsPercent': purchasePointsPercent,
      'pointsToCurrencyRatio': pointsToCurrencyRatio,
      'sharesRewardPoints': sharesRewardPoints,
      'reviewRewardPoints': reviewRewardPoints,
      'currencyUnit': currencyUnit,
      'shippingCost': shippingCost,
      'oneSignalAppId': oneSignalAppId,
      'oneSignalRestKey': oneSignalRestKey,
      'firstOrderDiscountEnabled': firstOrderDiscountEnabled,
      'firstOrderDiscountPercent': firstOrderDiscountPercent,
      'firstOrderDiscountAmount': firstOrderDiscountAmount,
      'maxDailyReviewPoints': maxDailyReviewPoints,
      'maxDailySharePoints': maxDailySharePoints,
      'maxDailyPurchasePoints': maxDailyPurchasePoints,
      'isStoreEnabled': isStoreEnabled,
      'isPosEnabled': isPosEnabled,
      'posExpiryDate': posExpiryDate?.toIso8601String(),
      'posActivationCode': posActivationCode,
      'isCarsEnabled': isCarsEnabled,
      'carsExpiryDate': carsExpiryDate?.toIso8601String(),
      'carsActivationCode': carsActivationCode,
      // Tiers fields in JSON
      'posTier': posTier,
      'posDeviceLimit': posDeviceLimit,
      'isTrialActive': isTrialActive,
      'trialStartDate': trialStartDate?.toIso8601String(),
      'trialEndDate': trialEndDate?.toIso8601String(),
      'posGraceDays': posGraceDays,
      'posLanSyncEnabled': posLanSyncEnabled,
      'posCloudBackupEnabled': posCloudBackupEnabled,
      'posRemoteDashEnabled': posRemoteDashEnabled,
      'posExcelEnabled': posExcelEnabled,
      'posMultiBranchEnabled': posMultiBranchEnabled,
      'posVideoGenEnabled': posVideoGenEnabled,
      'posDailyVideoQuota': posDailyVideoQuota,
    };
  }

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return TenantModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      adminIds: (json['adminIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      logoUrl: json['logoUrl'] as String?,
      description: json['description'] as String? ?? '',
      whatsappNumber: json['whatsappNumber'] as String? ?? '',
      primaryColor: json['primaryColor'] as String? ?? '#000000',
      isActive: json['isActive'] as bool? ?? false,
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      expiryDate: parseDate(json['expiryDate']),
      activationCode: json['activationCode'] as String?,
      subscriberCount: json['subscriberCount'] as int? ?? 0,
      managerName: json['managerName'] as String?,
      managerPhone: json['managerPhone'] as String?,
      registrationPoints: json['registrationPoints'] as int? ?? 50,
      purchasePointsPercent: (json['purchasePointsPercent'] as num? ?? 0.05).toDouble(),
      pointsToCurrencyRatio: (json['pointsToCurrencyRatio'] as num? ?? 1.0).toDouble(),
      sharesRewardPoints: json['sharesRewardPoints'] as int? ?? 10,
      reviewRewardPoints: json['reviewRewardPoints'] as int? ?? 5,
      currencyUnit: json['currencyUnit'] as String? ?? 'IQD',
      shippingCost: (json['shippingCost'] as num? ?? 5000.0).toDouble(),
      oneSignalAppId: json['oneSignalAppId'] as String?,
      oneSignalRestKey: json['oneSignalRestKey'] as String?,
      firstOrderDiscountEnabled: json['firstOrderDiscountEnabled'] as bool? ?? false,
      firstOrderDiscountPercent: (json['firstOrderDiscountPercent'] as num? ?? 0.1).toDouble(),
      firstOrderDiscountAmount: (json['firstOrderDiscountAmount'] as num? ?? 0.0).toDouble(),
      maxDailyReviewPoints: json['maxDailyReviewPoints'] as int? ?? 50,
      maxDailySharePoints: json['maxDailySharePoints'] as int? ?? 50,
      maxDailyPurchasePoints: json['maxDailyPurchasePoints'] as int? ?? 1000,
      isStoreEnabled: json['isStoreEnabled'] as bool? ?? json['isActive'] as bool? ?? false,
      isPosEnabled: json['isPosEnabled'] as bool? ?? false,
      posExpiryDate: parseDate(json['posExpiryDate']),
      posActivationCode: json['posActivationCode'] as String?,
      isCarsEnabled: json['isCarsEnabled'] as bool? ?? false,
      carsExpiryDate: parseDate(json['carsExpiryDate']),
      carsActivationCode: json['carsActivationCode'] as String?,
      // Tiers fields parsing
      posTier: json['posTier'] as String? ?? 'A',
      posDeviceLimit: json['posDeviceLimit'] as int? ?? 1,
      isTrialActive: json['isTrialActive'] as bool? ?? false,
      trialStartDate: parseDate(json['trialStartDate']),
      trialEndDate: parseDate(json['trialEndDate']),
      posGraceDays: json['posGraceDays'] as int? ?? 14,
      posLanSyncEnabled: json['posLanSyncEnabled'] as bool? ?? false,
      posCloudBackupEnabled: json['posCloudBackupEnabled'] as bool? ?? false,
      posRemoteDashEnabled: json['posRemoteDashEnabled'] as bool? ?? false,
      posExcelEnabled: json['posExcelEnabled'] as bool? ?? false,
      posMultiBranchEnabled: json['posMultiBranchEnabled'] as bool? ?? false,
      posVideoGenEnabled: json['posVideoGenEnabled'] as bool? ?? false,
      posDailyVideoQuota: json['posDailyVideoQuota'] as int? ?? 0,
    );
  }

  TenantModel copyWith({
    String? id,
    String? name,
    List<String>? adminIds,
    String? logoUrl,
    String? description,
    String? whatsappNumber,
    String? primaryColor,
    bool? isActive,
    DateTime? createdAt,
    DateTime? expiryDate,
    String? activationCode,
    int? subscriberCount,
    String? managerName,
    String? managerPhone,
    int? registrationPoints,
    double? purchasePointsPercent,
    double? pointsToCurrencyRatio,
    int? sharesRewardPoints,
    int? reviewRewardPoints,
    String? currencyUnit,
    double? shippingCost,
    String? oneSignalAppId,
    String? oneSignalRestKey,
    bool? firstOrderDiscountEnabled,
    double? firstOrderDiscountPercent,
    double? firstOrderDiscountAmount,
    int? maxDailyReviewPoints,
    int? maxDailySharePoints,
    int? maxDailyPurchasePoints,
    bool? isStoreEnabled,
    bool? isPosEnabled,
    DateTime? posExpiryDate,
    String? posActivationCode,
    bool? isCarsEnabled,
    DateTime? carsExpiryDate,
    String? carsActivationCode,
    // Tiers copyWith
    String? posTier,
    int? posDeviceLimit,
    bool? isTrialActive,
    DateTime? trialStartDate,
    DateTime? trialEndDate,
    int? posGraceDays,
    bool? posLanSyncEnabled,
    bool? posCloudBackupEnabled,
    bool? posRemoteDashEnabled,
    bool? posExcelEnabled,
    bool? posMultiBranchEnabled,
    bool? posVideoGenEnabled,
    int? posDailyVideoQuota,
  }) {
    return TenantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      adminIds: adminIds ?? this.adminIds,
      logoUrl: logoUrl ?? this.logoUrl,
      description: description ?? this.description,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      primaryColor: primaryColor ?? this.primaryColor,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      expiryDate: expiryDate ?? this.expiryDate,
      activationCode: activationCode ?? this.activationCode,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      managerName: managerName ?? this.managerName,
      managerPhone: managerPhone ?? this.managerPhone,
      registrationPoints: registrationPoints ?? this.registrationPoints,
      purchasePointsPercent: purchasePointsPercent ?? this.purchasePointsPercent,
      pointsToCurrencyRatio: pointsToCurrencyRatio ?? this.pointsToCurrencyRatio,
      sharesRewardPoints: sharesRewardPoints ?? this.sharesRewardPoints,
      reviewRewardPoints: reviewRewardPoints ?? this.reviewRewardPoints,
      currencyUnit: currencyUnit ?? this.currencyUnit,
      shippingCost: shippingCost ?? this.shippingCost,
      oneSignalAppId: oneSignalAppId ?? this.oneSignalAppId,
      oneSignalRestKey: oneSignalRestKey ?? this.oneSignalRestKey,
      firstOrderDiscountEnabled: firstOrderDiscountEnabled ?? this.firstOrderDiscountEnabled,
      firstOrderDiscountPercent: firstOrderDiscountPercent ?? this.firstOrderDiscountPercent,
      firstOrderDiscountAmount: firstOrderDiscountAmount ?? this.firstOrderDiscountAmount,
      maxDailyReviewPoints: maxDailyReviewPoints ?? this.maxDailyReviewPoints,
      maxDailySharePoints: maxDailySharePoints ?? this.maxDailySharePoints,
      maxDailyPurchasePoints: maxDailyPurchasePoints ?? this.maxDailyPurchasePoints,
      isStoreEnabled: isStoreEnabled ?? this.isStoreEnabled,
      isPosEnabled: isPosEnabled ?? this.isPosEnabled,
      posExpiryDate: posExpiryDate ?? this.posExpiryDate,
      posActivationCode: posActivationCode ?? this.posActivationCode,
      isCarsEnabled: isCarsEnabled ?? this.isCarsEnabled,
      carsExpiryDate: carsExpiryDate ?? this.carsExpiryDate,
      carsActivationCode: carsActivationCode ?? this.carsActivationCode,
      posTier: posTier ?? this.posTier,
      posDeviceLimit: posDeviceLimit ?? this.posDeviceLimit,
      isTrialActive: isTrialActive ?? this.isTrialActive,
      trialStartDate: trialStartDate ?? this.trialStartDate,
      trialEndDate: trialEndDate ?? this.trialEndDate,
      posGraceDays: posGraceDays ?? this.posGraceDays,
      posLanSyncEnabled: posLanSyncEnabled ?? this.posLanSyncEnabled,
      posCloudBackupEnabled: posCloudBackupEnabled ?? this.posCloudBackupEnabled,
      posRemoteDashEnabled: posRemoteDashEnabled ?? this.posRemoteDashEnabled,
      posExcelEnabled: posExcelEnabled ?? this.posExcelEnabled,
      posMultiBranchEnabled: posMultiBranchEnabled ?? this.posMultiBranchEnabled,
      posVideoGenEnabled: posVideoGenEnabled ?? this.posVideoGenEnabled,
      posDailyVideoQuota: posDailyVideoQuota ?? this.posDailyVideoQuota,
    );
  }
}

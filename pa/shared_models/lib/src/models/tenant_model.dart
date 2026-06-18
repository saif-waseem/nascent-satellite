import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'tenant_model.g.dart';

@HiveType(typeId: 3)
class TenantModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final List<String> adminIds; // Changed from ownerId
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
  final DateTime? expiryDate; // [NEW]
  @HiveField(10)
  final String? activationCode; // [NEW]
  @HiveField(11)
  final int subscriberCount; // [NEW]
  @HiveField(12)
  final String? managerName; // [NEW]
  @HiveField(13)
  final String? managerPhone; // [NEW]
  @HiveField(32)
  final bool isStoreEnabled; // [NEW]
  @HiveField(29)
  final bool isPosEnabled; // [NEW]
  @HiveField(30)
  final DateTime? posExpiryDate; // [NEW]
  @HiveField(31)
  final String? posActivationCode; // [NEW]
  @HiveField(34)
  final bool isCarsEnabled; // [NEW]
  @HiveField(35)
  final DateTime? carsExpiryDate; // [NEW]
  @HiveField(36)
  final String? carsActivationCode; // [NEW]
  @HiveField(33)
  final String appType; // [NEW] 'retail', 'restaurant', 'cars', etc.
  
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
    this.appType = 'retail',
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
        appType,
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
      'appType': appType,
    };
  }

  static DateTime _parseDate(dynamic val) {
    if (val is DateTime) return val;
    if (val is String) return DateTime.parse(val);
    // Removed Timestamp check to eliminate cloud_firestore dependency
    return DateTime.now();
  }

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Store',
      adminIds: (json['adminIds'] as List?)?.cast<String>() ?? [json['ownerId'] as String? ?? ''],
      logoUrl: json['logoUrl'] as String?,
      description: json['description'] as String? ?? '',
      whatsappNumber: json['whatsappNumber'] as String? ?? '',
      primaryColor: json['primaryColor'] as String? ?? '#000000',
      isActive: json['isActive'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']),
      expiryDate: json['expiryDate'] != null ? _parseDate(json['expiryDate']) : null,
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
      posExpiryDate: json['posExpiryDate'] != null ? _parseDate(json['posExpiryDate']) : null,
      posActivationCode: json['posActivationCode'] as String?,
      isCarsEnabled: json['isCarsEnabled'] as bool? ?? false,
      carsExpiryDate: json['carsExpiryDate'] != null ? _parseDate(json['carsExpiryDate']) : null,
      carsActivationCode: json['carsActivationCode'] as String?,
      appType: json['appType'] as String? ?? 'retail',
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
    String? appType,
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
      appType: appType ?? this.appType,
    );
  }
}

class LoyaltySettingsModel {
  final int pointsPerUnit;
  final int registrationBonus;
  final double minimumPurchaseAmount;

  const LoyaltySettingsModel({
    this.pointsPerUnit = 1,
    this.registrationBonus = 50,
    this.minimumPurchaseAmount = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'pointsPerUnit': pointsPerUnit,
      'registrationBonus': registrationBonus,
      'minimumPurchaseAmount': minimumPurchaseAmount,
    };
  }

  factory LoyaltySettingsModel.fromJson(Map<String, dynamic> json) {
    return LoyaltySettingsModel(
      pointsPerUnit: json['pointsPerUnit'] ?? 1,
      registrationBonus: json['registrationBonus'] ?? 50,
      minimumPurchaseAmount: (json['minimumPurchaseAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  LoyaltySettingsModel copyWith({
    int? pointsPerUnit,
    int? registrationBonus,
    double? minimumPurchaseAmount,
  }) {
    return LoyaltySettingsModel(
      pointsPerUnit: pointsPerUnit ?? this.pointsPerUnit,
      registrationBonus: registrationBonus ?? this.registrationBonus,
      minimumPurchaseAmount: minimumPurchaseAmount ?? this.minimumPurchaseAmount,
    );
  }
}

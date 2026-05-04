import 'package:freezed_annotation/freezed_annotation.dart';

part 'promo_banner_model.freezed.dart';
part 'promo_banner_model.g.dart';

@freezed
class PromoBannerModel with _$PromoBannerModel {
  factory PromoBannerModel({
    required String id,
    required String imageUrl,
    required String title,
    String? linkToCategoryId,
    String? linkToProductId,
    @Default(true) bool isActive,
    DateTime? expiryDate,
    @Default(0) int priority, // Higher priority shows first
  }) = _PromoBannerModel;

  factory PromoBannerModel.fromJson(Map<String, dynamic> json) => _$PromoBannerModelFromJson(json);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promo_banner_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PromoBannerModelImpl _$$PromoBannerModelImplFromJson(
        Map<String, dynamic> json) =>
    _$PromoBannerModelImpl(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String,
      title: json['title'] as String,
      linkToCategoryId: json['linkToCategoryId'] as String?,
      linkToProductId: json['linkToProductId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.parse(json['expiryDate'] as String),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$PromoBannerModelImplToJson(
        _$PromoBannerModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'imageUrl': instance.imageUrl,
      'title': instance.title,
      'linkToCategoryId': instance.linkToCategoryId,
      'linkToProductId': instance.linkToProductId,
      'isActive': instance.isActive,
      'expiryDate': instance.expiryDate?.toIso8601String(),
      'priority': instance.priority,
    };

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'promo_banner_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PromoBannerModel _$PromoBannerModelFromJson(Map<String, dynamic> json) {
  return _PromoBannerModel.fromJson(json);
}

/// @nodoc
mixin _$PromoBannerModel {
  String get id => throw _privateConstructorUsedError;
  String get imageUrl => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get linkToCategoryId => throw _privateConstructorUsedError;
  String? get linkToProductId => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  DateTime? get expiryDate => throw _privateConstructorUsedError;
  int get priority => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PromoBannerModelCopyWith<PromoBannerModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PromoBannerModelCopyWith<$Res> {
  factory $PromoBannerModelCopyWith(
          PromoBannerModel value, $Res Function(PromoBannerModel) then) =
      _$PromoBannerModelCopyWithImpl<$Res, PromoBannerModel>;
  @useResult
  $Res call(
      {String id,
      String imageUrl,
      String title,
      String? linkToCategoryId,
      String? linkToProductId,
      bool isActive,
      DateTime? expiryDate,
      int priority});
}

/// @nodoc
class _$PromoBannerModelCopyWithImpl<$Res, $Val extends PromoBannerModel>
    implements $PromoBannerModelCopyWith<$Res> {
  _$PromoBannerModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? imageUrl = null,
    Object? title = null,
    Object? linkToCategoryId = freezed,
    Object? linkToProductId = freezed,
    Object? isActive = null,
    Object? expiryDate = freezed,
    Object? priority = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: null == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      linkToCategoryId: freezed == linkToCategoryId
          ? _value.linkToCategoryId
          : linkToCategoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      linkToProductId: freezed == linkToProductId
          ? _value.linkToProductId
          : linkToProductId // ignore: cast_nullable_to_non_nullable
              as String?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      expiryDate: freezed == expiryDate
          ? _value.expiryDate
          : expiryDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PromoBannerModelImplCopyWith<$Res>
    implements $PromoBannerModelCopyWith<$Res> {
  factory _$$PromoBannerModelImplCopyWith(_$PromoBannerModelImpl value,
          $Res Function(_$PromoBannerModelImpl) then) =
      __$$PromoBannerModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String imageUrl,
      String title,
      String? linkToCategoryId,
      String? linkToProductId,
      bool isActive,
      DateTime? expiryDate,
      int priority});
}

/// @nodoc
class __$$PromoBannerModelImplCopyWithImpl<$Res>
    extends _$PromoBannerModelCopyWithImpl<$Res, _$PromoBannerModelImpl>
    implements _$$PromoBannerModelImplCopyWith<$Res> {
  __$$PromoBannerModelImplCopyWithImpl(_$PromoBannerModelImpl _value,
      $Res Function(_$PromoBannerModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? imageUrl = null,
    Object? title = null,
    Object? linkToCategoryId = freezed,
    Object? linkToProductId = freezed,
    Object? isActive = null,
    Object? expiryDate = freezed,
    Object? priority = null,
  }) {
    return _then(_$PromoBannerModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: null == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      linkToCategoryId: freezed == linkToCategoryId
          ? _value.linkToCategoryId
          : linkToCategoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      linkToProductId: freezed == linkToProductId
          ? _value.linkToProductId
          : linkToProductId // ignore: cast_nullable_to_non_nullable
              as String?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      expiryDate: freezed == expiryDate
          ? _value.expiryDate
          : expiryDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PromoBannerModelImpl implements _PromoBannerModel {
  _$PromoBannerModelImpl(
      {required this.id,
      required this.imageUrl,
      required this.title,
      this.linkToCategoryId,
      this.linkToProductId,
      this.isActive = true,
      this.expiryDate,
      this.priority = 0});

  factory _$PromoBannerModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$PromoBannerModelImplFromJson(json);

  @override
  final String id;
  @override
  final String imageUrl;
  @override
  final String title;
  @override
  final String? linkToCategoryId;
  @override
  final String? linkToProductId;
  @override
  @JsonKey()
  final bool isActive;
  @override
  final DateTime? expiryDate;
  @override
  @JsonKey()
  final int priority;

  @override
  String toString() {
    return 'PromoBannerModel(id: $id, imageUrl: $imageUrl, title: $title, linkToCategoryId: $linkToCategoryId, linkToProductId: $linkToProductId, isActive: $isActive, expiryDate: $expiryDate, priority: $priority)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PromoBannerModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.linkToCategoryId, linkToCategoryId) ||
                other.linkToCategoryId == linkToCategoryId) &&
            (identical(other.linkToProductId, linkToProductId) ||
                other.linkToProductId == linkToProductId) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.expiryDate, expiryDate) ||
                other.expiryDate == expiryDate) &&
            (identical(other.priority, priority) ||
                other.priority == priority));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, imageUrl, title,
      linkToCategoryId, linkToProductId, isActive, expiryDate, priority);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PromoBannerModelImplCopyWith<_$PromoBannerModelImpl> get copyWith =>
      __$$PromoBannerModelImplCopyWithImpl<_$PromoBannerModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PromoBannerModelImplToJson(
      this,
    );
  }
}

abstract class _PromoBannerModel implements PromoBannerModel {
  factory _PromoBannerModel(
      {required final String id,
      required final String imageUrl,
      required final String title,
      final String? linkToCategoryId,
      final String? linkToProductId,
      final bool isActive,
      final DateTime? expiryDate,
      final int priority}) = _$PromoBannerModelImpl;

  factory _PromoBannerModel.fromJson(Map<String, dynamic> json) =
      _$PromoBannerModelImpl.fromJson;

  @override
  String get id;
  @override
  String get imageUrl;
  @override
  String get title;
  @override
  String? get linkToCategoryId;
  @override
  String? get linkToProductId;
  @override
  bool get isActive;
  @override
  DateTime? get expiryDate;
  @override
  int get priority;
  @override
  @JsonKey(ignore: true)
  _$$PromoBannerModelImplCopyWith<_$PromoBannerModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

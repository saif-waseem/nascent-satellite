import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:collection/collection.dart';

part 'review_model.freezed.dart';
part 'review_model.g.dart';

@Freezed(makeCollectionsUnmodifiable: false)
class ReviewModel with _$ReviewModel {
  factory ReviewModel({
    required String id,
    required String productId,
    required String userId,
    required String userName,
    required double rating,
    required String comment,
    List<String>? imageUrls,
    required DateTime createdAt,
    @Default(false) bool isVerifiedPurchase,
  }) = _ReviewModel;

  factory ReviewModel.fromJson(Map<String, dynamic> json) => _$ReviewModelFromJson(json);
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message_model.freezed.dart';
part 'chat_message_model.g.dart';

@freezed
class ChatMessageModel with _$ChatMessageModel {
  factory ChatMessageModel({
    required String id,
    required String senderId,
    required String receiverId,
    required String text,
    String? imageUrl,
    required DateTime timestamp,
    @Default(false) bool isRead,
    @Default('text') String type, // text, image, system
  }) = _ChatMessageModel;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => _$ChatMessageModelFromJson(json);
}

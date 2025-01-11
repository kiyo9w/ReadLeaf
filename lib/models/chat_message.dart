import 'package:hive/hive.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 3)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String text;

  @HiveField(1)
  final bool isUser;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final String? avatarImagePath;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.avatarImagePath,
  });
}

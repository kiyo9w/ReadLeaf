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

  @HiveField(4)
  final String? characterName;

  @HiveField(5)
  final String? bookId;

  @HiveField(6)
  bool isSynced;

  @HiveField(7)
  DateTime? lastSyncedAt;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.avatarImagePath,
    this.characterName,
    this.bookId,
    this.isSynced = false,
    this.lastSyncedAt,
  });

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? avatarImagePath,
    String? characterName,
    String? bookId,
    bool? isSynced,
    DateTime? lastSyncedAt,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      avatarImagePath: avatarImagePath ?? this.avatarImagePath,
      characterName: characterName ?? this.characterName,
      bookId: bookId ?? this.bookId,
      isSynced: isSynced ?? this.isSynced,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

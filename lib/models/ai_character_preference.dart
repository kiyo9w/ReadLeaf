import 'package:hive/hive.dart';

part 'ai_character_preference.g.dart';

@HiveType(typeId: 6)
class AiCharacterPreference extends HiveObject {
  @HiveField(0)
  final String characterName;

  @HiveField(1)
  final DateTime lastUsed;

  AiCharacterPreference({
    required this.characterName,
    required this.lastUsed,
  });
}

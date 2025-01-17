// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_character_preference.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AiCharacterPreferenceAdapter extends TypeAdapter<AiCharacterPreference> {
  @override
  final int typeId = 6;

  @override
  AiCharacterPreference read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AiCharacterPreference(
      characterName: fields[0] as String,
      lastUsed: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AiCharacterPreference obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.characterName)
      ..writeByte(1)
      ..write(obj.lastUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiCharacterPreferenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_metadata.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookMetadataAdapter extends TypeAdapter<BookMetadata> {
  @override
  final int typeId = 0;

  @override
  BookMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookMetadata(
      filePath: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String?,
      lastOpenedPage: fields[3] as int,
      totalPages: fields[4] as int,
      highlights: (fields[5] as List).cast<TextHighlight>(),
      aiConversations: (fields[6] as List).cast<AiConversation>(),
      isStarred: fields[7] as bool,
      lastReadTime: fields[8] as DateTime,
      readingProgress: fields[9] as double,
      fileType: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BookMetadata obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.filePath)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.lastOpenedPage)
      ..writeByte(4)
      ..write(obj.totalPages)
      ..writeByte(5)
      ..write(obj.highlights)
      ..writeByte(6)
      ..write(obj.aiConversations)
      ..writeByte(7)
      ..write(obj.isStarred)
      ..writeByte(8)
      ..write(obj.lastReadTime)
      ..writeByte(9)
      ..write(obj.readingProgress)
      ..writeByte(10)
      ..write(obj.fileType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TextHighlightAdapter extends TypeAdapter<TextHighlight> {
  @override
  final int typeId = 1;

  @override
  TextHighlight read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TextHighlight(
      text: fields[0] as String,
      pageNumber: fields[1] as int,
      createdAt: fields[2] as DateTime,
      note: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TextHighlight obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.pageNumber)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextHighlightAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AiConversationAdapter extends TypeAdapter<AiConversation> {
  @override
  final int typeId = 2;

  @override
  AiConversation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AiConversation(
      selectedText: fields[0] as String,
      aiResponse: fields[1] as String,
      timestamp: fields[2] as DateTime,
      pageNumber: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AiConversation obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.selectedText)
      ..writeByte(1)
      ..write(obj.aiResponse)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.pageNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiConversationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

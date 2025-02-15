// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_library.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserLibraryImpl _$$UserLibraryImplFromJson(Map<String, dynamic> json) =>
    _$UserLibraryImpl(
      filePaths: (json['filePaths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      favorites: (json['favorites'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      lastOpenedPages: (json['lastOpenedPages'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
      bookmarks: (json['bookmarks'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
                k, (e as List<dynamic>).map((e) => e as String).toList()),
          ) ??
          const {},
      lastReadTimes: (json['lastReadTimes'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, DateTime.parse(e as String)),
          ) ??
          const {},
    );

Map<String, dynamic> _$$UserLibraryImplToJson(_$UserLibraryImpl instance) =>
    <String, dynamic>{
      'filePaths': instance.filePaths,
      'favorites': instance.favorites,
      'lastOpenedPages': instance.lastOpenedPages,
      'bookmarks': instance.bookmarks,
      'lastReadTimes': instance.lastReadTimes
          .map((k, e) => MapEntry(k, e.toIso8601String())),
    };

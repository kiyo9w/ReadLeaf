import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'user_library.freezed.dart';
part 'user_library.g.dart';

@freezed
class UserLibrary with _$UserLibrary {
  const factory UserLibrary({
    @Default([]) List<String> filePaths,
    @Default([]) List<String> favorites,
    @Default({}) Map<String, int> lastOpenedPages,
    @Default({}) Map<String, List<String>> bookmarks,
    @Default({}) Map<String, DateTime> lastReadTimes,
  }) = _UserLibrary;

  factory UserLibrary.fromJson(Map<String, dynamic> json) =>
      _$UserLibraryFromJson(json);
}

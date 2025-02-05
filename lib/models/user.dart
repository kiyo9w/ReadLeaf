import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'user_preferences.dart';
import 'user_library.dart';
import 'user_ai_settings.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String username,
    String? avatarUrl,
    @Default(UserPreferences()) UserPreferences preferences,
    @Default(UserLibrary()) UserLibrary library,
    @Default(UserAISettings()) UserAISettings aiSettings,
    @Default(false) bool isAnonymous,
    DateTime? lastSyncTime,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  factory User.anonymous() => const User(
        id: '',
        email: '',
        username: 'Anonymous User',
        isAnonymous: true,
      );
}

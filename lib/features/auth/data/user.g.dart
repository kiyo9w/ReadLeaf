// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      socialProvider: json['socialProvider'] as String?,
      preferences: json['preferences'] == null
          ? const UserPreferences()
          : UserPreferences.fromJson(
              json['preferences'] as Map<String, dynamic>),
      library: json['library'] == null
          ? const UserLibrary()
          : UserLibrary.fromJson(json['library'] as Map<String, dynamic>),
      aiSettings: json['aiSettings'] == null
          ? const UserAISettings()
          : UserAISettings.fromJson(json['aiSettings'] as Map<String, dynamic>),
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      lastSyncTime: json['lastSyncTime'] == null
          ? null
          : DateTime.parse(json['lastSyncTime'] as String),
    );

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'username': instance.username,
      'avatarUrl': instance.avatarUrl,
      'socialProvider': instance.socialProvider,
      'preferences': instance.preferences.toJson(),
      'library': instance.library.toJson(),
      'aiSettings': instance.aiSettings.toJson(),
      'isAnonymous': instance.isAnonymous,
      'lastSyncTime': instance.lastSyncTime?.toIso8601String(),
    };

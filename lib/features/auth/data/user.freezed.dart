// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

User _$UserFromJson(Map<String, dynamic> json) {
  return _User.fromJson(json);
}

/// @nodoc
mixin _$User {
  String get id => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String? get socialProvider => throw _privateConstructorUsedError;
  UserPreferences get preferences => throw _privateConstructorUsedError;
  UserLibrary get library => throw _privateConstructorUsedError;
  UserAISettings get aiSettings => throw _privateConstructorUsedError;
  bool get isAnonymous => throw _privateConstructorUsedError;
  DateTime? get lastSyncTime => throw _privateConstructorUsedError;

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserCopyWith<User> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserCopyWith<$Res> {
  factory $UserCopyWith(User value, $Res Function(User) then) =
      _$UserCopyWithImpl<$Res, User>;
  @useResult
  $Res call(
      {String id,
      String email,
      String username,
      String? avatarUrl,
      String? socialProvider,
      UserPreferences preferences,
      UserLibrary library,
      UserAISettings aiSettings,
      bool isAnonymous,
      DateTime? lastSyncTime});

  $UserPreferencesCopyWith<$Res> get preferences;
  $UserLibraryCopyWith<$Res> get library;
  $UserAISettingsCopyWith<$Res> get aiSettings;
}

/// @nodoc
class _$UserCopyWithImpl<$Res, $Val extends User>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? username = null,
    Object? avatarUrl = freezed,
    Object? socialProvider = freezed,
    Object? preferences = null,
    Object? library = null,
    Object? aiSettings = null,
    Object? isAnonymous = null,
    Object? lastSyncTime = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      socialProvider: freezed == socialProvider
          ? _value.socialProvider
          : socialProvider // ignore: cast_nullable_to_non_nullable
              as String?,
      preferences: null == preferences
          ? _value.preferences
          : preferences // ignore: cast_nullable_to_non_nullable
              as UserPreferences,
      library: null == library
          ? _value.library
          : library // ignore: cast_nullable_to_non_nullable
              as UserLibrary,
      aiSettings: null == aiSettings
          ? _value.aiSettings
          : aiSettings // ignore: cast_nullable_to_non_nullable
              as UserAISettings,
      isAnonymous: null == isAnonymous
          ? _value.isAnonymous
          : isAnonymous // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSyncTime: freezed == lastSyncTime
          ? _value.lastSyncTime
          : lastSyncTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserPreferencesCopyWith<$Res> get preferences {
    return $UserPreferencesCopyWith<$Res>(_value.preferences, (value) {
      return _then(_value.copyWith(preferences: value) as $Val);
    });
  }

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserLibraryCopyWith<$Res> get library {
    return $UserLibraryCopyWith<$Res>(_value.library, (value) {
      return _then(_value.copyWith(library: value) as $Val);
    });
  }

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserAISettingsCopyWith<$Res> get aiSettings {
    return $UserAISettingsCopyWith<$Res>(_value.aiSettings, (value) {
      return _then(_value.copyWith(aiSettings: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UserImplCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$$UserImplCopyWith(
          _$UserImpl value, $Res Function(_$UserImpl) then) =
      __$$UserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String email,
      String username,
      String? avatarUrl,
      String? socialProvider,
      UserPreferences preferences,
      UserLibrary library,
      UserAISettings aiSettings,
      bool isAnonymous,
      DateTime? lastSyncTime});

  @override
  $UserPreferencesCopyWith<$Res> get preferences;
  @override
  $UserLibraryCopyWith<$Res> get library;
  @override
  $UserAISettingsCopyWith<$Res> get aiSettings;
}

/// @nodoc
class __$$UserImplCopyWithImpl<$Res>
    extends _$UserCopyWithImpl<$Res, _$UserImpl>
    implements _$$UserImplCopyWith<$Res> {
  __$$UserImplCopyWithImpl(_$UserImpl _value, $Res Function(_$UserImpl) _then)
      : super(_value, _then);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? username = null,
    Object? avatarUrl = freezed,
    Object? socialProvider = freezed,
    Object? preferences = null,
    Object? library = null,
    Object? aiSettings = null,
    Object? isAnonymous = null,
    Object? lastSyncTime = freezed,
  }) {
    return _then(_$UserImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      socialProvider: freezed == socialProvider
          ? _value.socialProvider
          : socialProvider // ignore: cast_nullable_to_non_nullable
              as String?,
      preferences: null == preferences
          ? _value.preferences
          : preferences // ignore: cast_nullable_to_non_nullable
              as UserPreferences,
      library: null == library
          ? _value.library
          : library // ignore: cast_nullable_to_non_nullable
              as UserLibrary,
      aiSettings: null == aiSettings
          ? _value.aiSettings
          : aiSettings // ignore: cast_nullable_to_non_nullable
              as UserAISettings,
      isAnonymous: null == isAnonymous
          ? _value.isAnonymous
          : isAnonymous // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSyncTime: freezed == lastSyncTime
          ? _value.lastSyncTime
          : lastSyncTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserImpl with DiagnosticableTreeMixin implements _User {
  const _$UserImpl(
      {required this.id,
      required this.email,
      required this.username,
      this.avatarUrl,
      this.socialProvider,
      this.preferences = const UserPreferences(),
      this.library = const UserLibrary(),
      this.aiSettings = const UserAISettings(),
      this.isAnonymous = false,
      this.lastSyncTime});

  factory _$UserImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserImplFromJson(json);

  @override
  final String id;
  @override
  final String email;
  @override
  final String username;
  @override
  final String? avatarUrl;
  @override
  final String? socialProvider;
  @override
  @JsonKey()
  final UserPreferences preferences;
  @override
  @JsonKey()
  final UserLibrary library;
  @override
  @JsonKey()
  final UserAISettings aiSettings;
  @override
  @JsonKey()
  final bool isAnonymous;
  @override
  final DateTime? lastSyncTime;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'User(id: $id, email: $email, username: $username, avatarUrl: $avatarUrl, socialProvider: $socialProvider, preferences: $preferences, library: $library, aiSettings: $aiSettings, isAnonymous: $isAnonymous, lastSyncTime: $lastSyncTime)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'User'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('email', email))
      ..add(DiagnosticsProperty('username', username))
      ..add(DiagnosticsProperty('avatarUrl', avatarUrl))
      ..add(DiagnosticsProperty('socialProvider', socialProvider))
      ..add(DiagnosticsProperty('preferences', preferences))
      ..add(DiagnosticsProperty('library', library))
      ..add(DiagnosticsProperty('aiSettings', aiSettings))
      ..add(DiagnosticsProperty('isAnonymous', isAnonymous))
      ..add(DiagnosticsProperty('lastSyncTime', lastSyncTime));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.socialProvider, socialProvider) ||
                other.socialProvider == socialProvider) &&
            (identical(other.preferences, preferences) ||
                other.preferences == preferences) &&
            (identical(other.library, library) || other.library == library) &&
            (identical(other.aiSettings, aiSettings) ||
                other.aiSettings == aiSettings) &&
            (identical(other.isAnonymous, isAnonymous) ||
                other.isAnonymous == isAnonymous) &&
            (identical(other.lastSyncTime, lastSyncTime) ||
                other.lastSyncTime == lastSyncTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      email,
      username,
      avatarUrl,
      socialProvider,
      preferences,
      library,
      aiSettings,
      isAnonymous,
      lastSyncTime);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      __$$UserImplCopyWithImpl<_$UserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserImplToJson(
      this,
    );
  }
}

abstract class _User implements User {
  const factory _User(
      {required final String id,
      required final String email,
      required final String username,
      final String? avatarUrl,
      final String? socialProvider,
      final UserPreferences preferences,
      final UserLibrary library,
      final UserAISettings aiSettings,
      final bool isAnonymous,
      final DateTime? lastSyncTime}) = _$UserImpl;

  factory _User.fromJson(Map<String, dynamic> json) = _$UserImpl.fromJson;

  @override
  String get id;
  @override
  String get email;
  @override
  String get username;
  @override
  String? get avatarUrl;
  @override
  String? get socialProvider;
  @override
  UserPreferences get preferences;
  @override
  UserLibrary get library;
  @override
  UserAISettings get aiSettings;
  @override
  bool get isAnonymous;
  @override
  DateTime? get lastSyncTime;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

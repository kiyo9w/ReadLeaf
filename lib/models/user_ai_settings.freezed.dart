// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_ai_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserAISettings _$UserAISettingsFromJson(Map<String, dynamic> json) {
  return _UserAISettings.fromJson(json);
}

/// @nodoc
mixin _$UserAISettings {
  String get characterName => throw _privateConstructorUsedError;
  List<String> get customCharacters => throw _privateConstructorUsedError;
  bool get enableAutoSummary => throw _privateConstructorUsedError;
  bool get enableContextualInsights => throw _privateConstructorUsedError;
  Map<String, dynamic> get modelSpecificSettings =>
      throw _privateConstructorUsedError;

  /// Serializes this UserAISettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserAISettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserAISettingsCopyWith<UserAISettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserAISettingsCopyWith<$Res> {
  factory $UserAISettingsCopyWith(
          UserAISettings value, $Res Function(UserAISettings) then) =
      _$UserAISettingsCopyWithImpl<$Res, UserAISettings>;
  @useResult
  $Res call(
      {String characterName,
      List<String> customCharacters,
      bool enableAutoSummary,
      bool enableContextualInsights,
      Map<String, dynamic> modelSpecificSettings});
}

/// @nodoc
class _$UserAISettingsCopyWithImpl<$Res, $Val extends UserAISettings>
    implements $UserAISettingsCopyWith<$Res> {
  _$UserAISettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserAISettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? characterName = null,
    Object? customCharacters = null,
    Object? enableAutoSummary = null,
    Object? enableContextualInsights = null,
    Object? modelSpecificSettings = null,
  }) {
    return _then(_value.copyWith(
      characterName: null == characterName
          ? _value.characterName
          : characterName // ignore: cast_nullable_to_non_nullable
              as String,
      customCharacters: null == customCharacters
          ? _value.customCharacters
          : customCharacters // ignore: cast_nullable_to_non_nullable
              as List<String>,
      enableAutoSummary: null == enableAutoSummary
          ? _value.enableAutoSummary
          : enableAutoSummary // ignore: cast_nullable_to_non_nullable
              as bool,
      enableContextualInsights: null == enableContextualInsights
          ? _value.enableContextualInsights
          : enableContextualInsights // ignore: cast_nullable_to_non_nullable
              as bool,
      modelSpecificSettings: null == modelSpecificSettings
          ? _value.modelSpecificSettings
          : modelSpecificSettings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserAISettingsImplCopyWith<$Res>
    implements $UserAISettingsCopyWith<$Res> {
  factory _$$UserAISettingsImplCopyWith(_$UserAISettingsImpl value,
          $Res Function(_$UserAISettingsImpl) then) =
      __$$UserAISettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String characterName,
      List<String> customCharacters,
      bool enableAutoSummary,
      bool enableContextualInsights,
      Map<String, dynamic> modelSpecificSettings});
}

/// @nodoc
class __$$UserAISettingsImplCopyWithImpl<$Res>
    extends _$UserAISettingsCopyWithImpl<$Res, _$UserAISettingsImpl>
    implements _$$UserAISettingsImplCopyWith<$Res> {
  __$$UserAISettingsImplCopyWithImpl(
      _$UserAISettingsImpl _value, $Res Function(_$UserAISettingsImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserAISettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? characterName = null,
    Object? customCharacters = null,
    Object? enableAutoSummary = null,
    Object? enableContextualInsights = null,
    Object? modelSpecificSettings = null,
  }) {
    return _then(_$UserAISettingsImpl(
      characterName: null == characterName
          ? _value.characterName
          : characterName // ignore: cast_nullable_to_non_nullable
              as String,
      customCharacters: null == customCharacters
          ? _value._customCharacters
          : customCharacters // ignore: cast_nullable_to_non_nullable
              as List<String>,
      enableAutoSummary: null == enableAutoSummary
          ? _value.enableAutoSummary
          : enableAutoSummary // ignore: cast_nullable_to_non_nullable
              as bool,
      enableContextualInsights: null == enableContextualInsights
          ? _value.enableContextualInsights
          : enableContextualInsights // ignore: cast_nullable_to_non_nullable
              as bool,
      modelSpecificSettings: null == modelSpecificSettings
          ? _value._modelSpecificSettings
          : modelSpecificSettings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserAISettingsImpl
    with DiagnosticableTreeMixin
    implements _UserAISettings {
  const _$UserAISettingsImpl(
      {this.characterName = '',
      final List<String> customCharacters = const [],
      this.enableAutoSummary = true,
      this.enableContextualInsights = true,
      final Map<String, dynamic> modelSpecificSettings = const {}})
      : _customCharacters = customCharacters,
        _modelSpecificSettings = modelSpecificSettings;

  factory _$UserAISettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserAISettingsImplFromJson(json);

  @override
  @JsonKey()
  final String characterName;
  final List<String> _customCharacters;
  @override
  @JsonKey()
  List<String> get customCharacters {
    if (_customCharacters is EqualUnmodifiableListView)
      return _customCharacters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_customCharacters);
  }

  @override
  @JsonKey()
  final bool enableAutoSummary;
  @override
  @JsonKey()
  final bool enableContextualInsights;
  final Map<String, dynamic> _modelSpecificSettings;
  @override
  @JsonKey()
  Map<String, dynamic> get modelSpecificSettings {
    if (_modelSpecificSettings is EqualUnmodifiableMapView)
      return _modelSpecificSettings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_modelSpecificSettings);
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'UserAISettings(characterName: $characterName, customCharacters: $customCharacters, enableAutoSummary: $enableAutoSummary, enableContextualInsights: $enableContextualInsights, modelSpecificSettings: $modelSpecificSettings)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'UserAISettings'))
      ..add(DiagnosticsProperty('characterName', characterName))
      ..add(DiagnosticsProperty('customCharacters', customCharacters))
      ..add(DiagnosticsProperty('enableAutoSummary', enableAutoSummary))
      ..add(DiagnosticsProperty(
          'enableContextualInsights', enableContextualInsights))
      ..add(
          DiagnosticsProperty('modelSpecificSettings', modelSpecificSettings));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserAISettingsImpl &&
            (identical(other.characterName, characterName) ||
                other.characterName == characterName) &&
            const DeepCollectionEquality()
                .equals(other._customCharacters, _customCharacters) &&
            (identical(other.enableAutoSummary, enableAutoSummary) ||
                other.enableAutoSummary == enableAutoSummary) &&
            (identical(
                    other.enableContextualInsights, enableContextualInsights) ||
                other.enableContextualInsights == enableContextualInsights) &&
            const DeepCollectionEquality()
                .equals(other._modelSpecificSettings, _modelSpecificSettings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      characterName,
      const DeepCollectionEquality().hash(_customCharacters),
      enableAutoSummary,
      enableContextualInsights,
      const DeepCollectionEquality().hash(_modelSpecificSettings));

  /// Create a copy of UserAISettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserAISettingsImplCopyWith<_$UserAISettingsImpl> get copyWith =>
      __$$UserAISettingsImplCopyWithImpl<_$UserAISettingsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserAISettingsImplToJson(
      this,
    );
  }
}

abstract class _UserAISettings implements UserAISettings {
  const factory _UserAISettings(
      {final String characterName,
      final List<String> customCharacters,
      final bool enableAutoSummary,
      final bool enableContextualInsights,
      final Map<String, dynamic> modelSpecificSettings}) = _$UserAISettingsImpl;

  factory _UserAISettings.fromJson(Map<String, dynamic> json) =
      _$UserAISettingsImpl.fromJson;

  @override
  String get characterName;
  @override
  List<String> get customCharacters;
  @override
  bool get enableAutoSummary;
  @override
  bool get enableContextualInsights;
  @override
  Map<String, dynamic> get modelSpecificSettings;

  /// Create a copy of UserAISettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserAISettingsImplCopyWith<_$UserAISettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

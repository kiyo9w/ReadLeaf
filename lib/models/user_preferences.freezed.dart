// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserPreferences _$UserPreferencesFromJson(Map<String, dynamic> json) {
  return _UserPreferences.fromJson(json);
}

/// @nodoc
mixin _$UserPreferences {
  bool get darkMode => throw _privateConstructorUsedError;
  String get fontSize => throw _privateConstructorUsedError;
  bool get enableAIFeatures => throw _privateConstructorUsedError;
  bool get showReadingProgress => throw _privateConstructorUsedError;
  bool get enableAutoSync => throw _privateConstructorUsedError;
  Map<String, dynamic> get customSettings => throw _privateConstructorUsedError;

  /// Serializes this UserPreferences to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserPreferences
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserPreferencesCopyWith<UserPreferences> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserPreferencesCopyWith<$Res> {
  factory $UserPreferencesCopyWith(
          UserPreferences value, $Res Function(UserPreferences) then) =
      _$UserPreferencesCopyWithImpl<$Res, UserPreferences>;
  @useResult
  $Res call(
      {bool darkMode,
      String fontSize,
      bool enableAIFeatures,
      bool showReadingProgress,
      bool enableAutoSync,
      Map<String, dynamic> customSettings});
}

/// @nodoc
class _$UserPreferencesCopyWithImpl<$Res, $Val extends UserPreferences>
    implements $UserPreferencesCopyWith<$Res> {
  _$UserPreferencesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserPreferences
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? darkMode = null,
    Object? fontSize = null,
    Object? enableAIFeatures = null,
    Object? showReadingProgress = null,
    Object? enableAutoSync = null,
    Object? customSettings = null,
  }) {
    return _then(_value.copyWith(
      darkMode: null == darkMode
          ? _value.darkMode
          : darkMode // ignore: cast_nullable_to_non_nullable
              as bool,
      fontSize: null == fontSize
          ? _value.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as String,
      enableAIFeatures: null == enableAIFeatures
          ? _value.enableAIFeatures
          : enableAIFeatures // ignore: cast_nullable_to_non_nullable
              as bool,
      showReadingProgress: null == showReadingProgress
          ? _value.showReadingProgress
          : showReadingProgress // ignore: cast_nullable_to_non_nullable
              as bool,
      enableAutoSync: null == enableAutoSync
          ? _value.enableAutoSync
          : enableAutoSync // ignore: cast_nullable_to_non_nullable
              as bool,
      customSettings: null == customSettings
          ? _value.customSettings
          : customSettings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserPreferencesImplCopyWith<$Res>
    implements $UserPreferencesCopyWith<$Res> {
  factory _$$UserPreferencesImplCopyWith(_$UserPreferencesImpl value,
          $Res Function(_$UserPreferencesImpl) then) =
      __$$UserPreferencesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool darkMode,
      String fontSize,
      bool enableAIFeatures,
      bool showReadingProgress,
      bool enableAutoSync,
      Map<String, dynamic> customSettings});
}

/// @nodoc
class __$$UserPreferencesImplCopyWithImpl<$Res>
    extends _$UserPreferencesCopyWithImpl<$Res, _$UserPreferencesImpl>
    implements _$$UserPreferencesImplCopyWith<$Res> {
  __$$UserPreferencesImplCopyWithImpl(
      _$UserPreferencesImpl _value, $Res Function(_$UserPreferencesImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserPreferences
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? darkMode = null,
    Object? fontSize = null,
    Object? enableAIFeatures = null,
    Object? showReadingProgress = null,
    Object? enableAutoSync = null,
    Object? customSettings = null,
  }) {
    return _then(_$UserPreferencesImpl(
      darkMode: null == darkMode
          ? _value.darkMode
          : darkMode // ignore: cast_nullable_to_non_nullable
              as bool,
      fontSize: null == fontSize
          ? _value.fontSize
          : fontSize // ignore: cast_nullable_to_non_nullable
              as String,
      enableAIFeatures: null == enableAIFeatures
          ? _value.enableAIFeatures
          : enableAIFeatures // ignore: cast_nullable_to_non_nullable
              as bool,
      showReadingProgress: null == showReadingProgress
          ? _value.showReadingProgress
          : showReadingProgress // ignore: cast_nullable_to_non_nullable
              as bool,
      enableAutoSync: null == enableAutoSync
          ? _value.enableAutoSync
          : enableAutoSync // ignore: cast_nullable_to_non_nullable
              as bool,
      customSettings: null == customSettings
          ? _value._customSettings
          : customSettings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserPreferencesImpl
    with DiagnosticableTreeMixin
    implements _UserPreferences {
  const _$UserPreferencesImpl(
      {this.darkMode = false,
      this.fontSize = 'medium',
      this.enableAIFeatures = true,
      this.showReadingProgress = true,
      this.enableAutoSync = false,
      final Map<String, dynamic> customSettings = const {}})
      : _customSettings = customSettings;

  factory _$UserPreferencesImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserPreferencesImplFromJson(json);

  @override
  @JsonKey()
  final bool darkMode;
  @override
  @JsonKey()
  final String fontSize;
  @override
  @JsonKey()
  final bool enableAIFeatures;
  @override
  @JsonKey()
  final bool showReadingProgress;
  @override
  @JsonKey()
  final bool enableAutoSync;
  final Map<String, dynamic> _customSettings;
  @override
  @JsonKey()
  Map<String, dynamic> get customSettings {
    if (_customSettings is EqualUnmodifiableMapView) return _customSettings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_customSettings);
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'UserPreferences(darkMode: $darkMode, fontSize: $fontSize, enableAIFeatures: $enableAIFeatures, showReadingProgress: $showReadingProgress, enableAutoSync: $enableAutoSync, customSettings: $customSettings)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'UserPreferences'))
      ..add(DiagnosticsProperty('darkMode', darkMode))
      ..add(DiagnosticsProperty('fontSize', fontSize))
      ..add(DiagnosticsProperty('enableAIFeatures', enableAIFeatures))
      ..add(DiagnosticsProperty('showReadingProgress', showReadingProgress))
      ..add(DiagnosticsProperty('enableAutoSync', enableAutoSync))
      ..add(DiagnosticsProperty('customSettings', customSettings));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserPreferencesImpl &&
            (identical(other.darkMode, darkMode) ||
                other.darkMode == darkMode) &&
            (identical(other.fontSize, fontSize) ||
                other.fontSize == fontSize) &&
            (identical(other.enableAIFeatures, enableAIFeatures) ||
                other.enableAIFeatures == enableAIFeatures) &&
            (identical(other.showReadingProgress, showReadingProgress) ||
                other.showReadingProgress == showReadingProgress) &&
            (identical(other.enableAutoSync, enableAutoSync) ||
                other.enableAutoSync == enableAutoSync) &&
            const DeepCollectionEquality()
                .equals(other._customSettings, _customSettings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      darkMode,
      fontSize,
      enableAIFeatures,
      showReadingProgress,
      enableAutoSync,
      const DeepCollectionEquality().hash(_customSettings));

  /// Create a copy of UserPreferences
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserPreferencesImplCopyWith<_$UserPreferencesImpl> get copyWith =>
      __$$UserPreferencesImplCopyWithImpl<_$UserPreferencesImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserPreferencesImplToJson(
      this,
    );
  }
}

abstract class _UserPreferences implements UserPreferences {
  const factory _UserPreferences(
      {final bool darkMode,
      final String fontSize,
      final bool enableAIFeatures,
      final bool showReadingProgress,
      final bool enableAutoSync,
      final Map<String, dynamic> customSettings}) = _$UserPreferencesImpl;

  factory _UserPreferences.fromJson(Map<String, dynamic> json) =
      _$UserPreferencesImpl.fromJson;

  @override
  bool get darkMode;
  @override
  String get fontSize;
  @override
  bool get enableAIFeatures;
  @override
  bool get showReadingProgress;
  @override
  bool get enableAutoSync;
  @override
  Map<String, dynamic> get customSettings;

  /// Create a copy of UserPreferences
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserPreferencesImplCopyWith<_$UserPreferencesImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

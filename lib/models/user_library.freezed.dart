// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_library.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserLibrary _$UserLibraryFromJson(Map<String, dynamic> json) {
  return _UserLibrary.fromJson(json);
}

/// @nodoc
mixin _$UserLibrary {
  List<String> get filePaths => throw _privateConstructorUsedError;
  List<String> get favorites => throw _privateConstructorUsedError;
  Map<String, int> get lastOpenedPages => throw _privateConstructorUsedError;
  Map<String, List<String>> get bookmarks => throw _privateConstructorUsedError;
  Map<String, DateTime> get lastReadTimes => throw _privateConstructorUsedError;

  /// Serializes this UserLibrary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserLibrary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserLibraryCopyWith<UserLibrary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserLibraryCopyWith<$Res> {
  factory $UserLibraryCopyWith(
          UserLibrary value, $Res Function(UserLibrary) then) =
      _$UserLibraryCopyWithImpl<$Res, UserLibrary>;
  @useResult
  $Res call(
      {List<String> filePaths,
      List<String> favorites,
      Map<String, int> lastOpenedPages,
      Map<String, List<String>> bookmarks,
      Map<String, DateTime> lastReadTimes});
}

/// @nodoc
class _$UserLibraryCopyWithImpl<$Res, $Val extends UserLibrary>
    implements $UserLibraryCopyWith<$Res> {
  _$UserLibraryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserLibrary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? filePaths = null,
    Object? favorites = null,
    Object? lastOpenedPages = null,
    Object? bookmarks = null,
    Object? lastReadTimes = null,
  }) {
    return _then(_value.copyWith(
      filePaths: null == filePaths
          ? _value.filePaths
          : filePaths // ignore: cast_nullable_to_non_nullable
              as List<String>,
      favorites: null == favorites
          ? _value.favorites
          : favorites // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastOpenedPages: null == lastOpenedPages
          ? _value.lastOpenedPages
          : lastOpenedPages // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      bookmarks: null == bookmarks
          ? _value.bookmarks
          : bookmarks // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      lastReadTimes: null == lastReadTimes
          ? _value.lastReadTimes
          : lastReadTimes // ignore: cast_nullable_to_non_nullable
              as Map<String, DateTime>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserLibraryImplCopyWith<$Res>
    implements $UserLibraryCopyWith<$Res> {
  factory _$$UserLibraryImplCopyWith(
          _$UserLibraryImpl value, $Res Function(_$UserLibraryImpl) then) =
      __$$UserLibraryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<String> filePaths,
      List<String> favorites,
      Map<String, int> lastOpenedPages,
      Map<String, List<String>> bookmarks,
      Map<String, DateTime> lastReadTimes});
}

/// @nodoc
class __$$UserLibraryImplCopyWithImpl<$Res>
    extends _$UserLibraryCopyWithImpl<$Res, _$UserLibraryImpl>
    implements _$$UserLibraryImplCopyWith<$Res> {
  __$$UserLibraryImplCopyWithImpl(
      _$UserLibraryImpl _value, $Res Function(_$UserLibraryImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserLibrary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? filePaths = null,
    Object? favorites = null,
    Object? lastOpenedPages = null,
    Object? bookmarks = null,
    Object? lastReadTimes = null,
  }) {
    return _then(_$UserLibraryImpl(
      filePaths: null == filePaths
          ? _value._filePaths
          : filePaths // ignore: cast_nullable_to_non_nullable
              as List<String>,
      favorites: null == favorites
          ? _value._favorites
          : favorites // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastOpenedPages: null == lastOpenedPages
          ? _value._lastOpenedPages
          : lastOpenedPages // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      bookmarks: null == bookmarks
          ? _value._bookmarks
          : bookmarks // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String>>,
      lastReadTimes: null == lastReadTimes
          ? _value._lastReadTimes
          : lastReadTimes // ignore: cast_nullable_to_non_nullable
              as Map<String, DateTime>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserLibraryImpl with DiagnosticableTreeMixin implements _UserLibrary {
  const _$UserLibraryImpl(
      {final List<String> filePaths = const [],
      final List<String> favorites = const [],
      final Map<String, int> lastOpenedPages = const {},
      final Map<String, List<String>> bookmarks = const {},
      final Map<String, DateTime> lastReadTimes = const {}})
      : _filePaths = filePaths,
        _favorites = favorites,
        _lastOpenedPages = lastOpenedPages,
        _bookmarks = bookmarks,
        _lastReadTimes = lastReadTimes;

  factory _$UserLibraryImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserLibraryImplFromJson(json);

  final List<String> _filePaths;
  @override
  @JsonKey()
  List<String> get filePaths {
    if (_filePaths is EqualUnmodifiableListView) return _filePaths;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_filePaths);
  }

  final List<String> _favorites;
  @override
  @JsonKey()
  List<String> get favorites {
    if (_favorites is EqualUnmodifiableListView) return _favorites;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_favorites);
  }

  final Map<String, int> _lastOpenedPages;
  @override
  @JsonKey()
  Map<String, int> get lastOpenedPages {
    if (_lastOpenedPages is EqualUnmodifiableMapView) return _lastOpenedPages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_lastOpenedPages);
  }

  final Map<String, List<String>> _bookmarks;
  @override
  @JsonKey()
  Map<String, List<String>> get bookmarks {
    if (_bookmarks is EqualUnmodifiableMapView) return _bookmarks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_bookmarks);
  }

  final Map<String, DateTime> _lastReadTimes;
  @override
  @JsonKey()
  Map<String, DateTime> get lastReadTimes {
    if (_lastReadTimes is EqualUnmodifiableMapView) return _lastReadTimes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_lastReadTimes);
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'UserLibrary(filePaths: $filePaths, favorites: $favorites, lastOpenedPages: $lastOpenedPages, bookmarks: $bookmarks, lastReadTimes: $lastReadTimes)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'UserLibrary'))
      ..add(DiagnosticsProperty('filePaths', filePaths))
      ..add(DiagnosticsProperty('favorites', favorites))
      ..add(DiagnosticsProperty('lastOpenedPages', lastOpenedPages))
      ..add(DiagnosticsProperty('bookmarks', bookmarks))
      ..add(DiagnosticsProperty('lastReadTimes', lastReadTimes));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserLibraryImpl &&
            const DeepCollectionEquality()
                .equals(other._filePaths, _filePaths) &&
            const DeepCollectionEquality()
                .equals(other._favorites, _favorites) &&
            const DeepCollectionEquality()
                .equals(other._lastOpenedPages, _lastOpenedPages) &&
            const DeepCollectionEquality()
                .equals(other._bookmarks, _bookmarks) &&
            const DeepCollectionEquality()
                .equals(other._lastReadTimes, _lastReadTimes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_filePaths),
      const DeepCollectionEquality().hash(_favorites),
      const DeepCollectionEquality().hash(_lastOpenedPages),
      const DeepCollectionEquality().hash(_bookmarks),
      const DeepCollectionEquality().hash(_lastReadTimes));

  /// Create a copy of UserLibrary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserLibraryImplCopyWith<_$UserLibraryImpl> get copyWith =>
      __$$UserLibraryImplCopyWithImpl<_$UserLibraryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserLibraryImplToJson(
      this,
    );
  }
}

abstract class _UserLibrary implements UserLibrary {
  const factory _UserLibrary(
      {final List<String> filePaths,
      final List<String> favorites,
      final Map<String, int> lastOpenedPages,
      final Map<String, List<String>> bookmarks,
      final Map<String, DateTime> lastReadTimes}) = _$UserLibraryImpl;

  factory _UserLibrary.fromJson(Map<String, dynamic> json) =
      _$UserLibraryImpl.fromJson;

  @override
  List<String> get filePaths;
  @override
  List<String> get favorites;
  @override
  Map<String, int> get lastOpenedPages;
  @override
  Map<String, List<String>> get bookmarks;
  @override
  Map<String, DateTime> get lastReadTimes;

  /// Create a copy of UserLibrary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserLibraryImplCopyWith<_$UserLibraryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

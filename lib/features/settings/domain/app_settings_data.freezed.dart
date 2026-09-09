// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppSettingsData {

 AppThemePreference get themePreference; AppLanguage get language; String get defaultDueTime; String get timezoneName;
/// Create a copy of AppSettingsData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsDataCopyWith<AppSettingsData> get copyWith => _$AppSettingsDataCopyWithImpl<AppSettingsData>(this as AppSettingsData, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AppSettingsData;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettingsData&&(identical(other.themePreference, _this.themePreference) || other.themePreference == _this.themePreference)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.defaultDueTime, _this.defaultDueTime) || other.defaultDueTime == _this.defaultDueTime)&&(identical(other.timezoneName, _this.timezoneName) || other.timezoneName == _this.timezoneName));
}


@override
int get hashCode {
  final _this = this as AppSettingsData;
  return Object.hash(runtimeType,_this.themePreference,_this.language,_this.defaultDueTime,_this.timezoneName);
}

@override
String toString() {
  final _this = this as AppSettingsData;
  return 'AppSettingsData(themePreference: ${_this.themePreference}, language: ${_this.language}, defaultDueTime: ${_this.defaultDueTime}, timezoneName: ${_this.timezoneName})';
}


}

/// @nodoc
abstract mixin class $AppSettingsDataCopyWith<$Res>  {
  factory $AppSettingsDataCopyWith(AppSettingsData value, $Res Function(AppSettingsData) _then) = _$AppSettingsDataCopyWithImpl;
@useResult
$Res call({
 AppThemePreference themePreference, AppLanguage language, String defaultDueTime, String timezoneName
});




}
/// @nodoc
class _$AppSettingsDataCopyWithImpl<$Res>
    implements $AppSettingsDataCopyWith<$Res> {
  _$AppSettingsDataCopyWithImpl(this._self, this._then);

  final AppSettingsData _self;
  final $Res Function(AppSettingsData) _then;

/// Create a copy of AppSettingsData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themePreference = null,Object? language = null,Object? defaultDueTime = null,Object? timezoneName = null,}) {
  return _then(AppSettingsData(
themePreference: null == themePreference ? _self.themePreference : themePreference // ignore: cast_nullable_to_non_nullable
as AppThemePreference,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as AppLanguage,defaultDueTime: null == defaultDueTime ? _self.defaultDueTime : defaultDueTime // ignore: cast_nullable_to_non_nullable
as String,timezoneName: null == timezoneName ? _self.timezoneName : timezoneName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettingsData].
extension AppSettingsDataPatterns on AppSettingsData {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettingsData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettingsData() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettingsData value)  $default,){
final _that = this;
switch (_that) {
case _AppSettingsData():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettingsData value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettingsData() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AppThemePreference themePreference,  AppLanguage language,  String defaultDueTime,  String timezoneName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettingsData() when $default != null:
return $default(_that.themePreference,_that.language,_that.defaultDueTime,_that.timezoneName);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AppThemePreference themePreference,  AppLanguage language,  String defaultDueTime,  String timezoneName)  $default,) {final _that = this;
switch (_that) {
case _AppSettingsData():
return $default(_that.themePreference,_that.language,_that.defaultDueTime,_that.timezoneName);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AppThemePreference themePreference,  AppLanguage language,  String defaultDueTime,  String timezoneName)?  $default,) {final _that = this;
switch (_that) {
case _AppSettingsData() when $default != null:
return $default(_that.themePreference,_that.language,_that.defaultDueTime,_that.timezoneName);case _:
  return null;

}
}

}

/// @nodoc


class _AppSettingsData extends AppSettingsData {
  const _AppSettingsData({this.themePreference = AppThemePreference.system, this.language = AppLanguage.en, this.defaultDueTime = '07:00', this.timezoneName = ''}): super._();
  

@override@JsonKey() final  AppThemePreference themePreference;
@override@JsonKey() final  AppLanguage language;
@override@JsonKey() final  String defaultDueTime;
@override@JsonKey() final  String timezoneName;

/// Create a copy of AppSettingsData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsDataCopyWith<_AppSettingsData> get copyWith => __$AppSettingsDataCopyWithImpl<_AppSettingsData>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettingsData&&(identical(other.themePreference, themePreference) || other.themePreference == themePreference)&&(identical(other.language, language) || other.language == language)&&(identical(other.defaultDueTime, defaultDueTime) || other.defaultDueTime == defaultDueTime)&&(identical(other.timezoneName, timezoneName) || other.timezoneName == timezoneName));
}


@override
int get hashCode {
    return Object.hash(runtimeType,themePreference,language,defaultDueTime,timezoneName);
}

@override
String toString() {
    return 'AppSettingsData(themePreference: $themePreference, language: $language, defaultDueTime: $defaultDueTime, timezoneName: $timezoneName)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsDataCopyWith<$Res> implements $AppSettingsDataCopyWith<$Res> {
  factory _$AppSettingsDataCopyWith(_AppSettingsData value, $Res Function(_AppSettingsData) _then) = __$AppSettingsDataCopyWithImpl;
@override @useResult
$Res call({
 AppThemePreference themePreference, AppLanguage language, String defaultDueTime, String timezoneName
});




}
/// @nodoc
class __$AppSettingsDataCopyWithImpl<$Res>
    implements _$AppSettingsDataCopyWith<$Res> {
  __$AppSettingsDataCopyWithImpl(this._self, this._then);

  final _AppSettingsData _self;
  final $Res Function(_AppSettingsData) _then;

/// Create a copy of AppSettingsData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themePreference = null,Object? language = null,Object? defaultDueTime = null,Object? timezoneName = null,}) {
  return _then(_AppSettingsData(
themePreference: null == themePreference ? _self.themePreference : themePreference // ignore: cast_nullable_to_non_nullable
as AppThemePreference,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as AppLanguage,defaultDueTime: null == defaultDueTime ? _self.defaultDueTime : defaultDueTime // ignore: cast_nullable_to_non_nullable
as String,timezoneName: null == timezoneName ? _self.timezoneName : timezoneName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on

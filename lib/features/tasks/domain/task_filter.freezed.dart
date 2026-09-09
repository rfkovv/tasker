// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_filter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TaskFilter {

 TaskStatus? get status; TaskPriority? get priority; String? get tag; bool get hideDone; bool get noDueDate; TaskSort get sort; String? get contactId; String? get titleQuery;
/// Create a copy of TaskFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskFilterCopyWith<TaskFilter> get copyWith => _$TaskFilterCopyWithImpl<TaskFilter>(this as TaskFilter, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TaskFilter;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskFilter&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.priority, _this.priority) || other.priority == _this.priority)&&(identical(other.tag, _this.tag) || other.tag == _this.tag)&&(identical(other.hideDone, _this.hideDone) || other.hideDone == _this.hideDone)&&(identical(other.noDueDate, _this.noDueDate) || other.noDueDate == _this.noDueDate)&&(identical(other.sort, _this.sort) || other.sort == _this.sort)&&(identical(other.contactId, _this.contactId) || other.contactId == _this.contactId)&&(identical(other.titleQuery, _this.titleQuery) || other.titleQuery == _this.titleQuery));
}


@override
int get hashCode {
  final _this = this as TaskFilter;
  return Object.hash(runtimeType,_this.status,_this.priority,_this.tag,_this.hideDone,_this.noDueDate,_this.sort,_this.contactId,_this.titleQuery);
}

@override
String toString() {
  final _this = this as TaskFilter;
  return 'TaskFilter(status: ${_this.status}, priority: ${_this.priority}, tag: ${_this.tag}, hideDone: ${_this.hideDone}, noDueDate: ${_this.noDueDate}, sort: ${_this.sort}, contactId: ${_this.contactId}, titleQuery: ${_this.titleQuery})';
}


}

/// @nodoc
abstract mixin class $TaskFilterCopyWith<$Res>  {
  factory $TaskFilterCopyWith(TaskFilter value, $Res Function(TaskFilter) _then) = _$TaskFilterCopyWithImpl;
@useResult
$Res call({
 TaskStatus? status, TaskPriority? priority, String? tag, bool hideDone, bool noDueDate, TaskSort sort, String? contactId, String? titleQuery
});




}
/// @nodoc
class _$TaskFilterCopyWithImpl<$Res>
    implements $TaskFilterCopyWith<$Res> {
  _$TaskFilterCopyWithImpl(this._self, this._then);

  final TaskFilter _self;
  final $Res Function(TaskFilter) _then;

/// Create a copy of TaskFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = freezed,Object? priority = freezed,Object? tag = freezed,Object? hideDone = null,Object? noDueDate = null,Object? sort = null,Object? contactId = freezed,Object? titleQuery = freezed,}) {
  return _then(TaskFilter(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TaskStatus?,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as TaskPriority?,tag: freezed == tag ? _self.tag : tag // ignore: cast_nullable_to_non_nullable
as String?,hideDone: null == hideDone ? _self.hideDone : hideDone // ignore: cast_nullable_to_non_nullable
as bool,noDueDate: null == noDueDate ? _self.noDueDate : noDueDate // ignore: cast_nullable_to_non_nullable
as bool,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as TaskSort,contactId: freezed == contactId ? _self.contactId : contactId // ignore: cast_nullable_to_non_nullable
as String?,titleQuery: freezed == titleQuery ? _self.titleQuery : titleQuery // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskFilter].
extension TaskFilterPatterns on TaskFilter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskFilter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskFilter value)  $default,){
final _that = this;
switch (_that) {
case _TaskFilter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskFilter value)?  $default,){
final _that = this;
switch (_that) {
case _TaskFilter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TaskStatus? status,  TaskPriority? priority,  String? tag,  bool hideDone,  bool noDueDate,  TaskSort sort,  String? contactId,  String? titleQuery)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskFilter() when $default != null:
return $default(_that.status,_that.priority,_that.tag,_that.hideDone,_that.noDueDate,_that.sort,_that.contactId,_that.titleQuery);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TaskStatus? status,  TaskPriority? priority,  String? tag,  bool hideDone,  bool noDueDate,  TaskSort sort,  String? contactId,  String? titleQuery)  $default,) {final _that = this;
switch (_that) {
case _TaskFilter():
return $default(_that.status,_that.priority,_that.tag,_that.hideDone,_that.noDueDate,_that.sort,_that.contactId,_that.titleQuery);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TaskStatus? status,  TaskPriority? priority,  String? tag,  bool hideDone,  bool noDueDate,  TaskSort sort,  String? contactId,  String? titleQuery)?  $default,) {final _that = this;
switch (_that) {
case _TaskFilter() when $default != null:
return $default(_that.status,_that.priority,_that.tag,_that.hideDone,_that.noDueDate,_that.sort,_that.contactId,_that.titleQuery);case _:
  return null;

}
}

}

/// @nodoc


class _TaskFilter extends TaskFilter {
  const _TaskFilter({this.status, this.priority, this.tag, this.hideDone = false, this.noDueDate = false, this.sort = TaskSort.none, this.contactId, this.titleQuery}): super._();
  

@override final  TaskStatus? status;
@override final  TaskPriority? priority;
@override final  String? tag;
@override@JsonKey() final  bool hideDone;
@override@JsonKey() final  bool noDueDate;
@override@JsonKey() final  TaskSort sort;
@override final  String? contactId;
@override final  String? titleQuery;

/// Create a copy of TaskFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskFilterCopyWith<_TaskFilter> get copyWith => __$TaskFilterCopyWithImpl<_TaskFilter>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskFilter&&(identical(other.status, status) || other.status == status)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.tag, tag) || other.tag == tag)&&(identical(other.hideDone, hideDone) || other.hideDone == hideDone)&&(identical(other.noDueDate, noDueDate) || other.noDueDate == noDueDate)&&(identical(other.sort, sort) || other.sort == sort)&&(identical(other.contactId, contactId) || other.contactId == contactId)&&(identical(other.titleQuery, titleQuery) || other.titleQuery == titleQuery));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,priority,tag,hideDone,noDueDate,sort,contactId,titleQuery);
}

@override
String toString() {
    return 'TaskFilter(status: $status, priority: $priority, tag: $tag, hideDone: $hideDone, noDueDate: $noDueDate, sort: $sort, contactId: $contactId, titleQuery: $titleQuery)';
}


}

/// @nodoc
abstract mixin class _$TaskFilterCopyWith<$Res> implements $TaskFilterCopyWith<$Res> {
  factory _$TaskFilterCopyWith(_TaskFilter value, $Res Function(_TaskFilter) _then) = __$TaskFilterCopyWithImpl;
@override @useResult
$Res call({
 TaskStatus? status, TaskPriority? priority, String? tag, bool hideDone, bool noDueDate, TaskSort sort, String? contactId, String? titleQuery
});




}
/// @nodoc
class __$TaskFilterCopyWithImpl<$Res>
    implements _$TaskFilterCopyWith<$Res> {
  __$TaskFilterCopyWithImpl(this._self, this._then);

  final _TaskFilter _self;
  final $Res Function(_TaskFilter) _then;

/// Create a copy of TaskFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = freezed,Object? priority = freezed,Object? tag = freezed,Object? hideDone = null,Object? noDueDate = null,Object? sort = null,Object? contactId = freezed,Object? titleQuery = freezed,}) {
  return _then(_TaskFilter(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TaskStatus?,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as TaskPriority?,tag: freezed == tag ? _self.tag : tag // ignore: cast_nullable_to_non_nullable
as String?,hideDone: null == hideDone ? _self.hideDone : hideDone // ignore: cast_nullable_to_non_nullable
as bool,noDueDate: null == noDueDate ? _self.noDueDate : noDueDate // ignore: cast_nullable_to_non_nullable
as bool,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as TaskSort,contactId: freezed == contactId ? _self.contactId : contactId // ignore: cast_nullable_to_non_nullable
as String?,titleQuery: freezed == titleQuery ? _self.titleQuery : titleQuery // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

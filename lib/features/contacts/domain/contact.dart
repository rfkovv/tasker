import 'package:freezed_annotation/freezed_annotation.dart';

part 'contact.freezed.dart';

@freezed
abstract class Contact with _$Contact {
  const factory Contact({
    required String id,
    required String name,
    String? role,
    String? email,
    String? phone,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Contact;

  const Contact._();
}

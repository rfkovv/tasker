import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/contact_repository_provider.dart';
import '../../domain/contact.dart';

part 'contact_form_provider.g.dart';

class ContactFormState {
  const ContactFormState({
    this.name = '',
    this.role = '',
    this.email = '',
    this.phone = '',
  });

  factory ContactFormState.initial() => const ContactFormState();

  final String name;
  final String role;
  final String email;
  final String phone;

  ContactFormState copyWith({
    String? name,
    String? role,
    String? email,
    String? phone,
  }) {
    return ContactFormState(
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}

@riverpod
class ContactForm extends _$ContactForm {
  @override
  ContactFormState build(Contact? contact) {
    if (contact == null) return ContactFormState.initial();
    return ContactFormState(
      name: contact.name,
      role: contact.role ?? '',
      email: contact.email ?? '',
      phone: contact.phone ?? '',
    );
  }

  void setName(String value) => state = state.copyWith(name: value);

  void setRole(String value) => state = state.copyWith(role: value);

  void setEmail(String value) => state = state.copyWith(email: value);

  void setPhone(String value) => state = state.copyWith(phone: value);

  Future<bool> save() async {
    if (state.name.trim().isEmpty) return false;

    final repository = ref.read(contactRepositoryProvider);

    if (contact == null) {
      await repository.create(
        name: state.name.trim(),
        role: state.role.isNotEmpty ? state.role : null,
        email: state.email.isNotEmpty ? state.email : null,
        phone: state.phone.isNotEmpty ? state.phone : null,
      );
    } else {
      final updated = contact!.copyWith(
        name: state.name.trim(),
        role: state.role.isNotEmpty ? state.role : null,
        email: state.email.isNotEmpty ? state.email : null,
        phone: state.phone.isNotEmpty ? state.phone : null,
        updatedAt: DateTime.now(),
      );
      await repository.update(updated);
    }
    return true;
  }
}

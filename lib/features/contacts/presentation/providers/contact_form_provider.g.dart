// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_form_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ContactForm)
final contactFormProvider = ContactFormFamily._();

final class ContactFormProvider
    extends $NotifierProvider<ContactForm, ContactFormState> {
  ContactFormProvider._({
    required ContactFormFamily super.from,
    required Contact? super.argument,
  }) : super(
         retry: null,
         name: r'contactFormProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contactFormHash();

  @override
  String toString() {
    return r'contactFormProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ContactForm create() => ContactForm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContactFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContactFormState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ContactFormProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contactFormHash() => r'69f21849069b6428aa31bd90d2a5cfd98ddc92aa';

final class ContactFormFamily extends $Family
    with
        $ClassFamilyOverride<
          ContactForm,
          ContactFormState,
          ContactFormState,
          ContactFormState,
          Contact?
        > {
  ContactFormFamily._()
    : super(
        retry: null,
        name: r'contactFormProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ContactFormProvider call(Contact? contact) =>
      ContactFormProvider._(argument: contact, from: this);

  @override
  String toString() => r'contactFormProvider';
}

abstract class _$ContactForm extends $Notifier<ContactFormState> {
  late final _$args = ref.$arg as Contact?;
  Contact? get contact => _$args;

  ContactFormState build(Contact? contact);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ContactFormState, ContactFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ContactFormState, ContactFormState>,
              ContactFormState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

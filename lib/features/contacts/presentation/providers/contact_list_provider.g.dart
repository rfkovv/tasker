// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contactList)
final contactListProvider = ContactListFamily._();

final class ContactListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Contact>>,
          List<Contact>,
          Stream<List<Contact>>
        >
    with $FutureModifier<List<Contact>>, $StreamProvider<List<Contact>> {
  ContactListProvider._({
    required ContactListFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'contactListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contactListHash();

  @override
  String toString() {
    return r'contactListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Contact>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Contact>> create(Ref ref) {
    final argument = this.argument as String?;
    return contactList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ContactListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contactListHash() => r'0f101d00366f90a8b836c6893dbb5d2b2417150a';

final class ContactListFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Contact>>, String?> {
  ContactListFamily._()
    : super(
        retry: null,
        name: r'contactListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ContactListProvider call(String? nameFilter) =>
      ContactListProvider._(argument: nameFilter, from: this);

  @override
  String toString() => r'contactListProvider';
}

@ProviderFor(watchContactById)
final watchContactByIdProvider = WatchContactByIdFamily._();

final class WatchContactByIdProvider
    extends
        $FunctionalProvider<AsyncValue<Contact?>, Contact?, Stream<Contact?>>
    with $FutureModifier<Contact?>, $StreamProvider<Contact?> {
  WatchContactByIdProvider._({
    required WatchContactByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'watchContactByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchContactByIdHash();

  @override
  String toString() {
    return r'watchContactByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Contact?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Contact?> create(Ref ref) {
    final argument = this.argument as String;
    return watchContactById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchContactByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchContactByIdHash() => r'46b951e541705cf93c24cf9417e7041fff9cfcc3';

final class WatchContactByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Contact?>, String> {
  WatchContactByIdFamily._()
    : super(
        retry: null,
        name: r'watchContactByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchContactByIdProvider call(String id) =>
      WatchContactByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'watchContactByIdProvider';
}

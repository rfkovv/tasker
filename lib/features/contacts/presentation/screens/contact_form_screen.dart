import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/contact.dart';
import '../providers/contact_form_provider.dart';
import '../providers/contact_list_provider.dart';

class ContactFormScreen extends ConsumerStatefulWidget {
  const ContactFormScreen({super.key, this.contactId, this.onSaved});

  final String? contactId;
  final VoidCallback? onSaved;

  @override
  ConsumerState<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends ConsumerState<ContactFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  bool _controllersSeeded = false;

  bool get _isNew =>
      widget.contactId == null || widget.contactId == 'new';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _roleController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactAsync = _isNew
        ? const AsyncValue<Contact?>.data(null)
        : ref.watch(watchContactByIdProvider(widget.contactId!));
    final contact =
        contactAsync is AsyncData<Contact?> ? contactAsync.value : null;
    final form = ref.watch(contactFormProvider(contact));
    final formNotifier = ref.read(contactFormProvider(contact).notifier);

    if (contact != null && !_controllersSeeded) {
      _controllersSeeded = true;
      _nameController.text = contact.name;
      _roleController.text = contact.role ?? '';
      _emailController.text = contact.email ?? '';
      _phoneController.text = contact.phone ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New Contact' : 'Edit Contact'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: contactAsync is AsyncLoading
                ? const Center(child: CircularProgressIndicator())
                : contactAsync is AsyncError
                    ? Center(child: Text('Error: ${contactAsync.error}'))
                    : _buildForm(context, form, formNotifier),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final saved = await formNotifier.save();
                      if (saved && context.mounted) {
                        widget.onSaved?.call();
                        Navigator.maybePop(context);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    ContactFormState form,
    ContactForm formController,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onChanged: formController.setName,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _roleController,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onChanged: formController.setRole,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: formController.setEmail,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            onChanged: formController.setPhone,
          ),
        ],
      ),
    );
  }
}

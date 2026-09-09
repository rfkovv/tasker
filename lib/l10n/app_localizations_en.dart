// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tasks => 'Tasks';

  @override
  String get contacts => 'Contacts';

  @override
  String get settings => 'Settings';

  @override
  String get addTask => 'Add Task';

  @override
  String get addContact => 'Add Contact';

  @override
  String get noTasksYet => 'No tasks yet';

  @override
  String get noTasksHint => 'Tap \"Add Task\" to create your first task';

  @override
  String get noContactsYet => 'No contacts yet';

  @override
  String get noContactsHint =>
      'Tap \"Add Contact\" to create your first contact';

  @override
  String errorWithValue(String error) {
    return 'Error: $error';
  }

  @override
  String get filters => 'Filters';

  @override
  String get filter => 'Filter';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterPriority => 'Priority';

  @override
  String get filterAll => 'All';

  @override
  String get filterTags => 'Tags';

  @override
  String get hideDone => 'Hide done';

  @override
  String get noTags => 'No tags';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String get statusTodo => 'To Do';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusDone => 'Done';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get overdue => 'Overdue';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dec';

  @override
  String get relevantPersons => 'Relevant Persons';

  @override
  String get newTask => 'New Task';

  @override
  String get editTask => 'Edit Task';

  @override
  String get edit => 'Edit';

  @override
  String get markDone => 'Mark done';

  @override
  String get markTodo => 'Back to to-do';

  @override
  String get delete => 'Delete';

  @override
  String get subtasks => 'Subtasks';

  @override
  String subtaskProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String get subtaskHint => 'Type a subtask and press Enter...';

  @override
  String get noSubtasks => 'No subtasks yet';

  @override
  String get comments => 'Comments';

  @override
  String get addComment => 'Add comment';

  @override
  String get commentHint => 'Write a comment...';

  @override
  String get noComments => 'No comments yet';

  @override
  String get taskNotFound => 'Task not found';

  @override
  String get save => 'Save';

  @override
  String get titleLabel => 'Title';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get dueDate => 'Due date';

  @override
  String get noDueDate => 'No due date';

  @override
  String get tags => 'Tags';

  @override
  String get tagsHint => 'Type a tag and press enter...';

  @override
  String get linkContact => 'Link contact';

  @override
  String get noContactsLinked => 'No contacts linked';

  @override
  String get linkContactTitle => 'Link Contact';

  @override
  String get noContactsAvailable => 'No contacts available';

  @override
  String get createNewContact => 'Create new contact';

  @override
  String get nameLabel => 'Name';

  @override
  String get roleOptional => 'Role (optional)';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get back => 'Back';

  @override
  String get createAndLink => 'Create & Link';

  @override
  String get newContact => 'New Contact';

  @override
  String get editContact => 'Edit Contact';

  @override
  String get roleLabel => 'Role';

  @override
  String get emailLabel => 'Email';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePolish => 'Polish';
}

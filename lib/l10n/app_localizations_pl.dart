// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get tasks => 'Zadania';

  @override
  String get contacts => 'Kontakty';

  @override
  String get settings => 'Ustawienia';

  @override
  String get addTask => 'Dodaj zadanie';

  @override
  String get addContact => 'Dodaj kontakt';

  @override
  String get noTasksYet => 'Brak zadań';

  @override
  String get noTasksHint =>
      'Kliknij „Dodaj zadanie”, aby utworzyć pierwsze zadanie';

  @override
  String get noContactsYet => 'Brak kontaktów';

  @override
  String get noContactsHint =>
      'Kliknij „Dodaj kontakt”, aby utworzyć pierwszy kontakt';

  @override
  String errorWithValue(String error) {
    return 'Błąd: $error';
  }

  @override
  String get filters => 'Filtry';

  @override
  String get filter => 'Filtruj';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterPriority => 'Priorytet';

  @override
  String get filterAll => 'Wszystkie';

  @override
  String get filterTags => 'Tagi';

  @override
  String get hideDone => 'Ukryj zrobione';

  @override
  String get noTags => 'Brak tagów';

  @override
  String get resetFilters => 'Wyczyść filtry';

  @override
  String get statusTodo => 'Do zrobienia';

  @override
  String get statusInProgress => 'W trakcie';

  @override
  String get statusDone => 'Zrobione';

  @override
  String get priorityLow => 'Niski';

  @override
  String get priorityMedium => 'Średni';

  @override
  String get priorityHigh => 'Wysoki';

  @override
  String get priorityUrgent => 'Pilny';

  @override
  String get overdue => 'Po terminie';

  @override
  String get today => 'Dziś';

  @override
  String get tomorrow => 'Jutro';

  @override
  String get monthJan => 'sty';

  @override
  String get monthFeb => 'lut';

  @override
  String get monthMar => 'mar';

  @override
  String get monthApr => 'kwi';

  @override
  String get monthMay => 'maj';

  @override
  String get monthJun => 'cze';

  @override
  String get monthJul => 'lip';

  @override
  String get monthAug => 'sie';

  @override
  String get monthSep => 'wrz';

  @override
  String get monthOct => 'paź';

  @override
  String get monthNov => 'lis';

  @override
  String get monthDec => 'gru';

  @override
  String get relevantPersons => 'Osoby istotne';

  @override
  String get newTask => 'Nowe zadanie';

  @override
  String get editTask => 'Edytuj zadanie';

  @override
  String get save => 'Zapisz';

  @override
  String get titleLabel => 'Tytuł';

  @override
  String get descriptionLabel => 'Opis';

  @override
  String get dueDate => 'Termin';

  @override
  String get noDueDate => 'Brak terminu';

  @override
  String get tags => 'Tagi';

  @override
  String get tagsHint => 'Wpisz tag i naciśnij Enter...';

  @override
  String get linkContact => 'Powiąż kontakt';

  @override
  String get noContactsLinked => 'Brak powiązanych kontaktów';

  @override
  String get linkContactTitle => 'Powiąż kontakt';

  @override
  String get noContactsAvailable => 'Brak dostępnych kontaktów';

  @override
  String get createNewContact => 'Utwórz nowy kontakt';

  @override
  String get nameLabel => 'Imię i nazwisko';

  @override
  String get roleOptional => 'Rola (opcjonalnie)';

  @override
  String get emailOptional => 'Email (opcjonalnie)';

  @override
  String get phoneOptional => 'Telefon (opcjonalnie)';

  @override
  String get back => 'Wstecz';

  @override
  String get createAndLink => 'Utwórz i powiąż';

  @override
  String get newContact => 'Nowy kontakt';

  @override
  String get editContact => 'Edytuj kontakt';

  @override
  String get roleLabel => 'Rola';

  @override
  String get emailLabel => 'Email';

  @override
  String get phoneLabel => 'Telefon';

  @override
  String get settingsTheme => 'Motyw';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Jasny';

  @override
  String get themeDark => 'Ciemny';

  @override
  String get settingsLanguage => 'Język';

  @override
  String get languageEnglish => 'Angielski';

  @override
  String get languagePolish => 'Polski';
}

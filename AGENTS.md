# AGENTS.md

PROJECT: TaskMaster (Flutter menedżer zadań)
ARCHITECTURE: See ARCHITECTURE.md — follow it strictly, no deviations without approval.

CURRENT PHASE: Stage 2.5 — Settings + i18n + theme

STAGE 2.5 SCOPE (do NOT exceed):
- features/settings: provider globalny (@Riverpod, keepAlive) +
  ekran ustawień zgodny z zasadami layoutu
- Sidebar: wpis "Settings" PRZYPIĘTY DO DOŁU lewego panelu
  (oddzielony od filtra nawigacji)
- Język: polski + angielski (flutter_localizations + gen_l10n,
  pliki .arb; l10n.yaml + flutter_localizations w pubspec)
- ZERO hardcoded UI strings — wszystko przez AppLocalizations;
  obowiązuje wstecz dla istniejących ekranów (tasks, contacts)
- Motyw: system / jasny / ciemny (dwie ThemeData + themeMode)
- Persistence: app_settings (key-value); odczyt przy starcie PRZED
  budową MaterialApp; zmiana stosowana natychmiast, bez restartu
- Router: '/settings'

OUT OF SCOPE:
- Zadania/kontakty zmiany funkcjonalne, kalendarz, sync, ekspedycje

IMPLEMENTATION ORDER:
1. Konfiguracja i18n: l10n.yaml, pubspec (flutter_localizations),
   pliki .arb (PL + EN) pokrywające WSZYSTKIE istniejące ekrany
2. Migracja istniejących widgetów na AppLocalizations (no hardcoded strings)
3. SettingsProvider + persist w app_settings (theme, language)
4. Ekran settings + wpis w sidebarze (dół)
5. Startup: odczyt ustawień przed MaterialApp (bez mrugnięcia domyślnym motywem)
6. Tests: persistencja providera, widget test przełączania motywu/języka

COMPLETION CRITERIA:
- Zmiana języka i motywu natychmiastowa, przetrwa restart;
  wszystkie istniejące ekrany przetłumaczone PL/EN;
  settings dostępne z dołu sidebaru

RULES:
1. Feature-first structure; mirror conventions of features/tasks/ exactly
2. Barrel exports only — hide impl and DAO internally
3. Status is source of truth on Task (getter, not column)
4. Riverpod: mutate providers OUTSIDE widget lifecycle — derive form
   state from parameters (family provider / route watch), never mutate
   in initState/build
5. UI layout rules from ARCHITECTURE.md: left sidebar = filters/nav,
   bottom = primary actions, top-right corner empty
6. Tests required after each layer; flutter analyze + flutter test
   must pass before proceeding
7. Do not rewrite working code from Stage 1 except minimal, justified
   integration points
8. NO hardcoded UI strings — every user-visible text goes through
   AppLocalizations (.arb, PL+EN), also for all future screens

WORKFLOW:
1. ContactsDao in local_db (schema tables already exist)
2. features/contacts/domain
3. features/contacts/data + mapper
4. Repository tests (in-memory drift)
5. features/contacts/presentation + linking UI in task form
6. Router: '/contacts', '/contacts/:id'


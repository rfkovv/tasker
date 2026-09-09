# AGENTS.md

PROJECT: TaskMaster (Flutter menedżer zadań)
ARCHITECTURE: See ARCHITECTURE.md — follow it strictly, no deviations without approval.

CURRENT PHASE: Stage 5.5 — Search (global) + contact expansion + filters

STAGE 5.5 SCOPE (do NOT exceed):
1. TIMEZONE SEARCH: dropdown strefy czasowej w settingsach z polem
   wyszukiwania (fuzzy, case-insensitive; lista stref IANA)
2. GLOBAL SEARCH (features/search):
   - Wejście: przycisk lupy w topbarze (centralnie) → overlay/pole
     z wynikami; skrót klawiaturowy Ctrl+K (desktop)
   - Wyniki pogrupowane sekcjami: Zadania | Osoby istotne;
     architektura pod przyszłe sekcje (lista sekcji = rejestrowana,
     nie hardcodowana)
   - Zadanie: klik → ekran detali; Kontakt: klik → detale kontaktu
   - Sortowanie wyników: dopasowanie tytułu (prefiks > substring),
     potem alfabetycznie; LIMIT wyników per sekcja (np. 10) +
     "pokaż więcej" → pełna lista zadań z filtrem tekstowym
   - Query przez repository (Case-insensitive LIKE), debounce input
3. CONTACT EXPANSION:
   - Kliknięcie kontaktu na liście → rozwinięcie z listą AKTYWNYCH
     zadań zlinkowanych z tym kontaktem (mini-kafelki)
   - Przycisk "Zobacz wszystkie zadania" → nawigacja do listy zadań
     z załączonym filtrem po kontakcie (TaskFilter.contactId — nowy
     wymiar filtra)
   - Aktywne filtry z nagłówka listy zawsze widoczne (badge)

OUT OF SCOPE: buildy Windows/Android, sync, lokalizacje pod ekspedycje

IMPLEMENTATION ORDER:
1. TaskFilter: dodanie contactId (query layer)
2. Search feature: search provider (fold results: tasks + contacts),
   overlay UI, keyboard shortcut
3. Contact expansion UI na liście kontaktów (aktywne zadania + link)
4. i18n PL/EN wszystkich nowych stringów
5. Tests: search unit (grupowanie, ranking), widget (rozwinięcie
   kontaktu, przycisk → lista z filtrem), analyze per warstwa

COMPLETION CRITERIA:
- Ctrl+K/overlay znajduje zadania i kontakty wspólnie;
  kontakt rozwija się z aktywnymi zadaniami; "zobacz wszystkie
  zadania" otwiera listę prefiltrowaną po kontakcie; strefa ma
  wyszukiwarkę; testy zielone

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


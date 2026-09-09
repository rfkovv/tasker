# AGENTS.md

PROJECT: TaskMaster (Flutter menedżer zadań)
ARCHITECTURE: See ARCHITECTURE.md — follow it strictly, no deviations without approval.

CURRENT PHASE: Stage 4 — Task detail screen, subtasks, comments

STAGE 4 SCOPE (do NOT exceed):
- Ekran detali zadania (/tasks/:id — routing istnieje, ekran nowy):
  nagłówek (tytuł, status, priorytet), pola editable
  (description, priority, dueDate z godziną), sekcje: subtasks,
  komentarze, Relevant Persons; akcje na dole (edit, status toggle)
- Subtasks: checklist w ramach zadania — dodawanie, odhaczanie
  (checkbox), usuwanie; zliczanie postępu na kafelku listy ("x/y")
- Komentarze: lista chronologiczna z timestampami; dodawanie przez
  pole na dole sekcji (zgodnie z layout rules); usuwanie SOFT delete
  (deletedAt) — spójnie z resztą systemu; BEZ pola autora (model
  użytkownika dopiero przy sync)
- Integracja: kliknięcie kafelka na liście → ekran detali
  (nie bezpośrednio do edycji); edit = przycisk na ekranie detali
- DAO: SubtasksDao + CommentsDao w local_db (tabele już w schemacie)
- Feature-first: rozszerzenie features/tasks (domain: Subtask,
  Comment, repozytorium), mirror konwencji istniejącego kodu

OUT OF SCOPE:
- kalendarz, Kanban, Gantt, drag&drop, lokalizacje kontaktów,
  sync, buildy Windows/Android, notyfikacje

IMPLEMENTATION ORDER:
1. Domain: Subtask, Comment, interfejsy repozytorium (watch, create,
   toggle, soft delete), mappery
2. DAO: SubtasksDao, CommentsDao (join per taskId, in-memory drift tests)
3. Detail screen: sekcje subtasks + komentarze + Relevant Persons,
   edycja pól, akcje na dole
4. List integration: kliknięcie → detale, progress "x/y" na kafelku
5. i18n: wszystkie nowe stringi przez AppLocalizations (PL+EN)
6. Tests: domain unit, DAO repository, widget test ekranu detali
   i progresu na kafelku

COMPLETION CRITERIA:
- Zadanie ma pełny ekran detali z checklistą subtasks i komentarzami;
  postęp "x/y" widoczny na liście; komentarze i subtasks przetrwają
  restart; usunięte komentarze nie wracają; wszystkie testy zielone

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


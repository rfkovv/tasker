# AGENTS.md

PROJECT: TaskMaster (Flutter menedżer zadań)
ARCHITECTURE: See ARCHITECTURE.md — follow it strictly, no deviations without approval.

CURRENT PHASE: Stage 3 — Task list redesign (tiles + Relevant Persons)

STAGE 3 SCOPE (do NOT exceed):
- task_tile.dart rozbudowa — kolejność treści:
  1) tytuł (prominent)
  2) skrócony opis (maxLines: 2, ellipsis)
  3) deadline (format daty; wizualne oznaczenie overdue — reuse)
  4) tagi jako chipy
  5) linkowane kontakty pod etykietą "Relevant Persons"
     (imiona jako chipy/avatary; UI-only naming — model i baza
     nadal "contacts", NIE zmieniamy nazw klas/tabel)
- Dane kontaktów dla kafelka: join przez publiczny interfejs
  features/contacts barrel (repository/provider) — NIE przez import
  z features/contacts/data; provider listy zadań dołącza nazwy kontaktów
- "Add task": ostatnia pozycja listy (footer tile) + warunkowy FAB
  (prawy dolny róg) TYLKO gdy lista przekracza wysokość okna
- Kontakty: brak zmian funkcjonalnych

OUT OF SCOPE: subtasks, komentarze, kalendarz, sync, ekspedycje

RULES (przypomnienie): DAG zależności — tasks mogą konsumować kontakty
tylko przez publiczny interfejs; zero importów z contacts/data

IMPLEMENTATION ORDER:
1. Joining provider (tasks + contact names per task)
2. task_tile redesign (content wg kolejności powyżej)
3. Footer "Add task" + conditional FAB (scroll check)
4. Widget tests: tile content, FAB conditional
5. analyze + testy per warstwa

COMPLETION CRITERIA:
- Kafelek pokazuje: tytuł, 2-liniowy skrócony opis, deadline
  (overdue wizualnie), tagi, "Relevant Persons";
  Add task jako ostatnia pozycja; FAB tylko gdy lista się nie mieści;
  wszystkie testy zielone

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


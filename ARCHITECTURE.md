# TaskMaster — Architektura

Aplikacja menedżera zadań (Flutter, offline-first).
Platformy docelowe: Windows, Linux, Android.
Dev environment: Linux.

## Zasady ogólne

1. **Feature-first**: każdy moduł to katalog `features/<nazwa>/` z własnym
   podziałem na `domain/`, `data/`, `presentation/`. Globalny podział na
   warstwy NIE stosujemy.
2. **DAG zależności**: moduły komunicują się wyłącznie przez publiczne
   interfejsy eksportowane w barrel file. Cykle zabronione.
3. **Offline-first, sync-ready**: stabilne UUID v4 od pierwszej migracji,
   kolumny `createdAt`/`updatedAt` (epoch millis) i `deletedAt` (soft delete)
   w każdej tabeli danych. Synchronizacja (timestamp-based) będzie dodana
   później bez przepisywania rdzenia.
4. **Material 3** — jednolity motyw od początku (unikać rozjazdu stylistyki
   między widokami).
5. **Riverpod — mutacje poza lifecycle**: providerów nie mutujemy
   w initState/build/dispose. Stan formularza derive'ujemy z parametrów
   (family provider / watch), nie "wpychamy" go w lifecycle widgetu.

## Zasady UI (desktop)
- Lewy sidebar: filtry/nawigacja pomocnicza
- Dół okna: akcje główne (Save itp.), SafeArea
- Prawy górny róg: pusty (docelowo pod menu/systemowe akcje)

## Stack

- Flutter (stable)
- Stan: Riverpod (codegen: @riverpod)
- Nawigacja: go_router
- Baza: drift (SQLite)
- Motyw: Material 3

## Struktura projektu (feature-first)

lib/
  app/
    main.dart               — runApp(ProviderScope(child: TaskMasterApp()))
    app_router.dart         — GoRouter: '/', '/tasks/:id'
    app_shell.dart          — adaptacyjny layout (desktop: nav rail; mobile: bottom nav)
  local_db/                 — wspólna warstwa bazy (drift), patrz niżej
  features/
    tasks/                  — etap 1
    contacts/               — etap 2
    settings/               — etap 3 (opcjonalnie)
  shared/                   — motyw, wspólne widgety, utilsy

Każdy feature: domain/ (encje, enumy, interfejs repozytorium),
data/ (implementacja + mapper), presentation/ (providers, screens, widgets),
plus barrel `<feature>.dart` eksportujący WYŁĄCZNIE: encje, interfejs
repozytorium, filtry, publiczne providery i ekrany. Implementacje i DAO
nigdy nie są eksportowane poza moduł.

## Schemat bazy (drift, schemaVersion = 1)

tasks
  id TEXT PK, title TEXT, description TEXT NULL,
  priority TEXT (enum TaskPriority: low/medium/high/urgent),
  status TEXT (enum TaskStatus: todo/inProgress/done) — ŹRÓDŁO PRAWDY,
  dueDate INT NULL, startDate INT NULL (pod Gantt, etap 7),
  ownerId TEXT (pod przyszły sync),
  createdAt INT, updatedAt INT, deletedAt INT NULL

tags
  id TEXT PK, name TEXT UNIQUE

task_tags (łącząca, composite PK)
  taskId TEXT FK -> tasks, tagId TEXT FK -> tags

subtasks
  id TEXT PK, taskId FK -> tasks, title TEXT, isCompleted BOOL, position INT,
  createdAt INT, updatedAt INT

comments
  id TEXT PK, taskId FK -> tasks, body TEXT, createdAt INT

contacts
  id TEXT PK, name TEXT, role TEXT NULL, email TEXT NULL, phone TEXT NULL,
  createdAt INT, updatedAt INT, deletedAt INT NULL

task_contacts (łącząca, composite PK — relacja wiele-do-wielu)
  taskId TEXT FK, contactId TEXT FK

task_dependencies (pod Gantt, etap 7)
  predecessorId FK, successorId FK

app_settings (key-value)
  key TEXT PK, value TEXT

Uwagi:
- Brak kolumny isDone (usunięta decyzją — source of truth = status;
  Task.isDone jako getter na encji domeny).
- Brak kolumny position w tasks (dodana w etapie 7 jako fractional
  indexing — kolizje reorder przy syncu rozwiązane leksykograficznie).
- Timestampy: epoch millis; ID: UUID v4.

## Komunikacja frontend ↔ dane

Logika bazodanowa przez repository pattern: UI zna WYŁĄCZNIE interfejs
TaskRepository (Riverpod provider). Mapper (task_mapper.dart) jako jedyny
punkt styku encji domeny z wierszami drift. DAO nigdy nie opuszcza modułu.

## Synchronizacja (PRZYSZŁOŚĆ — nie etap bieżący)

Zaprojektowana pod dodanie bez rewrite:
- soft delete (deletedAt) — kasowanie replikuje się jako rekord
- updatedAt jako podstawa LWW (last-write-wins)
- ownerId — deviceId profilu (UUID generowany raz, cache w app_settings)
- brak cykli: sync podpięty na poziomie repozytoriów, nie UI
Docelowa strategia sync (etap 6+, do wyboru: Syncthing/plik bazowy,
CRDT, własny serwer) — warstwa danych ma pozwalać na wpięcie bez zmian w UI.

## Plan wdrożenia (każdy etap kończy się działającą wersją)

1. Rdzeń zadań + persystencja (drift, CRUD, filtry, overdue, desktop dev)
2. Kontakty + linkowanie task↔contact (tworzenie kontaktu z formularza)
3. Subtasks + komentarze + detale ekranu zadania
4. Build Windows i Linux (release, CI: GitHub Actions runner windows)
5. Build/test Android (nawigacja mobilna, path_provider)
6. Przygotowanie warstwy pod sync (frakcyjne pozycje, migracje schematów)
7. Kanban, Kalendarz, Gantt

## Szczegóły etapu 1

local_db/:
  database.dart          — AppDatabase (drift), schemaVersion 1, MigrationStrategy
  tables/*.dart          — klasy tabel (jak wyżej)
  daos/tasks_dao.dart    — watchAllTasks(filter), watchTaskById, upsertTask,
                           softDeleteTask, updateStatus
  providers/database_provider.dart — @Riverpod(keepAlive: true)
  value_objects/owner_id.dart — UUID profilu, cache w app_settings

features/tasks/:
  domain/: task.dart (freezed, getter isOverdue, isDone),
           task_priority.dart, task_status.dart,
           task_repository.dart (interfejs: watchAll, watchById, create,
           update, updateStatus, delete), task_filter.dart
  data/:
    task_repository_impl.dart, task_mapper.dart
  presentation/:
    providers/task_list_provider.dart (Stream<List<Task>>, TaskFilter),
    task_form_provider.dart,
    screens/task_list_screen.dart, task_form_screen.dart,
    widgets/task_tile.dart, task_priority_badge.dart, overdue_indicator.dart
  tasks.dart (barrel: tylko Task, TaskRepository, TaskFilter,
  taskListProvider, TaskListScreen)

app/: main.dart, app_router.dart (GoRouter: '/', '/tasks/:id'), app_shell.dart

Kryterium ukończenia etapu 1: aplikacja odpala na desktopie, lista zadań
z SQLite, tworzenie/edycja/usuwanie (tytuł, opis, tagi, priorytet, termin),
wizualne oznaczenie przeterminowanych, dane przeżywają restart.
Testy: unit na isOverdue/filtrowaniu, repository test na
TaskRepositoryImpl (in-memory drift), widget test task_tile.

## Ścieżki platformowe (nota pod etapy 4–5)

Lokalizacja bazy przez path_provider:
- Android/iOS: getApplicationDocumentsDirectory()
- Linux: XDG data dir (~/.local/share/taskmaster)
- Windows: %APPDATA% (path_provider_windows)
Decyzja raz, helper w app/, żadnych hardcoded ścieżek w DAO.

## Aktualnie nieznane / otwarte

- Toggle done↔todo w liście zgubi informację o inProgress — świadome
  uproszczenie, do przeglądu w etapie 3.
- Sync: finalny mechanizm (serwer vs folder pliku) — pytania na etapie 6,
  architektura przygotowana pod każdy wariant.

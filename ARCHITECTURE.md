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
- UNIFIED HEADER HIERARCHY (all destinations, portrait + desktop):
  Row 1 (very top) = screen title (destination name, i18n);
  Row 2 (only if that menu HAS controls) = toolbar with ONLY that
  menu's controls — Tasks: Lista|Kalendarz + Filtruj (+ badge);
  Contacts: its filter control; Kosz: segmented Zadania|Kontakty +
  "Opróżnij kosz"; Settings: NO toolbar.
  Portrait mobile: title AND toolbar hide TOGETHER on scroll down,
  reappear on scroll up (shared DestinationBody → HideOnScrollHeader).
  Desktop (≥1000 px): both rows STATIC, always visible.
  Landscape/compact: UNCHANGED — no title, compact toolbar, floating
  search (re-verified, not modified by the hierarchy layer).
  Shared widget: lib/shared/destination_header.dart (DestinationBody) —
  the ONE place the title→toolbar hierarchy lives.
- SEARCH TRIGGER = floating circular button (FloatingSearchButton)
  EVERYWHERE a search trigger exists: portrait, landscape/compact AND
  desktop (tasks + contacts). Documented EXCEPTION to "top-right
  corner empty / primary actions at bottom": the floating search sits
  top-end of the content area (inside SafeArea, ≥48 dp, never covering
  interactive controls like the calendar view switcher). Old title-row
  (AppBar) search triggers REMOVED. Settings: no search trigger (no
  new controls). Kosz: NO search trigger (trash is not searchable in
  MVP). Single shared search overlay + Ctrl+K untouched.
  Hide while /search overlay is open.
- Sidebar (desktop): NavigationRail z głównymi destynacjami (Tasks,
  Contacts, Kosz); Settings przyklejony do DOŁU panelu (poza railem,
  pod separatorem). Kosz = trzecia pozycja w raile, PRZED
  separatorem/Ustawieniami. selectedIndex raila defensywnie mapowany
  z trasy (nieznana trasa → index 0; /trash → 2; /settings →
  selectedIndex null), nigdy poza zakresem destinations.
  Mobile NavigationBar: Tasks → Contacts → Kosz → Settings
  (Kosz na trzeciej pozycji).
- Filtry zadań/kontaktów: przycisk "Filter" w toolbarze (dropdown:
  status, priorytet, tagi, hide done / inicjał kontaktu) + badge
  podsumowania w tym samym wierszu; lewy sidebar tylko nawigacja
- Unified mobile toolbar (tasks, narrow/mobile — portrait AND compact
  landscape): ONE row = segmented control Lista|Kalendarz + przycisk
  Filtruj + aktywny badge filtra/sortowania; chuje się przy scrollu w
  dół i wraca przy scrollu w górę (wspólny widget HideOnScrollHeader —
  JEDNO miejsce w codebase z logiką scroll-hide). Filtr dropdown wciąż
  otwiera się pod przyciskiem Filtruj. Floating search button bez
  zmian (compact only, poza toolbarem; portrait top bar bez zmian).
  Desktop (≥ 1000 px): zero zmian — filter row wewnątrz TaskListScreen.
- Task tile: title → summary (2 linie) → deadline (+overdue) → tagi →
  "Relevant Persons" (chipy kontaktów)
- Nazewnictwo UI: kontakty w kontekście zadania = "Relevant Persons";
  moduł i baza danych nadal "contacts" (nie zmieniamy modelu)
- Add task / Add contact: ostatnia pozycja listy; FAB (prawy dolny róg)
  tylko gdy lista przekracza wysokość okna
- Layout dwupanelowy (lista | kalendarz) zależy WYŁĄCZNIE od
  rozmiaru okna; stany listy (filtry, sortowanie, pusty wynik)
  nigdy nie wpływają na obecność panelu kalendarza
- Global search: jedna współdzielona instancja UI (overlay + Ctrl+K
  jako skrót do tej samej instancji); przycisk powrotu obowiązkowy;
  otwarcie wyniku zamyka wyszukiwanie i nawiguje standardowo
  (bez równoległych tras/overlay-i)
- Compact mode (mobile): aktywowany WYŁĄCZNIE przez rozmiar okna
  (mobile branch active: width < kDesktopBreakpoint = 1000 — ten sam
  warunek co bottom NavigationBar — AND height < kCompactHeightLimit
  = 600 logical px) —
  nigdy przez Orientation/OrientationBuilder. W compact mode:
  a) pasek tytułu (AppBar) ukryty na ekranach list
  b) globalny search trigger = pływający okrągły przycisk
     (FloatingSearchButton) w prawym górnym rogu obszaru treści:
     wewnątrz SafeArea (nigdy pod system bars), margines 12 dp,
     touch target ≥ 48 dp; nigdy nie zasłania przełącznika widoku
     kalendarza (week/month/quarter — nagłówek kalendarza rezerwuje
     miejsce w compact); nie koliduje z warunkowym Add FAB (ten
     zostaje w dolnym prawym rogu); na widoku listy unosi się nad
     treścią (standardowy overlay); otwiera TĘ SAMĄ wspólną nakładkę
     wyszukiwania (pojedynczy entry point, pojedynczy overlay);
     ukryty gdy nakładka wyszukiwania jest otwarta
  c) NavigationBar: wysokość ~56 dp, etykiety ukryte (ikony);
     touch targets ≥ 48 dp
  d) edge-to-edge: content, footer i NavigationBar respektują
     SafeArea/system insets (nic nie renderuje się pod system bars)
- Poza mobile narrow (desktop ≥ 1000 px, wysokie tablety): layout
  pozostaje piksel-identyczny z zachowaniem dotychczasowym; portrait
  mobile traci TYLKO drugi wiersz chrome (scalony unified toolbar),
  top bar (title + search) bez zmian

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

## Plan wdrożenia (zaktualizowany)

1. Rdzeń zadań + persystencja ✅ (done)
2. Kontakty + linkowanie ✅ (etap 2)
3. Subtasks + komentarze + detale ekranu zadania
4. Widok Kalendarza + unscheduled backlog (drag & drop / click-to-match;
   pattern:  drag z backlogu na dzień = ustaw dueDate; drag z dnia
   na backlog = usuń termin; click-to-match jako fallback)
5. Build Windows i Linux (release, CI: GitHub Actions runner windows)
6. Build/test Android (nawigacja mobilna, path_provider, long-press drag)
7. Przygotowanie warstwy pod sync
8. Kanban, Gantt

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

## Feature "Ekspedycje" (features/expeditions) — etap daleki

Przeznaczenie: planowanie tras służbowych — trasa zawsze zaczyna się
i kończy w siedzibie (HQ), przez wybrane przystanki. Planowanie statyczne
(obliczenie i zaplanowanie trasy), NIE nawigacja na żywo (przyszła opcja).

### Model danych (nowa kolekcja, migracja schematu)

expedition
  id TEXT PK, name TEXT,
  ratePerKm REAL            — kopia wartości z momentu planowania
                              (koszt ma być czytelny offline),
  status enum (draft/planned/done),
  createdAt INT, updatedAt INT, deletedAt INT NULL

expedition_stop (przystanek; kolejność = order INT)
  id TEXT PK, expeditionId FK, taskId FK NULL,
  locationId TEXT (references punkt geokodowany),
  dwellMinutes INT          — czas postoju (manualna zmiana = cascade),
  frozen: legDistanceKm REAL, legDurationMin INT,
          etaMin INT, etdMin REAL NULL (odliczone od startu),
  createdAt, updatedAt

expedition_tasks (composite PK)   — który task należy do ekspedycji
  taskId FK, expeditionId FK

### Zmiany w istniejących modelach (mała migracja — wcześniej!)

- Kontakt: kolumna location (nazwa + lat + lon; geokodowanie Nominatim;
  wpisanie z mapy, UI-driven)
- Task: kolumna location (edytowalna; DEFAULT = lokalizacja
  primary contact). Wprowadzamy pojęcie "primary contact" — flaga
  isPrimary na relacji task_contact (dokładnie jeden na task);
  NIE dziedziczymy z "pierwszego kontaktu z listy"
- HQ: jedna globalna lokalizacja z settingsów (klucz hq_location)

### Wyliczenia (logika domenowa, testowalna bez UI)

- Trasa: OSRM route service — geometria, dystans per leg,
  czas przejazdu (duration per leg). Kolejność: HQ → przystanki
  (kolejność ręczna, draggable) → HQ
- Dystans całkowity = suma odcinków geometrii (km)
- Koszt = dystans × stawka (stawka z settingsów lub kafelka)
- Harmonogram: eta_i = etd_(i-1) + legDuration (z OSRM);
  etd_i = eta_i + postój_i; ręczna zmiana czasu postoju dowolnego
  przystanku przelicza wszystkie kolejne (kaskadowo);
  wyświetlany też ETA powrotu do HQ
- Wartości frozen (legDistance, legDuration, eta/etd) trzymamy
  w rekordach przystanków — plan oglądalny offline, choć liczony online

### Źródła danych (OTWARTE USŁUGI)

- Routing/travel time: OSRM (demo api dla dev; self-host docelowo)
  lub OpenRouteService (darmowy klucz)
- Geokodowanie: Nominatim — wybór lokalizacji Z MAPY (zasada UI-driven,
  nie ręczne wpisywanie); fallback: ręczne wpisanie adresu
- Kafelki mapy: OpenStreetMap via flutter_map
- UWAGA OFFLINE: jedyny moduł wymagający połączenia (kafelki + routing).
  Wymaga łączności w fazie MVP; cache kafelków i offline routing
  (Valhalla/GraphHopper) to osobny etap przyszły

### UI (zgodnie z zasadami layoutu)

- Góra zakładki: edytowalne kafelki konfiguracji — siedziba, stawka km,
  domyślny czas postoju (siedziba i stawka globalne — app_settings;
  stawka per-ekspedycja tylko jeśli pola wymagają rozbieżności)
- Środek: mapa z wyrysowaną trasą (flutter_map + polyline)
- Prawy panel: per przystanek nazwa (z zadania), dystans odcinka,
  czas przyjazdu/odjazdu, czas postoju (edytowalny); na dole:
  łącznie dystans i koszt
- Wybór zadań: na początku tworzenia ekspedycji — lista zadań z
  filtrem "ma lokalizację" (checkboxy); przystanek = lokalizacja zadania
- Kolejność przystanków: drag & drop w prawym panelu;
  optymalizacja kolejności (TSP) jako przyszła opcja
- Ręczna zmiana czasu postoju dowolnego przystanku przelicza
  wszystkie ETA/ETD downstream (cascade) + czas powrotu do HQ

### Zależności modelowe (wymagane PRZED tym etapem)

- Migracja schematu: location na contact i task, flaga primary
  contact, kolekcje expeditions
- i18n: wszystkie stringi modułu przez gen_l10n (PL/EN)
- Kolejność przystanków: ręczna; optymalizacja TSP jako przyszła opcja
  
## Aktualnie nieznane / otwarte

- Toggle done↔todo w liście zgubi informację o inProgress — świadome
  uproszczenie, do przeglądu w etapie 3.
- Sync: finalny mechanizm (serwer vs folder pliku) — pytania na etapie 6,
  architektura przygotowana pod każdy wariant.
  
  ## SYNC (Stage 8) — specyfikacja

**Zasada nadrzędna**: dumb server, smart client. Serwer przechowuje i porządkuje,
klient scalalnia. Cała logika merge po stronie klienta (Dart, testowalna).

### Serwer (Proxmox)
- Dart Frog, Postgres (kontener), Caddy reverse proxy (TLS, Let's Encrypt).
- Auth: POST /auth/register, POST /auth/login (email+hasło, argon2/bcrypt),
  token 32B losowych, serwer trzyma tylko hash. MVP: jedno konto (owner).
- Tabele serwera: users, auth_tokens, sync_events
  (owner_id, seq BIGSERIAL globalny, table_name, row_id, payload JSONB,
  updated_at, device_id, received_at).
- POST /sync/push {events:[…]} → dopisuje eventy, zwraca {firstSeq,lastSeq}.
- GET /sync/pull?after=<seq>&limit=N → eventy ownera o seq>after, ORDER BY seq,
  {events, nextCursor, hasMore}.
- Serwer NIE rozstrzyga konflitków. Walidacja: whitelist nazw tabel, limit rozmiaru
  batcha, rate limit.

### Klient (drift)
- features/sync (domain/data/presentation). Warstwa danych używa wspólnego
  modułu bazy (local_db) BEZPOŚREDNIO — to infrastruktura, nie import cudzego
  feature. Zakaz importu presentation innych features.
- Migracje: sync_outbox (tableName, rowId, payload, createdAt, attempts),
  sync_inbox (odłożone eventy z brakującymi rodzicami), sync_conflicts (log),
  app_settings + deviceId (UUID v4 przy pierwszym starcie), lastSyncCursor,
  serverUrl, authToken, syncEnabled.
- Outbox: KAŻDA mutacja repozytorium zapisuje wiersz do sync_outbox W TEJ SAMEJ
  TRANSAKCJI drift (pełny stan po mutacji, tombstone = wiersz z deletedAt).
  Push: batch z outbox → POST /sync/push → usunięcie po ack. Błędy: backoff
  wykładniczy + attempts.
- Pull: GET po kursorze → aplikowanie eventów po kolei w kolejności seq,
  transakcyjnie, kursor zapisywany razem z ostatnim aplikowanym eventem
  (odporność na crash w trakcie).
- Dwufazowość per batch: najpierw encje (tasks, tags, contacts), potem
  relacje/dzieci (subtasks, comments, task_tags, task_contacts,
  task_dependencies). Event z brakującym rodzicem → sync_inbox, retry przy
  każdym syncu, NIE blokuje reszty.
- DAG: przed aplikacją krawędzi task_dependencies — detekcja cyklu (DFS) na
  aktualnym grafie; cykl → skip + wpis do sync_conflicts, nie przerywa syncu.

### Semantyka konfliktów — POPRAWKA (po decyzji o Koszu)
- Row-level LWW, cały rekord: wygrywa wiersz o większym
  max(updatedAt, deletedAt) — niezależnie czy to edycja, usunięcie
  czy przywrócenie. Tiebreak: deviceId; identyczne → no-op.
- Przywrócenie z kosza = zwykła edycja (deletedAt → null, bump updatedAt).
- Trwałe usunięcie = purge-event w logu; urządzenia hard-delete'ują
  lokalnie; serwer trzyma tombstone do TTL (90 dni, konfigurowalne);
  bez protokołu ack w MVP.

### Kosz (model usuwania)
- Zero nowych tabel fizycznych: kosz = wiersze z deletedAt != null,
  surfaced w dedykowanej destynacji "Kosz" (segmented Zadania Kontakty).
- Usunięcie taska soft-kasuje kaskadowo potomków w tej samej transakcji;
  przywrócenie przywraca task + wszystkie aktualnie usunięte wiersze
  go referencjonujące (subtasks, comments, task_tags,
  task_dependencies, task_contacts). Kontakt analogicznie
  (linki, NIE zadania po drugiej stronie).
- Trwałe usunięcie WYŁĄCZNIE ręczne w Koszu ("Opróżnij kosz" +
  confirm). Żadnych auto-purge, nigdzie.
- UI: destynacja /trash. Desktop rail — trzecia pozycja, PRZED
  separatorem/Ustawieniami. Mobile NavigationBar — trzecia pozycja
  (Kosz), Ustawienia czwarte. Header hierarchy: tytuł "Kosz" na górze,
  toolbar poniżej (segmented Zadania|Kontakty + "Opróżnij kosz").
  NO search trigger (brak floating lupy w Koszu — kosz nie jest
  przeszukiwalny w MVP). Portrait scroll-hide, desktop static — te same
  reguły co każda destynacja. Per-item restore button na liśmie.
  "Opróżnij kosz" = jedyny nieodwracalny action w aplikacji; dialog
  potwierdzenia before hard DELETE wszystkich soft-deleted rows w
  jednej transakcji. Restore = zwykła edycja (deletedAt → null, bump
  updatedAt). Przywrócenie taska czyści deletedAt na tasku ORAZ na
  wszystkich aktualnie usuniętych wierszach go referencjonujących
  (comments — jedyne tabele z deletedAt poza tasks/contacts; subtasks,
  task_tags, task_dependencies, task_contacts nie mają kolumny
  deletedAt, wiersze pozostają nietknięte). Przywrócenie kontaktu
  przywraca tylko kontakt (linki task_contacts pozostają) — NIE
  przywraca zadań po drugiej stronie linku.

### UI/UX
- Settings: sekcja Sync — server URL, login, status (idle/push/pull/error,
  timestamp), "Synchronizuj teraz", lista konfliktów DAG.
- Auto-sync: przy starcie aplikacji + debounce 4 s po mutacjach; manual:
  przycisk. Wszystkie stringi przez .arb (PL+EN).
- app_settings NIE synchronizowane (per urządzenie).

### Plan implementacji (warstwy, MODEL PŁATNY)
1. Serwer: szkielet Dart Frog + Postgres + auth + healthcheck; deploy za Caddy.
2. Klient: migracje + outbox zapisywany przez WSZYSTKIE repozytoria.
3. Push path + backoff + testy.
4. Pull path: inbox, LWW, dwufazowość, cycle guard + matryca testów
   konfliktów (edycja↔edycja, edycja↔usunięcie, cykl DAG, przerwany sync,
   out-of-order eventy, brakujący rodzic).
5. Settings UI sync + status provider.
6. Test integracyjny dwuetapowy (Linux + Android): równoległe operacje z
   matrycy → identyczna zawartość baz.

### Kryteria domknięcia Stage 8
Dwie instancje osiągają identyczną zawartość bazy po równoległych operacjach
z matrycy; sync przeżywa restart aplikacji i utratę sieci; analyze + testy
zielone; serwer healthcheck za TLS.

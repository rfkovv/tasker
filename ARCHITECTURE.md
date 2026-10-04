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
   w każdej tabeli danych. Synchronizacja: ZAIMPLEMENTOWANA (Stage 8b–8c,
   patrz sekcja SYNC — as-built).
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
  menu's controls — Tasks: Lista Kalendarz + Filtruj (+ badge);
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
  Filtruj + aktywny badge filtra/sortowania; chowa się przy scrollu w
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
  = 600 logical px) — nigdy przez Orientation/OrientationBuilder.
  W compact mode:
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
- Sync server: Dart (dart:io HttpServer, stdlib only, zero runtime
  deps) — patrz sekcja SYNC

## Struktura projektu (feature-first)

lib/
  app/
    main.dart               — runApp(ProviderScope(child: TaskMasterApp()))
    app_router.dart         — GoRouter
    app_shell.dart          — adaptacyjny layout (desktop: nav rail; mobile: bottom nav)
  local_db/                 — wspólna warstwa bazy (drift), patrz niżej
  features/
    tasks/                  — etap 1
    contacts/               — etap 2
    settings/               — etap 3
    sync/                   — Stage 8b/8c (patrz SYNC — as-built)
  shared/                   — motyw, wspólne widgety, utilsy
server/                     — dumb sync server (Stage 8c-1; osobna paczka
                             Dart, wykluczona z analizy Fluttera w
                             analysis_options.yaml)

Każdy feature: domain/ (encje, enumy, interfejs repozytorium),
data/ (implementacja + mapper), presentation/ (providers, screens, widgets),
plus barrel `<feature>.dart` eksportujący WYŁĄCZNIE: encje, interfejs
repozytorium, filtry, publiczne providery i ekrany. Implementacje i DAO
nigdy nie są eksportowane poza moduł.
WYJĄTEK: features/sync — warstwa data sync używa local_db BEZPOŚREDNIO
(infrastruktura, nie import cudzego feature); zakaz importu presentation
innych features nadal obowiązuje.

## Schemat bazy (drift, schemaVersion = 4)

tasks
  id TEXT PK, title TEXT, description TEXT NULL,
  priority TEXT (enum TaskPriority: low/medium/high/urgent),
  status TEXT (enum TaskStatus: todo/inProgress/done) — ŹRÓDŁO PRAWDY,
  dueDate INT NULL, startDate INT NULL (pod Gantt),
  ownerId TEXT (deviceId profilu),
  createdAt INT, updatedAt INT, deletedAt INT NULL

tags
  id TEXT PK, name TEXT UNIQUE

task_tags (łącząca, composite PK)
  taskId TEXT FK -> tasks, tagId TEXT FK -> tags

subtasks
  id TEXT PK, taskId FK -> tasks, title TEXT, isCompleted BOOL, position INT,
  createdAt INT, updatedAt INT

comments
  id TEXT PK, taskId FK -> tasks, body TEXT, createdAt INT,
  updatedAt INT, deletedAt INT NULL

contacts
  id TEXT PK, name TEXT, role TEXT NULL, email TEXT NULL, phone TEXT NULL,
  createdAt INT, updatedAt INT, deletedAt INT NULL

task_contacts (łącząca, composite PK)
  taskId TEXT FK, contactId TEXT FK

task_dependencies (pod Gantt)
  predecessorId FK, successorId FK

app_settings (key-value, NIE synchronizowane — per urządzenie)
  key TEXT PK, value TEXT
  (klucze sync: deviceId, sync cursor, lastSyncedAt)

sync_outbox (Stage 8b-1; transactional enqueue, FIFO, dedup przy pushu)
  tableName, rowId, payload, createdAt (+ attempts wg implementacji)

Uwagi:
- Brak kolumny isDone (source of truth = status; Task.isDone getter).
- Timestampy: epoch millis; ID: UUID v4.
- Dostępu do bazy w kontekście sync NIE dodaje się przez repozytoria —
  silnik sync (features/sync/data) używa drift bezpośrednio.

## Komunikacja frontend ↔ dane

Logika bazodanowa przez repository pattern: UI zna WYŁĄCZNIE interfejs
TaskRepository (Riverpod provider). Mapper (task_mapper.dart) jako jedyny
punkt styku encji domeny z wierszami drift. DAO nigdy nie opuszcza modułu.
(Wyjątek: silnik sync — patrz wyżej.)

## SYNC (Stages 8b–8c) — AS-BUILT (stan faktyczny; sekcja autorytatywna)

**Zasada nadrzędna**: local-first, dumb server, smart client. Lokalna baza
(drift, v4) jest jedynym źródłem prawdy; aplikacja w pełni funkcjonalna
offline. Serwer przechowuje i porządkuje, klient scalalnia. Cała logika
merge po stronie klienta (Dart, testowalna). Serwer ma ZERO wiedzy o
tabelach i domenach.

### Komponenty (lib/features/sync/)
- **Outbox** (8b-1): każda mutacja whitelisted tabeli enqueue'uje event
  W TEJ SAMEJ transakcji drift.
- **Push engine** (8b-2): outbox FIFO, dedup po (tableName, rowId) z
  zachowaniem najnowszego, pominięcie brakujących wierszy, kolejność
  parents-first (tasks → tags/contacts → subtasks/comments → linki),
  push przez transport, atomowe czyszczenie batcha. `fullPush()` (8c-3):
  wszystkie wiersze whitelisted tabel BEZ outboxa (tylko initial sync).
- **Pull engine** (8b-3): `pullAndMerge(cursor)`, domyślnie
  `persistCursor: true` (initial sync jako jedyny wyjątek). Tabele danych:
  LWW po `max(coalesce(updatedAt, createdAt), coalesce(deletedAt, 0))`
  — soft-delete jest edycją. Incoming wygrywa tylko przy STRICTE większym.
  Tabele join (task_tags, task_contacts, task_dependencies): pure
  add-wins — brak linku lokalnie → insert; obecny → no-op; incoming
  removal → ZAWSZE skip (conflictLost). Zastosowane eventy NIGDY nie
  enqueue'ują do outboxa (no echo).
- **Coordinator** (8b-4 + 8c-3): sesja = push → pull → persist
  lastSyncedAt (app_settings, per-device). Triggery: watch na outbox +
  3 s debounce (koaleskuje burst), startup (post-frame), manualne
  `syncNow()`. Sesje koalesują (re-entrant wywołania dzielą Future).
  Failure → backoff wykładniczy 5 s → ×2 → cap 15 min, jitter ±20 %
  (injectable), reset po sukcesie; pauza w tle (AppLifecycle), resume na
  foreground; mutation debounce anuluje pending backoff.
- **Initial sync** (null cursor, 8c-3): pull (cały log) → fullPush() →
  pull ponownie → persist kursora. Nigdy nie enqueue'uje całej bazy.
- **Transport** (8c-2): `HttpSyncTransport` na dart:io HttpClient (stdlib;
  `allowSelfSigned` wymaga badCertificateCallback — dlatego nie package:http).
  Push chunkowany ≤ 200/request; pull: paginacja (limit 500, follow
  hasMore) W RAMACH jednego wywołania — kontrakt silnika: "wszystko od
  kursora". Zero retry w transporcie. Timeouty: connect 5 s, request 30 s.
- **Config** (8c-4): compile-time przez --dart-define: SYNC_BASE_URL,
  SYNC_API_KEY, SYNC_ALLOW_SELF_SIGNED. Dev fallbacki: localhost:8080,
  placeholder key, self-signed=true. Release bez SYNC_BASE_URL → głośne
  ostrzeżenie startupowe. Endpoint jest częścią WYDANIA aplikacji, NIE
  daną użytkownika; jeden serwer; brak konfiguracji runtime.

### Serwer (server/, 8c-1)
Dart, stdlib only, zero runtime deps; cel deploy: Proxmox LXC.
- POST /events (Bearer auth, constant-time compare; batch ≤ 200, inaczej
  413) → { accepted, firstSeq, lastSeq }
- GET /events?since=<seq>&limit=<n> (since WYŁĄCZNY; default 500,
  max 1000) → { events, nextCursor, hasMore }
- GET /health (bez auth) → { ok, lastSeq }
Storage: append-only NDJSON (SYNC_LOG_PATH); ack ⇒ flush() (trwałość na
kill-process; pełna odporność na utratę zasilania wymagałaby fsync —
udokumentowane w kodzie, patrz Backlog #5). Seq recovery po restarcie:
max(file)+1. Konfiguracja env: SYNC_HOST, SYNC_PORT, SYNC_API_KEY,
SYNC_LOG_PATH, SYNC_CERT_PATH/SYNC_KEY_PATH (HTTPS; brak → plain HTTP
+ ostrzeżenie na stderr). SIGTERM → drain in-flight, flush, exit 0.

### Semantyka protokołu
- Log serwera może zawierać duplikaty eventów (retry idempotent):
  nieszkodliwe — merge po stronie klienta dedupuje po (tableName, rowId).
- Kursor (app_settings, per-device) = seq serwera. lastSyncedAt =
  wall-clock ostatniej udanej sesji (app_settings, per-device).

### Konwergencja usuwania (istotne!)
- Soft-delete konwerguje jako zwykła edycja (LWW na deletedAt).
- "Opróżnij kosz" (hard delete lokalny) NIE emituje jeszcze purge-eventów
  — wiersze odrpcone z kosza mogą wrócić na urządzeniu z innego
  urządzenia po pullu. Obsługiwane przez protokół purge (Backlog #7).
- Removals linków join-tables NIE konwergują (pure add-wins). Link usunięty
  na jednym urządzeniu zostaje na innych — do czasu zmiany protokołu
  (Backlog #6). NIE poprawiać ad hoc.

### Zgodność ze starą specyfikacją Stage 8 (NIEWYKONANE punkty)
Kontakt z Postgres/auth/inbox został świadomie porzucony przy pracach:
- Dart Frog + Postgres + Caddy → zamiast tego stdlib server + NDJSON
  (dumb invariant, minimalizm); autoryzacja: statyczny Bearer API key
  (konto ownera nie istnieje), brak sync_inbox (zamiast tego kolejność
  parents-first + skip), brak sync_conflicts (liczniki w PullSummary),
  brak rate limit, brak TTL tombstone'ów, brak purge-eventów, brak
  detekcji cykli DAG (brak CRUD dependencies), brak UI konfiguracji
  (endpoint compile-time). Wszystkie te punkty — patrz Backlog.

## Plan wdrożenia (każdy etap kończy się działającą wersją)

1. Rdzeń zadań + persystencja ✅
2. Kontakty + linkowanie ✅
3. Subtasks + komentarze + detale ekranu zadania ✅
4. Widok Kalendarza + unscheduled backlog ✅
5. Build Windows i Linux ✅
6. Build/test Android ✅
7. Przygotowanie warstwy pod sync ✅ (7.5: landscape polish ✅)
8. SYNC — Stage 8b (silnik lokalny: outbox/push/pull-LWW/coordinator) ✅
   + Stage 8c (server/transport/backoff/config) ✅ + Stage 8d (UI sync:
   status + "Synchronizuj teraz") — BIEŻĄCY
9. Kanban, Gantt (przyszłość)

## Szczegóły etapu 1

local_db/:
  database.dart          — AppDatabase (drift), MigrationStrategy
  tables/*.dart          — klasy tabel
  daos/tasks_dao.dart    — watchAllTasks(filter), watchTaskById, upsertTask,
                           softDeleteTask, updateStatus
  providers/database_provider.dart — @Riverpod(keepAlive: true)
  value_objects/owner_id.dart — UUID profilu, cache w app_settings

app/: main.dart, app_router.dart, app_shell.dart

## Ścieżki platformowe (nota pod etapy 4–5)

Lokalizacja bazy przez path_provider:
- Android/iOS: getApplicationDocumentsDirectory()
- Linux: XDG data dir (~/.local/share/taskmaster)
- Windows: %APPDATA% (path_provider_windows)
Decyzja raz, helper w app/, żadnych hardcoded ścieżek w DAO.

## Feature "Ekspedycje" (features/expeditions) — etap daleki

[NIEZMIENIONE — treść sekcji jak w dotychczasowej wersji pliku]

## BACKLOG (kolejność wg priorytetu)

1. **Domena + Let's Encrypt + wyłączenie self-signed**: certyfikat LE
   na Proxmoxie → SYNC_CERT_PATH/SYNC_KEY_PATH; potem w apce default
   SYNC_ALLOW_SELF_SIGNED=false i usunięcie flagi.
   Źródło: ustalenie 8c-4 ("IP teraz, domena później").
2. **Backup logu serwera cronem** (host Proxmoxa, poza kontenerem):
   codziennie cp/rsync SYNC_LOG_PATH na drugą lokację. Jedyna kopia
   danych poza urządzeniami.
3. **Edycja komentarzy (UI)**: musi bumpować updatedAt (LWW; invariant
   w AGENTS.md > RULES 11).
4. **CRUD zależności (task_dependencies)**: każdy CRUD enqueue'uje eventy
   outboxa; wdrożenie od razu z detekcją cykli DAG (DFS) przy pullu
   (z dawnej specyfikacji Stage 8 — teraz z Backlogiem).
5. **fsync / SQLite dla logu serwera**: flush() = trwałość na
   kill-process, nie na utratę zasilania hosta. Komentarz w
   server/lib/src/event_log.dart.
6. **Zbieżność removalów join-tables**: zmiana protokołu — purge-event
   dla join tables rozstrzygany przez total order logu serwera.
   Zmiana server + pull engine RAZEM; nie robić ad hoc.
7. **Purge-eventy dla "Opróżnij kosz"**: hard delete lokalny ma emitować
   purge-event; urządzenia hard-delete'ują lokalnie; docelowo TTL
   tombstone'ów po stronie serwera. Do czasu wdrożenia: wiersze
   opróżnione z kosza mogą wrócić po pullu z innego urządzenia
   (świadome ograniczenie).
8. **Sync conflicts UI** (dawne sync_conflicts): w MVP liczniki
   skipped/conflictLost w PullSummary; UI listy konfliktów — dopiero
   gdy pojawi się pierwszy realny konflikt do pokazania.

## Aktualnie nieznane / otwarte

- Toggle done↔todo w liście zgubi informację o inProgress — świadome
  uproszczenie, do przeglądu w etapie 3.
- (usunięto — sync zdecydowany i wdrożony, patrz SYNC as-built)

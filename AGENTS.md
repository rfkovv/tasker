# AGENTS.md

PROJECT: TaskMaster (Flutter menedżer zadań)
ARCHITECTURE: See ARCHITECTURE.md — follow it strictly, no deviations without approval.

CURRENT PHASE: Stage 7 — Android build

STAGE 7 SCOPE (do NOT exceed):
- Konfiguracja platformy android/ w projekcie Flutter (jeśli
  brak: flutter create --platforms=android .)
- Ścieżka bazy danych: getApplicationDocumentsDirectory()
  (zgodnie z ARCHITECTURE.md — drift path strategy per platform)
- Release build: flutter build apk --release (debug build do dev na
  telefonie: flutter run)
- Signature config: debug keystore wystarczy na start (release
  signing — osobny krok przy publikacji; SKONFIGUROWAĆ ale bez
  realnego keystore produkcyjnego)
- Ikona aplikacji + splash (flutter_launcher_icons — podstawowe)
- Test na urządzeniu/emulatorze: CRUD, persystencja, drag & drop
  kalendarza (dotyk = long-press drag), klawiatura ekranowa
  nie zasłania Save (resizeToAvoidBottomInset)

OUT OF SCOPE: Play Store publishing, iOS, notyfikacje, sync

IMPLEMENTATION ORDER:
1. flutter create --platforms=android (uważać: NIE nadpisać lib/)
2. Drift database path dla Android (getApplicationDocumentsDirectory)
3. APK release build + instalacja (adb install)
4. Test dotykowy DnD + klawiatura
5. README: sekcja Android build

COMPLETION CRITERIA:
- flutter run -d <device> działa z Linuksa (USB debug lub emulator)
- Release APK instaluje się i działa; zadania persystują;
  drag & drop działa na dotyk

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


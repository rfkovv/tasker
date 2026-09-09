# AGENTS.md

PROJECT: TaskMaster (Flutter menedżer zadań)
ARCHITECTURE: See ARCHITECTURE.md — follow it strictly, no deviations without approval.

CURRENT PHASE: Stage 5 — Calendar view + drag & drop scheduling

STAGE 5 SCOPE (do NOT exceed):
- UKŁAD: ekran zadań dzieli się na dwie strefy obok siebie:
  lewa = istniejąca lista zadań (bez zmian funkcjonalnych),
  prawa = siatka kalendarza. Backlog = istniejąca lista zadań
  (NIE tworzymy osobnego UI "unscheduled backlog")
- KALENDARZ: siatka miesięczna; zadania z dueDate jako kafelki
  w komórkach dni; przełącznik widoku tydzień/miesiąc/kwartał
  (domyślnie miesiąc)
- DRAG & DROP (pełna symetria):
  a) zadanie bez terminu z listy → komórka dnia = ustaw dueDate
     (godzina domyślna z ustawień)
  b) kafelek na kalendarzu → inna komórka = zmiana dueDate
  c) kafelek z kalendarza → lista (backlog) = dueDate NULL
- Termin zmienia się WYŁĄCZNIE przez drag & drop — zero ręcznego
  wpisywania daty w tym widoku (edycja godziny zostaje w formularzu)
- Ustawienia (etap 2.5): klucz default_due_time (startowo 07:00,
  edytowalny), selektor strefy czasowej (timezone-aware: porównania
  i zapisy UTC, wyświetlanie wg strefy z ustawień)
- Deadliny widoczne na kafelku kalendarza = tytuł + godzina;
  overdue styling reused

OUT OF SCOPE: nawigacja na żywo, notyfikacje, edycja zadania z
kafelek kalendarza (otwieranie detali — tak), kwartał poza prostą
siatką, cykliczne zadania

IMPLEMENTATION ORDER:
1. Layout: dwukolumnowy ekran zadań (lista | kalendarz) + przełącznik
   miesiąc/tydzień/kwartał (nawigacja bez zmiany destynacji)
2. Rendering: zadania z dueDate na siatce (group by day, strefa-aware)
3. DnD: LongPressDraggable/Draggable na kafelkach listy i siatki,
   DragTarget na komórkach + lista jako target (zdjęcie terminu)
4. Logika domeny: mapowanie drop→dueDate (data komórki + default
   time + timezone), testy jednostkowe (strefy czasowe!)
5. i18n: nowe stringi PL/EN
6. Tests: unit (date mapping, strefy), widget (drop = dueDate update,
   drop na listę = null), analyze per warstwa

COMPLETION CRITERIA:
- Drag zadania z listy na dzień ustawia termin (widoczny na kafelku
  i w formularzu z godziną 07:00); przeciągnięcie między dniami
  zmienia termin; zwrot na listę usuwa termin; przełącznik
  tydzień/miesiąc/kwartał działa; wszystko przetrwa restart

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


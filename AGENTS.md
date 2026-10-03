# AGENTS.md

PROJECT: TaskMaster (Flutter menedżer zadań)
ARCHITECTURE: See ARCHITECTURE.md — follow it strictly, no deviations without approval.

CURRENT PHASE: 7.5 — COMPLETE (compact landscape mode, floating search button,
trigger-condition fix). All layers committed; analyze clean, tests green (207).

CONTEXT: Stage 7.5 delivered size-triggered compact mode for mobile landscape:
no top bar on list screens, floating circular search button (top-end, SafeArea,
≥48 dp, hides while the shared search overlay is open), compact NavigationBar
(labels hidden, ~56 dp), calendar header reserves space so the view switcher is
never covered. Compact condition = mobile layout branch (width <
kDesktopBreakpoint = 1000 — same branch as bottom NavigationBar) AND height <
kCompactHeightLimit = 600. Reactive to window-size changes; never
Orientation/OrientationBuilder. Next stage not yet specified — do not start
work beyond the current brief.

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

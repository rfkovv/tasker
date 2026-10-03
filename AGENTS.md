# AGENTS.md

PROJECT: TaskMaster (Flutter menedżer zadań)
ARCHITECTURE: See ARCHITECTURE.md — follow it strictly, no deviations without approval.

CURRENT PHASE: 7.5 — landscape polish: code complete (fdd9cf6), device verification pending

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
1. Check state first — git status, flutter analyze, flutter test; do
   not redo committed work
2. Implement exactly one layer; reuse existing widgets/flows; no
   duplication; no scope creep
3. flutter analyze + flutter test must pass before proceeding to the
   next layer
4. Commit with a conventional message; the working tree must be clean
   afterwards
5. Report: git diff --stat, changed files, and what was verified

COMPLETION CRITERIA (per layer):
- flutter analyze: no new issues
- flutter test: all green, including new/updated size-regime tests
- grep confirms architecture invariants (e.g. no Orientation/
  OrientationBuilder layout branching; single shared search overlay;
  no hardcoded compact-mode width thresholds)
- No files changed outside the intended scope (presentation layer +
  ARCHITECTURE.md + tests, unless the layer is docs-only)
- Working tree clean after the final commit

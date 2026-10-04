# AGENTS.md

PROJECT: TaskMaster (Flutter menedżer zadań)
ARCHITECTURE: See ARCHITECTURE.md — follow it strictly, no deviations without approval.

CURRENT PHASE: Stage 8d — UI sync: status + "Synchronizuj teraz" in Settings
(sync engine + dumb server complete: 8b ✅ 8c ✅; see ARCHITECTURE.md > SYNC)

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
9. SYNC — LOCAL-FIRST INVARIANT (binding): the local DB is the single
   source of truth; the app is fully functional with the sync server
   absent/failing/unreachable. No UI or app logic may ever block on
   sync. When in doubt, choose the option that keeps the app working
   with the transport absent.
10. SYNC — SERVER IS DUMB (binding): never add domain logic, table
    knowledge, or merge logic to server/. Validation only (auth,
    envelope shape, batch size). All merge logic lives client-side.
11. SYNC — PENDING INVARIANTS (binding): any future comment-edit UI
    MUST bump `updatedAt` (LWW depends on it). Any future CRUD for
    task_dependencies MUST enqueue sync_outbox events (whitelisted
    table). Join-table removals do not converge yet (see
    ARCHITECTURE.md > SYNC > Known limitations) — do not "fix" this
    ad hoc; protocol change required (Backlog #6).

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

# AGENTS.md

PROJECT: TaskMaster (Flutter menedżer zadań)
ARCHITECTURE: See ARCHITECTURE.md — follow it strictly, no deviations without approval.

CURRENT PHASE: Stage 1 — Core tasks + persistence

STAGE 1 SCOPE (do NOT exceed):
- Tasks CRUD (create, read, update, delete)
- Local SQLite persistence via drift
- Task entity: id, title, description, tags[], priority, dueDate, status (todo/inProgress/done), createdAt, updatedAt, deletedAt
- TaskRepository interface + implementation
- UI: task list screen, task form screen, basic filters
- NO contacts module (structure exists, but skip implementation for now)
- NO Kanban/Kalendarz/Gantt
- NO sync (prepare for it with UUID + updated_at)

RULES:
1. Feature-first structure: features/tasks/domain, data, presentation
2. Barrel exports only: features/tasks/tasks.dart — hide impl and DAO internally
3. Status is source of truth (no isDone column) — use getter on Task
4. Tests required: unit on domain logic, repository tests (in-memory drift)
5. After each layer: flutter analyze + flutter test before proceeding
6. Report progress at each step; ask if unclear

WORKFLOW:
1. local_db/ — database, tables, DAO, providers
2. features/tasks/domain/ — entities, enums, repository interface
3. features/tasks/data/ — repository impl + mapper
4. Test repository (in-memory drift)
5. features/tasks/presentation/ — providers, screens, widgets
6. app/ — main.dart, router, shell
7. Widget tests for task_tile + task_list_screen

COMMENCEMENT:
Acknowledge receipt of scope and begin with Step 1.

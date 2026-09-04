# AGENTS.md

PROJECT: TaskMaster (Flutter menedżer zadań)
ARCHITECTURE: See ARCHITECTURE.md — follow it strictly, no deviations without approval.

CURRENT PHASE: Stage 2 — Contacts + task↔contact linking

STAGE 2 SCOPE (do NOT exceed):
- Contacts CRUD: name, role, email, phone (contacts feature)
- Linking contacts to tasks (many-to-many, task_contacts table)
- Creating a contact inline from the task form screen
- Detaching a contact from a task
- Left sidebar: contacts list/filter (consistent with stage-1 layout rules)

OUT OF SCOPE (later stages):
- Subtasks, comments (stage 3)
- Windows/Android builds (stages 4-5)
- Sync (stage 6)
- Kanban/Calendar/Gantt (stage 7)

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

WORKFLOW:
1. ContactsDao in local_db (schema tables already exist)
2. features/contacts/domain
3. features/contacts/data + mapper
4. Repository tests (in-memory drift)
5. features/contacts/presentation + linking UI in task form
6. Router: '/contacts', '/contacts/:id'

COMPLETION CRITERIA:
- Contacts CRUD persists across restart; task↔contact linking works;
  inline contact creation from task form
- Repository tests for ContactsDao + linking; widget test for linking UI

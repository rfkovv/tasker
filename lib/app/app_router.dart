import 'package:go_router/go_router.dart';

import '../features/contacts/presentation/screens/contact_form_screen.dart';
import '../features/contacts/presentation/screens/contact_list_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/tasks/presentation/screens/task_board_screen.dart';
import '../features/tasks/presentation/screens/task_detail_screen.dart';
import '../features/tasks/presentation/screens/task_form_screen.dart';
import 'app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => TaskBoardScreen(
            onOpenTask: (id) => context.push('/tasks/$id'),
          ),
        ),
        GoRoute(
          path: '/tasks/new',
          builder: (context, state) => TaskFormScreen(
            taskId: 'new',
            onSaved: () => context.go('/'),
          ),
        ),
        GoRoute(
          path: '/tasks/:id/edit',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TaskFormScreen(
              taskId: id,
              onSaved: () => context.go('/tasks/$id'),
            );
          },
        ),
        GoRoute(
          path: '/tasks/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TaskDetailScreen(
              taskId: id,
              onEdit: (targetId) => context.push('/tasks/$targetId/edit'),
            );
          },
        ),
        GoRoute(
          path: '/contacts',
          builder: (context, state) => ContactListScreen(
            onOpenContact: (id) => context.push('/contacts/$id'),
          ),
        ),
        GoRoute(
          path: '/contacts/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ContactFormScreen(
              contactId: id,
              onSaved: () => context.go('/contacts'),
            );
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

import 'package:go_router/go_router.dart';

import '../features/contacts/presentation/screens/contact_form_screen.dart';
import '../features/contacts/presentation/screens/contact_list_screen.dart';
import '../features/tasks/presentation/screens/task_form_screen.dart';
import '../features/tasks/presentation/screens/task_list_screen.dart';
import 'app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => TaskListScreen(
            onOpenTask: (id) => context.push('/tasks/$id'),
          ),
        ),
        GoRoute(
          path: '/tasks/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TaskFormScreen(
              taskId: id,
              onSaved: () => context.go('/'),
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
      ],
    ),
  ],
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dutch_learn_app/presentation/providers/settings_provider.dart';
import 'package:dutch_learn_app/presentation/screens/home_screen.dart';
import 'package:dutch_learn_app/presentation/screens/learning_screen.dart';
import 'package:dutch_learn_app/presentation/screens/settings_screen.dart';
import 'package:dutch_learn_app/presentation/screens/sync_screen.dart';
import 'package:dutch_learn_app/presentation/theme/app_theme.dart';

/// Router configuration for the app.
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/sync',
      name: 'sync',
      builder: (context, state) => const SyncScreen(),
    ),
    GoRoute(
      path: '/learning/:projectId',
      name: 'learning',
      builder: (context, state) {
        final projectId = state.pathParameters['projectId']!;
        return LearningScreen(projectId: projectId);
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

/// Main application widget.
class DutchLearnApp extends ConsumerWidget {
  const DutchLearnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Dutch Learn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}

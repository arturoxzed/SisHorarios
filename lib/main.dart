import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';
import 'screens/dashboard_screen.dart';
import 'screens/levels_screen.dart';
import 'screens/subjects_screen.dart';
import 'screens/teachers_screen.dart';
import 'screens/schedules_screen.dart';
import 'screens/visualization_screen.dart';
import 'screens/conflict_resolution_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..initialize(),
      child: const SchoolSchedulerApp(),
    ),
  );
}

class SchoolSchedulerApp extends StatelessWidget {
  const SchoolSchedulerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horarios Escolares',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          const AppSidebar(),
          Expanded(
            child: _ScreenRouter(screen: provider.currentScreen),
          ),
        ],
      ),
    );
  }
}

class _ScreenRouter extends StatelessWidget {
  final AppScreen screen;
  const _ScreenRouter({required this.screen});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(screen),
        child: switch (screen) {
          AppScreen.dashboard => const DashboardScreen(),
          AppScreen.levels => const LevelsScreen(),
          AppScreen.subjects => const SubjectsScreen(),
          AppScreen.teachers => const TeachersScreen(),
          AppScreen.schedules => const SchedulesScreen(),
          AppScreen.visualization => const VisualizationScreen(),
          AppScreen.conflictResolution => const ConflictResolutionScreen(),
        },
      ),
    );
  }
}
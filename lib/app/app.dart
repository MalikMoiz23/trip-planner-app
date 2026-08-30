import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/core/motion.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/app/app_state.dart';
import 'package:trip_planner/features/planner/planner_controller.dart';
import 'package:trip_planner/features/shell/home_shell.dart';
import 'package:trip_planner/features/shell/splash_screen.dart';

class TripPlannerApp extends StatelessWidget {
  const TripPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => AppState()..init()),
        ChangeNotifierProvider<PlannerController>(
          create: (context) {
            final app = context.read<AppState>();
            return PlannerController(repo: app.repository, appState: app);
          },
        ),
      ],
      child: Consumer<AppState>(
        builder: (context, app, _) => MaterialApp(
          title: 'Trip Planner',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          // MaterialApp crossfades between the two over this, so switching mode
          // sweeps rather than snaps — the palette is lerpable for that reason.
          themeAnimationDuration: Motion.slow,
          themeAnimationCurve: Motion.standard,
          themeMode: app.themeMode,
          home: const _Bootstrap(),
        ),
      ),
    );
  }
}

/// Holds the splash until the bundled catalogue and stored settings are in
/// memory, so no screen ever renders against a half-loaded repository.
class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.error != null) {
      return SplashScreen(error: app.error, onRetry: app.init);
    }
    return app.isReady ? const HomeShell() : const SplashScreen();
  }
}

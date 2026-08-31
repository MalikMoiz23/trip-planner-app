import 'package:flutter/material.dart';

import 'package:trip_planner/core/motion.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/features/assistant/assistant_screen.dart';
import 'package:trip_planner/features/explore/explore_screen.dart';
import 'package:trip_planner/features/trips/saved_trips_screen.dart';
import 'package:trip_planner/features/settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    ExploreScreen(),
    AssistantScreen(),
    SavedTripsScreen(),
    SettingsScreen(),
  ];

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final motion = Motion.of(context);

    return Scaffold(
      // IndexedStack keeps each tab's scroll position, so the switch is a
      // crossfade over live state rather than a rebuild from the top.
      body: AnimatedSwitcher(
        duration: motion.d(Motion.base),
        switchInCurve: Motion.enter,
        switchOutCurve: Motion.exit,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.012), end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: IndexedStack(index: _index, children: _tabs),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        height: 66,
        backgroundColor: Theme.of(context).cardTheme.color,
        indicatorColor: p.primary.withValues(alpha: 0.14),
        // The default is a snap; this is the same easing as everything else.
        animationDuration: motion.d(Motion.base),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded, color: p.primary),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded, color: p.primary),
            label: 'Ask',
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded, color: p.primary),
            label: 'My trips',
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded, color: p.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

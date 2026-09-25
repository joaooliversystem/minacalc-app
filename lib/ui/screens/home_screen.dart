import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/i18n.dart';
import '../widgets/status_badge.dart';
import 'jobs_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'sync_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppController controller;
  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(widget.controller.language);
    final screens = [
      JobsScreen(controller: widget.controller),
      MapScreen(controller: widget.controller),
      SyncScreen(controller: widget.controller),
      ProfileScreen(controller: widget.controller),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('MinaCalc Pro', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [Padding(padding: const EdgeInsets.only(right: 10), child: Center(child: SyncStatusBadge(controller: widget.controller)))],
      ),
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.assignment_outlined), selectedIcon: const Icon(Icons.assignment), label: s.t('jobs')),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map), label: s.t('map')),
          NavigationDestination(icon: const Icon(Icons.sync_outlined), selectedIcon: const Icon(Icons.sync), label: s.t('sync')),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: s.t('profile')),
        ],
      ),
    );
  }
}

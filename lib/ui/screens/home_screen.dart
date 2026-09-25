import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../theme.dart';
import '../widgets/status_badge.dart';
import 'parity_pages.dart';

class HomeScreen extends StatefulWidget {
  final AppController controller;
  const HomeScreen({super.key, required this.controller});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String page = 'dashboard';

  String get title => switch (page) {
        'dashboard' => 'Visão geral',
        'plans' => 'Planos',
        'operations' => 'Trabalhos',
        'map' => 'Mapa',
        'reports' => 'Relatórios',
        'teams' => 'Equipes',
        'companies' => 'Empresas',
        'users' => 'Usuários',
        'checklists' => 'Checklists',
        'approvals' => 'Aprovações',
        'alerts' => 'Alertas',
        'references' => 'Referências',
        'settings' => 'Configurações',
        'sync' => 'Sincronização',
        'profile' => 'Minha conta',
        _ => 'MinaCalc Pro',
      };

  void go(String value) {
    setState(() => page = value);
    Navigator.maybePop(context);
  }

  List<(String, IconData, String)> menus() {
    final common = <(String, IconData, String)>[
      ('dashboard', Icons.dashboard_outlined, 'Visão geral'),
      ('plans', Icons.assignment_outlined, 'Planos'),
      ('operations', Icons.engineering_outlined, 'Trabalhos'),
      ('map', Icons.map_outlined, 'Mapa'),
      ('reports', Icons.description_outlined, 'Relatórios'),
    ];
    if (widget.controller.role == 'cliente') return [...common, ('profile', Icons.person_outline, 'Minha conta')];
    if (widget.controller.role == 'campo') {
      return [...common, ('references', Icons.menu_book_outlined, 'Referências'), ('sync', Icons.sync, 'Sincronização'), ('profile', Icons.person_outline, 'Minha conta')];
    }
    final extra = <(String, IconData, String)>[
      ('teams', Icons.groups_outlined, 'Equipes'),
      ('references', Icons.menu_book_outlined, 'Referências'),
      ('approvals', Icons.verified_outlined, 'Aprovações'),
      ('alerts', Icons.warning_amber_outlined, 'Alertas'),
    ];
    if (widget.controller.isAdmin) {
      extra.add(('companies', Icons.business_outlined, 'Empresas'));
      extra.add(('users', Icons.people_outline, 'Usuários'));
      extra.add(('checklists', Icons.fact_check_outlined, 'Checklists'));
      extra.add(('settings', Icons.settings_outlined, 'Configurações'));
    }
    return [...common, ...extra, ('sync', Icons.sync, 'Sincronização'), ('profile', Icons.person_outline, 'Minha conta')];
  }

  Widget body() => switch (page) {
        'dashboard' => DashboardParityPage(controller: widget.controller, onNavigate: go, onRegister: () => openRegisterOperation(context, widget.controller)),
        'plans' => PlansParityPage(controller: widget.controller),
        'operations' => OperationsParityPage(controller: widget.controller),
        'map' => MapParityPage(controller: widget.controller),
        'reports' => ReportsParityPage(controller: widget.controller),
        'teams' => SimpleEntityPage(controller: widget.controller, type: 'teams'),
        'companies' => SimpleEntityPage(controller: widget.controller, type: 'companies'),
        'users' => SimpleEntityPage(controller: widget.controller, type: 'users'),
        'checklists' => SimpleEntityPage(controller: widget.controller, type: 'checklists'),
        'approvals' => ApprovalsParityPage(controller: widget.controller),
        'alerts' => AlertsParityPage(controller: widget.controller),
        'references' => ReferencesParityPage(controller: widget.controller),
        'settings' => SettingsParityPage(controller: widget.controller),
        'sync' => SyncParityPage(controller: widget.controller),
        'profile' => ProfileParityPage(controller: widget.controller),
        _ => DashboardParityPage(controller: widget.controller, onNavigate: go, onRegister: () => openRegisterOperation(context, widget.controller)),
      };

  int bottomIndex() => switch (page) {
        'dashboard' => 0,
        'plans' => 2,
        'reports' => 3,
        _ => -1,
      };

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser ?? {};
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF0B1218),
        child: SafeArea(
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(22, 22, 22, 16), child: Image.asset('assets/logo.png', width: 178)),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                children: menus().map((m) {
                  final active = page == m.$1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: ListTile(
                      dense: true,
                      minTileHeight: 48,
                      selected: active,
                      selectedColor: MinaTheme.yellow,
                      selectedTileColor: const Color(0xFF2B2515),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9), side: active ? const BorderSide(color: Color(0xFF584817)) : BorderSide.none),
                      leading: Icon(m.$2, size: 21),
                      title: Text(m.$3, style: const TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () => go(m.$1),
                    ),
                  );
                }).toList(),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(13, 0, 13, 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: MinaTheme.panel, borderRadius: BorderRadius.circular(9), border: Border.all(color: MinaTheme.border)),
              child: Row(children: [
                const Icon(Icons.engineering_outlined, color: MinaTheme.yellow),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((user['name'] ?? 'MinaCalc Pro').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text((user['role'] ?? '').toString(), style: const TextStyle(color: MinaTheme.yellow, fontSize: 11)),
                ])),
              ]),
            ),
            Image.asset('assets/hazard.png', height: 52, width: double.infinity, fit: BoxFit.cover),
          ]),
        ),
      ),
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const Text('MinaCalc Pro', style: TextStyle(color: MinaTheme.muted, fontSize: 11)),
        ]),
        actions: [
          SizedBox(width: 146, child: Center(child: SyncStatusBadge(controller: widget.controller))),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: widget.controller.alerts(),
            builder: (context, snap) {
              final count = (snap.data ?? const []).where((x) => x['seen'] != true).length;
              return Stack(alignment: Alignment.center, children: [
                IconButton(onPressed: () => go(widget.controller.isManagement ? 'alerts' : 'sync'), icon: const Icon(Icons.notifications_none)),
                if (count > 0) Positioned(right: 4, top: 8, child: Container(constraints: const BoxConstraints(minWidth: 16), height: 16, padding: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: MinaTheme.yellow, borderRadius: BorderRadius.circular(20)), alignment: Alignment.center, child: Text('$count', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)))),
              ]);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween(begin: const Offset(.025, 0), end: Offset.zero).animate(animation), child: child)),
        child: KeyedSubtree(key: ValueKey(page), child: body()),
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: mathMax(bottomIndex(), 0),
        onDestinationSelected: (i) {
          if (i == 0) go('dashboard');
          if (i == 1) openRegisterOperation(context, widget.controller);
          if (i == 2) go('plans');
          if (i == 3) go('reports');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.engineering_outlined), selectedIcon: Icon(Icons.engineering), label: 'Registrar'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Planos'),
          NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Relatórios'),
        ],
      ),
    );
  }
}

int mathMax(int a, int b) => a > b ? a : b;

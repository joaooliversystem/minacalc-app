import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/i18n.dart';
import '../theme.dart';
import 'operation_wizard.dart';

class JobsScreen extends StatefulWidget {
  final AppController controller;
  const JobsScreen({super.key, required this.controller});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(widget.controller.language);
    return Column(children: [
      TabBar(controller: tabs, tabs: [Tab(text: s.t('toExecute')), Tab(text: s.t('completed'))]),
      Expanded(child: TabBarView(controller: tabs, children: [_Pending(controller: widget.controller), _Completed(controller: widget.controller)])),
    ]);
  }
}

class _Pending extends StatelessWidget {
  final AppController controller;
  const _Pending({required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(controller.language);
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([controller.plans(), controller.operations(), controller.localOperations()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final plans = List<Map<String, dynamic>>.from(snap.data![0] as List);
        final ops = List<Map<String, dynamic>>.from(snap.data![1] as List);
        final local = List<Map<String, dynamic>>.from(snap.data![2] as List);
        final used = <String>{...ops.where((o) => o['status'] == 'Concluída').map((o) => '${o['plan_id']}'), ...local.map((o) => '${o['plan_id']}')};
        final available = plans.where((p) => p['status'] == 'Ativo' && !used.contains('${p['id']}')).toList();
        if (available.isEmpty) return Center(child: Text(s.t('noJobs')));
        return RefreshIndicator(
          onRefresh: controller.sync.syncNow,
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: available.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final plan = available[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text((plan['name'] ?? plan['code'] ?? s.t('plan')).toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
                      const Icon(Icons.verified, color: MinaTheme.yellow),
                    ]),
                    const SizedBox(height: 8),
                    Text('${plan['client'] ?? plan['identification'] ?? ''}'),
                    Text('${plan['site'] ?? ''} • ${plan['team'] ?? ''}', style: const TextStyle(color: Colors.white60)),
                    const SizedBox(height: 14),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: controller.draftForPlan('${plan['id']}'),
                      builder: (context, draftSnap) {
                        final hasDraft = draftSnap.data != null;
                        return ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OperationWizard(controller: controller, plan: plan, initialDraft: draftSnap.data)));
                            if (context.mounted) (context as Element).markNeedsBuild();
                          },
                          icon: Icon(hasDraft ? Icons.edit_note : Icons.play_arrow),
                          label: Text(hasDraft ? s.t('continueDraft') : s.t('start')),
                        );
                      },
                    ),
                  ]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Completed extends StatelessWidget {
  final AppController controller;
  const _Completed({required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(controller.language);
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([controller.operations(), controller.localOperations()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final server = List<Map<String, dynamic>>.from(snap.data![0] as List).where((o) => o['status'] == 'Concluída').toList();
        final local = List<Map<String, dynamic>>.from(snap.data![1] as List);
        final all = [...local, ...server];
        if (all.isEmpty) return Center(child: Text(s.t('noCompleted')));
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: all.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final op = all[i];
            final pending = op['sync'] == 'Pendente';
            return ListTile(
              tileColor: MinaTheme.panel,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: MinaTheme.border)),
              leading: Icon(pending ? Icons.cloud_upload_outlined : Icons.task_alt, color: pending ? Colors.orangeAccent : Colors.greenAccent),
              title: Text((op['site'] ?? s.t('operation')).toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${op['team'] ?? ''}\n${pending ? s.t('awaitingSyncShort') : op['date'] ?? op['created_at'] ?? ''}'),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }
}

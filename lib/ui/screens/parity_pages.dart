import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../theme.dart';
import '../widgets/web_parity.dart';
import 'jobs_screen.dart';
import 'map_screen.dart';
import 'operation_wizard.dart';
import 'sync_screen.dart';

String _s(Object? v) => (v ?? '').toString();
double _n(Object? v) => double.tryParse(_s(v).replaceAll(',', '.')) ?? 0;

String _tr(AppController c, String pt, String en, String es) => switch (c.language) {
      'en' => en,
      'es' => es,
      _ => pt,
    };

class DashboardParityPage extends StatelessWidget {
  final AppController controller;
  final void Function(String page) onNavigate;
  final VoidCallback onRegister;
  const DashboardParityPage({super.key, required this.controller, required this.onNavigate, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([controller.plans(), controller.operations(), controller.reports(), controller.alerts(), controller.approvals()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final plans = List<Map<String, dynamic>>.from(snap.data![0] as List);
        final operations = List<Map<String, dynamic>>.from(snap.data![1] as List);
        final reports = List<Map<String, dynamic>>.from(snap.data![2] as List);
        final alerts = List<Map<String, dynamic>>.from(snap.data![3] as List);
        final approvals = List<Map<String, dynamic>>.from(snap.data![4] as List);
        final active = plans.where((p) => _s(p['status']) == 'Ativo').length;
        final unseen = alerts.where((a) => a['seen'] != true).length;
        final pendingApprovals = approvals.where((a) => _s(a['status']) == 'Pendente').length;
        return RefreshIndicator(
          onRefresh: controller.sync.syncNow,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(13, 16, 13, 94),
            children: [
              MCPageHeader(
                title: _tr(controller, 'Resumo operacional', 'Operational overview', 'Resumen operativo'),
                subtitle: _tr(controller, 'Visão mobile igual ao sistema web', 'Mobile view matching the web system', 'Vista móvil igual al sistema web'),
                action: controller.canOperate
                    ? IconButton.filled(onPressed: onRegister, icon: const Icon(Icons.add), tooltip: 'Registrar operação')
                    : null,
              ),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: 1.9,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  MCKpi(icon: Icons.assignment_outlined, label: 'Planos ativos', value: '$active'),
                  MCKpi(icon: Icons.engineering_outlined, label: 'Operações', value: '${operations.length}'),
                  MCKpi(icon: Icons.description_outlined, label: 'Relatórios', value: '${reports.length}'),
                  MCKpi(icon: Icons.warning_amber_outlined, label: 'Alertas abertos', value: '$unseen', warning: unseen > 0),
                ],
              ),
              const SizedBox(height: 18),
              MCFadeIn(child: MCPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('Operações recentes', style: TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w900))),
                  TextButton(onPressed: () => onNavigate('operations'), child: const Text('Ver todas')),
                ]),
                const Divider(),
                if (operations.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('Nenhuma operação registrada.', style: TextStyle(color: MinaTheme.muted))))
                else
                  ...operations.take(5).map((o) => _OperationRow(operation: o)),
              ]))),
              const SizedBox(height: 14),
              if (controller.isManagement)
                MCFadeIn(delayMs: 70, child: MCPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('Aprovações', style: TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w900))),
                    MCStatus('$pendingApprovals pendente(s)'),
                  ]),
                  const SizedBox(height: 12),
                  ...approvals.where((a) => _s(a['status']) == 'Pendente').take(3).map((a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_s(a['title']), maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Solicitado por ${_s(a['requester'])}', style: const TextStyle(color: MinaTheme.muted)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onNavigate('approvals'),
                  )),
                  if (pendingApprovals == 0) const Text('Nenhuma aprovação pendente.', style: TextStyle(color: MinaTheme.muted)),
                ]))),
              const SizedBox(height: 14),
              MCFadeIn(delayMs: 120, child: MCPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Sincronização de campo', style: TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('${controller.sync.pendingCount} alteração(ões) aguardando envio neste dispositivo.', style: const TextStyle(color: MinaTheme.muted)),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: controller.sync.syncNow, icon: const Icon(Icons.sync), label: const Text('Sincronizar agora')),
              ]))),
            ],
          ),
        );
      },
    );
  }
}

class _OperationRow extends StatelessWidget {
  final Map<String, dynamic> operation;
  const _OperationRow({required this.operation});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.location_on_outlined, color: MinaTheme.yellow, size: 21),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_s(operation['site']), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('${_s(operation['team'])} • ${_s(operation['date'] ?? operation['created_at'])}', style: const TextStyle(color: MinaTheme.muted, fontSize: 12)),
          ])),
          MCStatus(_s(operation['status'])),
        ]),
      );
}

class PlansParityPage extends StatefulWidget {
  final AppController controller;
  const PlansParityPage({super.key, required this.controller});
  @override
  State<PlansParityPage> createState() => _PlansParityPageState();
}

class _PlansParityPageState extends State<PlansParityPage> {
  String q = '';
  String status = 'Todos';
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.controller.plans(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snap.data!.where((p) {
          final okStatus = status == 'Todos' || _s(p['status']) == status;
          final hay = '${_s(p['name'])} ${_s(p['site'])} ${_s(p['code'])}'.toLowerCase();
          return okStatus && (q.isEmpty || hay.contains(q.toLowerCase()));
        }).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(13, 16, 13, 94),
          children: [
            MCPageHeader(
              title: 'Planos cadastrados',
              subtitle: 'Controle de versões, dimensionamento e liberação',
              action: widget.controller.canOperate ? IconButton.filled(onPressed: () => _editPlan(context), icon: const Icon(Icons.add)) : null,
            ),
            TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Pesquisar plano, código ou frente'), onChanged: (v) => setState(() => q = v)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: status,
              items: const ['Todos', 'Ativo', 'Em revisão', 'Rejeitado', 'Pausado', 'Arquivado'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (v) => setState(() => status = v ?? 'Todos'),
              decoration: const InputDecoration(labelText: 'Situação'),
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              const MCEmpty(title: 'Nenhum plano encontrado', text: 'Ajuste os filtros ou cadastre um novo plano.')
            else
              ...rows.map((p) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _PlanCard(
                    plan: p,
                    controller: widget.controller,
                    onEdit: () => _editPlan(context, p),
                    onChanged: () => setState(() {}),
                  ))),
          ],
        );
      },
    );
  }

  Future<void> _editPlan(BuildContext context, [Map<String, dynamic>? plan]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MinaTheme.bg2,
      builder: (_) => PlanEditorSheet(controller: widget.controller, existing: plan),
    );
    if (mounted) setState(() {});
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final AppController controller;
  final VoidCallback onEdit;
  final VoidCallback onChanged;
  const _PlanCard({required this.plan, required this.controller, required this.onEdit, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final summary = Map<String, dynamic>.from(plan['summary'] as Map? ?? const {});
    return MCPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_s(plan['code']), style: const TextStyle(color: MinaTheme.yellow, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 5),
          Text(_s(plan['name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ])),
        MCPendingDot(pending: plan['_local_pending'] == true),
      ]),
      const SizedBox(height: 8),
      Text('${_s(plan['site'])} • ${_s(plan['team'])}', style: const TextStyle(color: MinaTheme.muted)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        MCStatus(_s(plan['status'])),
        _MiniMetric('${_n(summary['volume_m3']).toStringAsFixed(0)} m³'),
        _MiniMetric('${_n(summary['drilling_m']).toStringAsFixed(0)} m perfuração'),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Editar'))),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          onSelected: (v) async {
            try {
              if (v == 'duplicate') {
                await controller.duplicatePlan(plan);
              } else if (v == 'delete') {
                if (!await mcConfirm(context, title: 'Excluir plano?', text: 'Somente planos rejeitados podem ser excluídos no servidor.', confirm: 'Excluir')) return;
                await controller.deletePlan(plan);
              } else {
                await controller.changePlanStatus(plan, v);
              }
              if (context.mounted) mcToast(context, controller.connectivity.hasNetwork ? 'Alteração processada.' : 'Alteração salva offline para sincronização.');
              onChanged();
            } catch (e) {
              if (context.mounted) mcToast(context, e.toString(), error: true);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'duplicate', child: Text('Duplicar plano')),
            PopupMenuItem(value: 'Em revisão', child: Text('Enviar para revisão')),
            PopupMenuItem(value: 'Pausado', child: Text('Pausar')),
            PopupMenuItem(value: 'Arquivado', child: Text('Arquivar')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'delete', child: Text('Excluir rejeitado')),
          ],
        ),
      ]),
    ]));
  }
}

class _MiniMetric extends StatelessWidget {
  final String text;
  const _MiniMetric(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: MinaTheme.panel2, borderRadius: BorderRadius.circular(8), border: Border.all(color: MinaTheme.border)),
        child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFFC8D0D7))),
      );
}

class PlanEditorSheet extends StatefulWidget {
  final AppController controller;
  final Map<String, dynamic>? existing;
  const PlanEditorSheet({super.key, required this.controller, this.existing});
  @override
  State<PlanEditorSheet> createState() => _PlanEditorSheetState();
}

class _PlanEditorSheetState extends State<PlanEditorSheet> {
  late final Map<String, TextEditingController> c;
  String explosive = '';
  String materialId = '';
  String teamId = '';
  String companyId = 'company_default';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing ?? const <String, dynamic>{};
    final z = Map<String, dynamic>.from(p['parameters'] as Map? ?? const {});
    String v(String key, [Object? fallback]) => _s(z.containsKey(key) ? z[key] : (p[key] ?? fallback));
    c = {
      for (final key in ['name','client_ref','site','team','responsible','bench_height','hole_depth','subdrilling','inclination_deg','hole_diameter_mm','holes','burden','spacing','booster','explosive_density','kg_per_meter','charge_per_hole_kg','powder_factor','people_radius','equipment_radius','center_lat','center_lng','notes'])
        key: TextEditingController(text: v(key)),
    };
    explosive = v('explosive_type');
    materialId = v('material_id');
    teamId = _s(p['team_id']);
    companyId = _s(p['company_id']).isEmpty ? _s(widget.controller.currentUser?['company_id']).isEmpty ? 'company_default' : _s(widget.controller.currentUser?['company_id']) : _s(p['company_id']);
    if (c['responsible']!.text.isEmpty) c['responsible']!.text = _s(widget.controller.currentUser?['name']);
  }

  @override
  void dispose() { for (final x in c.values) { x.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final volume = _n(c['burden']!.text) * _n(c['spacing']!.text) * _n(c['bench_height']!.text) * _n(c['holes']!.text);
    final drilling = _n(c['hole_depth']!.text) * _n(c['holes']!.text);
    final charge = volume * _n(c['powder_factor']!.text);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .96,
      minChildSize: .65,
      maxChildSize: .98,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
          child: Row(children: [
            Expanded(child: Text(widget.existing == null ? 'Novo planejamento' : 'Editar plano', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(18, 16, 18, 24), children: [
          _field('Nome do plano *', 'name'),
          _field('Cliente / mina / obra / identificação', 'client_ref'),
          _field('Frente / local *', 'site'),
          FutureBuilder<List<Map<String, dynamic>>>(future: widget.controller.teams(), builder: (context, snap) {
            final teams = snap.data ?? const [];
            return DropdownButtonFormField<String>(
              value: teamId.isEmpty ? null : teamId,
              decoration: const InputDecoration(labelText: 'Equipe *'),
              items: teams.map((t) => DropdownMenuItem(value: _s(t['id']), child: Text(_s(t['name'])))).toList(),
              onChanged: (id) { setState(() { teamId = id ?? ''; final t = teams.cast<Map<String,dynamic>?>().firstWhere((x) => _s(x?['id']) == teamId, orElse: () => null); if (t != null) { c['team']!.text = _s(t['name']); companyId = _s(t['company_id']); } }); },
            );
          }),
          const SizedBox(height: 12),
          _field('Responsável técnico *', 'responsible'),
          FutureBuilder<List<Map<String, dynamic>>>(future: widget.controller.materials(), builder: (context, snap) {
            final materials = snap.data ?? const [];
            return DropdownButtonFormField<String>(
              value: materialId.isEmpty ? null : materialId,
              decoration: const InputDecoration(labelText: 'Material'),
              items: materials.map((m) => DropdownMenuItem(value: _s(m['id']), child: Text(_s(m['name'])))).toList(),
              onChanged: (v) => setState(() => materialId = v ?? ''),
            );
          }),
          const SizedBox(height: 14),
          const Text('Parâmetros técnicos', style: TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...[
            ['Altura da bancada (m)','bench_height'], ['Profundidade do furo (m)','hole_depth'], ['Subfuração (m)','subdrilling'], ['Inclinação (graus)','inclination_deg'], ['Diâmetro do furo (mm)','hole_diameter_mm'], ['Quantidade de furos','holes'], ['Afastamento (m)','burden'], ['Espaçamento (m)','spacing'],
          ].map((x) => _field(x[0], x[1], number: true)),
          DropdownButtonFormField<String>(
            value: explosive.isEmpty ? null : explosive,
            decoration: const InputDecoration(labelText: 'Explosivo'),
            items: const ['ANFO','Emulsão','ANFO + Emulsão','Outro'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) => setState(() => explosive = v ?? ''),
          ),
          const SizedBox(height: 12),
          _field('Booster / iniciador', 'booster'),
          ...[
            ['Densidade do explosivo (g/cm³)','explosive_density'], ['Kg por metro (informado)','kg_per_meter'], ['Carga por furo (kg, informada)','charge_per_hole_kg'], ['Razão de carga validada (kg/m³)','powder_factor'], ['Raio de controle — pessoas (m)','people_radius'], ['Raio de controle — equipamentos (m)','equipment_radius'], ['Latitude do centro','center_lat'], ['Longitude do centro','center_lng'],
          ].map((x) => _field(x[0], x[1], number: true)),
          _field('Observações e condicionantes', 'notes', maxLines: 4),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: const Color(0xFF29220B), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF725A0D))),
            child: const Text('VALIDAÇÃO PENDENTE COM O CLIENTE: há referência a 500/300 m e 300/500 m. O aplicativo não escolhe a regra automaticamente.', style: TextStyle(color: MinaTheme.yellow2, fontSize: 12)),
          ),
          const SizedBox(height: 14),
          MCPanel(child: Row(children: [
            Expanded(child: _Calc('Volume teórico', '${volume.toStringAsFixed(2)} m³')),
            Expanded(child: _Calc('Perfuração total', '${drilling.toStringAsFixed(2)} m')),
            Expanded(child: _Calc('Carga estimada', '${charge.toStringAsFixed(2)} kg')),
          ])),
          const SizedBox(height: 18),
          ElevatedButton.icon(onPressed: busy ? null : _save, icon: busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('Salvar plano')),
          const SizedBox(height: 8),
          const Text('Quando estiver offline, o cadastro fica neste aparelho e entra na fila de sincronização.', textAlign: TextAlign.center, style: TextStyle(color: MinaTheme.muted, fontSize: 11)),
        ])),
      ]),
    );
  }

  Widget _field(String label, String key, {bool number = false, int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c[key],
          maxLines: maxLines,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => setState(() {}),
        ),
      );

  Future<void> _save() async {
    if (c['name']!.text.trim().isEmpty || c['site']!.text.trim().isEmpty || c['team']!.text.trim().isEmpty || c['responsible']!.text.trim().isEmpty) {
      mcToast(context, 'Preencha nome, frente/local, equipe e responsável.', error: true); return;
    }
    setState(() => busy = true);
    try {
      final values = <String, dynamic>{for (final e in c.entries) e.key: e.value.text.trim(), 'explosive_type': explosive, 'material_id': materialId, 'team_id': teamId, 'company_id': companyId};
      await widget.controller.savePlan(values, existing: widget.existing);
      if (mounted) { mcToast(context, widget.controller.connectivity.hasNetwork ? 'Plano salvo.' : 'Plano salvo offline.'); Navigator.pop(context); }
    } catch (e) { if (mounted) mcToast(context, e.toString(), error: true); }
    finally { if (mounted) setState(() => busy = false); }
  }
}

class _Calc extends StatelessWidget {
  final String label; final String value; const _Calc(this.label, this.value);
  @override Widget build(BuildContext context) => Column(children: [Text(label, textAlign: TextAlign.center, style: const TextStyle(color: MinaTheme.muted, fontSize: 9)), const SizedBox(height: 4), Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))]);
}

class OperationsParityPage extends StatelessWidget {
  final AppController controller;
  const OperationsParityPage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(13, 16, 13, 5), child: MCPageHeader(title: 'Trabalhos', subtitle: 'A executar e concluídos')),
        Expanded(child: JobsScreen(controller: controller)),
      ]);
}

class ReportsParityPage extends StatelessWidget {
  final AppController controller;
  const ReportsParityPage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([controller.reports(), controller.operations()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final reports = List<Map<String,dynamic>>.from(snap.data![0] as List);
        final ops = List<Map<String,dynamic>>.from(snap.data![1] as List);
        return ListView(padding: const EdgeInsets.fromLTRB(13,16,13,94), children: [
          const MCPageHeader(title: 'Relatórios', subtitle: 'Documentos emitidos pelas operações concluídas'),
          if (reports.isEmpty && ops.isEmpty)
            const MCEmpty(title: 'Nenhum relatório emitido', text: 'Conclua uma operação para gerar o primeiro relatório.')
          else
            ...((reports.isNotEmpty ? reports : ops.map((o) => {'id':'local-${o['id']}','operation_id':o['id'],'title':'Relatório ${o['site']}','date':o['date'],'status':'Emitido'}).toList()).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MCPanel(child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined, color: MinaTheme.yellow),
                title: Text(_s(r['title']), style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(_s(r['date']), style: const TextStyle(color: MinaTheme.muted)),
                trailing: MCStatus(_s(r['status']).isEmpty ? 'Emitido' : _s(r['status'])),
                onTap: () {
                  final op = ops.cast<Map<String,dynamic>?>().firstWhere((o) => _s(o?['id']) == _s(r['operation_id']), orElse: () => null);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ReportParityDetail(report: r, operation: op)));
                },
              )),
            ))),
        ]);
      },
    );
  }
}

class ReportParityDetail extends StatelessWidget {
  final Map<String,dynamic> report;
  final Map<String,dynamic>? operation;
  const ReportParityDetail({super.key, required this.report, this.operation});
  @override
  Widget build(BuildContext context) {
    final op = operation ?? const <String,dynamic>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório da operação')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        MCPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Image.asset('assets/logo.png', width: 220),
          const SizedBox(height: 18),
          Text(_s(report['title']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          MCStatus(_s(report['status']).isEmpty ? 'Emitido' : _s(report['status'])),
          const Divider(height: 28),
          _detail('Frente / local', op['site']), _detail('Equipe', op['team']), _detail('Responsável', op['responsible']), _detail('Data', op['date'] ?? report['date']), _detail('Condição', op['condition']), _detail('Observações', op['observations']),
          const SizedBox(height: 18),
          Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: MinaTheme.yellow, borderRadius: BorderRadius.circular(10)), child: const Text('VOLTAR PRA CASA É O MELHOR DESMONTE — Na dúvida, não faça.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
        ])),
      ]),
    );
  }
  Widget _detail(String l,Object? v)=>Padding(padding: const EdgeInsets.symmetric(vertical:7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[SizedBox(width:120,child:Text(l,style:const TextStyle(color:MinaTheme.muted,fontSize:12))),Expanded(child:Text(_s(v).isEmpty?'—':_s(v),style:const TextStyle(fontWeight:FontWeight.w700)))]));
}

class MapParityPage extends StatelessWidget {
  final AppController controller;
  const MapParityPage({super.key, required this.controller});
  @override Widget build(BuildContext context) => MapScreen(controller: controller);
}

class SyncParityPage extends StatelessWidget {
  final AppController controller;
  const SyncParityPage({super.key, required this.controller});
  @override Widget build(BuildContext context) => SyncScreen(controller: controller);
}

class SimpleEntityPage extends StatefulWidget {
  final AppController controller;
  final String type;
  const SimpleEntityPage({super.key, required this.controller, required this.type});
  @override State<SimpleEntityPage> createState()=>_SimpleEntityPageState();
}

class _SimpleEntityPageState extends State<SimpleEntityPage> {
  String get type => widget.type;
  String get title => switch(type){'teams'=>'Equipes','companies'=>'Empresas','users'=>'Usuários','checklists'=>'Checklists',_=>'Cadastros'};
  Future<List<Map<String,dynamic>>> _load()=>widget.controller.collection(type);
  @override
  Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:_load(),builder:(context,snap){
    if(!snap.hasData)return const Center(child:CircularProgressIndicator()); final rows=snap.data!;
    return ListView(padding:const EdgeInsets.fromLTRB(13,16,13,94),children:[
      MCPageHeader(title:title,subtitle:'Cadastros disponíveis também offline',action:IconButton.filled(onPressed:()=>_edit(context),icon:const Icon(Icons.add))),
      if(rows.isEmpty)MCEmpty(title:'Nenhum registro',text:'Cadastre o primeiro item.') else ...rows.map((r)=>Padding(padding:const EdgeInsets.only(bottom:12),child:MCPanel(child:ListTile(
        contentPadding:EdgeInsets.zero,
        leading:Icon(_icon(),color:MinaTheme.yellow),
        title:Text(_primary(r),style:const TextStyle(fontWeight:FontWeight.w900)),
        subtitle:Text(_secondary(r),style:const TextStyle(color:MinaTheme.muted)),
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[MCPendingDot(pending:r['_local_pending']==true),const Icon(Icons.chevron_right)]),
        onTap:()=>_edit(context,r),
      )))),
    ]);
  });
  IconData _icon()=>switch(type){'teams'=>Icons.groups_outlined,'companies'=>Icons.business_outlined,'users'=>Icons.people_outline,'checklists'=>Icons.fact_check_outlined,_=>Icons.folder_outlined};
  String _primary(Map<String,dynamic> r)=>_s(r[type=='users'?'name':'name']);
  String _secondary(Map<String,dynamic> r)=>switch(type){'teams'=>'${_s(r['lead'])} • ${_s(r['status'])}','companies'=>_s(r['document']),'users'=>'${_s(r['username'])} • ${_s(r['role'])} • ${_s(r['email'])}','checklists'=>'${(r['items'] as List?)?.length??0} item(ns)',_=>''};
  Future<void> _edit(BuildContext context,[Map<String,dynamic>? r])async{
    await showModalBottomSheet(context:context,isScrollControlled:true,useSafeArea:true,backgroundColor:MinaTheme.bg2,builder:(_)=>EntityEditorSheet(controller:widget.controller,type:type,existing:r)); if(mounted)setState((){});
  }
}

class EntityEditorSheet extends StatefulWidget {
  final AppController controller; final String type; final Map<String,dynamic>? existing;
  const EntityEditorSheet({super.key,required this.controller,required this.type,this.existing});
  @override State<EntityEditorSheet> createState()=>_EntityEditorSheetState();
}
class _EntityEditorSheetState extends State<EntityEditorSheet>{
  final form=GlobalKey<FormState>(); late final Map<String,TextEditingController> c; bool active=true; String role='campo'; String scope='team'; String companyId='company_default'; String teamId=''; bool busy=false;
  @override void initState(){super.initState();final r=widget.existing??const <String,dynamic>{};c={for(final k in ['name','document','lead','status','username','email','items'])k:TextEditingController(text:k=='items'?(r['items'] as List?)?.join('\n')??'':_s(r[k]))};active=r['active']!=false;role=_s(r['role']).isEmpty?'campo':_s(r['role']);scope=_s(r['access_scope']).isEmpty?(role=='campo'?'team':'company'):_s(r['access_scope']);companyId=_s(r['company_id']).isEmpty?'company_default':_s(r['company_id']);teamId=_s(r['team_id']);}
  @override void dispose(){for(final x in c.values)x.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Padding(padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text(widget.existing==null?'Novo cadastro':'Editar cadastro',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900))),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))]),const SizedBox(height:14),..._fields(),
    SwitchListTile(contentPadding:EdgeInsets.zero,value:active,onChanged:(v)=>setState(()=>active=v),title:const Text('Ativo')),
    const SizedBox(height:12),ElevatedButton.icon(onPressed:busy?null:_save,icon:const Icon(Icons.save_outlined),label:const Text('Salvar')),const SizedBox(height:8),
    if(widget.existing!=null&&widget.type!='checklists')OutlinedButton.icon(onPressed:busy?_delete:null,icon:const Icon(Icons.delete_outline),label:const Text('Excluir')),
    const SizedBox(height:8),const Text('Sem internet, a alteração fica pendente e é enviada automaticamente quando a conexão voltar.',textAlign:TextAlign.center,style:TextStyle(color:MinaTheme.muted,fontSize:11)),
  ]))));
  List<Widget> _fields(){Widget f(String key,String label,{TextInputType? keyboard,int maxLines=1})=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(controller:c[key],keyboardType:keyboard,maxLines:maxLines,decoration:InputDecoration(labelText:label),validator:(v)=>(key=='name'&&_s(v).trim().isEmpty)?'Obrigatório':null));
    if(widget.type=='companies')return[f('name','Nome da empresa *'),f('document','Documento')];
    if(widget.type=='teams')return[f('name','Nome da equipe *'),f('lead','Responsável / líder'),f('status','Situação')];
    if(widget.type=='checklists')return[f('name','Nome do checklist *'),f('items','Itens — um por linha',maxLines:8)];
    return[
      f('name','Nome *'),f('username','Usuário *'),f('email','E-mail *',keyboard:TextInputType.emailAddress),
      Padding(padding:const EdgeInsets.only(bottom:12),child:DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Perfil'),items:const ['admin','programador','gestor','campo','cliente'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>role=v??'campo'))),
      Padding(padding:const EdgeInsets.only(bottom:12),child:DropdownButtonFormField<String>(value:scope,decoration:const InputDecoration(labelText:'Escopo'),items:const ['all','company','team'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>scope=v??'company'))),
      FutureBuilder<List<Map<String,dynamic>>>(future:widget.controller.companies(),builder:(context,snap)=>Padding(padding:const EdgeInsets.only(bottom:12),child:DropdownButtonFormField<String>(value:companyId,decoration:const InputDecoration(labelText:'Empresa'),items:(snap.data??const []).map((x)=>DropdownMenuItem(value:_s(x['id']),child:Text(_s(x['name'])))).toList(),onChanged:(v)=>setState(()=>companyId=v??companyId)))),
      FutureBuilder<List<Map<String,dynamic>>>(future:widget.controller.teams(),builder:(context,snap)=>Padding(padding:const EdgeInsets.only(bottom:12),child:DropdownButtonFormField<String>(value:teamId.isEmpty?null:teamId,decoration:const InputDecoration(labelText:'Equipe'),items:(snap.data??const []).map((x)=>DropdownMenuItem(value:_s(x['id']),child:Text(_s(x['name'])))).toList(),onChanged:(v)=>setState(()=>teamId=v??'')))),
    ];
  }
  Future<void> _save()async{if(!(form.currentState?.validate()??false))return;setState(()=>busy=true);try{final values=<String,dynamic>{'name':c['name']!.text.trim(),'active':active};if(widget.type=='companies'){values['document']=c['document']!.text.trim();await widget.controller.saveCompany(values,existing:widget.existing);}else if(widget.type=='teams'){values.addAll({'lead':c['lead']!.text.trim(),'status':c['status']!.text.trim().isEmpty?'Disponível':c['status']!.text.trim(),'company_id':widget.existing?['company_id']??widget.controller.currentUser?['company_id']??'company_default'});await widget.controller.saveTeam(values,existing:widget.existing);}else if(widget.type=='checklists'){values['items']=c['items']!.text.split('\n').map((x)=>x.trim()).where((x)=>x.isNotEmpty).toList();await widget.controller.saveChecklist(values,existing:widget.existing);}else{values.addAll({'username':c['username']!.text.trim().toLowerCase(),'email':c['email']!.text.trim().toLowerCase(),'role':role,'access_scope':scope,'company_id':companyId,'team_id':teamId});await widget.controller.saveUser(values,existing:widget.existing);}if(mounted){mcToast(context,widget.controller.connectivity.hasNetwork?'Cadastro salvo.':'Cadastro salvo offline.');Navigator.pop(context);}}catch(e){if(mounted)mcToast(context,e.toString(),error:true);}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> _delete()async{if(widget.existing==null)return;if(!await mcConfirm(context,title:'Excluir registro?',text:'A exclusão será validada pelo servidor ao sincronizar.',confirm:'Excluir'))return;setState(()=>busy=true);try{if(widget.type=='companies')await widget.controller.deleteCompany(widget.existing!);else if(widget.type=='teams')await widget.controller.deleteTeam(widget.existing!);else if(widget.type=='users')await widget.controller.deleteUser(widget.existing!);if(mounted){mcToast(context,'Exclusão registrada.');Navigator.pop(context);}}catch(e){if(mounted)mcToast(context,e.toString(),error:true);}finally{if(mounted)setState(()=>busy=false);}}
}

class ApprovalsParityPage extends StatefulWidget{final AppController controller;const ApprovalsParityPage({super.key,required this.controller});@override State<ApprovalsParityPage> createState()=>_ApprovalsParityPageState();}
class _ApprovalsParityPageState extends State<ApprovalsParityPage>{@override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:widget.controller.approvals(),builder:(context,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());final rows=snap.data!;return ListView(padding:const EdgeInsets.fromLTRB(13,16,13,94),children:[const MCPageHeader(title:'Aprovações',subtitle:'Liberação e revisão de planos'),if(rows.isEmpty)const MCEmpty(title:'Nenhuma solicitação',text:'As revisões de planos aparecerão aqui.')else...rows.map((a)=>Padding(padding:const EdgeInsets.only(bottom:12),child:MCPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(_s(a['title']),style:const TextStyle(fontWeight:FontWeight.w900))),MCStatus(_s(a['status']))]),const SizedBox(height:6),Text('Solicitado por ${_s(a['requester'])}',style:const TextStyle(color:MinaTheme.muted)),if(_s(a['status'])=='Pendente')...[const SizedBox(height:12),Row(children:[Expanded(child:OutlinedButton(onPressed:()=>_decide(a,'rejeitar'),child:const Text('Rejeitar'))),const SizedBox(width:8),Expanded(child:ElevatedButton(onPressed:()=>_decide(a,'aprovar'),child:const Text('Aprovar')))])]]))))]);});
  Future<void> _decide(Map<String,dynamic>a,String decision)async{final note=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text(decision=='aprovar'?'Aprovar plano':'Rejeitar plano'),content:TextField(controller:note,maxLines:4,decoration:InputDecoration(labelText:decision=='rejeitar'?'Motivo / correção *':'Observação')),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Confirmar'))]));if(ok!=true)return;if(decision=='rejeitar'&&note.text.trim().isEmpty){if(mounted)mcToast(context,'Informe o motivo da rejeição.',error:true);return;}try{await widget.controller.decideApproval(a,decision,note.text.trim());if(mounted){mcToast(context,widget.controller.connectivity.hasNetwork?'Decisão processada.':'Decisão salva offline.');setState((){});}}catch(e){if(mounted)mcToast(context,e.toString(),error:true);}}
}

class AlertsParityPage extends StatefulWidget{final AppController controller;const AlertsParityPage({super.key,required this.controller});@override State<AlertsParityPage> createState()=>_AlertsParityPageState();}
class _AlertsParityPageState extends State<AlertsParityPage>{@override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:widget.controller.alerts(),builder:(context,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());final rows=snap.data!;return ListView(padding:const EdgeInsets.fromLTRB(13,16,13,94),children:[MCPageHeader(title:'Alertas',subtitle:'Ocorrências que exigem atenção',action:TextButton(onPressed:()async{await widget.controller.markAlertsSeen();if(mounted)setState((){});},child:const Text('Marcar lidos'))),if(rows.isEmpty)const MCEmpty(title:'Nenhum alerta aberto',text:'As ocorrências aparecerão aqui.')else...rows.map((a)=>Padding(padding:const EdgeInsets.only(bottom:10),child:MCPanel(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.warning_amber_rounded,color:_s(a['level'])=='danger'?MinaTheme.red:MinaTheme.yellow),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_s(a['title']),style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(_s(a['detail']),style:const TextStyle(color:MinaTheme.muted))])),if(a['seen']!=true)const Icon(Icons.circle,size:9,color:MinaTheme.yellow)]))))]);});}

class ReferencesParityPage extends StatelessWidget{final AppController controller;const ReferencesParityPage({super.key,required this.controller});@override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:controller.materials(),builder:(context,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());return ListView(padding:const EdgeInsets.fromLTRB(13,16,13,94),children:[const MCPageHeader(title:'Referências',subtitle:'Materiais e parâmetros operacionais'),...snap.data!.map((m)=>Padding(padding:const EdgeInsets.only(bottom:10),child:MCPanel(child:Row(children:[const Icon(Icons.menu_book_outlined,color:MinaTheme.yellow),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_s(m['name']),style:const TextStyle(fontWeight:FontWeight.w900)),Text('Densidade ${_s(m['density_min'])} a ${_s(m['density_max'])}',style:const TextStyle(color:MinaTheme.muted,fontSize:12))]))]))))]);});}

class SettingsParityPage extends StatefulWidget{final AppController controller;const SettingsParityPage({super.key,required this.controller});@override State<SettingsParityPage> createState()=>_SettingsParityPageState();}
class _SettingsParityPageState extends State<SettingsParityPage>{Map<String,dynamic>? data;late final Map<String,TextEditingController> c={'company':TextEditingController(),'technical_responsible':TextEditingController(),'registration':TextEditingController(),'retention_months':TextEditingController(),'people_radius':TextEditingController(),'equipment_radius':TextEditingController()};bool offline=true,gps=true,loaded=false;
  @override void dispose(){for(final x in c.values)x.dispose();super.dispose();}
  Future<void> _load()async{if(loaded)return;data=await widget.controller.settings()??{};for(final e in c.entries)e.value.text=_s(data![e.key]);offline=data!['offline']!=false;gps=data!['gps']!=false;loaded=true;}
  @override Widget build(BuildContext context)=>FutureBuilder(future:_load(),builder:(context,snap){if(!loaded)return const Center(child:CircularProgressIndicator());return ListView(padding:const EdgeInsets.fromLTRB(13,16,13,94),children:[const MCPageHeader(title:'Configurações gerais',subtitle:'Identificação, parâmetros padrão e integrações'),MCPanel(child:Column(children:[...c.entries.map((e)=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:e.value,keyboardType:['retention_months','people_radius','equipment_radius'].contains(e.key)?TextInputType.number:null,decoration:InputDecoration(labelText:switch(e.key){'company'=>'Empresa / operação','technical_responsible'=>'Responsável técnico','registration'=>'Registro profissional','retention_months'=>'Retenção de registros (meses)','people_radius'=>'Raio padrão — pessoas (m)','equipment_radius'=>'Raio padrão — equipamentos (m)',_=>e.key})))),SwitchListTile(value:offline,onChanged:(v)=>setState(()=>offline=v),title:const Text('Permitir rascunhos offline')),SwitchListTile(value:gps,onChanged:(v)=>setState(()=>gps=v),title:const Text('Exigir localização no fechamento')),Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF29220B),borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFF725A0D))),child:const Text('VALIDAÇÃO PENDENTE COM O CLIENTE: confirme 500/300 m ou 300/500 m antes de alterar os padrões.',style:TextStyle(color:MinaTheme.yellow2,fontSize:12))),const SizedBox(height:14),ElevatedButton.icon(onPressed:_save,icon:const Icon(Icons.save_outlined),label:const Text('Salvar configurações'))])),if(widget.controller.isProgrammer)...[const SizedBox(height:14),const MCPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('SMTP e e-mails automáticos',style:TextStyle(color:MinaTheme.yellow,fontWeight:FontWeight.w900)),SizedBox(height:7),Text('Por segurança, senha SMTP, teste de e-mail, redefinição de senha e convites permanecem como ações online. Os demais cadastros operacionais continuam disponíveis offline.',style:TextStyle(color:MinaTheme.muted))]))]]);});
  Future<void> _save()async{final values=<String,dynamic>{for(final e in c.entries)e.key:e.value.text.trim(),'offline':offline,'gps':gps};try{await widget.controller.saveSettings(values);if(mounted)mcToast(context,widget.controller.connectivity.hasNetwork?'Configurações salvas.':'Configurações salvas offline.');}catch(e){if(mounted)mcToast(context,e.toString(),error:true);}}
}

class ProfileParityPage extends StatelessWidget{final AppController controller;const ProfileParityPage({super.key,required this.controller});@override Widget build(BuildContext context){final u=controller.currentUser??{};return ListView(padding:const EdgeInsets.fromLTRB(13,16,13,94),children:[const MCPageHeader(title:'Minha conta',subtitle:'Dados do acesso atual'),MCPanel(child:Column(children:[Container(width:60,height:60,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:MinaTheme.yellow,width:2)),alignment:Alignment.center,child:Text(_s(u['name']).isEmpty?'M':_s(u['name'])[0],style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:MinaTheme.yellow))),const SizedBox(height:10),Text(_s(u['name']),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:6),MCStatus(_s(u['role'])),const SizedBox(height:16),ListTile(leading:const Icon(Icons.groups_outlined),title:Text(_s(u['team']).isEmpty?'Sem equipe':_s(u['team']))),ListTile(leading:const Icon(Icons.email_outlined),title:Text(_s(u['email']))),ListTile(leading:const Icon(Icons.person_outline),title:Text('Usuário: ${_s(u['username'])}'))])),const SizedBox(height:14),MCPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Idioma da interface',style:TextStyle(color:MinaTheme.yellow,fontWeight:FontWeight.w900)),const SizedBox(height:12),SegmentedButton<String>(segments:const [ButtonSegment(value:'pt-BR',label:Text('PT')),ButtonSegment(value:'en',label:Text('EN')),ButtonSegment(value:'es',label:Text('ES'))],selected:{controller.language},onSelectionChanged:(s)=>controller.setLanguage(s.first))])),const SizedBox(height:14),OutlinedButton.icon(onPressed:controller.logout,icon:const Icon(Icons.logout),label:const Text('Sair da conta'))]);}}

Future<void> openRegisterOperation(BuildContext context, AppController controller) async {
  final plans = await controller.plans();
  final ops = await controller.operations();
  final local = await controller.localOperations();
  final used = <String>{...ops.where((o) => _s(o['status']) == 'Concluída').map((o) => _s(o['plan_id'])), ...local.map((o) => _s(o['plan_id']))};
  final available = plans.where((p) => _s(p['status']) == 'Ativo' && !used.contains(_s(p['id']))).toList();
  if (!context.mounted) return;
  if (available.isEmpty) { mcToast(context, 'Nenhum plano ativo disponível para execução.', error: true); return; }
  final selected = await showModalBottomSheet<Map<String,dynamic>>(context: context, backgroundColor: MinaTheme.bg2, builder: (context) => SafeArea(child: ListView(shrinkWrap:true,padding:const EdgeInsets.all(14),children:[const Padding(padding:EdgeInsets.all(8),child:Text('Selecione o plano',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900))),...available.map((p)=>ListTile(title:Text(_s(p['name']),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${_s(p['site'])} • ${_s(p['team'])}'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.pop(context,p)))])));
  if (selected == null || !context.mounted) return;
  final draft = await controller.draftForPlan(_s(selected['id']));
  if (!context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => OperationWizard(controller: controller, plan: selected, initialDraft: draft)));
}

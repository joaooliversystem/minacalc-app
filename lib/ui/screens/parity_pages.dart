import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/app_controller.dart';
import '../../services/blast_calculation.dart';
import '../../services/formula_engine.dart';
import '../theme.dart';
import '../widgets/web_parity.dart';
import 'jobs_screen.dart';
import 'map_screen.dart';
import 'operation_wizard.dart';
import 'sync_screen.dart';

String _s(Object? v) => (v ?? '').toString();
double _n(Object? v) => double.tryParse(_s(v).replaceAll(',', '.')) ?? 0;

List<Map<String, dynamic>> _optionRows(
  List<Map<String, dynamic>> rows,
  String group, {
  Iterable<String> preserveValues = const <String>[],
}) {
  final preserved = preserveValues.where((value) => value.isNotEmpty).toSet();
  final out = rows
      .where((row) => _s(row['group']) == group && (row['active'] != false || preserved.contains(_s(row['value']))))
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
  for (final value in preserved) {
    if (!out.any((row) => _s(row['value']) == value)) {
      out.add({'value': value, 'label': value, 'active': false, 'sort_order': 9999, '_historical': true});
    }
  }
  out.sort((a, b) {
    final ao = (a['sort_order'] as num?)?.toInt() ?? 1000;
    final bo = (b['sort_order'] as num?)?.toInt() ?? 1000;
    final cmp = ao.compareTo(bo);
    return cmp != 0 ? cmp : _s(a['label']).compareTo(_s(b['label']));
  });
  return out;
}

String _optionText(Map<String, dynamic> row) {
  final label = _s(row['label']).isEmpty ? _s(row['value']) : _s(row['label']);
  return row['active'] == false ? '$label (arquivado)' : label;
}

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
                  MCKpi(icon: Icons.assignment_outlined, label: 'Planos liberados', value: '$active'),
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
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([
        widget.controller.plans(),
        widget.controller.operationalOptions(group: 'plan_status', preserveValues: status == 'Todos' ? const <String>[] : <String>[status]),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final plans = List<Map<String, dynamic>>.from(snap.data![0] as List);
        final statusRows = List<Map<String, dynamic>>.from(snap.data![1] as List);
        final rows = plans.where((p) {
          final okStatus = status == 'Todos' || _s(p['status']) == status;
          final hay = '${_s(p['name'])} ${_s(p['site'])} ${_s(p['code'])}'.toLowerCase();
          return okStatus && (q.isEmpty || hay.contains(q.toLowerCase()));
        }).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(13, 16, 13, 94),
          children: [
            MCPageHeader(
              title: 'Planos cadastrados',
              subtitle: 'Ativo = liberado para campo; conclusão é registrada na operação',
              action: widget.controller.canOperate ? IconButton.filled(onPressed: () => _editPlan(context), icon: const Icon(Icons.add)) : null,
            ),
            TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Pesquisar plano, código ou frente'), onChanged: (v) => setState(() => q = v)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,
              value: status,
              items: [
                const DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                ...statusRows.map((row) => DropdownMenuItem(value: _s(row['value']), child: Text(_optionText(row)))),
              ],
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
        MCStatus(_s(plan['status']) == 'Ativo' ? 'Ativo · liberado' : _s(plan['status'])),
        _MiniMetric('${_n(summary['volume_m3']).toStringAsFixed(0)} m³'),
        _MiniMetric('${_n(summary['drilling_m']).toStringAsFixed(0)} m perfuração'),
        if (_n(summary['tonnage_t']) > 0) _MiniMetric('${_n(summary['tonnage_t']).toStringAsFixed(0)} t'),
        if (_s((plan['parameters'] as Map?)?['explosive_type']).isNotEmpty) _MiniMetric(_s((plan['parameters'] as Map?)?['explosive_type'])),
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
  late final Future<List<dynamic>> _references;
  String materialId = '';
  String teamId = '';
  String companyId = 'company_default';
  String depthMode = 'manual';
  String explosiveId = '';
  String explosiveCategory = 'other';
  String explosiveDensitySource = 'manual';
  String boosterId = '';
  final Set<String> participantIds = <String>{};
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing ?? const <String, dynamic>{};
    final z = Map<String, dynamic>.from(p['parameters'] as Map? ?? const {});
    String v(String key, [Object? fallback]) => _s(z.containsKey(key) ? z[key] : (p[key] ?? fallback));
    c = {
      for (final key in [
        'name','client_ref','site','team','responsible','rock_density_t_m3','bench_height','hole_depth','subdrilling','stemming_height_m','inclination_deg','hole_diameter_mm','holes','burden','spacing',
        'explosive_type','explosive_variant','explosive_density','explosive_diameter_mm','kg_per_meter','charge_per_hole_kg','powder_factor','booster','booster_qty_planned','people_radius','equipment_radius','center_lat','center_lng','notes'
      ]) key: TextEditingController(text: v(key)),
    };
    materialId = v('material_id');
    teamId = _s(p['team_id']);
    companyId = _s(p['company_id']).isEmpty ? (_s(widget.controller.currentUser?['company_id']).isEmpty ? 'company_default' : _s(widget.controller.currentUser?['company_id'])) : _s(p['company_id']);
    depthMode = v('depth_mode', 'manual').isEmpty ? 'manual' : v('depth_mode', 'manual');
    explosiveId = v('explosive_id');
    explosiveCategory = v('explosive_category', 'other').isEmpty ? 'other' : v('explosive_category', 'other');
    explosiveDensitySource = v('explosive_density_source', 'manual').isEmpty ? 'manual' : v('explosive_density_source', 'manual');
    boosterId = v('booster_id');
    participantIds.addAll((p['participant_ids'] as List? ?? const []).map((e) => e.toString()));
    if (c['responsible']!.text.isEmpty) c['responsible']!.text = _s(widget.controller.currentUser?['name']);
    _references = Future.wait<dynamic>([
      widget.controller.teams(), widget.controller.materials(), widget.controller.explosives(), widget.controller.boosters(), widget.controller.technicalTables(), widget.controller.users(), widget.controller.operationalOptions(includeInactive: true), widget.controller.formulas(),
    ]);
  }

  @override
  void dispose() { for (final x in c.values) { x.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .96,
      minChildSize: .65,
      maxChildSize: .98,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PLANO DE FOGO · ESTRUTURA TÉCNICA 2.0', style: TextStyle(color: MinaTheme.yellow, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              const SizedBox(height: 3),
              Text(widget.existing == null ? 'Novo planejamento' : 'Editar plano', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ])),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: FutureBuilder<List<dynamic>>(
          future: _references,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final teams = List<Map<String,dynamic>>.from(snap.data![0] as List);
            final materials = List<Map<String,dynamic>>.from(snap.data![1] as List).where((x) => x['active'] != false || _s(x['id']) == materialId).toList();
            final explosives = List<Map<String,dynamic>>.from(snap.data![2] as List).where((x) => x['active'] != false || _s(x['id']) == explosiveId).toList();
            final boosters = List<Map<String,dynamic>>.from(snap.data![3] as List).where((x) => x['active'] != false || _s(x['id']) == boosterId).toList();
            final tables = List<Map<String,dynamic>>.from(snap.data![4] as List).where((x) => x['active'] != false).toList();
            final users = List<Map<String,dynamic>>.from(snap.data![5] as List).where((x) => x['active'] != false || participantIds.contains(_s(x['id']))).toList();
            final operationalOptions = List<Map<String,dynamic>>.from(snap.data![6] as List);
            final depthOptions = _optionRows(operationalOptions, 'depth_mode', preserveValues: [depthMode]);
            final depthPresetOptions = _optionRows(operationalOptions, 'hole_depth_preset');
            final diameterPresetOptions = _optionRows(operationalOptions, 'hole_diameter_preset');
            final stemmingPresetOptions = _optionRows(operationalOptions, 'stemming_preset');
            final categoryOptions = _optionRows(operationalOptions, 'explosive_category', preserveValues: [explosiveCategory]);
            final densitySourceOptions = _optionRows(operationalOptions, 'density_source', preserveValues: [explosiveDensitySource]);
            final material = materials.cast<Map<String,dynamic>?>().firstWhere((m) => _s(m?['id']) == materialId, orElse: () => null);
            final selectedExplosive = explosives.cast<Map<String,dynamic>?>().firstWhere((x) => _s(x?['id']) == explosiveId, orElse: () => null);
            final selectedBooster = boosters.cast<Map<String,dynamic>?>().firstWhere((x) => _s(x?['id']) == boosterId, orElse: () => null);
            final formulaRows = List<Map<String,dynamic>>.from(snap.data![7] as List);
            final calculation = BlastCalculation.calculate(
              formulaEngine: FormulaEngine(formulaRows),
              explosiveCategory: explosiveCategory,
              holeDiameterMm: _n(c['hole_diameter_mm']!.text),
              explosiveDiameterMm: _n(c['explosive_diameter_mm']!.text),
              explosiveDensityGcm3: _n(c['explosive_density']!.text),
              benchHeightM: _n(c['bench_height']!.text),
              holeDepthM: _n(c['hole_depth']!.text),
              subdrillingM: _n(c['subdrilling']!.text),
              depthMode: depthMode,
              stemmingHeightM: _n(c['stemming_height_m']!.text),
              holes: _n(c['holes']!.text).round(),
              burdenM: _n(c['burden']!.text),
              spacingM: _n(c['spacing']!.text),
              rockDensityTm3: _n(c['rock_density_t_m3']!.text),
            );
            return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(14, 14, 14, 28), children: [
              _planSection('01', 'Identificação', 'Dados do plano, obra, equipe e fluxo de aprovação', [
                _field('Nome do plano *', 'name'), _field('Cliente / mina / obra / identificação', 'client_ref'), _field('Frente / local *', 'site'),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,
                  value: teams.any((t) => _s(t['id']) == teamId) ? teamId : null,
                  decoration: const InputDecoration(labelText: 'Equipe *'),
                  items: teams.map((t) => DropdownMenuItem(value: _s(t['id']), child: Text(_s(t['name'])))).toList(),
                  onChanged: (id) { setState(() { teamId = id ?? ''; final t = teams.cast<Map<String,dynamic>?>().firstWhere((x) => _s(x?['id']) == teamId, orElse: () => null); if (t != null) { c['team']!.text = _s(t['name']); companyId = _s(t['company_id']); } }); },
                ),
                const SizedBox(height: 12), _field('Responsável técnico *', 'responsible'),
                const _StaticNote('Ao salvar, o plano ficará Em revisão até ser analisado em Aprovações.'),
              ]),
              _planSection('02', 'Bancada e perfuração', 'Geometria principal e profundidade usada nos cálculos homologados', [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,
                  value: materials.any((m) => _s(m['id']) == materialId) ? materialId : null,
                  decoration: const InputDecoration(labelText: 'Material / tipo de rocha'),
                  items: materials.map((m) => DropdownMenuItem(value: _s(m['id']), child: Text('${_s(m['name'])}${m['active'] == false ? ' (arquivado)' : ''}'))).toList(),
                  onChanged: (v) => setState(() => materialId = v ?? ''),
                ),
                if (material != null) Padding(padding: const EdgeInsets.only(top: 7), child: Text('Referência cadastrada: ${_fmtRange(material['density_min'], material['density_max'])} t/m³. Não aplicada automaticamente.', style: const TextStyle(color: MinaTheme.muted, fontSize: 11))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,
                  value: depthMode,
                  decoration: const InputDecoration(labelText: 'Modo da profundidade'),
                  items: depthOptions.map((row) => DropdownMenuItem(value: _s(row['value']), child: Text(_optionText(row)))).toList(),
                  onChanged: (v) => setState(() => depthMode = v ?? 'manual'),
                ),
                const SizedBox(height: 12), _field('Densidade da rocha usada (t/m³)', 'rock_density_t_m3', number: true), _field('Altura da bancada (m)', 'bench_height', number: true),
                if (depthPresetOptions.isNotEmpty) DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,
                  decoration: const InputDecoration(labelText: 'Atalho de profundidade'),
                  items: depthPresetOptions.map((row) => DropdownMenuItem(value: _s(row['value']), child: Text(_optionText(row)))).toList(),
                  onChanged: depthMode == 'manual' ? (v) => setState(() { if (v != null) c['hole_depth']!.text = v; }) : null,
                ),
                if (depthPresetOptions.isNotEmpty) const SizedBox(height: 12),
                _field('Profundidade informada do furo (m)', 'hole_depth', number: true, enabled: depthMode == 'manual'), _field('Subfuração (m)', 'subdrilling', number: true),
                if (stemmingPresetOptions.isNotEmpty) DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,
                  decoration: const InputDecoration(labelText: 'Atalho de tampão'),
                  items: stemmingPresetOptions.map((row) => DropdownMenuItem(value: _s(row['value']), child: Text(_optionText(row)))).toList(),
                  onChanged: (v) => setState(() { if (v != null) c['stemming_height_m']!.text = v; }),
                ),
                if (stemmingPresetOptions.isNotEmpty) const SizedBox(height: 12),
                _field('Tampão (m)', 'stemming_height_m', number: true),
                _field('Inclinação (graus)', 'inclination_deg', number: true),
                if (diameterPresetOptions.isNotEmpty) DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,
                  decoration: const InputDecoration(labelText: 'Atalho de diâmetro do furo'),
                  items: diameterPresetOptions.map((row) => DropdownMenuItem(value: _s(row['value']), child: Text(_optionText(row)))).toList(),
                  onChanged: (v) => setState(() { if (v != null) c['hole_diameter_mm']!.text = v; }),
                ),
                if (diameterPresetOptions.isNotEmpty) const SizedBox(height: 12),
                _field('Diâmetro do furo (mm)', 'hole_diameter_mm', number: true),
              ]),
              _planSection('03', 'Malha', 'Parâmetros geométricos usados no volume e na perfuração total', [
                _field('Quantidade de furos', 'holes', number: true), _field('Afastamento (m)', 'burden', number: true), _field('Espaçamento (m)', 'spacing', number: true),
                const _StaticNote('Volume = bancada × afastamento × espaçamento × nº de furos. Nenhuma fórmula adicional é aplicada.'),
              ]),
              _planSection('04', 'Explosivos', 'Selecione o explosivo; kg/m, carga/furo e razão são calculados automaticamente', [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,
                  value: explosives.any((x) => _s(x['id']) == explosiveId) ? explosiveId : null,
                  decoration: const InputDecoration(labelText: 'Explosivo do catálogo'),
                  items: [const DropdownMenuItem(value:'',child:Text('Preenchimento manual')), ...explosives.map((x) => DropdownMenuItem(value:_s(x['id']),child:Text('${_s(x['name'])}${x['active'] == false ? ' (arquivado)' : ''} — ${_validationText(x['validation_status'])}')))],
                  onChanged: (id) { setState(() { explosiveId = id ?? ''; final x = explosives.cast<Map<String,dynamic>?>().firstWhere((e) => _s(e?['id']) == explosiveId, orElse: () => null); if (x != null) { c['explosive_type']!.text = _s(x['name']); explosiveCategory = _s(x['category']).isEmpty ? 'other' : _s(x['category']); if (c['explosive_variant']!.text.isEmpty) c['explosive_variant']!.text = [_s(x['product_code']), _n(x['diameter_mm']) > 0 ? 'Ø ${_n(x['diameter_mm']).toStringAsFixed(0)} mm' : ''].where((e) => e.isNotEmpty).join(' · '); final status = _s(x['validation_status']); if (status == 'validated' || status == 'validated_document') { if (x['density_kg_l'] != null) c['explosive_density']!.text = '${x['density_kg_l']}'; if (x['diameter_mm'] != null && _n(x['diameter_mm']) > 0) c['explosive_diameter_mm']!.text = '${x['diameter_mm']}'; explosiveDensitySource = 'catalog'; } else { explosiveDensitySource = 'manual'; } } }); },
                ),
                if (selectedExplosive != null) _CatalogInfo(item: selectedExplosive, kind: 'explosive'),
                const SizedBox(height: 12), _field('Nome / tipo utilizado', 'explosive_type'),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,
                  value: explosiveCategory,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: categoryOptions.map((row) => DropdownMenuItem(value: _s(row['value']), child: Text(_optionText(row)))).toList(),
                  onChanged: (v) => setState(() => explosiveCategory = v ?? 'other'),
                ),
                const SizedBox(height: 12), _field('Variação / apresentação', 'explosive_variant'),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,
                  value: explosiveDensitySource,
                  decoration: const InputDecoration(labelText: 'Origem da densidade / kg/m'),
                  items: densitySourceOptions.map((row) => DropdownMenuItem(value: _s(row['value']), child: Text(_optionText(row)))).toList(),
                  onChanged: (v) => setState(() => explosiveDensitySource = v ?? 'manual'),
                ),
                const SizedBox(height: 12), _field('Densidade do explosivo (g/cm³)', 'explosive_density', number: true),
                _field('Diâmetro do cartucho / explosivo (mm)', 'explosive_diameter_mm', number: true, enabled: explosiveCategory == 'cartridge' || explosiveCategory == 'other'),
                _StaticNote(explosiveCategory == 'cartridge'
                    ? 'Encartuchado: o cálculo usa o diâmetro do cartucho/explosivo.'
                    : explosiveCategory == 'emulsion_pumped'
                        ? 'Emulsão bombeada: o cálculo usa automaticamente o diâmetro do furo.'
                        : explosiveCategory == 'anfo'
                            ? 'ANFO a granel: o cálculo usa o diâmetro do furo.'
                            : 'Categoria Outro: usa o diâmetro do explosivo quando informado; caso contrário, o diâmetro do furo.'),
                if (selectedExplosive != null && _s(selectedExplosive['validation_status']) != 'validated') const Padding(padding: EdgeInsets.only(top: 2), child: Text('Item ainda não validado: valores numéricos do catálogo não são aplicados automaticamente.', style: TextStyle(color: MinaTheme.yellow2, fontSize: 11))),
              ]),
              _planSection('05', 'Booster / iniciador', 'Registro do tipo e da quantidade planejada', [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,
                  value: boosters.any((x) => _s(x['id']) == boosterId) ? boosterId : null,
                  decoration: const InputDecoration(labelText: 'Booster do catálogo'),
                  items: [const DropdownMenuItem(value:'',child:Text('Preenchimento manual')), ...boosters.map((x) => DropdownMenuItem(value:_s(x['id']),child:Text('${_s(x['name'])} — ${_validationText(x['validation_status'])}')))],
                  onChanged: (id) { setState(() { boosterId = id ?? ''; final x = boosters.cast<Map<String,dynamic>?>().firstWhere((e) => _s(e?['id']) == boosterId, orElse: () => null); if (x != null) c['booster']!.text = _s(x['name']); }); },
                ),
                if (selectedBooster != null) _CatalogInfo(item: selectedBooster, kind: 'booster'),
                const SizedBox(height: 12), _field('Booster / iniciador utilizado', 'booster'), _field('Quantidade planejada', 'booster_qty_planned', number: true),
              ]),
              if (users.isNotEmpty) _planSection('06', 'Equipe envolvida', 'Participantes previstos além do responsável técnico', [
                ...users.map((u) => CheckboxListTile(
                  dense: true, contentPadding: EdgeInsets.zero, value: participantIds.contains(_s(u['id'])),
                  title: Text(_s(u['name']), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${_s(u['role'])}${_s(u['team']).isEmpty ? '' : ' · ${_s(u['team'])}'}'),
                  onChanged: (v) => setState(() { if (v == true) { participantIds.add(_s(u['id'])); } else { participantIds.remove(_s(u['id'])); } }),
                )),
              ]),
              _planSection(users.isNotEmpty ? '07' : '06', 'Controle e localização', 'Parâmetros editáveis até a validação definitiva', [
                _field('Raio de controle — pessoas (m)', 'people_radius', number: true), _field('Raio de controle — equipamentos (m)', 'equipment_radius', number: true),
                _field('Latitude do centro', 'center_lat', number: true), _field('Longitude do centro', 'center_lng', number: true), _field('Observações e condicionantes', 'notes', maxLines: 4),
                Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFF29220B), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF725A0D))), child: const Text('VALIDAÇÃO PENDENTE COM O CLIENTE: há referência a 500/300 m e 300/500 m. O aplicativo não escolhe a regra automaticamente.', style: TextStyle(color:MinaTheme.yellow2,fontSize:12))),
              ]),
              _planSection(users.isNotEmpty ? '08' : '07', 'Cálculos automáticos', 'Mesma regra no app online e offline; resultados são gravados com snapshot', [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _CalcCard('Profundidade considerada', '${calculation.effectiveHoleDepthM.toStringAsFixed(2)} m', depthMode == 'bench_plus_subdrilling' ? 'calculada' : 'informada'),
                  _CalcCard('Tampão', '${calculation.stemmingHeightM.toStringAsFixed(2)} m', 'informado'),
                  _CalcCard('Comprimento carregado', '${calculation.chargedLengthM.toStringAsFixed(2)} m', 'calculado'),
                  _CalcCard('Diâmetro usado', '${calculation.calculationDiameterMm.toStringAsFixed(1)} mm', calculation.diameterSource == 'cartridge' ? 'cartucho' : 'furo'),
                  _CalcCard('Kg por metro', '${calculation.kgPerMeter.toStringAsFixed(2)} kg/m', 'calculado'),
                  _CalcCard('Carga por furo', '${calculation.chargePerHoleKg.toStringAsFixed(2)} kg', 'calculada'),
                  _CalcCard('Volume por furo', '${calculation.volumePerHoleM3.toStringAsFixed(2)} m³', 'calculado'),
                  _CalcCard('Razão de carga', '${calculation.powderFactorKgM3.toStringAsFixed(3)} kg/m³', 'calculada'),
                  _CalcCard('Volume total', '${calculation.volumeM3.toStringAsFixed(2)} m³', 'calculado'),
                  _CalcCard('Perfuração total', '${calculation.drillingM.toStringAsFixed(2)} m', 'calculada'),
                  _CalcCard('Carga total', '${calculation.estimatedChargeKg.toStringAsFixed(2)} kg', 'calculada'),
                  _CalcCard('Tonelagem', calculation.tonnageT == null ? '—' : '${calculation.tonnageT!.toStringAsFixed(2)} t', 'calculada'),
                ]),
              ]),
              _planSection(users.isNotEmpty ? '09' : '08', 'Tabelas técnicas de referência', 'Consulta visual; itens pendentes não alimentam os cálculos', [
                if (tables.isEmpty) const _StaticNote('Nenhuma tabela técnica cadastrada. O preenchimento manual permanece disponível.')
                else ...tables.take(8).map((t) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.table_chart_outlined, color: MinaTheme.yellow), title: Text(_s(t['name']), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(_s(t['type'])), trailing: _ValidationChip(_s(t['validation_status'])))),
              ]),
              const SizedBox(height: 4),
              ElevatedButton.icon(onPressed: busy ? null : _save, icon: busy ? const SizedBox.square(dimension:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.save_outlined), label: Text(widget.existing?['status'] == 'Rejeitado' ? 'Salvar e reenviar para revisão' : 'Salvar plano')),
              const SizedBox(height: 8),
              const Text('Offline: o plano fica salvo neste aparelho e entra na fila de sincronização.', textAlign: TextAlign.center, style: TextStyle(color:MinaTheme.muted,fontSize:11)),
            ]);
          },
        )),
      ]),
    );
  }

  Widget _planSection(String number, String title, String subtitle, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: MCPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width:34,height:34,alignment:Alignment.center,decoration:BoxDecoration(color:MinaTheme.yellow.withValues(alpha:.10),borderRadius:BorderRadius.circular(9),border:Border.all(color:const Color(0xFF806A20))),child:Text(number,style:const TextStyle(color:MinaTheme.yellow,fontWeight:FontWeight.w900))),
        const SizedBox(width:10), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),const SizedBox(height:2),Text(subtitle,style:const TextStyle(color:MinaTheme.muted,fontSize:11))])),
      ]),
      const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Divider(height:1)), ...children,
    ])),
  );

  Widget _field(String label, String key, {bool number = false, int maxLines = 1, bool enabled = true}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c[key], enabled: enabled, maxLines: maxLines,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal:true,signed:true) : TextInputType.text,
      decoration: InputDecoration(labelText: label, suffixIcon: !enabled ? const Icon(Icons.calculate_outlined, size:18) : null),
      onChanged: (_) => setState(() {}),
    ),
  );

  Future<void> _save() async {
    if (c['name']!.text.trim().isEmpty || c['site']!.text.trim().isEmpty || c['team']!.text.trim().isEmpty || c['responsible']!.text.trim().isEmpty) {
      mcToast(context, 'Preencha nome, frente/local, equipe e responsável.', error:true); return;
    }
    setState(() => busy = true);
    try {
      final values = <String,dynamic>{
        for (final e in c.entries) e.key: e.value.text.trim(),
        'material_id': materialId, 'team_id': teamId, 'company_id': companyId, 'depth_mode': depthMode,
        'explosive_id': explosiveId, 'explosive_category': explosiveCategory, 'explosive_density_source': explosiveDensitySource,
        'booster_id': boosterId, 'participant_ids': participantIds.toList(),
      };
      await widget.controller.savePlan(values, existing: widget.existing);
      if (mounted) { mcToast(context, widget.controller.connectivity.hasNetwork ? 'Plano salvo.' : 'Plano salvo offline.'); Navigator.pop(context); }
    } catch (e) { if (mounted) mcToast(context, e.toString(), error:true); }
    finally { if (mounted) setState(() => busy = false); }
  }
}

class _StaticNote extends StatelessWidget {
  final String text; const _StaticNote(this.text);
  @override Widget build(BuildContext context) => Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:MinaTheme.panel2,borderRadius:BorderRadius.circular(9),border:Border.all(color:MinaTheme.border)),child:Text(text,style:const TextStyle(color:Color(0xFFC6CED5),fontSize:11)));
}

class _CatalogInfo extends StatelessWidget {
  final Map<String,dynamic> item; final String kind; const _CatalogInfo({required this.item,required this.kind});
  @override Widget build(BuildContext context) {
    final validated = _s(item['validation_status']) == 'validated';
    final details = <String>[];
    if (kind == 'explosive') { if (_n(item['diameter_mm']) > 0) details.add('Ø ${_n(item['diameter_mm']).toStringAsFixed(0)} mm'); if (item['density_kg_l'] != null) details.add('dens. ${item['density_kg_l']} g/cm³'); if (item['kg_per_meter'] != null) details.add('${item['kg_per_meter']} kg/m'); }
    else { if (item['unit_weight_kg'] != null) details.add('${item['unit_weight_kg']} kg/unidade'); if (_s(item['product_code']).isNotEmpty) details.add(_s(item['product_code'])); }
    return Padding(padding:const EdgeInsets.only(top:7),child:Row(children:[_ValidationChip(_s(item['validation_status'])),const SizedBox(width:8),Expanded(child:Text(details.isEmpty?'Sem valores adicionais cadastrados.':details.join(' · '),style:const TextStyle(color:MinaTheme.muted,fontSize:11)))]));
  }
}


class _ValidationChip extends StatelessWidget {
  final String status; const _ValidationChip(this.status);
  @override Widget build(BuildContext context) {
    final validated = status == 'validated' || status == 'validated_document'; final rejected = status == 'rejected';
    final color = validated ? MinaTheme.green : rejected ? MinaTheme.red : MinaTheme.yellow2;
    final text = validated ? 'Validado' : rejected ? 'Rejeitado' : 'Pendente';
    return Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:color.withValues(alpha:.10),borderRadius:BorderRadius.circular(7),border:Border.all(color:color.withValues(alpha:.55))),child:Text(text,style:TextStyle(color:color,fontSize:10,fontWeight:FontWeight.w800)));
  }
}

class _CalcCard extends StatelessWidget {
  final String label,value,kind; const _CalcCard(this.label,this.value,this.kind);
  @override Widget build(BuildContext context) => Container(width:150,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:MinaTheme.panel2,borderRadius:BorderRadius.circular(9),border:Border.all(color:MinaTheme.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:MinaTheme.muted,fontSize:9)),const SizedBox(height:4),Text(value,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:13)),const SizedBox(height:3),Text(kind,style:TextStyle(color:kind=='informada'?MinaTheme.blue:MinaTheme.yellow,fontSize:9))]));
}

String _validationText(Object? value) => ['validated','validated_document'].contains(_s(value)) ? 'Validado' : _s(value) == 'rejected' ? 'Rejeitado' : 'Pendente';
String _fmtRange(Object? a, Object? b) { final x = _n(a), y = _n(b); if (x == 0 && y == 0) return '—'; if (y == 0 || (x-y).abs() < .0001) return x.toStringAsFixed(2); return '${x.toStringAsFixed(2)}–${y.toStringAsFixed(2)}'; }

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

  Map<String,dynamic> _map(Object? v) => v is Map ? Map<String,dynamic>.from(v) : <String,dynamic>{};
  List<Map<String,dynamic>> _maps(Object? v) => v is List ? v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList() : <Map<String,dynamic>>[];
  String _value(Object? v,[String unit='']) {
    if (v == null || _s(v).isEmpty) return '—';
    if (v is num) {
      final d=v.toDouble(); final text=d==d.roundToDouble()?d.toInt().toString():d.toStringAsFixed(2).replaceAll(RegExp(r'0+$'),'').replaceAll(RegExp(r'\.$'),'');
      return '$text$unit';
    }
    return '${_s(v)}$unit';
  }
  String _answer(Object? status) => switch(_s(status)) {'conform'=>'C','nonconform'=>'NC','na'=>'N/A','pending'=>'Pendente',_=>_s(status).isEmpty?'—':_s(status)};

  @override
  Widget build(BuildContext context) {
    final op = operation ?? const <String,dynamic>{};
    final snapshot=_map(report['snapshot'] ?? op['final_report_snapshot']);
    final operationSnap=_map(snapshot['operation']);
    final snapshotPlan=_map(snapshot['plan']);
    final plan=snapshotPlan.isNotEmpty?snapshotPlan:_map(op['plan_snapshot']);
    final params=_map(plan['parameters']); final summary=_map(plan['summary']);
    final snapshotExecution=_map(snapshot['execution']);
    final execution=snapshotExecution.isNotEmpty?snapshotExecution:_map(op['execution']);
    final calc=_map(execution['calculations']); final planned=_map(calc['planned']); final executed=_map(calc['executed']);
    final snapshotParticipants=_maps(snapshot['participants']);
    final participants=snapshotParticipants.isNotEmpty?snapshotParticipants:_maps(op['participants']);
    final explosives=_maps(execution['explosives']); final boosters=_maps(execution['boosters']);
    final snapshotApff=_maps(snapshot['preliminary_analysis']);
    final apff=snapshotApff.isNotEmpty?snapshotApff:_maps(op['preliminary_analysis']);
    final snapshotChecklist=_maps(snapshot['checklist']);
    final checklist=snapshotChecklist.isNotEmpty?snapshotChecklist:_maps(op['checklist_answers']);
    final evidence=_map(snapshot['evidence']); final snapshotLocation=_map(evidence['location']); final location=snapshotLocation.isNotEmpty?snapshotLocation:_map(op['location']);
    final condition=_s(operationSnap['condition']).isNotEmpty?_s(operationSnap['condition']):_s(op['condition']);
    final responsible=_s(operationSnap['responsible']).isNotEmpty?_s(operationSnap['responsible']):_s(op['responsible']);
    final site=_s(operationSnap['site']).isNotEmpty?_s(operationSnap['site']):_s(op['site']);
    final date=_s(operationSnap['date']).isNotEmpty?_s(operationSnap['date']):_s(op['date'] ?? report['date']);
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório final')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        MCPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Image.asset('assets/logo.png', width: 220),
          const SizedBox(height: 18),
          Text(_s(report['title']).isEmpty?'Relatório Final do Plano de Fogo':_s(report['title']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6), MCStatus(_s(report['status']).isEmpty ? 'Emitido' : _s(report['status'])),
          const Divider(height: 28),
          _detail('Plano', plan['name']), _detail('Código / revisão', '${_s(plan['code'])} / ${_s(plan['revision'])}'), _detail('Cliente / mina / obra', plan['client_ref'] ?? params['client_ref']), _detail('Frente / local', site), _detail('Equipe', operationSnap['team'] ?? op['team']), _detail('Responsável', responsible), _detail('Data', date), _detail('Condição', condition),
        ])),
        _section('Planejamento técnico', [
          _detail('Furos planejados', planned['holes'] ?? params['holes']),
          _detail('Profundidade considerada', _value(summary['effective_hole_depth_m'],' m')),
          _detail('Tampão', _value(summary['stemming_height_m'] ?? params['stemming_height_m'],' m')),
          _detail('Comprimento carregado', _value(summary['charged_length_m'] ?? params['charged_length_m'],' m')),
          _detail('Diâmetro usado', _value(summary['calculation_diameter_mm'] ?? params['calculation_diameter_mm'],' mm')),
          _detail('Kg por metro', _value(summary['kg_per_meter'] ?? params['kg_per_meter'],' kg/m')),
          _detail('Carga por furo', _value(summary['charge_per_hole_kg'] ?? params['charge_per_hole_kg'],' kg')),
          _detail('Volume por furo', _value(summary['volume_per_hole_m3'],' m³')),
          _detail('Razão de carga', _value(summary['powder_factor_kg_m3'] ?? params['powder_factor'],' kg/m³')),
          _detail('Volume total', _value(planned['volume_m3'] ?? summary['volume_m3'],' m³')),
          _detail('Tonelagem', _value(planned['tonnage_t'] ?? summary['tonnage_t'],' t')),
          _detail('Perfuração', _value(planned['drilling_m'] ?? summary['drilling_m'],' m')),
          _detail('Carga estimada', _value(planned['estimated_charge_kg'] ?? summary['estimated_charge_kg'],' kg')),
        ]),
        _section('Executado', [
          _detail('Furos executados', executed['holes'] ?? execution['holes_executed']), _detail('Perfuração executada', _value(executed['drilling_m'] ?? execution['drilling_m_executed'],' m')), _detail('Explosivos', _value(executed['explosive_total_kg'],' kg')), _detail('Boosters', _value(executed['booster_total_qty'],' un')), _detail('Densidade da rocha', _value(executed['rock_density_t_m3'] ?? execution['rock_density_t_m3'],' t/m³')),
        ]),
        _section('Equipe envolvida', participants.isEmpty?[const Text('Nenhum participante adicional registrado.',style:TextStyle(color:MinaTheme.muted))]:participants.map((p)=>_detail(_s(p['name']), '${_s(p['role'])}${_s(p['team']).isNotEmpty?' · ${_s(p['team'])}':''}')).toList()),
        _section('Explosivos utilizados', explosives.isEmpty?[const Text('Nenhum explosivo detalhado.',style:TextStyle(color:MinaTheme.muted))]:explosives.map((e)=>_detail(_s(e['name']), '${_value(e['quantity_kg'],' kg')}${e['kg_per_meter']!=null?' · ${_value(e['kg_per_meter'],' kg/m')}':''}')).toList()),
        _section('Boosters utilizados', boosters.isEmpty?[const Text('Nenhum booster detalhado.',style:TextStyle(color:MinaTheme.muted))]:boosters.map((b)=>_detail(_s(b['name']), _value(b['quantity'],' un'))).toList()),
        _section('APFF / análise preliminar', [
          _detail('Itens', apff.length), _detail('Não conformidades', apff.where((a)=>_s(a['status'])=='nonconform').length), _detail('NC impeditivas', apff.where((a)=>_s(a['status'])=='nonconform'&&a['blocking']==true).length),
          ...apff.map((a)=>Padding(padding:const EdgeInsets.only(top:8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_s(a['label']),style:const TextStyle(fontWeight:FontWeight.w700)),Text('${_answer(a['status'])}${_s(a['note']).isNotEmpty?' · ${_s(a['note'])}':''}',style:TextStyle(color:_s(a['status'])=='nonconform'?Colors.orange:MinaTheme.muted,fontSize:12))])))
        ]),
        _section('Checklist operacional', checklist.isEmpty?[const Text('Checklist não disponível.',style:TextStyle(color:MinaTheme.muted))]:checklist.map((a)=>_detail(_s(a['label']), _answer(a['status']))).toList()),
        _section('GPS e observações', [
          _detail('Localização', location['label']), _detail('Coordenadas', location['lat']==null?'—':'${_s(location['lat'])}, ${_s(location['lng'])}'), _detail('Precisão', location['accuracy']==null?'—':_value(location['accuracy'],' m')), _detail('Observações', operationSnap['observations'] ?? op['observations'])
        ]),
        MCPanel(child: Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: MinaTheme.yellow, borderRadius: BorderRadius.circular(10)), child: const Text('VOLTAR PRA CASA É O MELHOR DESMONTE — Na dúvida, não faça.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)))),
      ]),
    );
  }
  Widget _section(String title,List<Widget> children)=>Padding(padding:const EdgeInsets.only(top:12),child:MCPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),const Divider(height:22),...children])));
  Widget _detail(String l,Object? v)=>Padding(padding: const EdgeInsets.symmetric(vertical:7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[SizedBox(width:130,child:Text(l,style:const TextStyle(color:MinaTheme.muted,fontSize:12))),Expanded(child:Text(_s(v).isEmpty?'—':_s(v),style:const TextStyle(fontWeight:FontWeight.w700)))]));
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
    if(widget.type=='teams')return[
      f('name','Nome da equipe *'),
      f('lead','Responsável / líder'),
      FutureBuilder<List<Map<String,dynamic>>>(
        future: widget.controller.operationalOptions(group: 'team_status', preserveValues: [c['status']!.text]),
        builder: (context, snap) {
          final rows = snap.data ?? const <Map<String,dynamic>>[];
          final current = c['status']!.text.trim().isEmpty ? 'Disponível' : c['status']!.text.trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              menuMaxHeight: 360,
              value: rows.any((row) => _s(row['value']) == current) ? current : null,
              decoration: const InputDecoration(labelText: 'Situação'),
              items: rows.map((row) => DropdownMenuItem(value: _s(row['value']), child: Text(_optionText(row)))).toList(),
              onChanged: (value) => setState(() => c['status']!.text = value ?? current),
            ),
          );
        },
      ),
    ];
    if(widget.type=='checklists')return[f('name','Nome do checklist *'),f('items','Itens — um por linha',maxLines:8)];
    return[
      f('name','Nome *'),f('username','Usuário *'),f('email','E-mail *',keyboard:TextInputType.emailAddress),
      Padding(padding:const EdgeInsets.only(bottom:12),child:DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,value:role,decoration:const InputDecoration(labelText:'Perfil'),items:const ['admin','programador','gestor','campo','cliente'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>role=v??'campo'))),
      Padding(padding:const EdgeInsets.only(bottom:12),child:DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,value:scope,decoration:const InputDecoration(labelText:'Escopo'),items:const ['all','company','team'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>scope=v??'company'))),
      FutureBuilder<List<Map<String,dynamic>>>(future:widget.controller.companies(),builder:(context,snap)=>Padding(padding:const EdgeInsets.only(bottom:12),child:DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,value:companyId,decoration:const InputDecoration(labelText:'Empresa'),items:(snap.data??const []).map((x)=>DropdownMenuItem(value:_s(x['id']),child:Text(_s(x['name'])))).toList(),onChanged:(v)=>setState(()=>companyId=v??companyId)))),
      FutureBuilder<List<Map<String,dynamic>>>(future:widget.controller.teams(),builder:(context,snap)=>Padding(padding:const EdgeInsets.only(bottom:12),child:DropdownButtonFormField<String>(
                  isExpanded: true,
                  menuMaxHeight: 360,value:teamId.isEmpty?null:teamId,decoration:const InputDecoration(labelText:'Equipe'),items:(snap.data??const []).map((x)=>DropdownMenuItem(value:_s(x['id']),child:Text(_s(x['name'])))).toList(),onChanged:(v)=>setState(()=>teamId=v??'')))),
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


class BillingParityPage extends StatefulWidget {
  final AppController controller;
  const BillingParityPage({super.key, required this.controller});
  @override
  State<BillingParityPage> createState() => _BillingParityPageState();
}

class _BillingParityPageState extends State<BillingParityPage> {
  late Future<Map<String, dynamic>> future = widget.controller.billingStatus();

  String money(Object? cents) {
    final value = ((cents as num?)?.toInt() ?? int.tryParse(_s(cents)) ?? 0) / 100;
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  (String, Color) statusView(String status) => switch (status) {
        'trial' => ('Período grátis', MinaTheme.blue),
        'paid' => ('Pago', MinaTheme.green),
        'pending' => ('PIX pendente', MinaTheme.yellow),
        'overdue' => ('Vencido', MinaTheme.red),
        'awaiting_invoice' => ('Aguardando cobrança', MinaTheme.muted),
        'not_configured' => ('Não configurado', MinaTheme.muted),
        'not_enabled' => ('Não habilitado', MinaTheme.muted),
        _ => (status.isEmpty ? 'Pendente' : status, MinaTheme.yellow),
      };

  void refresh() => setState(() => future = widget.controller.refreshBilling());

  Widget qrImage(String value) {
    if (value.startsWith('data:image') && value.contains(',')) {
      try {
        final bytes = base64Decode(value.split(',').last);
        return Image.memory(bytes, width: 250, height: 250, fit: BoxFit.contain);
      } catch (_) {}
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(value, width: 250, height: 250, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink());
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(13, 16, 13, 94),
            children: [
              const MCPageHeader(title: 'Plano e PIX', subtitle: 'Mensalidade MinaCalc Pro'),
              MCPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Não foi possível consultar a cobrança.', style: TextStyle(fontWeight: FontWeight.w900, color: MinaTheme.red)),
                const SizedBox(height: 8),
                Text('${snap.error}', style: const TextStyle(color: MinaTheme.muted)),
                const SizedBox(height: 14),
                ElevatedButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
              ])),
            ],
          );
        }
        final b = snap.data ?? const <String, dynamic>{};
        final invoice = b['invoice'] is Map ? Map<String, dynamic>.from(b['invoice'] as Map) : <String, dynamic>{};
        final status = statusView(_s(b['status']));
        final pix = _s(invoice['pix_copy_paste']);
        final qr = _s(invoice['pix_qr_image']);
        final checkout = _s(invoice['checkout_url']);
        return ListView(
          padding: const EdgeInsets.fromLTRB(13, 16, 13, 94),
          children: [
            MCPageHeader(title: 'Plano e PIX', subtitle: '${_s(b['company_name']).isEmpty ? 'Sua empresa' : _s(b['company_name'])} • MinaCalc Pro'),
            MCPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('MinaCalc Pro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(_s(b['message']), style: const TextStyle(color: MinaTheme.muted)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(border: Border.all(color: status.$2), borderRadius: BorderRadius.circular(20)), child: Text(status.$1, style: TextStyle(color: status.$2, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 16),
              Text('${money(b['amount_cents'])} / mês via PIX', style: const TextStyle(color: MinaTheme.yellow, fontSize: 18, fontWeight: FontWeight.w900)),
              if (b['offline_cache'] == true) ...[const SizedBox(height: 8), const Text('Status salvo anteriormente. Conecte-se para atualizar ou pagar.', style: TextStyle(color: MinaTheme.muted, fontSize: 12))],
              if (_s(b['status']) == 'trial') ...[const SizedBox(height: 12), Text('Período gratuito até ${_s(b['trial_until'])}.', style: const TextStyle(color: MinaTheme.green, fontWeight: FontWeight.w800))],
            ])),
            if (invoice.isNotEmpty) ...[
              const SizedBox(height: 14),
              MCPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Cobrança atual', style: TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(money(invoice['amount_cents'] ?? b['amount_cents']), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                if (_s(invoice['due_date']).isNotEmpty) Text('Vencimento: ${_s(invoice['due_date'])}', style: const TextStyle(color: MinaTheme.muted)),
                if (qr.isNotEmpty) ...[const SizedBox(height: 16), Center(child: qrImage(qr))],
                if (pix.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('PIX copia e cola', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  SelectableText(pix, style: const TextStyle(color: MinaTheme.muted, fontSize: 12)),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: pix)); if (context.mounted) mcToast(context, 'Código PIX copiado.'); }, icon: const Icon(Icons.copy), label: const Text('Copiar código PIX'))),
                ],
                if (checkout.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () async { final uri = Uri.tryParse(checkout); if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) { if (context.mounted) mcToast(context, 'Não foi possível abrir o pagamento.', error: true); } }, icon: const Icon(Icons.open_in_new), label: const Text('Abrir pagamento'))),
                ],
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: TextButton.icon(onPressed: widget.controller.connectivity.hasNetwork ? refresh : null, icon: const Icon(Icons.refresh), label: const Text('Atualizar status'))),
              ])),
            ],
          ],
        );
      },
    );
  }
}

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

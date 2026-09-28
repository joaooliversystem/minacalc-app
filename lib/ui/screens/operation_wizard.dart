import 'dart:io';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import '../../controllers/app_controller.dart';
import '../../core/i18n.dart';
import '../theme.dart';

class OperationWizard extends StatefulWidget {
  final AppController controller;
  final Map<String, dynamic> plan;
  final Map<String, dynamic>? initialDraft;
  const OperationWizard({super.key, required this.controller, required this.plan, this.initialDraft});

  @override
  State<OperationWizard> createState() => _OperationWizardState();
}

class _OperationWizardState extends State<OperationWizard> {
  int step = 0;
  bool loading = true;

  late final TextEditingController site;
  late final TextEditingController observations;
  late final TextEditingController holesExecuted;
  late final TextEditingController drillingExecuted;
  late final TextEditingController rockDensity;
  late final TextEditingController actualAverageDepth;
  late final TextEditingController stemmingHeight;
  late final TextEditingController weather;
  late final TextEditingController waterPercent;
  late final TextEditingController dismantleType;
  late final TextEditingController scheduledTime;
  late final TextEditingController loadingStartTime;
  late final TextEditingController loadingEndTime;

  String team = '';
  String condition = 'Conforme';
  String clientUuid = '';

  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> participants = [];
  List<Map<String, dynamic>> explosiveCatalog = [];
  List<Map<String, dynamic>> boosterCatalog = [];
  final Set<String> participantIds = {};

  List<String> checklistItems = [];
  List<bool> checklist = [];
  List<Map<String, dynamic>> preliminaryItems = [];
  final Map<String, String> preliminaryStatus = {};
  final Map<String, String> preliminaryNote = {};

  final Map<String, double> explosiveQty = {};
  final Map<String, int> boosterQty = {};

  List<String> photos = [];
  Map<String, dynamic>? location;
  String? signaturePath;
  late final SignatureController signature;

  Map<String, dynamic> get parameters => Map<String, dynamic>.from(widget.plan['parameters'] as Map? ?? const {});
  Map<String, dynamic> get summary => Map<String, dynamic>.from(widget.plan['summary'] as Map? ?? const {});

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft ?? const <String, dynamic>{};
    site = TextEditingController(text: '${draft['site'] ?? widget.plan['site'] ?? ''}');
    observations = TextEditingController(text: '${draft['observations'] ?? ''}');
    team = '${draft['team'] ?? widget.plan['team'] ?? ''}';
    condition = '${draft['condition'] ?? 'Conforme'}';
    clientUuid = '${draft['client_uuid'] ?? const Uuid().v4()}';

    holesExecuted = TextEditingController(text: _draftOrPlan(draft, 'holes_executed', parameters['holes']));
    drillingExecuted = TextEditingController(text: _draftOrPlan(draft, 'drilling_m_executed', summary['drilling_m']));
    rockDensity = TextEditingController(text: _draftOrPlan(draft, 'rock_density_t_m3', summary['rock_density_t_m3'] ?? parameters['rock_density_t_m3']));

    final pc = Map<String, dynamic>.from(draft['preliminary_context'] as Map? ?? const {});
    actualAverageDepth = TextEditingController(text: _text(pc['actual_average_hole_depth_m']));
    stemmingHeight = TextEditingController(text: _text(pc['stemming_height_m']));
    weather = TextEditingController(text: _text(pc['weather_conditions']));
    waterPercent = TextEditingController(text: _text(pc['water_presence_percent']));
    dismantleType = TextEditingController(text: _text(pc['dismantle_type']));
    scheduledTime = TextEditingController(text: _text(pc['scheduled_time']));
    loadingStartTime = TextEditingController(text: _text(pc['loading_start_time']));
    loadingEndTime = TextEditingController(text: _text(pc['loading_end_time']));

    photos = List<String>.from(draft['photo_paths'] as List? ?? const []);
    final rawLoc = draft['location'];
    if (rawLoc is Map) location = Map<String, dynamic>.from(rawLoc);
    signaturePath = draft['signature_path']?.toString();
    signature = SignatureController(penStrokeWidth: 3, penColor: Colors.white, exportBackgroundColor: Colors.black);

    for (final id in (draft['participant_ids'] as List? ?? widget.plan['participant_ids'] as List? ?? const [])) {
      participantIds.add('$id');
    }
    for (final row in (draft['preliminary_analysis'] as List? ?? const [])) {
      if (row is! Map) continue;
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      preliminaryStatus[id] = '${row['status'] ?? 'pending'}';
      preliminaryNote[id] = '${row['note'] ?? ''}';
    }
    for (final row in (draft['explosives'] as List? ?? const [])) {
      if (row is! Map) continue;
      final id = '${row['explosive_id'] ?? row['id'] ?? ''}';
      final qty = _num(row['quantity_kg']);
      if (id.isNotEmpty && qty > 0) explosiveQty[id] = qty;
    }
    for (final row in (draft['boosters'] as List? ?? const [])) {
      if (row is! Map) continue;
      final id = '${row['booster_id'] ?? row['id'] ?? ''}';
      final qty = _num(row['quantity']).round();
      if (id.isNotEmpty && qty > 0) boosterQty[id] = qty;
    }
    _loadReferenceData();
  }

  static String _text(dynamic value) => value == null ? '' : '$value';
  static double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0;
  static String _draftOrPlan(Map<String, dynamic> draft, String key, dynamic fallback) => _text(draft.containsKey(key) ? draft[key] : fallback);

  Future<void> _loadReferenceData() async {
    final allTeams = await widget.controller.teams();
    final company = '${widget.plan['company_id'] ?? ''}';
    teams = allTeams.where((t) => company.isEmpty || '${t['company_id'] ?? ''}' == company).toList();

    final directory = await widget.controller.participantDirectory();
    participants = directory.where((u) {
      final sameCompany = company.isEmpty || '${u['company_id'] ?? ''}' == company;
      final planTeamId = '${widget.plan['team_id'] ?? ''}';
      final sameTeam = planTeamId.isEmpty || '${u['team_id'] ?? ''}'.isEmpty || '${u['team_id'] ?? ''}' == planTeamId;
      return sameCompany && sameTeam;
    }).toList();
    final me = '${widget.controller.currentUser?['id'] ?? ''}';
    if (me.isNotEmpty) participantIds.add(me);

    final models = await widget.controller.checklists();
    Map<String, dynamic>? operational;
    Map<String, dynamic>? preliminary;
    for (final m in models) {
      if (m['active'] == false) continue;
      final type = '${m['type'] ?? 'operational'}';
      if (type == 'operational' && operational == null) operational = m;
      if (type == 'preliminary_analysis' && preliminary == null) preliminary = m;
    }
    if (operational != null) {
      final raw = operational['items'];
      if (raw is List) checklistItems = raw.map((e) => '$e').toList();
    }
    final savedChecklist = widget.initialDraft?['checklist'];
    if (savedChecklist is List && savedChecklist.length == checklistItems.length) {
      checklist = savedChecklist.map((e) => e == true).toList();
    } else {
      checklist = List<bool>.filled(checklistItems.length, false);
    }
    if (preliminary != null) preliminaryItems = _flattenChecklist(preliminary);

    explosiveCatalog = await widget.controller.explosives();
    boosterCatalog = await widget.controller.boosters();
    if (mounted) setState(() => loading = false);
  }

  List<Map<String, dynamic>> _flattenChecklist(Map<String, dynamic> model) {
    final out = <Map<String, dynamic>>[];
    final sections = model['sections'];
    if (sections is List && sections.isNotEmpty) {
      for (final section in sections) {
        if (section is! Map) continue;
        final title = '${section['title'] ?? ''}';
        final items = section['items'];
        if (items is! List) continue;
        for (final item in items) {
          if (item is String) {
            out.add({'id': 'apff_${out.length + 1}', 'label': item, 'section': title, 'required': true, 'allow_na': true, 'blocking': false});
          } else if (item is Map) {
            out.add({...Map<String, dynamic>.from(item), 'section': title});
          }
        }
      }
    } else {
      for (final item in (model['items'] as List? ?? const [])) {
        out.add({'id': 'apff_${out.length + 1}', 'label': '$item', 'section': 'Análise preliminar', 'required': true, 'allow_na': true, 'blocking': false});
      }
    }
    return out;
  }

  @override
  void dispose() {
    for (final c in [site, observations, holesExecuted, drillingExecuted, rockDensity, actualAverageDepth, stemmingHeight, weather, waterPercent, dismantleType, scheduledTime, loadingStartTime, loadingEndTime]) {
      c.dispose();
    }
    signature.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(widget.controller.language);
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final titles = ['Dados e equipe', 'Execução', 'Análise preliminar', 'Checklist', 'Explosivos e booster', s.t('photos'), s.t('location'), s.t('observations'), s.t('signature'), s.t('review')];
    return Scaffold(
      appBar: AppBar(title: Text(titles[step])),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (step + 1) / titles.length, minHeight: 4, color: MinaTheme.yellow, backgroundColor: Colors.white12),
            Expanded(child: _stepBody(s)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(children: [
                OutlinedButton.icon(onPressed: _saveDraft, icon: const Icon(Icons.save_outlined), label: Text(s.t('saveDraft'))),
                const SizedBox(height: 8),
                Row(children: [
                  if (step > 0) Expanded(child: OutlinedButton(onPressed: () => setState(() => step--), child: Text(s.t('back')))),
                  if (step > 0) const SizedBox(width: 10),
                  Expanded(child: ElevatedButton(onPressed: step == 9 ? _finish : _next, child: Text(step == 9 ? s.t('finish') : s.t('next')))),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody(AppStrings s) {
    switch (step) {
      case 0:
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('${widget.plan['name'] ?? widget.plan['code'] ?? 'Plano'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${widget.plan['client'] ?? widget.plan['identification'] ?? ''}', style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 22),
          TextField(controller: site, decoration: InputDecoration(labelText: s.t('site'))),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: team.isEmpty ? null : team,
            decoration: InputDecoration(labelText: s.t('team')),
            items: [
              if (team.isNotEmpty && !teams.any((t) => '${t['name']}' == team)) DropdownMenuItem(value: team, child: Text(team)),
              ...teams.map((t) => DropdownMenuItem(value: '${t['name']}', child: Text('${t['name']}'))),
            ],
            onChanged: (v) => setState(() => team = v ?? ''),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: condition,
            decoration: InputDecoration(labelText: s.t('condition')),
            items: const [DropdownMenuItem(value: 'Conforme', child: Text('Conforme')), DropdownMenuItem(value: 'Atenção', child: Text('Atenção')), DropdownMenuItem(value: 'Aguardando inspeção', child: Text('Aguardando inspeção'))],
            onChanged: (v) => setState(() => condition = v ?? 'Conforme'),
          ),
          const SizedBox(height: 18),
          const Text('Participantes da atividade', style: TextStyle(fontWeight: FontWeight.w900, color: MinaTheme.yellow)),
          const SizedBox(height: 8),
          if (participants.isEmpty) const Text('Nenhum participante sincronizado para este plano.', style: TextStyle(color: Colors.white60)),
          ...participants.map((u) {
            final id = '${u['id']}';
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: participantIds.contains(id),
              title: Text('${u['name']}'),
              subtitle: Text('${u['role'] ?? ''}${('${u['team'] ?? ''}').isNotEmpty ? ' · ${u['team']}' : ''}'),
              activeColor: MinaTheme.yellow,
              checkColor: Colors.black,
              onChanged: (v) => setState(() => v == true ? participantIds.add(id) : participantIds.remove(id)),
            );
          }),
        ]);
      case 1:
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Planejado × executado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Furos planejados: ${_text(parameters['holes'])} · Perfuração planejada: ${_text(summary['drilling_m'])} m', style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 18),
          _number(holeLabel: 'Total de furos executados *', controller: holesExecuted, integer: true),
          _number(holeLabel: 'Perfuração executada (m)', controller: drillingExecuted),
          _number(holeLabel: 'Densidade da rocha (t/m³)', controller: rockDensity),
          _number(holeLabel: 'Altura média real de furação (m)', controller: actualAverageDepth),
          _number(holeLabel: 'Altura do tampão (m)', controller: stemmingHeight),
          _number(holeLabel: 'Presença de água (%)', controller: waterPercent),
          TextField(controller: weather, decoration: const InputDecoration(labelText: 'Condições climáticas')),
          const SizedBox(height: 12),
          TextField(controller: dismantleType, decoration: const InputDecoration(labelText: 'Tipo de desmonte')),
          const SizedBox(height: 12),
          TextField(controller: scheduledTime, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: 'Hora programada (HH:MM)')),
          const SizedBox(height: 12),
          TextField(controller: loadingStartTime, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: 'Início do carregamento (HH:MM)')),
          const SizedBox(height: 12),
          TextField(controller: loadingEndTime, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: 'Término do carregamento (HH:MM)')),
        ]);
      case 2:
        if (preliminaryItems.isEmpty) return const Center(child: Text('Modelo APFF não sincronizado.'));
        return ListView(padding: const EdgeInsets.all(12), children: [
          const Text('Análise Preliminar do Plano de Fogo (APFF)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Marque C, NC ou N/A. Não conformidades exigem comentário.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          ..._preliminaryWidgets(),
        ]);
      case 3:
        if (checklistItems.isEmpty) return Center(child: Text(s.t('checklistUnavailable')));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: checklistItems.length,
          itemBuilder: (_, i) => CheckboxListTile(
            value: checklist[i],
            activeColor: MinaTheme.yellow,
            checkColor: Colors.black,
            title: Text(checklistItems[i]),
            onChanged: (v) => setState(() => checklist[i] = v ?? false),
          ),
        );
      case 4:
        return _materialsStep();
      case 5:
        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: photos.length >= 8 ? null : _capturePhoto, icon: const Icon(Icons.camera_alt_outlined), label: Text(s.t('capture')))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: photos.length >= 8 ? null : _gallery, icon: const Icon(Icons.photo_library_outlined), label: Text(s.t('gallery')))),
          ]),
          const SizedBox(height: 14),
          Text('${photos.length}/8 ${s.t('evidenceSaved')}', style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: photos.length,
            itemBuilder: (_, i) => Stack(fit: StackFit.expand, children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(photos[i]), fit: BoxFit.cover)),
              Positioned(top: 4, right: 4, child: IconButton.filled(onPressed: () => setState(() => photos.removeAt(i)), icon: const Icon(Icons.close))),
            ]),
          ),
        ]);
      case 6:
        return ListView(padding: const EdgeInsets.all(16), children: [
          ElevatedButton.icon(onPressed: _captureLocation, icon: const Icon(Icons.gps_fixed), label: Text(s.t('getLocation'))),
          const SizedBox(height: 18),
          if (location != null)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Lat: ${location!['lat']}'),
              Text('Lng: ${location!['lng']}'),
              Text('${s.t('accuracy')}: ±${((location!['accuracy'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} m', style: const TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w800)),
            ])))
          else Text(s.t('noLocation'), textAlign: TextAlign.center),
        ]);
      case 7:
        return ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: observations, minLines: 7, maxLines: 12, decoration: InputDecoration(labelText: s.t('observations'), alignLabelWithHint: true)),
        ]);
      case 8:
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text(s.t('signInstruction'), style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 14),
          Container(
            height: 260,
            decoration: BoxDecoration(border: Border.all(color: MinaTheme.border), borderRadius: BorderRadius.circular(12), color: Colors.black),
            clipBehavior: Clip.antiAlias,
            child: Signature(controller: signature, backgroundColor: Colors.black),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () { signature.clear(); setState(() => signaturePath = null); }, icon: const Icon(Icons.clear), label: Text(s.t('clear'))),
          if (signaturePath != null) Text(s.t('signatureSaved'), style: const TextStyle(color: Colors.greenAccent)),
        ]);
      default:
        final nc = preliminaryStatus.values.where((v) => v == 'nonconform').length;
        final expTotal = explosiveQty.values.fold<double>(0, (a, b) => a + b);
        final bstTotal = boosterQty.values.fold<int>(0, (a, b) => a + b);
        return ListView(padding: const EdgeInsets.all(16), children: [
          _Review(label: s.t('plan'), value: '${widget.plan['name'] ?? widget.plan['code'] ?? ''}'),
          _Review(label: s.t('site'), value: site.text),
          _Review(label: s.t('team'), value: team),
          const _Review(label: 'Participantes', value: ''),
          Padding(padding: const EdgeInsets.only(left: 120, bottom: 8), child: Text('${participantIds.length} selecionado(s)', style: const TextStyle(fontWeight: FontWeight.w700))),
          _Review(label: 'Furos', value: '${holesExecuted.text} executados / ${_text(parameters['holes'])} planejados'),
          _Review(label: 'Perfuração', value: '${drillingExecuted.text} m / ${_text(summary['drilling_m'])} m planejados'),
          _Review(label: 'APFF', value: nc == 0 ? 'Sem NC registrada' : '$nc não conformidade(s)'),
          _Review(label: s.t('checklist'), value: '${checklist.where((v) => v).length}/${checklist.length}'),
          _Review(label: 'Explosivos', value: '${expTotal.toStringAsFixed(2)} kg'),
          _Review(label: 'Boosters', value: '$bstTotal un'),
          _Review(label: s.t('photos'), value: '${photos.length}'),
          _Review(label: s.t('location'), value: location == null ? s.t('pendingStatus') : '${location!['lat']}, ${location!['lng']}'),
          _Review(label: s.t('signature'), value: signaturePath == null ? s.t('pendingStatus') : s.t('recordedStatus')),
          _Review(label: s.t('observations'), value: observations.text.isEmpty ? '—' : observations.text),
          if (nc > 0) const Padding(padding: EdgeInsets.only(top: 14), child: Text('Atenção: há não conformidades na análise preliminar. Os comentários serão preservados e a operação ficará sinalizada para acompanhamento.', style: TextStyle(color: Colors.orangeAccent, height: 1.4))),
          const SizedBox(height: 14),
          Text(s.t('offlineFinishInfo'), style: const TextStyle(color: Colors.orangeAccent, height: 1.4)),
        ]);
    }
  }

  Widget _number({required String holeLabel, required TextEditingController controller, bool integer = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !integer),
          decoration: InputDecoration(labelText: holeLabel),
        ),
      );

  List<Widget> _preliminaryWidgets() {
    final widgets = <Widget>[];
    String lastSection = '';
    for (final item in preliminaryItems) {
      final id = '${item['id'] ?? ''}';
      final section = '${item['section'] ?? ''}';
      if (section != lastSection) {
        lastSection = section;
        widgets.add(Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 8), child: Text(section, style: const TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w900, fontSize: 16))));
      }
      final blocking = item['blocking'] == true;
      widgets.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${item['label'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
            if (blocking) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Item marcado como impeditivo no formulário de referência.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: preliminaryStatus[id] == null || preliminaryStatus[id] == 'pending' ? null : preliminaryStatus[id],
              decoration: const InputDecoration(labelText: 'Situação'),
              items: const [
                DropdownMenuItem(value: 'conform', child: Text('C — Conforme')),
                DropdownMenuItem(value: 'nonconform', child: Text('NC — Não conforme')),
                DropdownMenuItem(value: 'na', child: Text('N/A — Não aplicável')),
              ],
              onChanged: (v) => setState(() => preliminaryStatus[id] = v ?? 'pending'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: preliminaryNote[id] ?? '',
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Comentário / tratativa'),
              onChanged: (v) => preliminaryNote[id] = v.trim(),
            ),
          ]),
        ),
      ));
    }
    return widgets;
  }

  Widget _materialsStep() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Explosivos utilizados', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Informe somente quantidades efetivamente utilizadas.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 12),
        if (explosiveCatalog.isEmpty) const Text('Catálogo de explosivos indisponível.'),
        ...explosiveCatalog.where((e) => e['active'] != false).map((e) {
          final id = '${e['id']}';
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${e['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), Text('${e['category'] ?? ''}', style: const TextStyle(color: Colors.white60))])),
            const SizedBox(width: 12),
            SizedBox(width: 120, child: TextFormField(initialValue: explosiveQty[id]?.toString() ?? '', keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'kg'), onChanged: (v) { final q = _num(v); if (q > 0) explosiveQty[id] = q; else explosiveQty.remove(id); })),
          ])));
        }),
        const SizedBox(height: 20),
        const Text('Boosters utilizados', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        if (boosterCatalog.isEmpty) const Text('Catálogo de boosters indisponível.'),
        ...boosterCatalog.where((e) => e['active'] != false).map((b) {
          final id = '${b['id']}';
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${b['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), if (b['weight_g'] != null) Text('${b['weight_g']} g', style: const TextStyle(color: Colors.white60))])),
            const SizedBox(width: 12),
            SizedBox(width: 120, child: TextFormField(initialValue: boosterQty[id]?.toString() ?? '', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'un'), onChanged: (v) { final q = _num(v).round(); if (q > 0) boosterQty[id] = q; else boosterQty.remove(id); })),
          ])));
        }),
      ]);

  Future<void> _next() async {
    if (step == 0 && (site.text.trim().isEmpty || team.trim().isEmpty)) return _toast(AppStrings(widget.controller.language).t('informSiteTeam'));
    if (step == 1 && _num(holesExecuted.text) < 1) return _toast('Informe o total de furos executados.');
    if (step == 2) {
      for (final item in preliminaryItems) {
        final id = '${item['id'] ?? ''}';
        final status = preliminaryStatus[id] ?? 'pending';
        if (item['required'] != false && status == 'pending') return _toast('Preencha todos os itens obrigatórios da análise preliminar.');
        if (item['allow_na'] == false && status == 'na') return _toast('Há item obrigatório que não permite N/A.');
        if (status == 'nonconform' && (preliminaryNote[id] ?? '').trim().isEmpty) return _toast('Descreva cada não conformidade antes de continuar.');
      }
      if (preliminaryStatus.values.any((v) => v == 'nonconform') && condition == 'Conforme') condition = 'Atenção';
    }
    if (step == 3 && checklist.any((v) => !v)) return _toast(AppStrings(widget.controller.language).t('completeChecklist'));
    if (step == 6 && location == null) return _toast(AppStrings(widget.controller.language).t('captureLocationFirst'));
    if (step == 8) {
      if (signature.isNotEmpty) {
        final bytes = await signature.toPngBytes();
        if (bytes != null) signaturePath = await widget.controller.media.saveSignature(bytes);
      }
      if (signaturePath == null) return _toast(AppStrings(widget.controller.language).t('collectSignature'));
    }
    await _saveDraft(showMessage: false);
    if (mounted) setState(() => step++);
  }

  Future<void> _saveDraft({bool showMessage = true}) async {
    await widget.controller.saveDraft('${widget.plan['id']}', _payload());
    if (showMessage) _toast(AppStrings(widget.controller.language).t('draftSaved'));
  }

  Map<String, dynamic> _payload() {
    final me = '${widget.controller.currentUser?['id'] ?? ''}';
    if (me.isNotEmpty) participantIds.add(me);
    final prelim = preliminaryItems.map((item) {
      final id = '${item['id'] ?? ''}';
      return {
        'id': id,
        'section': '${item['section'] ?? ''}',
        'label': '${item['label'] ?? ''}',
        'status': preliminaryStatus[id] ?? 'pending',
        'note': preliminaryNote[id] ?? '',
        'required': item['required'] != false,
        'allow_na': item['allow_na'] != false,
        'blocking': item['blocking'] == true,
      };
    }).toList();
    final explosives = explosiveCatalog.where((e) => (explosiveQty['${e['id']}'] ?? 0) > 0).map((e) => {
          'explosive_id': '${e['id']}',
          'name': '${e['name'] ?? ''}',
          'category': '${e['category'] ?? 'other'}',
          'density_kg_l': e['density_kg_l'],
          'kg_per_meter': e['kg_per_meter'],
          'quantity_kg': explosiveQty['${e['id']}'],
          'notes': '',
        }).toList();
    final boosters = boosterCatalog.where((b) => (boosterQty['${b['id']}'] ?? 0) > 0).map((b) => {
          'booster_id': '${b['id']}',
          'name': '${b['name'] ?? ''}',
          'quantity': boosterQty['${b['id']}'],
          'unit': 'un',
          'notes': '',
        }).toList();
    final checklistAnswers = <Map<String, dynamic>>[];
    for (var i = 0; i < checklistItems.length; i++) {
      checklistAnswers.add({'id': 'op_${i + 1}', 'section': 'Checklist operacional', 'label': checklistItems[i], 'status': checklist[i] ? 'conform' : 'pending', 'note': '', 'required': true, 'allow_na': false, 'blocking': false});
    }
    return {
      'client_uuid': clientUuid,
      'plan_id': widget.plan['id'],
      'site': site.text.trim(),
      'team': team,
      'condition': condition,
      'participant_ids': participantIds.toList(),
      'holes_executed': _num(holesExecuted.text).round(),
      'drilling_m_executed': drillingExecuted.text.trim().isEmpty ? null : _num(drillingExecuted.text),
      'rock_density_t_m3': rockDensity.text.trim().isEmpty ? null : _num(rockDensity.text),
      'preliminary_context': {
        'actual_average_hole_depth_m': actualAverageDepth.text.trim().isEmpty ? null : _num(actualAverageDepth.text),
        'stemming_height_m': stemmingHeight.text.trim().isEmpty ? null : _num(stemmingHeight.text),
        'weather_conditions': weather.text.trim(),
        'water_presence_percent': waterPercent.text.trim().isEmpty ? null : _num(waterPercent.text),
        'dismantle_type': dismantleType.text.trim(),
        'scheduled_time': scheduledTime.text.trim(),
        'loading_start_time': loadingStartTime.text.trim(),
        'loading_end_time': loadingEndTime.text.trim(),
      },
      'preliminary_analysis': prelim,
      'checklist': checklist,
      'checklist_items': checklistItems,
      'checklist_answers': checklistAnswers,
      'explosives': explosives,
      'boosters': boosters,
      'photo_paths': photos,
      'location': location,
      'observations': observations.text.trim(),
      'signature_path': signaturePath,
    };
  }

  Future<void> _finish() async {
    if (_num(holesExecuted.text) < 1) return _toast('Informe o total de furos executados.');
    for (final item in preliminaryItems) {
      final id = '${item['id'] ?? ''}';
      final status = preliminaryStatus[id] ?? 'pending';
      if (item['required'] != false && status == 'pending') return _toast('A análise preliminar está incompleta.');
      if (item['allow_na'] == false && status == 'na') return _toast('Há item obrigatório da análise preliminar que não permite N/A.');
      if (status == 'nonconform' && (preliminaryNote[id] ?? '').trim().isEmpty) return _toast('Descreva cada não conformidade antes de finalizar.');
    }
    if (preliminaryStatus.values.any((v) => v == 'nonconform') && condition == 'Conforme') condition = 'Atenção';
    if (checklist.any((v) => !v)) return _toast(AppStrings(widget.controller.language).t('checklistIncomplete'));
    if (location == null) return _toast(AppStrings(widget.controller.language).t('locationPending'));
    if (signaturePath == null) return _toast(AppStrings(widget.controller.language).t('signaturePending'));
    await widget.controller.finishOperation(_payload());
    if (!mounted) return;
    _toast(AppStrings(widget.controller.language).t('awaitingSync'));
    Navigator.of(context).pop();
  }

  Future<void> _capturePhoto() async {
    final path = await widget.controller.media.capturePhoto();
    if (path != null && mounted) setState(() => photos.add(path));
  }

  Future<void> _gallery() async {
    final selected = await widget.controller.media.selectPhotos(remaining: 8 - photos.length);
    if (mounted) setState(() => photos.addAll(selected.take(8 - photos.length)));
  }

  Future<void> _captureLocation() async {
    try {
      final pos = await widget.controller.location.bestPosition();
      if (!mounted) return;
      setState(() => location = {'lat': pos.latitude, 'lng': pos.longitude, 'accuracy': pos.accuracy, 'label': site.text.trim()});
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Review extends StatelessWidget {
  final String label;
  final String value;
  const _Review({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.white60))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

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
  String team = '';
  String condition = 'Conforme';
  String clientUuid = '';
  List<String> checklistItems = [];
  List<bool> checklist = [];
  List<String> photos = [];
  Map<String, dynamic>? location;
  String? signaturePath;
  List<Map<String, dynamic>> teams = [];
  late final SignatureController signature;

  @override
  void initState() {
    super.initState();
    site = TextEditingController(text: (widget.initialDraft?['site'] ?? widget.plan['site'] ?? '').toString());
    observations = TextEditingController(text: (widget.initialDraft?['observations'] ?? '').toString());
    team = (widget.initialDraft?['team'] ?? widget.plan['team'] ?? '').toString();
    condition = (widget.initialDraft?['condition'] ?? 'Conforme').toString();
    clientUuid = (widget.initialDraft?['client_uuid'] ?? const Uuid().v4()).toString();
    photos = List<String>.from(widget.initialDraft?['photo_paths'] as List? ?? const []);
    final rawLoc = widget.initialDraft?['location'];
    if (rawLoc is Map) location = Map<String, dynamic>.from(rawLoc);
    signaturePath = widget.initialDraft?['signature_path']?.toString();
    signature = SignatureController(penStrokeWidth: 3, penColor: Colors.white, exportBackgroundColor: Colors.black);
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    final allTeams = await widget.controller.teams();
    final company = (widget.plan['company_id'] ?? '').toString();
    teams = allTeams.where((t) => company.isEmpty || (t['company_id'] ?? '').toString() == company).toList();
    final models = await widget.controller.checklists();
    if (models.isNotEmpty) {
      final raw = models.first['items'];
      if (raw is List) checklistItems = raw.map((e) => e.toString()).toList();
    }
    final savedChecklist = widget.initialDraft?['checklist'];
    if (savedChecklist is List && savedChecklist.length == checklistItems.length) {
      checklist = savedChecklist.map((e) => e == true).toList();
    } else {
      checklist = List<bool>.filled(checklistItems.length, false);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    site.dispose();
    observations.dispose();
    signature.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(widget.controller.language);
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final titles = [s.t('site'), s.t('checklist'), s.t('photos'), s.t('location'), s.t('observations'), s.t('signature'), s.t('review')];
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
                  Expanded(child: ElevatedButton(onPressed: step == 6 ? _finish : _next, child: Text(step == 6 ? s.t('finish') : s.t('next')))),
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
          Text((widget.plan['name'] ?? widget.plan['code'] ?? 'Plano').toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text((widget.plan['client'] ?? widget.plan['identification'] ?? '').toString(), style: const TextStyle(color: Colors.white60)),
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
            items: [
              DropdownMenuItem(value: 'Conforme', child: Text(s.t('conform'))),
              DropdownMenuItem(value: 'Atenção', child: Text(s.t('requiresAttention'))),
            ],
            onChanged: (v) => setState(() => condition = v ?? 'Conforme'),
          ),
        ]);
      case 1:
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
      case 2:
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
      case 3:
        return ListView(padding: const EdgeInsets.all(16), children: [
          ElevatedButton.icon(onPressed: _captureLocation, icon: const Icon(Icons.gps_fixed), label: Text(s.t('getLocation'))),
          const SizedBox(height: 18),
          if (location != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Lat: ${location!['lat']}'),
            Text('Lng: ${location!['lng']}'),
            Text('${s.t('accuracy')}: ±${((location!['accuracy'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} m', style: const TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w800)),
          ]))) else Text(s.t('noLocation'), textAlign: TextAlign.center),
        ]);
      case 4:
        return ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: observations, minLines: 7, maxLines: 12, decoration: InputDecoration(labelText: s.t('observations'), alignLabelWithHint: true)),
        ]);
      case 5:
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
        return ListView(padding: const EdgeInsets.all(16), children: [
          _Review(label: s.t('plan'), value: (widget.plan['name'] ?? widget.plan['code'] ?? '').toString()),
          _Review(label: s.t('site'), value: site.text),
          _Review(label: s.t('team'), value: team),
          _Review(label: s.t('condition'), value: condition),
          _Review(label: s.t('checklist'), value: '${checklist.where((v) => v).length}/${checklist.length}'),
          _Review(label: s.t('photos'), value: '${photos.length}'),
          _Review(label: s.t('location'), value: location == null ? s.t('pendingStatus') : '${location!['lat']}, ${location!['lng']}'),
          _Review(label: s.t('signature'), value: signaturePath == null ? s.t('pendingStatus') : s.t('recordedStatus')),
          _Review(label: s.t('observations'), value: observations.text.isEmpty ? '—' : observations.text),
          const SizedBox(height: 14),
          Text(s.t('offlineFinishInfo'), style: const TextStyle(color: Colors.orangeAccent, height: 1.4)),
        ]);
    }
  }

  Future<void> _next() async {
    if (step == 0 && (site.text.trim().isEmpty || team.trim().isEmpty)) return _toast(AppStrings(widget.controller.language).t('informSiteTeam'));
    if (step == 1 && checklist.any((v) => !v)) return _toast(AppStrings(widget.controller.language).t('completeChecklist'));
    if (step == 3 && location == null) return _toast(AppStrings(widget.controller.language).t('captureLocationFirst'));
    if (step == 5) {
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

  Map<String, dynamic> _payload() => {
        'client_uuid': clientUuid,
        'plan_id': widget.plan['id'],
        'site': site.text.trim(),
        'team': team,
        'condition': condition,
        'checklist': checklist,
        'checklist_items': checklistItems,
        'photo_paths': photos,
        'location': location,
        'observations': observations.text.trim(),
        'signature_path': signaturePath,
      };

  Future<void> _finish() async {
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

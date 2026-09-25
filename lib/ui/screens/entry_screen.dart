import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/i18n.dart';
import '../theme.dart';
import 'terms_screen.dart';

class EntryScreen extends StatelessWidget {
  final AppController controller;
  const EntryScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(controller.language);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/quarry.png', fit: BoxFit.cover, alignment: Alignment.center),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE90B1117), Color(0xFA080C10)]))),
          SafeArea(
            child: Column(children: [
              SizedBox(height: 24, width: double.infinity, child: Image.asset('assets/hazard.png', fit: BoxFit.cover)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: SegmentedButton<String>(
                        segments: const [ButtonSegment(value: 'pt-BR', label: Text('PT')), ButtonSegment(value: 'en', label: Text('EN')), ButtonSegment(value: 'es', label: Text('ES'))],
                        selected: {controller.language},
                        onSelectionChanged: (set) => controller.setLanguage(set.first),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(child: Image.asset('assets/logo.png', width: 245)),
                    const SizedBox(height: 12),
                    Text(s.t('appTagline'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB8BEC5), fontWeight: FontWeight.w700, letterSpacing: .5)),
                    const SizedBox(height: 6),
                    const Text('CÁLCULO PROFISSIONAL DE BLASTING', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: MinaTheme.yellow, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.black, size: 40),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.t('safetyTitle'), style: const TextStyle(color: Colors.black, fontSize: 19, fontWeight: FontWeight.w900)),
                          Text(s.t('safetySub'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                        ])),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    _ValueCard(icon: Icons.verified_outlined, title: s.t('missionTitle'), lines: const ['Planejar desmonte seguro e controlado', 'Minimizar riscos à equipe e ao entorno', 'Garantir conformidade técnica e legal']),
                    const SizedBox(height: 10),
                    _ValueCard(icon: Icons.visibility_outlined, title: s.t('visionTitle'), lines: const ['Ser referência em segurança no desmonte', 'Inovação com responsabilidade e precisão', 'Ambiente zero acidente como padrão']),
                    const SizedBox(height: 10),
                    _ValueCard(icon: Icons.shield_outlined, title: s.t('valuesTitle'), lines: const ['Segurança em primeiro lugar, sempre', 'Ética, transparência e respeito', 'Competência e profissionalismo contínuo']),
                    const SizedBox(height: 18),
                    const Center(child: Column(children: [Text('Robério Sousa', style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('20 anos de experiência em segurança e desmonte de rocha', textAlign: TextAlign.center, style: TextStyle(color: MinaTheme.muted, fontSize: 12))])),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TermsScreen(controller: controller))),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(s.t('access').toUpperCase()),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18, width: double.infinity, child: Image.asset('assets/hazard.png', fit: BoxFit.cover)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lines;
  const _ValueCard({required this.icon, required this.title, required this.lines});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xE6111920), border: Border.all(color: MinaTheme.border), borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF2B2515), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: MinaTheme.yellow)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            ...lines.map((x) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $x', style: const TextStyle(color: Color(0xFFC8D0D7), fontSize: 12)))),
          ])),
        ]),
      );
}

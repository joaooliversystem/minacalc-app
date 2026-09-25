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
      body: SafeArea(
        child: Column(
          children: [
            Container(height: 24, decoration: const BoxDecoration(gradient: LinearGradient(colors: [MinaTheme.yellow, Colors.black, MinaTheme.yellow, Colors.black]))),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'pt-BR', label: Text('PT')),
                          ButtonSegment(value: 'en', label: Text('EN')),
                          ButtonSegment(value: 'es', label: Text('ES')),
                        ],
                        selected: {controller.language},
                        onSelectionChanged: (set) => controller.setLanguage(set.first),
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Icon(Icons.engineering, color: MinaTheme.yellow, size: 74),
                    const SizedBox(height: 8),
                    const Text('MinaCalc Pro', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: MinaTheme.yellow)),
                    Text(s.t('appTagline'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: MinaTheme.yellow, borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.black, size: 44),
                        Text(s.t('safetyTitle').toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900)),
                        Text(s.t('safetySub'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(child: _ValueCard(icon: Icons.track_changes, title: s.t('missionTitle'), text: s.t('missionText'))),
                      const SizedBox(width: 10),
                      Expanded(child: _ValueCard(icon: Icons.visibility_outlined, title: s.t('visionTitle'), text: s.t('visionText'))),
                    ]),
                    const SizedBox(height: 10),
                    _ValueCard(icon: Icons.verified_user_outlined, title: s.t('valuesTitle'), text: s.t('valuesText')),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TermsScreen(controller: controller))),
                      icon: const Icon(Icons.lock_open_outlined),
                      label: Text(s.t('access').toUpperCase()),
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 18, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.black, MinaTheme.yellow, Colors.black, MinaTheme.yellow]))),
          ],
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _ValueCard({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: MinaTheme.panel, border: Border.all(color: const Color(0xFF5A4A18)), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: MinaTheme.yellow, size: 32),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, height: 1.3)),
      ]),
    );
  }
}

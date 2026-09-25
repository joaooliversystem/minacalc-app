import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/i18n.dart';
import '../theme.dart';
import 'login_screen.dart';

class TermsScreen extends StatefulWidget {
  final AppController controller;
  const TermsScreen({super.key, required this.controller});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool accepted = false;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(widget.controller.language);
    return Scaffold(
      appBar: AppBar(title: Text('MinaCalc | ${s.t('fieldMode')}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.warning_amber_rounded, color: MinaTheme.yellow, size: 82),
            const SizedBox(height: 8),
            Text(s.t('termsTitle').toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w900, fontSize: 26)),
            Text(s.t('termsSub'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD7BD62), fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(border: Border.all(color: MinaTheme.yellow, width: 1.6), borderRadius: BorderRadius.circular(16), color: MinaTheme.panel),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.t('legalTitle'), style: const TextStyle(color: MinaTheme.yellow, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text(s.legalNotice, style: const TextStyle(height: 1.45, fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              value: accepted,
              activeColor: MinaTheme.yellow,
              checkColor: Colors.black,
              title: Text(s.t('understood'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              onChanged: (v) => setState(() => accepted = v ?? false),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: accepted
                  ? () async {
                      await widget.controller.acceptTerms(true);
                      if (!context.mounted) return;
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginScreen(controller: widget.controller)));
                    }
                  : null,
              icon: const Icon(Icons.shield_outlined),
              label: Text(s.t('agree').toUpperCase()),
            ),
            const SizedBox(height: 16),
            Text('${s.t('term')} ${widget.controller.termsVersion} • MinaCalc Pro ${widget.controller.appConfig?['server_version'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

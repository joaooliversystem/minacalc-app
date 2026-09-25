import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/i18n.dart';

class ProfileScreen extends StatelessWidget {
  final AppController controller;
  const ProfileScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(controller.language);
    final user = controller.currentUser ?? const <String, dynamic>{};
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 38)),
        const SizedBox(height: 12),
        Text('${user['name'] ?? user['username'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text('${user['role'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 24),
        Text(s.t('language'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'pt-BR', label: Text('PT')), ButtonSegment(value: 'en', label: Text('EN')), ButtonSegment(value: 'es', label: Text('ES'))],
          selected: {controller.language},
          onSelectionChanged: (v) => controller.setLanguage(v.first),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(onPressed: controller.logout, icon: const Icon(Icons.logout), label: Text(s.t('logout'))),
      ],
    );
  }
}

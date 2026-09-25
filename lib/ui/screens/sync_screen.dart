import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/i18n.dart';
import '../widgets/status_badge.dart';

class SyncScreen extends StatelessWidget {
  final AppController controller;
  const SyncScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(controller.language);
    final sync = controller.sync;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(s.t('deviceSync'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: SyncStatusBadge(controller: controller)),
        const SizedBox(height: 22),
        ListTile(leading: const Icon(Icons.pending_actions), title: Text('${sync.pendingCount} ${s.t('pending')}')),
        if (sync.conflictCount > 0) ListTile(leading: const Icon(Icons.compare_arrows, color: Colors.orangeAccent), title: Text('${sync.conflictCount} ${s.t('conflicts')}')),
        if (sync.lastSyncAt != null) ListTile(leading: const Icon(Icons.schedule), title: Text(s.t('lastSync')), subtitle: Text(sync.lastSyncAt!.toLocal().toString())),
        if (sync.lastError != null) ListTile(leading: const Icon(Icons.error_outline, color: Colors.redAccent), title: Text(s.t('lastError')), subtitle: Text(sync.lastError!)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: sync.syncNow, icon: const Icon(Icons.sync), label: Text(s.t('retry').toUpperCase())),
        const SizedBox(height: 18),
        Text(s.t('syncDescription'), style: const TextStyle(color: Colors.white60, height: 1.4)),
      ],
    );
  }
}

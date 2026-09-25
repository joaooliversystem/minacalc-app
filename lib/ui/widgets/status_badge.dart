import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../core/i18n.dart';
import '../../services/sync_engine.dart';

class SyncStatusBadge extends StatelessWidget {
  final AppController controller;
  const SyncStatusBadge({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(controller.language);
    final sync = controller.sync;
    if (controller.offlineSessionOnly) {
      const color = Colors.orangeAccent;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), border: Border.all(color: color.withValues(alpha: .6)), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_clock_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(s.t('offlineSession'), overflow: TextOverflow.ellipsis, style: const TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      );
    }
    final (label, color, icon) = switch (sync.mode) {
      SyncMode.online => (s.t('online'), Colors.greenAccent, Icons.cloud_done_outlined),
      SyncMode.offline => (s.t('offline'), Colors.orangeAccent, Icons.cloud_off_outlined),
      SyncMode.syncing => ('${s.t('syncing')} • ${sync.pendingCount}', Colors.amberAccent, Icons.sync),
      SyncMode.error => (s.t('syncError'), Colors.redAccent, Icons.error_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

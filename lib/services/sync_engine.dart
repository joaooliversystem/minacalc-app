import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/local_db.dart';
import 'connectivity_service.dart';

enum SyncMode { online, offline, syncing, error }

class SyncEngine extends ChangeNotifier {
  final LocalDb db;
  final ApiClient api;
  final ConnectivityService connectivity;
  final Future<void> Function()? onSessionInvalid;
  StreamSubscription<bool>? _networkSub;
  bool _running = false;
  SyncMode mode = SyncMode.offline;
  int pendingCount = 0;
  int conflictCount = 0;
  String? lastError;
  DateTime? lastSyncAt;

  SyncEngine({required this.db, required this.api, required this.connectivity, this.onSessionInvalid});

  Future<void> _refreshCounters() async {
    pendingCount = await db.pendingCount();
    conflictCount = await db.conflictCount();
  }

  Future<void> start() async {
    await _refreshCounters();
    _networkSub ??= connectivity.changes.listen((hasNetwork) {
      if (!hasNetwork) {
        mode = SyncMode.offline;
        notifyListeners();
      } else {
        unawaited(syncNow());
      }
    });
    if (connectivity.hasNetwork) unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (_running || api.token == null || api.token!.isEmpty) return;
    if (!connectivity.hasNetwork) {
      mode = SyncMode.offline;
      await _refreshCounters();
      notifyListeners();
      return;
    }
    _running = true;
    mode = SyncMode.syncing;
    lastError = null;
    notifyListeners();
    try {
      await api.status();
      await _pushQueue();
      await _pullAll();
      await _refreshCounters();
      mode = SyncMode.online;
      lastSyncAt = DateTime.now();
    } on ApiException catch (e) {
      lastError = e.message;
      if (e.statusCode == 401 || e.statusCode == 403) {
        await onSessionInvalid?.call();
      }
      mode = e.statusCode == 0 ? SyncMode.offline : SyncMode.error;
    } catch (e) {
      lastError = e.toString();
      mode = SyncMode.error;
    } finally {
      _running = false;
      await _refreshCounters();
      notifyListeners();
    }
  }

  Future<void> _pushQueue() async {
    final rows = await db.pendingQueue(limit: 100);
    for (final row in rows) {
      final id = row['id'] as int;
      final kind = row['kind'] as String;
      final payload = Map<String, dynamic>.from(row['payload'] as Map);
      try {
        if (kind == 'evidence_upload') {
          final path = (payload['path'] ?? '').toString();
          if (path.isEmpty || !await File(path).exists()) {
            throw ApiException('A foto local não está mais disponível.', 422);
          }
          await api.uploadEvidence(
            clientUuid: (payload['client_uuid'] ?? '').toString(),
            uploadId: (payload['client_upload_id'] ?? '').toString(),
            path: path,
          );
          await db.queueDone(id);
          continue;
        }

        final data = Map<String, dynamic>.from(payload);
        if (kind == 'operation_commit') {
          final signaturePath = (data.remove('signature_path') ?? '').toString();
          data.remove('photo_paths');
          data['photos'] = <String>[];
          if (signaturePath.isEmpty || !await File(signaturePath).exists()) {
            throw ApiException('Assinatura local não encontrada.', 422);
          }
          data['signature'] = await _dataUri(signaturePath, 'image/png');
        }

        final change = <String, dynamic>{
          'mutation_id': row['mutation_id'],
          'kind': kind,
          'data': data,
          if (row['base_version'] != null) 'base_version': row['base_version'],
        };
        final response = await api.push([change]);
        final results = response['results'];
        if (results is! List || results.isEmpty) throw ApiException('Servidor não confirmou a sincronização.', 500);
        final result = Map<String, dynamic>.from(results.first as Map);
        if (result['ok'] != true) {
          throw ApiException((result['message'] ?? 'Alteração não sincronizada.').toString(), (result['status'] as num?)?.toInt() ?? 422);
        }
        await db.queueDone(id);
        if (kind == 'operation_commit') {
          final clientUuid = (data['client_uuid'] ?? '').toString();
          if (clientUuid.isNotEmpty) await db.deleteLocal('local_operations', clientUuid);
        }
      } on ApiException catch (e) {
        if (e.statusCode == 409) {
          await db.queueConflict(id, e.message);
          continue;
        }
        await db.queueError(id, e.message);
        if (e.statusCode == 401 || e.statusCode == 403) rethrow;
        if (e.statusCode == 0) rethrow;
      } catch (e) {
        await db.queueError(id, e.toString());
        rethrow;
      }
    }
  }

  Future<void> _pullAll() async {
    var cursor = int.tryParse(await db.getMeta('sync_cursor') ?? '0') ?? 0;
    var keepGoing = true;
    while (keepGoing) {
      final response = await api.pull(cursor);
      if (response['reset_required'] == true) {
        final full = await api.snapshot();
        final snapshot = Map<String, dynamic>.from(full['snapshot'] as Map);
        await db.applySnapshot(snapshot);
        return;
      }
      final events = response['events'];
      if (events is List) {
        for (final raw in events) {
          if (raw is Map) await db.applySyncEvent(Map<String, dynamic>.from(raw));
        }
      }
      cursor = (response['cursor'] as num?)?.toInt() ?? cursor;
      await db.setMeta('sync_cursor', '$cursor');
      keepGoing = response['has_more'] == true;
    }
  }

  Future<String> _dataUri(String path, String mime) async {
    final bytes = await File(path).readAsBytes();
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  Future<void> disposeEngine() async {
    await _networkSub?.cancel();
  }
}

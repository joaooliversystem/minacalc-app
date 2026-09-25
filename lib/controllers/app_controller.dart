import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../data/api_client.dart';
import '../data/local_db.dart';
import '../data/session_store.dart';
import '../services/connectivity_service.dart';
import '../services/location_service.dart';
import '../services/media_service.dart';
import '../services/offline_map_service.dart';
import '../services/sync_engine.dart';

class AppController extends ChangeNotifier {
  final LocalDb db = LocalDb();
  final ApiClient api = ApiClient();
  final SessionStore session = SessionStore();
  final ConnectivityService connectivity = ConnectivityService();
  final LocationService location = LocationService();
  final MediaService media = MediaService();
  final OfflineMapService offlineMaps = OfflineMapService();
  final Uuid _uuid = const Uuid();

  late final SyncEngine sync;
  bool initialized = false;
  bool termsAccepted = false;
  bool hasSession = false;
  bool offlineSessionOnly = false;
  String language = 'pt-BR';
  String termsVersion = AppConstants.fallbackTermsVersion;
  Map<String, dynamic>? currentUser;
  Map<String, dynamic>? appConfig;
  String? authError;

  Future<void> initialize() async {
    await db.db;
    language = await session.language();
    termsAccepted = await session.termsAccepted();
    await connectivity.start();
    final token = await session.token;
    final user = await session.user;
    final expires = await session.expiresAt;
    final sessionStillValid = expires == null || expires.isAfter(DateTime.now());
    if (token != null && user != null && sessionStillValid) {
      api.token = token;
      currentUser = user;
      hasSession = true;
      offlineSessionOnly = false;
    } else if (token != null && user != null && !connectivity.hasNetwork) {
      api.token = token;
      currentUser = user;
      hasSession = true;
      offlineSessionOnly = true;
    } else if (token != null) {
      await session.clearSession();
    }
    sync = SyncEngine(
      db: db,
      api: api,
      connectivity: connectivity,
      onSyncSuccess: _refreshAuxiliaryData,
      onSessionInvalid: () async {
        await session.clearSession();
        api.token = null;
        hasSession = false;
        offlineSessionOnly = false;
        currentUser = null;
        authError = 'Sua sessão precisa ser renovada. Faça login online novamente.';
        notifyListeners();
      },
    );
    sync.addListener(notifyListeners);
    if (hasSession) await sync.start();
    initialized = true;
    notifyListeners();
    if (connectivity.hasNetwork) {
      unawaited(refreshConfig());
      if (hasSession) unawaited(_refreshAuxiliaryData());
    }
  }

  Future<void> refreshConfig() async {
    try {
      appConfig = await api.appConfig();
      termsVersion = (appConfig?['terms_version'] ?? AppConstants.fallbackTermsVersion).toString();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _refreshAuxiliaryData() async {
    if (!connectivity.hasNetwork || api.token == null || api.token!.isEmpty) return;
    try {
      final boot = await api.bootstrap();
      for (final collection in const ['reports', 'alerts']) {
        final raw = boot[collection];
        if (raw is List) {
          await db.replaceCollection(
            collection,
            raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
          );
        }
      }
      if (boot['settings'] is Map) {
        final settings = Map<String, dynamic>.from(boot['settings'] as Map);
        settings['id'] = 'main';
        await db.putLocal('settings', 'main', settings);
        await db.setMeta('server_settings', jsonEncode(settings));
      }
      notifyListeners();
    } catch (_) {
      // Auxiliary data is best-effort. Core offline/sync data remains available.
    }
  }

  Future<void> setLanguage(String value) async {
    language = value;
    await session.setLanguage(value);
    notifyListeners();
  }

  Future<void> acceptTerms(bool value) async {
    termsAccepted = value;
    await session.setTermsAccepted(value);
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    authError = null;
    if (!connectivity.hasNetwork) {
      authError = 'O primeiro login neste aparelho exige conexão com a internet.';
      notifyListeners();
      return false;
    }
    try {
      final config = await api.appConfig();
      appConfig = config;
      termsVersion = (config['terms_version'] ?? AppConstants.fallbackTermsVersion).toString();
      final response = await api.login(
        username: username,
        password: password,
        deviceId: await session.deviceId(),
        language: language,
        termsVersion: termsVersion,
      );
      final token = (response['access_token'] ?? '').toString();
      final user = Map<String, dynamic>.from(response['user'] as Map);
      api.token = token;
      await session.saveSession(token: token, user: user, expiresAt: (response['expires_at'] ?? '').toString());
      currentUser = user;
      hasSession = true;
      offlineSessionOnly = false;
      if (response['snapshot'] is Map) {
        await db.applySnapshot(Map<String, dynamic>.from(response['snapshot'] as Map));
      }
      await sync.start();
      await _refreshAuxiliaryData();
      notifyListeners();
      return true;
    } catch (e) {
      authError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    if (connectivity.hasNetwork) await api.logout();
    await session.clearSession();
    await db.clearSyncedData();
    api.token = null;
    currentUser = null;
    hasSession = false;
    offlineSessionOnly = false;
    termsAccepted = false;
    await session.setTermsAccepted(false);
    notifyListeners();
  }

  String get role => (currentUser?['role'] ?? '').toString();
  bool get isManagement => ['admin', 'programador', 'gestor'].contains(role);
  bool get isAdmin => ['admin', 'programador'].contains(role);
  bool get isProgrammer => role == 'programador';
  bool get canOperate => role != 'cliente';

  Future<List<Map<String, dynamic>>> collection(String name) => db.all(name);
  Future<List<Map<String, dynamic>>> plans() => db.all('plans');
  Future<List<Map<String, dynamic>>> operations() => db.all('operations');
  Future<List<Map<String, dynamic>>> teams() => db.all('teams');
  Future<List<Map<String, dynamic>>> companies() => db.all('companies');
  Future<List<Map<String, dynamic>>> users() => db.all('users');
  Future<List<Map<String, dynamic>>> checklists() => db.all('checklists');
  Future<List<Map<String, dynamic>>> materials() => db.all('materials');
  Future<List<Map<String, dynamic>>> approvals() => db.all('approvals');
  Future<List<Map<String, dynamic>>> reports() => db.all('reports');
  Future<List<Map<String, dynamic>>> alerts() => db.all('alerts');
  Future<List<Map<String, dynamic>>> localOperations() => db.all('local_operations');
  Future<List<Map<String, dynamic>>> mapPoints() => db.all('map_points');
  Future<Map<String, dynamic>?> settings() => db.one('settings', 'main');

  Future<Map<String, dynamic>?> draftForPlan(String planId) => db.one('drafts', planId);

  Future<void> saveDraft(String planId, Map<String, dynamic> data) async {
    await db.putLocal('drafts', planId, {...data, 'id': planId, 'updated_at': DateTime.now().toIso8601String()});
    notifyListeners();
  }

  Future<void> queueApiAction({
    required String action,
    required Map<String, dynamic> body,
    String? collection,
    String? recordId,
    Map<String, dynamic>? optimisticRecord,
    bool deleteLocal = false,
    bool removeLocalAfterSync = false,
    String? resultKey,
  }) async {
    if (collection != null && recordId != null) {
      if (deleteLocal) {
        await db.deleteLocal(collection, recordId);
      } else if (optimisticRecord != null) {
        final version = await db.recordVersion(collection, recordId);
        await db.putLocal(collection, recordId, optimisticRecord, version: version);
      }
    }
    final identity = recordId ?? _uuid.v4();
    await db.enqueue(
      mutationId: 'api-$action-$identity',
      kind: 'api_action',
      payload: {
        'action': action,
        'body': body,
        if (collection != null) 'local_collection': collection,
        if (recordId != null) 'local_record_id': recordId,
        if (removeLocalAfterSync) 'remove_local_after_sync': true,
        if (resultKey != null) 'result_key': resultKey,
      },
      baseVersion: recordId == null || collection == null ? null : await db.recordVersion(collection, recordId),
    );
    notifyListeners();
    await sync.syncNow();
    notifyListeners();
  }

  Future<void> savePlan(Map<String, dynamic> values, {Map<String, dynamic>? existing}) async {
    final isNew = existing == null;
    final localId = (existing?['id'] ?? 'local_pl_${_uuid.v4()}').toString();
    final p = Map<String, dynamic>.from(values)..['id'] = isNew ? '' : localId;
    final parseNum = (Object? v) => double.tryParse('$v'.replaceAll(',', '.')) ?? 0;
    final params = <String, dynamic>{
      'client_ref': p['client_ref'] ?? '',
      'material_id': p['material_id'] ?? '',
      'bench_height': parseNum(p['bench_height']),
      'hole_depth': parseNum(p['hole_depth']),
      'subdrilling': parseNum(p['subdrilling']),
      'inclination_deg': parseNum(p['inclination_deg']),
      'hole_diameter_mm': parseNum(p['hole_diameter_mm']),
      'holes': parseNum(p['holes']).round(),
      'burden': parseNum(p['burden']),
      'spacing': parseNum(p['spacing']),
      'explosive_type': p['explosive_type'] ?? '',
      'booster': p['booster'] ?? '',
      'explosive_density': parseNum(p['explosive_density']),
      'kg_per_meter': parseNum(p['kg_per_meter']),
      'charge_per_hole_kg': parseNum(p['charge_per_hole_kg']),
      'powder_factor': parseNum(p['powder_factor']),
      'people_radius': parseNum(p['people_radius']),
      'equipment_radius': parseNum(p['equipment_radius']),
      'center_lat': p['center_lat'] ?? '',
      'center_lng': p['center_lng'] ?? '',
    };
    final volume = parseNum(p['burden']) * parseNum(p['spacing']) * parseNum(p['bench_height']) * parseNum(p['holes']);
    final drilling = parseNum(p['hole_depth']) * parseNum(p['holes']);
    final estimated = volume * parseNum(p['powder_factor']);
    final optimistic = <String, dynamic>{
      ...?existing,
      'id': localId,
      'code': existing?['code'] ?? 'PEND-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'name': p['name'] ?? '',
      'site': p['site'] ?? '',
      'team': p['team'] ?? '',
      'team_id': p['team_id'] ?? '',
      'company_id': p['company_id'] ?? currentUser?['company_id'] ?? 'company_default',
      'responsible': p['responsible'] ?? currentUser?['name'] ?? '',
      'status': 'Em revisão',
      'notes': p['notes'] ?? '',
      'parameters': params,
      'summary': {'volume_m3': volume, 'drilling_m': drilling, 'estimated_charge_kg': estimated},
      'updated_at': DateTime.now().toIso8601String(),
      'created_at': existing?['created_at'] ?? DateTime.now().toIso8601String(),
      '_local_pending': true,
    };
    final body = <String, dynamic>{'plan': p};
    final baseVersion = existing?['_sync_version'];
    if (baseVersion is num && baseVersion.toInt() > 0) body['base_version'] = baseVersion.toInt();
    await queueApiAction(
      action: 'plan_save',
      body: body,
      collection: 'plans',
      recordId: localId,
      optimisticRecord: optimistic,
      removeLocalAfterSync: isNew,
      resultKey: 'plan',
    );
  }

  Future<void> duplicatePlan(Map<String, dynamic> source) async {
    final params = Map<String, dynamic>.from(source['parameters'] as Map? ?? const {});
    final values = <String, dynamic>{
      ...params,
      'name': '${(source['name'] ?? 'Plano').toString()} — Cópia',
      'site': source['site'] ?? '',
      'team': source['team'] ?? '',
      'team_id': source['team_id'] ?? '',
      'company_id': source['company_id'] ?? currentUser?['company_id'] ?? 'company_default',
      'responsible': source['responsible'] ?? currentUser?['name'] ?? '',
      'notes': source['notes'] ?? '',
    };
    await savePlan(values);
  }

  Future<void> changePlanStatus(Map<String, dynamic> plan, String status) async {
    final id = '${plan['id']}';
    await queueApiAction(
      action: 'plan_status',
      body: {'id': id, 'status': status},
      collection: 'plans',
      recordId: id,
      optimisticRecord: {...plan, 'status': status, 'updated_at': DateTime.now().toIso8601String(), '_local_pending': true},
    );
  }

  Future<void> deletePlan(Map<String, dynamic> plan) => queueApiAction(
        action: 'plan_delete',
        body: {'id': plan['id']},
        collection: 'plans',
        recordId: '${plan['id']}',
        deleteLocal: true,
      );

  Future<void> saveCompany(Map<String, dynamic> values, {Map<String, dynamic>? existing}) async {
    final id = (existing?['id'] ?? 'emp_${_uuid.v4().replaceAll('-', '').substring(0, 12)}').toString();
    final record = <String, dynamic>{
      ...?existing,
      ...values,
      'id': id,
      'active': values['active'] ?? true,
      'created_at': existing?['created_at'] ?? DateTime.now().toIso8601String(),
      '_local_pending': true,
    };
    await queueApiAction(action: 'company_save', body: {'company': record}, collection: 'companies', recordId: id, optimisticRecord: record);
  }

  Future<void> deleteCompany(Map<String, dynamic> company) => queueApiAction(
        action: 'company_delete',
        body: {'id': company['id']},
        collection: 'companies',
        recordId: '${company['id']}',
        deleteLocal: true,
      );

  Future<void> saveTeam(Map<String, dynamic> values, {Map<String, dynamic>? existing}) async {
    final id = (existing?['id'] ?? 'eq_${_uuid.v4().replaceAll('-', '').substring(0, 12)}').toString();
    final record = <String, dynamic>{
      ...?existing,
      ...values,
      'id': id,
      'members': (values['member_ids'] as List?)?.length ?? existing?['members'] ?? 0,
      'active': values['active'] ?? true,
      '_local_pending': true,
    };
    final bodyTeam = Map<String, dynamic>.from(values)..['id'] = id;
    await queueApiAction(action: 'team_save', body: {'team': bodyTeam}, collection: 'teams', recordId: id, optimisticRecord: record);
  }

  Future<void> deleteTeam(Map<String, dynamic> team) => queueApiAction(
        action: 'team_delete',
        body: {'id': team['id']},
        collection: 'teams',
        recordId: '${team['id']}',
        deleteLocal: true,
      );

  Future<void> saveChecklist(Map<String, dynamic> values, {Map<String, dynamic>? existing}) async {
    final id = (existing?['id'] ?? 'ck_${_uuid.v4().replaceAll('-', '').substring(0, 12)}').toString();
    final record = <String, dynamic>{...?existing, ...values, 'id': id, '_local_pending': true};
    await queueApiAction(action: 'checklist_save', body: {'checklist': record}, collection: 'checklists', recordId: id, optimisticRecord: record);
  }

  Future<void> saveUser(Map<String, dynamic> values, {Map<String, dynamic>? existing}) async {
    final isNew = existing == null;
    final localId = (existing?['id'] ?? 'local_usr_${_uuid.v4()}').toString();
    final bodyUser = Map<String, dynamic>.from(values)..['id'] = isNew ? '' : localId;
    if (isNew) bodyUser['send_invite'] = true;
    bodyUser.remove('password');
    final optimistic = <String, dynamic>{
      ...?existing,
      ...values,
      'id': localId,
      'active': values['active'] ?? true,
      '_local_pending': true,
    };
    await queueApiAction(
      action: 'user_save',
      body: {'user': bodyUser},
      collection: 'users',
      recordId: localId,
      optimisticRecord: optimistic,
      removeLocalAfterSync: isNew,
    );
  }

  Future<void> deleteUser(Map<String, dynamic> user) => queueApiAction(
        action: 'user_delete',
        body: {'id': user['id']},
        collection: 'users',
        recordId: '${user['id']}',
        deleteLocal: true,
      );

  Future<void> decideApproval(Map<String, dynamic> approval, String decision, String note) async {
    final id = '${approval['id']}';
    final status = decision == 'rejeitar' ? 'Rejeitado' : 'Aprovado';
    await queueApiAction(
      action: 'approval_decide',
      body: {'id': id, 'decision': decision, 'note': note},
      collection: 'approvals',
      recordId: id,
      optimisticRecord: {...approval, 'status': status, 'note': note, '_local_pending': true},
    );
  }

  Future<void> markAlertsSeen() async {
    final current = await alerts();
    for (final alert in current) {
      final id = (alert['id'] ?? '').toString();
      if (id.isNotEmpty) await db.putLocal('alerts', id, {...alert, 'seen': true});
    }
    await queueApiAction(action: 'alerts_seen', body: const {});
  }

  Future<void> saveSettings(Map<String, dynamic> values) async {
    final current = await settings() ?? <String, dynamic>{'id': 'main'};
    final optimistic = {...current, ...values, 'id': 'main', '_local_pending': true};
    await queueApiAction(action: 'settings_save', body: values, collection: 'settings', recordId: 'main', optimisticRecord: optimistic, resultKey: 'settings');
  }

  Future<void> finishOperation(Map<String, dynamic> data) async {
    final clientUuid = (data['client_uuid'] ?? _uuid.v4()).toString();
    data['client_uuid'] = clientUuid;
    final photoPaths = List<String>.from(data['photo_paths'] as List? ?? const []);
    await db.enqueue(mutationId: 'op-$clientUuid', kind: 'operation_commit', payload: data);
    for (var i = 0; i < photoPaths.length; i++) {
      final uploadId = '$clientUuid-photo-$i';
      await db.enqueue(
        mutationId: uploadId,
        kind: 'evidence_upload',
        payload: {'client_uuid': clientUuid, 'client_upload_id': uploadId, 'path': photoPaths[i]},
      );
    }
    await db.putLocal('local_operations', clientUuid, {
      'id': clientUuid,
      'client_uuid': clientUuid,
      'plan_id': data['plan_id'],
      'site': data['site'],
      'team': data['team'],
      'status': 'Aguardando sincronização',
      'created_at': DateTime.now().toIso8601String(),
      'sync': 'Pendente',
    });
    await db.deleteLocal('drafts', (data['plan_id'] ?? '').toString());
    await sync.syncNow();
    notifyListeners();
  }

  Future<void> saveMapPoint(Map<String, dynamic> point) async {
    final id = (point['id'] ?? 'local-${_uuid.v4()}').toString();
    point['id'] = id;
    final version = await db.recordVersion('map_points', id);
    await db.putLocal('map_points', id, point, version: version);
    await db.enqueue(
      mutationId: 'map-${_uuid.v4()}',
      kind: 'map_point_upsert',
      payload: point,
      baseVersion: version > 0 ? version : null,
    );
    await sync.syncNow();
    notifyListeners();
  }

  @override
  void dispose() {
    sync.removeListener(notifyListeners);
    unawaited(sync.disposeEngine());
    unawaited(connectivity.dispose());
    super.dispose();
  }
}

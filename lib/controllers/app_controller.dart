import 'dart:async';

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
      // O primeiro login já ocorreu online. Se a credencial expirar durante uma
      // jornada sem sinal, mantemos somente os dados locais até a rede voltar.
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
      onSessionInvalid: () async {
        // O servidor confirmou que a credencial não é mais válida. A partir daqui
        // é necessário renovar online; os dados locais permanecem até o usuário
        // autenticar novamente ou optar por sair da conta.
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
    if (connectivity.hasNetwork) unawaited(refreshConfig());
  }

  Future<void> refreshConfig() async {
    try {
      appConfig = await api.appConfig();
      termsVersion = (appConfig?['terms_version'] ?? AppConstants.fallbackTermsVersion).toString();
      notifyListeners();
    } catch (_) {}
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
      if (response['snapshot'] is Map) await db.applySnapshot(Map<String, dynamic>.from(response['snapshot'] as Map));
      await sync.start();
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

  Future<List<Map<String, dynamic>>> plans() => db.all('plans');
  Future<List<Map<String, dynamic>>> operations() => db.all('operations');
  Future<List<Map<String, dynamic>>> teams() => db.all('teams');
  Future<List<Map<String, dynamic>>> localOperations() => db.all('local_operations');
  Future<List<Map<String, dynamic>>> checklists() => db.all('checklists');
  Future<List<Map<String, dynamic>>> mapPoints() => db.all('map_points');

  Future<Map<String, dynamic>?> draftForPlan(String planId) => db.one('drafts', planId);

  Future<void> saveDraft(String planId, Map<String, dynamic> data) async {
    await db.putLocal('drafts', planId, {...data, 'id': planId, 'updated_at': DateTime.now().toIso8601String()});
    notifyListeners();
  }

  Future<void> finishOperation(Map<String, dynamic> data) async {
    final clientUuid = (data['client_uuid'] ?? const Uuid().v4()).toString();
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
    final id = (point['id'] ?? 'local-${const Uuid().v4()}').toString();
    point['id'] = id;
    final version = await db.recordVersion('map_points', id);
    await db.putLocal('map_points', id, point, version: version);
    await db.enqueue(
      mutationId: 'map-${const Uuid().v4()}',
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

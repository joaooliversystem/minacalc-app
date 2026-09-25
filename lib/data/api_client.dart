import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/constants.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? body;
  ApiException(this.message, this.statusCode, [this.body]);
  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _http;
  String? token;
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  Uri _uri(String action, [Map<String, String>? query]) {
    final base = Uri.parse(AppConstants.apiBaseUrl);
    return base.replace(queryParameters: {'action': action, ...?query});
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> appConfig() => _request('app_config', const {});
  Future<Map<String, dynamic>> bootstrap() => _request('bootstrap', const {});
  Future<Map<String, dynamic>> action(String action, Map<String, dynamic> body) => _request(action, body);

  Future<Map<String, dynamic>> requestPasswordReset(String email) =>
      _request('app_password_reset_request', {'email': email});

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String deviceId,
    required String language,
    required String termsVersion,
  }) {
    return _request('app_login', {
      'username': username,
      'password': password,
      'device_id': deviceId,
      'device_name': Platform.localHostname,
      'platform': Platform.operatingSystem,
      'app_version': AppConstants.appVersion,
      'terms_accepted': true,
      'terms_version': termsVersion,
      'language': language,
    });
  }

  Future<Map<String, dynamic>> snapshot() => _request('sync_snapshot', const {});
  Future<Map<String, dynamic>> status() => _request('sync_status', const {});
  Future<Map<String, dynamic>> pull(int cursor) => _request('sync_pull', {'cursor': cursor, 'limit': 300});

  Future<Map<String, dynamic>> push(List<Map<String, dynamic>> changes) {
    return _request('sync_push', {'changes': changes});
  }

  Future<void> logout() async {
    try {
      await _request('app_logout', const {});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> uploadEvidence({
    required String clientUuid,
    required String uploadId,
    required String path,
  }) async {
    final request = http.MultipartRequest('POST', _uri('evidence_upload'));
    if (token != null && token!.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['client_uuid'] = clientUuid;
    request.fields['client_upload_id'] = uploadId;
    request.files.add(await http.MultipartFile.fromPath('file', path));
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final text = await streamed.stream.bytesToString();
    final decoded = _decode(text);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300 || decoded['ok'] != true) {
      throw ApiException((decoded['message'] ?? 'Falha ao enviar evidência.').toString(), streamed.statusCode, decoded);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _request(String action, Map<String, dynamic> body) async {
    try {
      final response = await _http
          .post(_uri(action), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));
      final decoded = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300 || decoded['ok'] == false) {
        throw ApiException((decoded['message'] ?? 'Falha na comunicação com o servidor.').toString(), response.statusCode, decoded);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Sem conexão com o servidor.', 0);
    } on HttpException {
      throw ApiException('Falha de rede.', 0);
    } on FormatException {
      throw ApiException('Resposta inválida do servidor.', 0);
    }
  }

  Map<String, dynamic> _decode(String text) {
    if (text.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('JSON inválido');
  }
}

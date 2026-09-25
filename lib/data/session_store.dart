import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionStore {
  static const _secure = FlutterSecureStorage();
  static const _tokenKey = 'mc_access_token';
  static const _userKey = 'mc_user_json';
  static const _expiresKey = 'mc_token_expires';
  static const _languageKey = 'mc_language';
  static const _deviceKey = 'mc_device_id';
  static const _termsKey = 'mc_terms_accepted';

  Future<String?> get token => _secure.read(key: _tokenKey);

  Future<Map<String, dynamic>?> get user async {
    final raw = await _secure.read(key: _userKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
  }

  Future<DateTime?> get expiresAt async {
    final raw = await _secure.read(key: _expiresKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
    required String expiresAt,
  }) async {
    await _secure.write(key: _tokenKey, value: token);
    await _secure.write(key: _userKey, value: jsonEncode(user));
    await _secure.write(key: _expiresKey, value: expiresAt);
  }

  Future<void> clearSession() async {
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _userKey);
    await _secure.delete(key: _expiresKey);
  }

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_deviceKey, id);
    return id;
  }

  Future<String> language() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'pt-BR';
  }

  Future<void> setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value);
  }

  Future<bool> termsAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_termsKey) ?? false;
  }

  Future<void> setTermsAccepted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_termsKey, value);
  }
}

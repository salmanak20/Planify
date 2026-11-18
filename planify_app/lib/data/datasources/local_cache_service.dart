import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<void> saveJsonMap(String key, Map<String, dynamic> value) async {
    final prefs = await _prefs;
    await prefs.setString(key, jsonEncode(value));
  }

  Future<Map<String, dynamic>?> readJsonMap(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> saveJsonList(
    String key,
    List<Map<String, dynamic>> values,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(key, jsonEncode(values));
  }

  Future<List<Map<String, dynamic>>> readJsonList(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }

  Future<void> saveStringList(String key, List<String> values) async {
    final prefs = await _prefs;
    await prefs.setStringList(key, values);
  }

  Future<List<String>> readStringList(String key) async {
    final prefs = await _prefs;
    return prefs.getStringList(key) ?? <String>[];
  }
}

final localCacheServiceProvider = Provider<LocalCacheService>(
  (ref) => LocalCacheService(),
);

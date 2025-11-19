import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PredictionStorage {
  static const _key = 'prediction_history';

  /// Save the list (encoded as JSON) into SharedPreferences
  static Future<void> save(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }

  /// Load the stored list, returning an empty list when none present
  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(s) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Remove stored history
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

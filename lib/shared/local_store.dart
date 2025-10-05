import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedRoadmap {
  final String id;
  final String title;
  final String text;
  final DateTime createdAt;

  SavedRoadmap({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  static SavedRoadmap fromJson(Map<String, dynamic> j) {
    final createdStr = (j['createdAt'] ?? '') as String;
    DateTime created;
    try {
      created = DateTime.parse(createdStr);
    } catch (_) {
      created = DateTime.now();
    }
    return SavedRoadmap(
      id: (j['id'] ?? '').toString(),
      title: ((j['title'] ?? '') as String).trim().isNotEmpty
          ? (j['title'] as String)
          : 'Roadmap',
      text: (j['text'] ?? '') as String,
      createdAt: created,
    );
  }
}

class LocalStore {
  static const _keyRoadmaps = 'roadmaps_v2';

  static Future<List<SavedRoadmap>> listAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRoadmaps);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final list = decoded
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .map(SavedRoadmap.fromJson)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      await prefs.remove(_keyRoadmaps);
      return [];
    }
  }

  static Future<void> _writeAll(List<SavedRoadmap> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_keyRoadmaps, payload);
  }

  static Future<SavedRoadmap> saveNew(String text) async {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    final first = _firstNonEmptyLine(text);
    final item = SavedRoadmap(
      id: id,
      title: first.isEmpty ? 'Roadmap ${_shortDate(now)}' : first,
      text: text,
      createdAt: now,
    );
    final list = await listAll();
    list.insert(0, item);
    await _writeAll(list);
    return item;
  }

  static Future<void> deleteById(String id) async {
    final list = await listAll();
    list.removeWhere((e) => e.id == id);
    await _writeAll(list);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRoadmaps);
  }

  static String _firstNonEmptyLine(String t) {
    for (final l in t.replaceAll('\r', '').split('\n')) {
      final s = l.trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
}

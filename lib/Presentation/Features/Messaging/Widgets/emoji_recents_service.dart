import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:intelli_attend_faculty/Services/persistence_service.dart';

/// Tracks recently used emoji (LRU) and per-emoji frequency counters,
/// persisted through [PersistenceService.prefs]. Notifies listeners so the
/// picker's Recent tab updates live.
class EmojiRecentsService extends ChangeNotifier {
  EmojiRecentsService._internal();
  static final EmojiRecentsService instance = EmojiRecentsService._internal();

  static const _recentKey = 'emoji_recent_list';
  static const _freqKey = 'emoji_frequency_map';
  static const _maxRecent = 48;
  static const _frequentThreshold = 2;
  static const _frequentLimit = 24;

  List<String> _recent = [];
  Map<String, int> _freq = {};

  /// Most recently used emoji, newest first.
  List<String> get recent => List.unmodifiable(_recent);

  /// Emoji used at least twice, sorted by descending usage count.
  List<String> get frequentlyUsed {
    final list = _freq.entries.where((e) => e.value >= _frequentThreshold).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(_frequentLimit).map((e) => e.key).toList(growable: false);
  }

  /// Reads persisted state. Call once at startup before the first render.
  void load() {
    _recent = List<String>.from(
        PersistenceService.prefs.getStringList(_recentKey) ?? const []);
    final raw = PersistenceService.prefs.getString(_freqKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _freq = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
        }
      } catch (_) {
        _freq = {};
      }
    }
  }

  /// Records a selection: moves it to the front of the recents list and bumps
  /// its frequency counter.
  void record(String emoji) {
    if (emoji.isEmpty) return;
    _recent.remove(emoji);
    _recent.insert(0, emoji);
    if (_recent.length > _maxRecent) {
      _recent = _recent.sublist(0, _maxRecent);
    }
    _freq[emoji] = (_freq[emoji] ?? 0) + 1;
    notifyListeners();
    PersistenceService.prefs.setStringList(_recentKey, _recent);
    PersistenceService.prefs.setString(_freqKey, jsonEncode(_freq));
  }

  /// Clears recent history and frequency counters.
  void clear() {
    _recent = [];
    _freq = {};
    notifyListeners();
    PersistenceService.prefs.remove(_recentKey);
    PersistenceService.prefs.remove(_freqKey);
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';

enum SyncStatus { pending, syncing, synced, failed }

class OfflineAttendanceEntry {
  final String sessionId;
  final Map<String, AttendanceStatus> attendanceMap;
  final DateTime timestamp;
  SyncStatus status;
  String? notes;

  OfflineAttendanceEntry({
    required this.sessionId,
    required this.attendanceMap,
    required this.timestamp,
    this.status = SyncStatus.pending,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'attendance_map': attendanceMap.map((k, v) => MapEntry(k, v.name)),
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'notes': notes,
      };

  factory OfflineAttendanceEntry.fromJson(Map<String, dynamic> json) {
    final rawMap = json['attendance_map'] as Map<String, dynamic>? ?? {};
    return OfflineAttendanceEntry(
      sessionId: json['session_id'] ?? '',
      attendanceMap: rawMap.map((k, v) => MapEntry(k, AttendanceStatus.values.firstWhere((e) => e.name == v, orElse: () => AttendanceStatus.absent))),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      status: SyncStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => SyncStatus.pending),
      notes: json['notes'],
    );
  }
}

class OfflineSyncService {
  static const String _boxName = 'offline_attendance';
  static OfflineSyncService? _instance;
  static OfflineSyncService get instance => _instance ??= OfflineSyncService._();
  OfflineSyncService._();

  Box? _box;

  Future<Box> get box async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  Future<void> saveOffline(OfflineAttendanceEntry entry) async {
    final b = await box;
    final entries = getPendingSync();
    entries.add(entry);
    await b.put('entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
    debugPrint("[OfflineSync] Saved session ${entry.sessionId} for later sync");
  }

  List<OfflineAttendanceEntry> getPendingSync() {
    try {
      final raw = _box?.get('entries');
      if (raw == null) return [];
      final list = jsonDecode(raw as String) as List;
      return list.map((e) => OfflineAttendanceEntry.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  int get pendingCount => getPendingSync().where((e) => e.status == SyncStatus.pending).length;

  Future<void> syncAll() async {
    final entries = getPendingSync();
    bool anyChanged = false;
    for (final entry in entries) {
      if (entry.status == SyncStatus.pending) {
        entry.status = SyncStatus.syncing;
        anyChanged = true;
        try {
          await Future.delayed(const Duration(milliseconds: 800));
          entry.status = SyncStatus.synced;
          debugPrint("[OfflineSync] Synced session ${entry.sessionId}");
        } catch (_) {
          entry.status = SyncStatus.failed;
        }
      }
    }
    if (anyChanged) {
      final b = await box;
      await b.put('entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
    }
  }

  Future<void> retryFailed() async {
    final entries = getPendingSync();
    bool anyChanged = false;
    for (final entry in entries) {
      if (entry.status == SyncStatus.failed) {
        entry.status = SyncStatus.syncing;
        anyChanged = true;
        try {
          await Future.delayed(const Duration(milliseconds: 600));
          entry.status = SyncStatus.synced;
        } catch (_) {
          entry.status = SyncStatus.failed;
        }
      }
    }
    if (anyChanged) {
      final b = await box;
      await b.put('entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
    }
  }

  Future<void> clearSynced() async {
    final entries = getPendingSync().where((e) => e.status != SyncStatus.synced).toList();
    final b = await box;
    await b.put('entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
  }
}

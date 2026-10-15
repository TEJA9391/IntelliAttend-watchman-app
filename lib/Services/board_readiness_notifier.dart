import 'package:flutter/foundation.dart';

class BoardReadinessNotifier extends ChangeNotifier {
  BoardReadinessNotifier._();
  static final BoardReadinessNotifier instance = BoardReadinessNotifier._();

  final Set<String> _readySlots = {};

  bool isReady(String slotId) => _readySlots.contains(slotId);

  void markReady(String slotId) {
    if (_readySlots.add(slotId)) {
      debugPrint("📡 BoardReadinessNotifier: slot $slotId marked ready");
      notifyListeners();
    }
  }

  void clearReady(String slotId) {
    if (_readySlots.remove(slotId)) {
      debugPrint("📡 BoardReadinessNotifier: slot $slotId cleared");
      notifyListeners();
    }
  }

  void clearAll() {
    if (_readySlots.isNotEmpty) {
      _readySlots.clear();
      notifyListeners();
    }
  }
}

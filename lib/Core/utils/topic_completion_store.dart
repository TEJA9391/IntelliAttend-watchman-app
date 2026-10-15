import 'package:intelli_attend_faculty/Services/persistence_service.dart';

class TopicCompletionStore {
  TopicCompletionStore._();

  static String _key(String sessionId) => 'completed_topics_$sessionId';

  static Set<String> load(String sessionId) {
    try {
      final raw = PersistenceService.academicBox.get(_key(sessionId));
      if (raw is List) return raw.map((e) => e.toString()).toSet();
    } catch (_) {}
    return {};
  }

  static void save(String sessionId, Set<String> topics) {
    try {
      PersistenceService.academicBox.put(_key(sessionId), topics.toList());
    } catch (_) {}
  }

  static void toggle(String sessionId, String topicName) {
    final set = load(sessionId);
    if (set.contains(topicName)) {
      set.remove(topicName);
    } else {
      set.add(topicName);
    }
    save(sessionId, set);
  }

  static bool isCompleted(String sessionId, String topicName) =>
      load(sessionId).contains(topicName);
}

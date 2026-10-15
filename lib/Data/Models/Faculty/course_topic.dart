class CourseTopic {
  final String name;
  final bool isCompleted;
  final int completedCount;
  final int totalCount;

  const CourseTopic({
    required this.name,
    this.isCompleted = false,
    this.completedCount = 0,
    this.totalCount = 0,
  });

  factory CourseTopic.fromJson(Map<String, dynamic> json) {
    return CourseTopic(
      name: json['name'] as String? ?? json['topic_name'] as String? ?? '',
      isCompleted: json['is_completed'] as bool? ?? json['completed'] as bool? ?? false,
      completedCount: json['completed_count'] as int? ?? 0,
      totalCount: json['total_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'is_completed': isCompleted,
      'completed_count': completedCount,
      'total_count': totalCount,
    };
  }
}

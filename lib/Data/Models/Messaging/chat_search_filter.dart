/// Categories for in-conversation search.
///
/// Mirrors the search UX: a query is optional for content categories and the
/// date category, so selecting "PDF" alone lists every PDF message.
enum ChatSearchCategory {
  all,
  messages,
  date,
  pdf,
  media,
  assignments,
  attendance,
  links,
  replies;

  String get label {
    switch (this) {
      case ChatSearchCategory.all:
        return 'All';
      case ChatSearchCategory.messages:
        return 'Messages';
      case ChatSearchCategory.date:
        return 'Date';
      case ChatSearchCategory.pdf:
        return 'PDF';
      case ChatSearchCategory.media:
        return 'Media';
      case ChatSearchCategory.assignments:
        return 'Assignments';
      case ChatSearchCategory.attendance:
        return 'Attendance';
      case ChatSearchCategory.links:
        return 'Links';
      case ChatSearchCategory.replies:
        return 'Replies';
    }
  }

  /// Filter value sent to the backend (kept compatible with the old
  /// `media | documents | links` contract).
  String get serverFilter {
    switch (this) {
      case ChatSearchCategory.all:
      case ChatSearchCategory.date:
        return 'all';
      case ChatSearchCategory.messages:
        return 'messages';
      case ChatSearchCategory.pdf:
        return 'pdf';
      case ChatSearchCategory.media:
        return 'media';
      case ChatSearchCategory.assignments:
        return 'assignment';
      case ChatSearchCategory.attendance:
        return 'attendance_report';
      case ChatSearchCategory.links:
        return 'links';
      case ChatSearchCategory.replies:
        return 'replies';
    }
  }
}

/// An immutable snapshot of the active search: free-text [query], a
/// [category] and an optional day for the date filter.
class ChatSearchFilter {
  final String query;
  final ChatSearchCategory category;
  final DateTime? date;

  const ChatSearchFilter({
    this.query = '',
    this.category = ChatSearchCategory.all,
    this.date,
  });

  bool get hasQuery => query.trim().isNotEmpty;

  bool get hasDate => date != null;

  /// Whether anything worth searching is set.
  bool get isActive =>
      hasQuery || hasDate || category != ChatSearchCategory.all;

  ChatSearchFilter copyWith({
    String? query,
    ChatSearchCategory? category,
    DateTime? date,
    bool clearDate = false,
  }) {
    return ChatSearchFilter(
      query: query ?? this.query,
      category: category ?? this.category,
      date: clearDate ? null : (date ?? this.date),
    );
  }
}

/// Result of the in-conversation search screen: the ordered matched message
/// ids plus the index of the initially selected result, used by the chat
/// screen to start prev/next navigation.
class ChatSearchJump {
  final List<String> messageIds;
  final int index;

  const ChatSearchJump({required this.messageIds, required this.index});

  int get count => messageIds.length;
}

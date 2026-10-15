import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/Messaging/messaging_repository.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/chat_screen_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/peer_avatar.dart';

/// Forwards one or more messages to chats, individual students, whole
/// departments or faculty. Multi-select with search.
class ForwardScreen extends StatefulWidget {
  final List<ChatMessage> messages;
  final ChatScreenController? sourceController;

  const ForwardScreen({super.key, required this.messages, this.sourceController});

  @override
  State<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardTarget {
  final String key;
  final String title;
  final String subtitle;
  final String? department;
  final String? conversationId;
  final StudentContact? contact;

  const _ForwardTarget({
    required this.key,
    required this.title,
    required this.subtitle,
    this.department,
    this.conversationId,
    this.contact,
  });
}

class _ForwardScreenState extends State<ForwardScreen> {
  final MessageCacheService _cache = MessageCacheService.instance;
  final MessagingRepository _repository = MessagingRepository();
  final TextEditingController _search = TextEditingController();
  final Set<String> _selected = {};

  List<ChatConversation> _chats = [];
  List<StudentContact> _students = [];
  List<String> _departments = [];
  List<StudentContact> _faculty = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _chats = _cache.loadConversations();
    final response = await _repository.fetchContacts();
    if (response.success && response.data != null) {
      _students = response.data!.where((c) => !c.isFaculty).toList();
      _faculty = response.data!.where((c) => c.isFaculty).toList();
    } else {
      _students = [];
      _faculty = [];
    }
    _departments = _students
        .map((s) => s.department)
        .whereType<String>()
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();
    if (mounted) setState(() => _loading = false);
  }

  List<_ForwardTarget> get _targets {
    final query = _search.text.trim().toLowerCase();
    final targets = <_ForwardTarget>[];

    for (final c in _chats) {
      if (query.isNotEmpty && !c.title.toLowerCase().contains(query)) continue;
      targets.add(_ForwardTarget(
        key: 'chat_${c.id}',
        title: c.title,
        subtitle: 'Chat',
        conversationId: c.id,
      ));
    }
    for (final s in _students) {
      if (query.isNotEmpty &&
          !s.name.toLowerCase().contains(query) &&
          !(s.rollNumber?.toLowerCase().contains(query) ?? false)) {
        continue;
      }
      targets.add(_ForwardTarget(
        key: 'student_${s.id}',
        title: s.displayTitle,
        subtitle: [s.department, s.section].where((e) => e != null && e.isNotEmpty).join(' • '),
        conversationId: 'direct_${s.id}',
        contact: s,
      ));
    }
    for (final d in _departments) {
      if (query.isNotEmpty && !d.toLowerCase().contains(query)) continue;
      targets.add(_ForwardTarget(
        key: 'dept_$d',
        title: d,
        subtitle: 'Forward to entire department',
        department: d,
      ));
    }
    for (final f in _faculty) {
      if (query.isNotEmpty && !f.name.toLowerCase().contains(query)) continue;
      targets.add(_ForwardTarget(
        key: 'faculty_${f.id}',
        title: f.displayTitle,
        subtitle: 'Faculty',
        conversationId: 'direct_${f.id}',
        contact: f,
      ));
    }
    return targets;
  }

  List<_ForwardTarget> get _selectedTargets =>
      _targets.where((t) => _selected.contains(t.key)).toList();

  List<StudentContact> _expandTarget(_ForwardTarget t) {
    if (t.department != null) {
      return _students.where((s) => s.department == t.department).toList();
    }
    if (t.contact != null) return [t.contact!];
    return [];
  }

  Future<void> _send() async {
    final targets = _selectedTargets;
    if (targets.isEmpty) return;
    HapticService.medium();
    Navigator.pop(context);

    for (final target in targets) {
      final contacts = _expandTarget(target);
      final List<String> convIds;
      if (target.conversationId != null && contacts.isEmpty) {
        convIds = [target.conversationId!];
      } else {
        convIds = contacts.map((c) => 'direct_${c.id}').toList();
      }

      for (final convId in convIds) {
        final contact = contacts.isEmpty
            ? (target.contact ?? _chats.where((c) => c.id == target.conversationId).firstOrNull?.peer)
            : contacts[convIds.indexOf(convId)];
        if (contact != null) {
          // Ensure a conversation shell exists for new targets.
          await _cache.upsertConversation(
            ChatConversation(id: convId, peer: contact, createdAt: DateTime.now()),
          );
        }
        for (final message in widget.messages) {
          if (widget.sourceController != null) {
            await widget.sourceController!.forwardMessages(message, [convId]);
          } else {
            await _forwardOffline(message, convId);
          }
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messages forwarded')),
      );
    }
  }

  Future<void> _forwardOffline(ChatMessage message, String convId) async {
    final forwarded = message.copyWith(
      id: 'fwd_${DateTime.now().microsecondsSinceEpoch}_$convId',
      conversationId: convId,
      isForwarded: true,
      status: MessageStatus.pending,
      timestamp: DateTime.now(),
    );
    await _cache.mergeMessages(convId, [forwarded]);
    await _cache.enqueueOutbox(forwarded);
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targets;
    final selected = _selectedTargets;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Forward ${widget.messages.length > 1 ? '${widget.messages.length} messages' : 'message'}',
          style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text('${selected.length} selected',
                    style: GoogleFonts.inter(color: AppTheme.primary(context), fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search chats, students, departments…',
                hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary(context)),
                filled: true,
                fillColor: AppTheme.surface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : targets.isEmpty
                    ? Center(
                        child: Text('No recipients found',
                            style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 14)),
                      )
                    : ListView.builder(
                        itemCount: targets.length,
                        itemBuilder: (context, index) {
                          final t = targets[index];
                          final isSelected = _selected.contains(t.key);
                          return ListTile(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selected.remove(t.key);
                                } else {
                                  _selected.add(t.key);
                                }
                              });
                            },
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                PeerAvatar(name: t.title, radius: 22, backgroundColor: isSelected ? AppTheme.primary(context) : null),
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? AppTheme.primary(context) : AppTheme.surface(context),
                                      border: Border.all(
                                          color: isSelected ? Colors.white : AppTheme.border(context), width: 1.5),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            title: Text(t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    color: AppTheme.text(context), fontSize: 15, fontWeight: FontWeight.w600)),
                            subtitle: Text(t.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12)),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selected.isEmpty ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary(context),
                    disabledBackgroundColor: AppTheme.surface(context),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.forward_rounded, size: 18),
                  label: Text(
                    selected.isEmpty ? 'Select recipients' : 'Send',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

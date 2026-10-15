import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const int _pageSize = 20;
  final List<Map<String, dynamic>> _allSessionData = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _lastSessionId;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredSessions {
    if (_searchQuery.isEmpty) return _allSessionData;
    final q = _searchQuery.toLowerCase();
    return _allSessionData.where((s) {
      final course = (s['subject_name'] ?? s['course_name'] ?? '').toString().toLowerCase();
      final code = (s['subject_code'] ?? s['course_code'] ?? '').toString().toLowerCase();
      final section = (s['section'] ?? s['section_id'] ?? '').toString().toLowerCase();
      final room = (s['room_number'] ?? '').toString().toLowerCase();
      return course.contains(q) || code.contains(q) || section.contains(q) || room.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchPage();
  }

  Future<void> _fetchPage({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
      _allSessionData.clear();
      _lastSessionId = null;
    }

    try {
      final facultyEmail = FacultyService.canonicalId;
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final response = await context.read<ApiClient>().dio.get(
        '/api/v1/analytics/faculty/$facultyEmail/summary',
        queryParameters: {
          'limit': _pageSize.toString(),
          if (_lastSessionId != null) 'last_id': _lastSessionId,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $idToken'},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode != 200 || response.data == null) return;

      final data = response.data as Map;
      final sessionsRaw = data['sessions'] as List? ?? data['history'] as List? ?? [];

      if (mounted) {
        setState(() {
          _allSessionData.addAll(sessionsRaw.map((s) => Map<String, dynamic>.from(s as Map)));
          _hasMore = sessionsRaw.length >= _pageSize;
          if (sessionsRaw.isNotEmpty) {
            _lastSessionId = (sessionsRaw.last as Map)['session_id']?.toString() ?? (sessionsRaw.last as Map)['id']?.toString();
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("❌ HistoryScreen error: $e");
      if (mounted) setState(() { _isLoading = false; _isLoadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text("Attendance History",
            style: TextStyle(
                color: AppTheme.text(context), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text(context)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: "Search past sessions...",
                prefixIcon:
                    Icon(Icons.search, color: AppTheme.slate500(context)),
                fillColor: AppTheme.surface(context),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allSessionData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 64, color: AppTheme.slate500(context).withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text("No session history found.", 
                                 style: TextStyle(color: AppTheme.slate500(context))),
                          ],
                        ),
                      )
                    : _filteredSessions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 64, color: AppTheme.slate500(context).withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                Text("No matching sessions found.", 
                                     style: TextStyle(color: AppTheme.slate500(context))),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _fetchPage(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: _filteredSessions.length + (_hasMore && _searchQuery.isEmpty ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _filteredSessions.length) {
                                  return _buildLoadMoreButton();
                                }
                                return _buildHistoryItem(context, _filteredSessions[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton.icon(
                onPressed: () => _fetchPage(loadMore: true),
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text("Load more"),
              ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Map<String, dynamic> data) {
    final dateRaw = data['date'] ?? data['timestamp'];
    final DateTime? dt = dateRaw is DateTime ? dateRaw : (dateRaw is String ? DateTime.tryParse(dateRaw) : null);
    final dateStr = dt != null ? DateFormat('dd MMM yyyy').format(dt) : 'Unknown Date';
    final timeStr = dt != null ? DateFormat('hh:mm a').format(dt) : 'Unknown Time';
    
    final courseName = data['subject_name'] ?? 'Unknown Course';
    final presentCount = data['present_count'] ?? 0;
    final room = data['room_number'] ?? 'TBD';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppTheme.primary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.check_circle_outline,
                color: AppTheme.primary(context), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.text(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text("$dateStr • $timeStr • Room $room",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.textSecondary(context),
                        fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("$presentCount",
                  style: TextStyle(
                      color: AppTheme.primary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              Text("students",
                  style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

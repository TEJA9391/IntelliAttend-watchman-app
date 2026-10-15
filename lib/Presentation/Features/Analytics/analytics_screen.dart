import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Services/attendance_service.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _historicalStats;
  bool _isStatsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistoricalStats();
  }

  Future<void> _fetchHistoricalStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final facultyEmail = user.email!.toLowerCase();

    try {
      final idToken = await user.getIdToken();
      final response = await context.read<ApiClient>().dio.get(
        '/api/v1/analytics/faculty/$facultyEmail/summary',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (mounted && response.statusCode == 200 && response.data is Map) {
        setState(() {
          _historicalStats = response.data as Map<String, dynamic>?;
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Analytics Error: $e");
      if (mounted) setState(() => _isStatsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text("Attendance Analytics",
            style: TextStyle(
                color: AppTheme.text(context), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<List<StudentAttendance>>(
        valueListenable: AttendanceService().students,
        builder: (context, students, child) {
          int livePresentCount = students.where((s) => s.status == StudentStatus.present).length;
          int liveTotalCount = students.length;
          double liveRate = liveTotalCount > 0 ? (livePresentCount / liveTotalCount) * 100 : 0;

          if (_isStatsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatCards(liveRate, liveTotalCount),
                const SizedBox(height: 32),
                _buildChartCard(
                  context,
                  "Weekly Attendance Trend",
                  "14-day historical tracking",
                  _buildLineChart(context),
                ),
                const SizedBox(height: 24),
                _buildChartCard(
                  context,
                  "Section Performance",
                  "Comparison across sections",
                  _buildBarChart(context),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCards(double liveRate, int totalCount) {
    return Row(
      children: [
        Expanded(
            child: _buildSummaryCard(
                "Live Average", "${liveRate.toStringAsFixed(1)}%", Icons.shutter_speed_outlined, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(
            child: _buildSummaryCard(
                "Total Enrolled", totalCount.toString(), Icons.people_outline, Colors.teal)),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, String title, String subtitle, Widget chart) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.text(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.textSecondary(context), fontSize: 13)),
          const SizedBox(height: 24),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.28, child: chart),
        ],
      ),
    );
  }

  Widget _buildLineChart(BuildContext context) {
    final List<Map<String, dynamic>> trendData = 
        List<Map<String, dynamic>>.from(_historicalStats?['attendance_trend'] ?? []);

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: const CategoryAxis(isVisible: true),
      primaryYAxis: const NumericAxis(isVisible: false),
      series: <CartesianSeries>[
        SplineAreaSeries<Map<String, dynamic>, String>(
          dataSource: trendData,
          xValueMapper: (data, _) => data['day'],
          yValueMapper: (data, _) => data['count'],
          color: AppTheme.primary(context).withValues(alpha: 0.2),
          borderColor: AppTheme.primary(context),
          borderWidth: 3,
        )
      ],
    );
  }

  Widget _buildBarChart(BuildContext context) {
    final List<Map<String, dynamic>> sectionData = 
        List<Map<String, dynamic>>.from(_historicalStats?['section_performance'] ?? []);

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: const CategoryAxis(isVisible: true),
      primaryYAxis: const NumericAxis(isVisible: false),
      series: <CartesianSeries>[
        ColumnSeries<Map<String, dynamic>, String>(
          dataSource: sectionData,
          xValueMapper: (data, _) => data['section'],
          yValueMapper: (data, _) => data['percentage'],
          borderRadius: BorderRadius.circular(8),
          color: AppTheme.primary(context),
        )
      ],
    );
  }
}

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/override_slot.dart';

class OverrideRepository {
  /// Fetch overrides via server sync endpoint.
  Future<List<OverrideSlot>> fetchTodaysOverrides(String email) async {
    final fullEmail = email.toLowerCase().trim();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return [];

      final response = await ApiClient().dio.get(
        '/api/v1/faculty/sync',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final overrides = data['overrides'] as List? ?? [];
        return overrides
            .map((item) => OverrideSlot.fromJson(Map<String, dynamic>.from(item), item['id']?.toString() ?? ''))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ [OverrideRepo] Fetch error: $e');
      return [];
    }
  }
}

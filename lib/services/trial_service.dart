import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TrialService {
  static const int trialDays = 15;
  static const String _prefsKeyPaywallLocked = 'paywallLocked';
  static const String _prefsKeyLastCheckedAt = 'paywallLastCheckedAtMs';
  static const String _prefsKeyCachedCreatedAt = 'userCreatedAtMs';
  static const String _prefsKeyCachedPaymentStatus = 'paymentStatusCached';

  static Future<bool> _hasNetwork() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  static Future<bool> isPaywallLockedOffline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyPaywallLocked) ?? false;
  }

  static Future<void> _persistLockState({
    required bool locked,
    int? createdAtMs,
    String? paymentStatus,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyPaywallLocked, locked);
    await prefs.setInt(
      _prefsKeyLastCheckedAt,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (createdAtMs != null) {
      await prefs.setInt(_prefsKeyCachedCreatedAt, createdAtMs);
    }
    if (paymentStatus != null) {
      await prefs.setString(_prefsKeyCachedPaymentStatus, paymentStatus);
    }
  }

  static Future<bool> evaluateAndPersist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await _persistLockState(locked: false);
      return false;
    }

    final online = await _hasNetwork();
    if (!online) {
      return await isPaywallLockedOffline();
    }

    final fs = FirebaseFirestore.instance;
    final userDocRef = fs.collection('users').doc(user.uid);
    final userSnap = await userDocRef.get(
      GetOptions(source: Source.serverAndCache),
    );

    DateTime? createdAt;
    String paymentStatus = 'unpaid';

    if (userSnap.exists) {
      final data = userSnap.data() as Map<String, dynamic>;
      final createdAtField = data['createdAt'];
      if (createdAtField is Timestamp) {
        createdAt = createdAtField.toDate();
      } else if (createdAtField is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtField);
      } else if (createdAtField is String) {
        // Try ISO-8601 first, then fallback to human-readable formats like:
        // "September 10, 2025 at 12:39:35 PM UTC+3"
        createdAt = _tryParseDateString(createdAtField);
      }
      final ps = data['paymentStatus'];
      if (ps is String && ps.isNotEmpty) {
        paymentStatus = ps.toLowerCase();
      }
    }

    // Fallback to FirebaseAuth user metadata if Firestore missing createdAt
    createdAt ??= user.metadata.creationTime ?? DateTime.now();

    final now = DateTime.now();
    final daysUsed = now.difference(createdAt).inDays;
    final isExpired = daysUsed >= trialDays;
    final isPaid = paymentStatus == 'paid';
    final shouldLock = isExpired && !isPaid;

    await _persistLockState(
      locked: shouldLock,
      createdAtMs: createdAt.millisecondsSinceEpoch,
      paymentStatus: paymentStatus,
    );

    return shouldLock;
  }
}

DateTime? _tryParseDateString(String raw) {
  // 1) ISO-8601
  try {
    return DateTime.parse(raw);
  } catch (_) {}

  // 2) Human-readable: "September 10, 2025 at 12:39:35 PM UTC+3"
  //    Capture date part, time part, am/pm, and UTC offset hours
  final regex = RegExp(
    r'^(?<date>[A-Za-z]+\s+\d{1,2},\s+\d{4})\s+at\s+(?<time>\d{1,2}:\d{2}:\d{2})\s+(?<ampm>AM|PM)\s+UTC(?<offset>[+-]\d{1,2})$',
  );
  final m = regex.firstMatch(raw.trim());
  if (m != null) {
    try {
      final datePart = m.namedGroup('date')!; // e.g. September 10, 2025
      final timePart = m.namedGroup('time')!; // e.g. 12:39:35
      final ampm = m.namedGroup('ampm')!; // AM/PM
      final offsetStr = m.namedGroup('offset')!; // +3 or -3
      final offsetHours = int.parse(offsetStr);

      final fmt = DateFormat('MMMM d, y h:mm:ss a');
      // Parse as if in local timezone first
      final naive = fmt.parse('$datePart $timePart $ampm');
      // The string time is in UTC+offset; convert it to true UTC
      final utc = naive.toUtc().subtract(Duration(hours: offsetHours));
      // Return in local timezone for consistent comparisons with now()
      return utc.toLocal();
    } catch (_) {}
  }

  return null;
}

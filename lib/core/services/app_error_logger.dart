import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppErrorLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sanitizes raw error messages for Normal Admin and Shop Staff users.
  /// Replaces technical jargon (Firebase, Firestore, Stack Traces, Class names)
  /// with clean, friendly messages.
  static String sanitizeErrorMessage(
    dynamic rawError, {
    bool isMasterAdmin = false,
  }) {
    String cleanMessage = rawError.toString();
    if (cleanMessage.startsWith('Exception: ')) {
      cleanMessage = cleanMessage.substring('Exception: '.length);
    }

    if (isMasterAdmin) {
      return cleanMessage;
    }

    final String errStr = cleanMessage.toLowerCase();

    // 1. Preserve explicit user-facing business messages (Blocked, Expired, Credentials, Limits, Support)
    if (errStr.contains('blocked') ||
        errStr.contains('expired') ||
        errStr.contains('subscription') ||
        errStr.contains('support') ||
        errStr.contains('incorrect password') ||
        errStr.contains('invalid credentials') ||
        errStr.contains('shop code not found') ||
        errStr.contains('limit reached') ||
        errStr.contains('locked') ||
        errStr.contains('welcome') ||
        errStr.contains('success')) {
      return cleanMessage;
    }

    // 2. Network / Connectivity Issues
    if (errStr.contains('socketexception') ||
        errStr.contains('network') ||
        errStr.contains('connection failed') ||
        errStr.contains('timeout') ||
        errStr.contains('unavailable') ||
        errStr.contains('client is offline')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    }

    // 3. Permission / Authentication Issues
    if (errStr.contains('permission-denied') ||
        errStr.contains('unauthorized')) {
      return 'Access restricted. Please verify your staff permissions.';
    }

    // 4. Record / Document Not Found
    if (errStr.contains('not-found')) {
      return 'Requested item or record was not found.';
    }

    // 5. If it's already a clean readable sentence without technical code traces, pass it through
    if (!errStr.contains('firebase') &&
        !errStr.contains('firestore') &&
        !errStr.contains('[') &&
        !errStr.contains('stack trace') &&
        !errStr.contains('null check')) {
      return cleanMessage;
    }

    // 6. Default Fallback
    return 'An unexpected issue occurred. Please try again or contact support.';
  }

  /// Logs detailed error payload to Firestore `app_error_logs` collection.
  static Future<void> logError(
    dynamic error, {
    StackTrace? stackTrace,
    String context = 'App',
    String? customUserMessage,
  }) async {
    try {
      final box = Hive.isBoxOpen('settings')
          ? Hive.box<String>('settings')
          : null;

      final shopCode =
          box?.get('shopCode') ?? box?.get('shopName') ?? 'Unknown Shop';
      final shopName = box?.get('shopName') ?? 'Unknown Shop';
      final staffName =
          box?.get('staffName') ?? box?.get('username') ?? 'Admin User';
      final role = box?.get('role') ?? 'User';
      final isStaffDevice = box?.get('isStaffDevice') == 'true';

      final userDisplay = isStaffDevice
          ? '$staffName (Staff)'
          : '$staffName ($role)';

      final rawErrorStr = error.toString();
      final stackStr = stackTrace?.toString() ?? '';

      debugPrint(
        '🚨 [AppErrorLogger] Error captured for shop $shopCode: $rawErrorStr',
      );

      // Upload to Firestore `app_error_logs`
      await _firestore.collection('app_error_logs').add({
        'shopCode': shopCode,
        'shopName': shopName,
        'userName': userDisplay,
        'role': role,
        'context': context,
        'errorMessage': rawErrorStr,
        'stackTrace': stackStr,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'devicePrefix': box?.get('devicePrefix') ?? '',
      });
    } catch (e) {
      debugPrint('⚠️ [AppErrorLogger] Could not save error log: $e');
    }
  }

  /// Deletes all error logs from Firestore
  static Future<void> clearAllLogs() async {
    try {
      final snap = await _firestore.collection('app_error_logs').get();
      final batch = _firestore.batch();
      for (var doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('⚠️ [AppErrorLogger] Error clearing logs: $e');
    }
  }

  /// Deletes a specific error log doc
  static Future<void> deleteLog(String docId) async {
    try {
      await _firestore.collection('app_error_logs').doc(docId).delete();
    } catch (e) {
      debugPrint('⚠️ [AppErrorLogger] Error deleting log doc: $e');
    }
  }
}

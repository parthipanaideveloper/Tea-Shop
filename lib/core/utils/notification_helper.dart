import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import '../services/app_error_logger.dart';
import 'ui_utils.dart';

class NotificationHelper {
  static void showCenter(
    BuildContext? context,
    String message, {
    bool isError = false,
  }) {
    String displayMessage = message;

    if (isError) {
      bool isMasterAdmin = false;
      try {
        if (Hive.isBoxOpen('settings')) {
          final box = Hive.box<String>('settings');
          isMasterAdmin =
              box.get('is_impersonating') == 'true' ||
              box.get('role') == 'masterAdmin';
        }
      } catch (_) {}

      // Log full detailed error to Firestore app_error_logs for Master Admin
      AppErrorLogger.logError(message, context: 'Notification Toast');

      // Sanitize displayed message for normal admin and staff users
      displayMessage = AppErrorLogger.sanitizeErrorMessage(
        message,
        isMasterAdmin: isMasterAdmin,
      );
    }

    OverlayState? overlay;
    if (context != null && context.mounted) {
      try {
        overlay =
            Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.of(context);
      } catch (_) {}
    }

    // Fallback to global navigator overlay
    overlay ??= UiUtils.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.4,
        left: MediaQuery.of(context).size.width > 320
            ? (MediaQuery.of(context).size.width - 320) / 2
            : 10,
        width: MediaQuery.of(context).size.width > 320
            ? 320
            : MediaQuery.of(context).size.width - 20,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: isError ? Colors.red.shade600 : const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      displayMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Timer(const Duration(milliseconds: 2500), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}

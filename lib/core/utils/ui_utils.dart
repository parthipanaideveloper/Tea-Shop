import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'notification_helper.dart';

class UiUtils {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void showToast(String message, {bool isError = false}) {
    NotificationHelper.showCenter(navigatorKey.currentContext, message, isError: isError);
  }

  static void showSquarePopup(
    BuildContext? context,
    String message, {
    bool isError = true,
  }) {
    NotificationHelper.showCenter(context, message, isError: isError);
  }

  static ImageProvider? getLogoProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.length < 255 && File(path).existsSync()) {
      return FileImage(File(path));
    }
    try {
      String cleanBase64 = path;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
      while (cleanBase64.length % 4 != 0) {
        cleanBase64 += '=';
      }
      return MemoryImage(base64Decode(cleanBase64));
    } catch (e) {
      return null;
    }
  }

  static Future<String?> showPasswordPrompt(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final TextEditingController passwordCtrl = TextEditingController();
    bool obscure = true;

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setStateDialog(() {
                          obscure = !obscure;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final pwd = passwordCtrl.text.trim();
                  if (pwd.isEmpty) {
                    showSquarePopup(context, 'Password cannot be empty', isError: true);
                    return;
                  }
                  Navigator.pop(context, pwd);
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        });
      },
    );
  }
}

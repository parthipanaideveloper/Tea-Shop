import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

class TrialStorage {
  // Simple cipher to obfuscate content bound to deviceId
  static String _xorCipher(String text, String key) {
    if (key.isEmpty) key = 'fallback_key';
    final codeUnits = text.codeUnits;
    final keyUnits = key.codeUnits;
    final cipher = List<int>.filled(codeUnits.length, 0);

    for (var i = 0; i < codeUnits.length; i++) {
      cipher[i] = codeUnits[i] ^ keyUnits[i % keyUnits.length];
    }
    return base64Encode(cipher);
  }

  static String _xorDecipher(String base64Text, String key) {
    if (key.isEmpty) key = 'fallback_key';
    try {
      final codeUnits = base64Decode(base64Text);
      final keyUnits = key.codeUnits;
      final plain = List<int>.filled(codeUnits.length, 0);

      for (var i = 0; i < codeUnits.length; i++) {
        plain[i] = codeUnits[i] ^ keyUnits[i % keyUnits.length];
      }
      return String.fromCharCodes(plain);
    } catch (e) {
      return '';
    }
  }

  // Get external persistent hidden file path
  static Future<File?> _getExternalFile() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      // Accessing standard Download directory which persists across uninstalls
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) {
        return File('${dir.path}/.dts_pos_sys.bin');
      }
      // Fallback to system external files
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        return File('${extDir.path}/.dts_pos_sys.bin');
      }
    } catch (_) {}
    return null;
  }

  // Get local sandbox fallback path
  static Future<File> _getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/.dts_pos_local.bin');
  }

  Future<void> saveTrialStartDate(DateTime date, String deviceId) async {
    final payload = jsonEncode({
      'trial_start_date': date.toIso8601String(),
      'checksum': date.millisecondsSinceEpoch.toString(),
    });

    final encrypted = _xorCipher(payload, deviceId);

    // Save locally
    try {
      final localFile = await _getLocalFile();
      await localFile.writeAsString(encrypted);
    } catch (_) {}

    // Save externally (survives data clear / reinstall)
    try {
      final extFile = await _getExternalFile();
      if (extFile != null) {
        await extFile.writeAsString(encrypted);
      }
    } catch (_) {}
  }

  Future<DateTime?> loadTrialStartDate(String deviceId) async {
    String? content;

    // 1. Try reading from public external storage first (prevents reinstall abuse)
    try {
      final extFile = await _getExternalFile();
      if (extFile != null && await extFile.exists()) {
        content = await extFile.readAsString();
      }
    } catch (_) {}

    // 2. If not found in external, check sandbox local files
    if (content == null || content.isEmpty) {
      try {
        final localFile = await _getLocalFile();
        if (await localFile.exists()) {
          content = await localFile.readAsString();
        }
      } catch (_) {}
    }

    if (content == null || content.isEmpty) return null;

    final decrypted = _xorDecipher(content, deviceId);
    if (decrypted.isEmpty) return null;

    try {
      final map = jsonDecode(decrypted) as Map<String, dynamic>;
      final dateStr = map['trial_start_date'] as String;
      final date = DateTime.parse(dateStr);

      // Verification check
      final checksum = map['checksum'] as String;
      if (checksum == date.millisecondsSinceEpoch.toString()) {
        return date;
      }
    } catch (_) {}
    return null;
  }
}

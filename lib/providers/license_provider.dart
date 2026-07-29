import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/security_service.dart';
import '../services/trial_storage.dart';
import '../services/firebase_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LicenseState {
  final bool isRegistered;
  final DateTime? trialStartDate;
  final DateTime? subscriptionStart;
  final DateTime? subscriptionEnd;
  final String? activationKey;
  final String deviceId;

  LicenseState({
    required this.isRegistered,
    this.trialStartDate,
    this.subscriptionStart,
    this.subscriptionEnd,
    this.activationKey,
    this.deviceId = 'unknown_device_id',
  });

  LicenseState copyWith({
    bool? isRegistered,
    DateTime? trialStartDate,
    DateTime? subscriptionStart,
    DateTime? subscriptionEnd,
    String? activationKey,
    String? deviceId,
  }) {
    return LicenseState(
      isRegistered: isRegistered ?? this.isRegistered,
      trialStartDate: trialStartDate ?? this.trialStartDate,
      subscriptionStart: subscriptionStart ?? this.subscriptionStart,
      subscriptionEnd: subscriptionEnd ?? this.subscriptionEnd,
      activationKey: activationKey ?? this.activationKey,
      deviceId: deviceId ?? this.deviceId);
  }
}

class LicenseNotifier extends Notifier<LicenseState> {
  final _securityService = SecurityService();
  final _trialStorage = TrialStorage();

  @override
  LicenseState build() {
    final box = Hive.box<String>('settings');
    final isRegistered = box.get('isRegistered') == 'true';

    final trialStartStr = box.get('trialStartDate');
    final subStartStr = box.get('subscriptionStart');
    final subEndStr = box.get('subscriptionEnd');

    // Trigger background validation of device ID & trial restoration
    _initializeLicense();

    // Listen to remote deregistration/logout
    final sub = box.watch(key: 'isRegistered').listen((event) {
      if (event.value == 'false') {
        state = state.copyWith(isRegistered: false);
      }
    });
    ref.onDispose(() => sub.cancel());

    return LicenseState(
      isRegistered: isRegistered,
      trialStartDate: trialStartStr != null
          ? DateTime.tryParse(trialStartStr)
          : null,
      subscriptionStart: subStartStr != null
          ? DateTime.tryParse(subStartStr)
          : null,
      subscriptionEnd: subEndStr != null ? DateTime.tryParse(subEndStr) : null,
      activationKey: box.get('activationKey'),
      deviceId: 'loading...');
  }

  Future<void> _initializeLicense() async {
    final devId = await _securityService.getDeviceId();
    final box = Hive.box<String>('settings');

    // Save device ID locally for references
    await box.put('deviceId', devId);

    // Read the persistent trial start date (to prevent reinstall trial-reset abuse)
    DateTime? finalTrialStart = state.trialStartDate;
    final persistentTrial = await _trialStorage.loadTrialStartDate(devId);

    if (persistentTrial != null) {
      // If we found a trial start date in persistent external storage, enforce it!
      finalTrialStart = persistentTrial;
      await box.put('trialStartDate', finalTrialStart.toIso8601String());
    } else if (state.trialStartDate != null) {
      // If none was found in external storage but local documents has it, sync it to external storage
      await _trialStorage.saveTrialStartDate(state.trialStartDate!, devId);
    }

    DateTime? finalSubEnd = state.subscriptionEnd;

    state = state.copyWith(
      deviceId: devId,
      trialStartDate: finalTrialStart,
      subscriptionEnd: finalSubEnd);
  }

  Future<void> registerStore(
    String shopName, [
    String activationKey = '',
  ]) async {
    final devId = await _securityService.getDeviceId();
    final box = Hive.box<String>('settings');
    final now = DateTime.now();

    // Generate unique Shop Code if not already present
    var shopCode = box.get('shopCode');
    if (shopCode == null || shopCode.trim().isEmpty) {
      bool isUnique = false;
      while (!isUnique) {
        final rand = (10000 + Random().nextInt(90000)).toString();
        final code = 'DTS-$rand';
        final exists = await FirebaseSyncService().checkIfShopExists(code);
        if (!exists) {
          shopCode = code;
          isUnique = true;
        }
      }
    }

    // Save settings locally
    await box.put('isRegistered', 'true');
    await box.put('isStaffDevice', 'false');
    await box.put('shopCode', shopCode!);
    await box.put('shopName', shopName);
    await box.put('deviceId', devId);

    if (activationKey.isNotEmpty) {
      final expiry = now.add(const Duration(days: 60)); // 2 months subscription
      await box.put('activationKey', activationKey);
      await box.put('subscriptionStart', now.toIso8601String());
      await box.put('subscriptionEnd', expiry.toIso8601String());

      // Create base shop document asynchronously so real-time listeners work without blocking UI
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopCode.trim())
          .set({
            'shopName': shopName,
            'isBlocked': false,
            'createdAt': now.toIso8601String(),
          }, SetOptions(merge: true))
          .catchError((e) => debugPrint('Error setting initial shop doc: $e'));

      // Inject Global Templates in background so registration is instant
      unawaited(FirebaseSyncService().injectGlobalDefaults(shopCode).catchError((e) => debugPrint('Error injecting defaults: $e')));

      FirebaseSyncService().refreshShopCode();
      state = LicenseState(
        isRegistered: true,
        trialStartDate: null,
        subscriptionStart: now,
        subscriptionEnd: expiry,
        activationKey: activationKey,
        deviceId: devId);
    } else {
      await box.put('trialStartDate', now.toIso8601String());
      await _trialStorage.saveTrialStartDate(now, devId);

      // Create base shop document asynchronously
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopCode.trim())
          .set({
            'shopName': shopName,
            'isBlocked': false,
            'createdAt': now.toIso8601String(),
          }, SetOptions(merge: true))
          .catchError((e) => debugPrint('Error setting initial shop doc: $e'));

      // Inject Global Templates in background so registration is instant
      unawaited(FirebaseSyncService().injectGlobalDefaults(shopCode).catchError((e) => debugPrint('Error injecting defaults: $e')));

      FirebaseSyncService().refreshShopCode();
      state = LicenseState(
        isRegistered: true,
        trialStartDate: now,
        subscriptionStart: null,
        subscriptionEnd: null,
        activationKey: null,
        deviceId: devId);
    }
  }

  Future<void> connectStaffStore(String shopCode, String shopName, {bool isAdmin = false}) async {
    final devId = await _securityService.getDeviceId();
    final box = Hive.box<String>('settings');
    final now = DateTime.now();
    final futureDate = now.add(const Duration(days: 365 * 50));

    await box.put('isRegistered', 'true');
    await box.put('isStaffDevice', isAdmin ? 'false' : 'true');
    await box.put('shopCode', shopCode);
    await box.put('shopName', shopName);
    await box.put('deviceId', devId);
    await box.put('subscriptionStart', now.toIso8601String());
    await box.put('subscriptionEnd', futureDate.toIso8601String());

    FirebaseSyncService().refreshShopCode();

    state = LicenseState(
      isRegistered: true,
      trialStartDate: null,
      subscriptionStart: now,
      subscriptionEnd: futureDate, // Staff bypasses expiration checks
      deviceId: devId);
  }

  Future<bool> activateLicense(String key, [String? shopNameParam]) async {
    try {
      final devId = await _securityService.getDeviceId();
      final box = Hive.box<String>('settings');
      final shopName = shopNameParam ?? box.get('shopName') ?? '';

      final decoded = utf8.decode(base64.decode(key.trim()));
      final parts = decoded.split('|');
      if (parts.length != 4) return false;

      final name = parts[0];
      final expiryStr = parts[1];
      final keyDeviceId = parts[2];
      final signature = parts[3];

      // Verification 1: Match shop name (case-insensitive)
      if (name.trim().toLowerCase() != shopName.trim().toLowerCase())
        return false;

      // Verification 2: Verify device ID binding to block key sharing!
      if (keyDeviceId.trim() != devId.trim()) return false;

      final expiryDate = DateTime.tryParse(expiryStr);
      if (expiryDate == null) return false;

      // Verification 3: Cryptographic signature checks
      int sum = 0;
      for (int i = 0; i < name.length; i++) {
        sum += name.codeUnitAt(i);
      }
      for (int i = 0; i < expiryStr.length; i++) {
        sum += expiryStr.codeUnitAt(i);
      }
      for (int i = 0; i < keyDeviceId.length; i++) {
        sum += keyDeviceId.codeUnitAt(i);
      }
      final expectedSignature = ((sum * 31) % 99999).toString();

      if (signature != expectedSignature) return false;

      // Save license parameters
      final now = DateTime.now();
      final twoMonthsLater = now.add(
        const Duration(days: 60)); // 2 months duration
      await box.put('subscriptionStart', now.toIso8601String());
      await box.put('subscriptionEnd', twoMonthsLater.toIso8601String());
      await box.put('activationKey', key);

      state = state.copyWith(
        trialStartDate: null,
        subscriptionStart: now,
        subscriptionEnd: twoMonthsLater,
        activationKey: key);

      return true;
    } catch (_) {
      return false;
    }
  }

  // Admin utility helper to generate device-bound activation key
  static String generateKey(
    String shopName,
    DateTime expiryDate,
    String deviceId) {
    final expiryStr = expiryDate.toIso8601String().split('T')[0];
    int sum = 0;
    for (int i = 0; i < shopName.length; i++) {
      sum += shopName.codeUnitAt(i);
    }
    for (int i = 0; i < expiryStr.length; i++) {
      sum += expiryStr.codeUnitAt(i);
    }
    for (int i = 0; i < deviceId.length; i++) {
      sum += deviceId.codeUnitAt(i);
    }
    final signature = ((sum * 31) % 99999).toString();
    final combined = '$shopName|$expiryStr|$deviceId|$signature';
    return base64.encode(utf8.encode(combined));
  }
}

final licenseProvider = NotifierProvider<LicenseNotifier, LicenseState>(() {
  return LicenseNotifier();
});

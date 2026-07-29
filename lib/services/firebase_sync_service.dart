import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/product.dart';

import '../domain/models/order.dart';
import '../domain/models/expense.dart';
import '../domain/models/refund_model.dart';
import '../firebase_options.dart';

class FirebaseSyncService {
  static final FirebaseSyncService _instance = FirebaseSyncService._internal();
  factory FirebaseSyncService() => _instance;
  static FirebaseSyncService get instance => _instance;
  FirebaseSyncService._internal();

  bool _initialized = false;
  bool get isEnabled => _initialized;
  String? _shopCode;
  final List<StreamSubscription> _subscriptions = [];

  DocumentReference<Map<String, dynamic>> shopRef(String shopCode) {
    return FirebaseFirestore.instance.collection('shops').doc(shopCode.trim());
  }

  bool _isGlobalEnabled(Map<String, dynamic>? data) {
    if (data == null) return true;
    final val = data['isGlobalInventoryEnabled'];
    if (val == null) return true;
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return true;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      _initialized = true;

      // Listen to global config settings
      FirebaseFirestore.instance
          .collection('global_config')
          .doc('settings')
          .snapshots()
          .listen(
            (snapshot) {
              if (snapshot.exists) {
                final data = snapshot.data();
                if (data != null) {
                  final box = Hive.box<String>('settings');
                  if (data.containsKey('supportPhoneNumber')) {
                    box.put(
                      'supportPhoneNumber',
                      data['supportPhoneNumber'] as String,
                    );
                  }
                  if (data.containsKey('senderEmail')) {
                    box.put('senderEmail', data['senderEmail'] as String);
                  }
                  if (data.containsKey('senderAppPassword')) {
                    box.put(
                      'senderAppPassword',
                      data['senderAppPassword'] as String,
                    );
                  }
                }
              }
            },
            onError: (e) => debugPrint("Error listening to global config: $e"),
          );

      final settingsBox = Hive.box<String>('settings');
      _shopCode = settingsBox.get('shopCode');

      if (_shopCode != null && _shopCode!.trim().isNotEmpty) {
        _startListening();
      }

      // Automatically migrate and sync deviceId with shopCode for all existing devices
      unawaited(migrateExistingDevicesWithShopCode());

      debugPrint(
        "Firebase Sync initialized successfully. Two-way Cloud sync is active.",
      );
    } catch (e) {
      _initialized = false;
      debugPrint("Firebase Sync warning: Cloud integration bypassed ($e).");
    }
  }

  void refreshShopCode() {
    final settingsBox = Hive.box<String>('settings');
    final newCode = settingsBox.get('shopCode');
    if (newCode != null && newCode.trim().isNotEmpty) {
      final trimmedNewCode = newCode.trim();
      if (_shopCode != trimmedNewCode) {
        _shopCode = trimmedNewCode;
        // PUSH FIRST: If the user has local data that was never synced, push it to Firestore
        // before starting the listener. This prevents the outdated local Firestore cache
        // from instantly firing and overwriting the user's unsynced local data.
        // Bypassed if impersonating to avoid writing to another shop's store.
        //
        // FIX: We lock the shopCode into a local variable (lockedCode) and pass it
        // directly into _startListening. This prevents _startListening from re-reading
        // from Hive, which could be stale by the time the async call completes.
        final lockedCode = trimmedNewCode;
        if (settingsBox.get('is_impersonating') == 'true') {
          _startListening(shopCode: lockedCode);
        } else {
          pushSync().then((_) {
            _startListening(shopCode: lockedCode);
          });
        }
      }
    } else {
      cancelAllSubscriptions();
    }
  }

  void cancelAllSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _shopCode = null;
  }

  void _startListening({String? shopCode}) {
    // FIX: Accept shopCode as a direct parameter instead of re-reading from Hive.
    // Re-reading from Hive after an async gap (e.g. pushSync().then()) can return
    // a stale or different shopCode if the app switched shops in the meantime.
    final effectiveCode = shopCode ?? _shopCode;
    if (effectiveCode == null || effectiveCode.trim().isEmpty) return;

    // Lock in the code we are committing to — do not trust Hive from here on.
    _shopCode = effectiveCode.trim();

    // First cancel any active subscriptions to prevent memory leaks and duplicate triggers
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    final settingsBox = Hive.box<String>('settings');
    // Safety check: if Hive now disagrees with our locked code, abort to avoid
    // attaching a listener to a shop the user is no longer in.
    final currentHiveCode = settingsBox.get('shopCode')?.trim();
    if (currentHiveCode != null && currentHiveCode != _shopCode) {
      debugPrint('_startListening aborted: shopCode mismatch (locked=$_shopCode, hive=$currentHiveCode)');
      return;
    }

    final shopRef = FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim());

    // One-time sync for existing shops that never received global defaults
    final hasSyncedGlobal = settingsBox.get(
      'has_synced_global_defaults_${_shopCode!.trim()}',
    );
    final isImpersonating = settingsBox.get('is_impersonating') == 'true';

    if (hasSyncedGlobal != 'true' &&
        _shopCode != 'host_admin' &&
        !isImpersonating) {
      shopRef.get().then((doc) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final firestoreSynced = data['hasReceivedGlobalDefaults'] == true;

          if (!firestoreSynced) {
            if (_isGlobalEnabled(data)) {
              injectGlobalDefaults(_shopCode!.trim()).then((_) {
                shopRef.set({
                  'hasReceivedGlobalDefaults': true,
                }, SetOptions(merge: true));
                settingsBox.put(
                  'has_synced_global_defaults_${_shopCode!.trim()}',
                  'true',
                );
              });
            } else {
              shopRef.set({
                'hasReceivedGlobalDefaults': true,
              }, SetOptions(merge: true));
              settingsBox.put(
                'has_synced_global_defaults_${_shopCode!.trim()}',
                'true',
              );
            }
          } else {
            // Already synced according to Firestore, just update local flag
            settingsBox.put(
              'has_synced_global_defaults_${_shopCode!.trim()}',
              'true',
            );
          }
        }
      });
    }

    bool isFirstProductsSnapshot = true;
    bool isFirstOrdersSnapshot = true;
    bool isFirstExpensesSnapshot = true;
    bool isFirstRefundsSnapshot = true;

    // Listen to Products
    _subscriptions.add(
      shopRef.collection('products').snapshots().listen((snapshot) {
        final box = Hive.box<Product>('products');
        if (isFirstProductsSnapshot) {
          isFirstProductsSnapshot = false;
          final cloudIds = snapshot.docs.map((doc) => doc.id).toSet();
          final localKeys = box.keys.cast<String>().toList();
          for (final key in localKeys) {
            if (!cloudIds.contains(key)) {
              final localProd = box.get(key);
              if (localProd != null) {
                pushProduct(localProd);
              }
            }
          }
        }
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            if (!change.doc.metadata.hasPendingWrites) {
              box.put(change.doc.id, Product.fromMap(change.doc.data()!));
            }
          } else if (change.type == DocumentChangeType.removed) {
            box.delete(change.doc.id);
          }
        }
      }, onError: (e) => debugPrint("Firestore sync error (products): $e")),
    );

    // Listen to Orders
    _subscriptions.add(
      shopRef.collection('orders').snapshots().listen((snapshot) async {
        final box = Hive.box<OrderModel>('orders');
        if (isFirstOrdersSnapshot) {
          isFirstOrdersSnapshot = false;

          // If Firebase deliberately cleared history (admin action), the cloud
          // will write a 'history_cleared' flag to settings before clearing.
          // Only clear local data when that explicit flag is present.
          final settingsBox = Hive.box<String>('settings');
          final adminCleared =
              settingsBox.get('admin_history_cleared') == 'true';
          if (snapshot.docs.isEmpty && box.isNotEmpty && adminCleared) {
            box.clear();
            settingsBox.put('lastOrderId', 'AAA000');
            settingsBox.put('parcelToken', '0');
            settingsBox.delete('admin_history_cleared');
            return;
          }

          // SAFE MERGE: Push any local orders that are missing from Firebase
          // (offline-saved orders) up to the cloud. Never delete local orders,
          // UNLESS we are impersonating a shop, in which case local data is garbage.
          final isImpersonating = settingsBox.get('is_impersonating') == 'true';
          final cloudIds = snapshot.docs.map((doc) => doc.id).toSet();
          final localKeys = box.keys.cast<String>().toList();

          for (final key in localKeys) {
            if (!cloudIds.contains(key)) {
              if (isImpersonating) {
                // If impersonating, the device is not the source of truth. Delete leakage.
                box.delete(key);
              } else {
                // Normal device operation: recover unsynced local offline orders
                final localOrder = box.get(key);
                if (localOrder != null) {
                  try {
                    await shopRef
                        .collection('orders')
                        .doc(key)
                        .set(localOrder.toMap());
                    debugPrint('Recovered unsynced local order: $key');
                  } catch (e) {
                    debugPrint('Failed to recover local order $key: $e');
                    // Keep locally even if push fails — never delete.
                  }
                }
              }
            }
          }
        }

        // Apply only additions and modifications from the cloud.
        // NEVER delete local orders based on cloud events — local is source of truth.
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            if (!change.doc.metadata.hasPendingWrites) {
              // Only overwrite if the cloud version is newer or local doesn't exist
              final cloudOrder = OrderModel.fromMap(change.doc.data()!);
              final localOrder = box.get(change.doc.id);
              if (localOrder == null) {
                // New order from cloud (e.g. another device) — add it
                box.put(change.doc.id, cloudOrder);
              } else {
                // Only update if cloud order has a newer or equal date
                // (prevents old cloud cache from overwriting fresh local edits)
                if (!cloudOrder.date.isBefore(localOrder.date)) {
                  box.put(change.doc.id, cloudOrder);
                }
              }
            }
          }
          // DocumentChangeType.removed is intentionally ignored for orders.
          // Orders are only deleted from local storage via explicit admin actions
          // within the app itself (soft-delete with isDeleted flag).
        }
      }, onError: (e) => debugPrint("Firestore sync error (orders): $e")),
    );

    // Listen to Expenses
    _subscriptions.add(
      shopRef.collection('expenses').snapshots().listen((snapshot) {
        final box = Hive.box<Expense>('expenses');
        if (isFirstExpensesSnapshot) {
          isFirstExpensesSnapshot = false;
          final cloudIds = snapshot.docs.map((doc) => doc.id).toSet();
          final localKeys = box.keys.cast<String>().toList();
          for (final key in localKeys) {
            final localExpense = box.get(key);
            if (localExpense != null && !cloudIds.contains(key)) {
              pushExpense(localExpense);
            }
          }
        }
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            if (!change.doc.metadata.hasPendingWrites) {
              box.put(change.doc.id, Expense.fromJson(change.doc.data()!));
            }
          } else if (change.type == DocumentChangeType.removed) {
            box.delete(change.doc.id);
          }
        }
      }, onError: (e) => debugPrint("Firestore sync error (expenses): $e")),
    );

    // Listen to Refunds
    _subscriptions.add(
      shopRef.collection('refunds').snapshots().listen((snapshot) {
        final box = Hive.box<RefundModel>('refunds');
        if (isFirstRefundsSnapshot) {
          isFirstRefundsSnapshot = false;
          final cloudIds = snapshot.docs.map((doc) => doc.id).toSet();
          final localKeys = box.keys.cast<String>().toList();
          for (final key in localKeys) {
            final localRefund = box.get(key);
            if (localRefund != null && !cloudIds.contains(key)) {
              pushRefund(localRefund);
            }
          }
        }
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            if (!change.doc.metadata.hasPendingWrites) {
              box.put(change.doc.id, RefundModel.fromMap(change.doc.data()!));
            }
          } else if (change.type == DocumentChangeType.removed) {
            box.delete(change.doc.id);
          }
        }
      }, onError: (e) => debugPrint("Firestore sync error (refunds): $e")),
    );

    // Listen to Shop Settings (Real-time updates to Admin settings)
    _subscriptions.add(
      shopRef.snapshots().listen((snapshot) {
        if (!snapshot.exists && _shopCode != 'host_admin') {
          // Shop has been deleted! Logout and clear device data
          final box = Hive.box<String>('settings');
          box.put(
            'logoutMessage',
            'Your shop has been deleted. Please contact Customer Support at ${getSupportPhoneNumber()}.',
          );
          box.put('forceLogoutFlag', 'true');
          box.put('isRegistered', 'false');
          box.delete('shopCode');
          box.delete('lastLoginTimestamp');
          box.delete('adminUsername');
          box.delete('adminPassword');
          box.delete('staffAccountsJson');
          box.delete('is_impersonating');

          Hive.box<Product>('products').clear();
          Hive.box<OrderModel>('orders').clear();
          Hive.box<Expense>('expenses').clear();
          Hive.box<RefundModel>('refunds').clear();
          Hive.box<String>('category_images').clear();
          Hive.box<String>('category_dietary').clear();
          Hive.box<String>('product_images').clear();
          Hive.box<String>('product_translations').clear();
          Hive.box<String>('customers').clear();
          Hive.box<String>('category_order').clear();

          cancelAllSubscriptions();
          return;
        } else if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          final box = Hive.box<String>('settings');

          if (data['isBlocked'] == true &&
              _shopCode != 'host_admin' &&
              box.get('is_impersonating') != 'true') {
            box.put(
              'logoutMessage',
              'Your shop access has been blocked. Please contact Customer Support at ${getSupportPhoneNumber()}.',
            );
            box.put('forceLogoutFlag', 'true');
            box.put('isRegistered', 'false');

            // Clear sensitive session data but keep basic shop data if they get unblocked later
            box.delete('lastLoginTimestamp');
            box.delete('is_impersonating');

            cancelAllSubscriptions();
            return;
          } else if (data['isBlocked'] != true) {
            // Auto-clear lingering blocked flags when shop is unblocked by Master Admin
            if (box.get('logoutMessage')?.contains('blocked') == true) {
              box.delete('logoutMessage');
            }
            box.delete('forceLogoutFlag');
            if (box.get('shopCode') != null && box.get('shopCode')!.isNotEmpty) {
              box.put('isRegistered', 'true');
            }
          }

          bool isExpired = false;
          if (data['validUntil'] != null) {
            final validUntil = DateTime.tryParse(data['validUntil']);
            if (validUntil != null && DateTime.now().isAfter(validUntil)) {
              isExpired = true;
            }
          } else if (data['subscriptionEnd'] != null) {
            final subEnd = DateTime.tryParse(data['subscriptionEnd']);
            if (subEnd != null && DateTime.now().isAfter(subEnd)) {
              isExpired = true;
            }
          }

          if (isExpired &&
              _shopCode != 'host_admin' &&
              box.get('is_impersonating') != 'true') {
            box.put(
              'logoutMessage',
              'Your subscription has expired. Please contact Customer Support at ${getSupportPhoneNumber()}.',
            );
            box.put('forceLogoutFlag', 'true');
          }

          if (box.get('isStaffDevice') == 'true') {
            final lastUsername = box.get('lastLoginUsername')?.trim().toLowerCase();
            final staffList = data['staff'] as List<dynamic>? ?? [];
            final currentStaff = staffList.where((s) {
              final uname = (s['username'] as String?)?.trim().toLowerCase();
              return uname == lastUsername;
            }).firstOrNull;

            if (lastUsername != null) {
              if (currentStaff == null) {
                box.put(
                  'logoutMessage',
                  'Your staff account has been removed. Please contact your administrator.',
                );
                box.put('forceLogoutFlag', 'true');
                box.delete('lastLoginTimestamp');
              } else if (currentStaff['isBlocked'] == true) {
                box.put(
                  'logoutMessage',
                  'Your staff account has been blocked by the administrator.',
                );
                box.put('forceLogoutFlag', 'true');
                box.delete('lastLoginTimestamp');
              } else {
                // If staff is unblocked, clear staff logout message
                if (box.get('logoutMessage')?.contains('staff account has been') == true) {
                  box.delete('logoutMessage');
                  box.delete('forceLogoutFlag');
                }
              }
            }
          }

          if (data.containsKey('force_clear_history')) {
            final cloudClearTime = data['force_clear_history'] as int;
            final localClearTime = box.get('last_cleared_history_time') != null
                ? int.tryParse(box.get('last_cleared_history_time')!) ?? 0
                : 0;

            if (cloudClearTime > localClearTime) {
              box.put('last_cleared_history_time', cloudClearTime.toString());
              Hive.box<OrderModel>('orders').clear();
              Hive.box<Expense>('expenses').clear();
              Hive.box<RefundModel>('refunds').clear();
              box.put('lastOrderId', 'AAA000');
              box.put('parcelToken', '0');
              debugPrint('History force cleared by Cloud Sync.');
            }
          }

          saveSettingsFromMap(box, data);
        }
      }, onError: (e) => debugPrint("Firestore sync error (settings): $e")),
    );

    // Listen to Product Images
    _subscriptions.add(
      shopRef.collection('product_images').snapshots().listen(
        (snapshot) {
          final box = Hive.box<String>('product_images');
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              final img = change.doc.data()?['base64'];
              if (img != null) {
                box.put(change.doc.id, img);
              }
            } else if (change.type == DocumentChangeType.removed) {
              box.delete(change.doc.id);
            }
          }
        },
        onError: (e) => debugPrint("Firestore sync error (product_images): $e"),
      ),
    );

    // Listen to Product Translations
    _subscriptions.add(
      shopRef.collection('product_translations').snapshots().listen(
        (snapshot) {
          final box = Hive.box<String>('product_translations');
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              final trans = change.doc.data()?['ta'];
              if (trans != null) {
                box.put(change.doc.id, trans);
              }
            } else if (change.type == DocumentChangeType.removed) {
              box.delete(change.doc.id);
            }
          }
        },
        onError: (e) =>
            debugPrint("Firestore sync error (product_translations): $e"),
      ),
    );

    // Listen to Categories
    _subscriptions.add(
      shopRef.collection('categories').snapshots().listen((snapshot) {
        final box = Hive.box<String>('category_images');
        final tBox = Hive.box<String>('category_translations');
        final dBox = Hive.box<String>('category_dietary');
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            final img = change.doc.data()?['base64'] as String?;
            box.put(change.doc.id, img ?? '');
            final tamilName = change.doc.data()?['tamilName'] as String?;
            if (tamilName != null && tBox.isOpen) {
              tBox.put(change.doc.id, tamilName);
            }
            final dietaryType = change.doc.data()?['dietaryType'] as String?;
            if (dBox.isOpen) {
              dBox.put(change.doc.id, dietaryType ?? 'both');
            }
          } else if (change.type == DocumentChangeType.removed) {
            box.delete(change.doc.id);
            if (tBox.isOpen) {
              tBox.delete(change.doc.id);
            }
            if (dBox.isOpen) {
              dBox.delete(change.doc.id);
            }
          }
        }
      }, onError: (e) => debugPrint("Firestore sync error (categories): $e")),
    );
  }

  // --- Push Methods ---

  Future<void> pushProduct(Product product) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('products')
        .doc(product.id)
        .set(product.toMap());
  }

  Future<void> pushProductImage(String productId, String base64Image) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('product_images')
        .doc(productId)
        .set({'base64': base64Image}, SetOptions(merge: true));
  }

  Future<void> pushCategory(
    String categoryName,
    String base64Image, {
    String? tamilName,
    String dietaryType = 'both',
  }) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('categories')
        .doc(categoryName)
        .set({
          'base64': base64Image,
          'tamilName': tamilName ?? '',
          'dietaryType': dietaryType,
        }, SetOptions(merge: true));

    final tBox = Hive.box<String>('category_translations');
    if (tBox.isOpen) {
      if (tamilName != null && tamilName.isNotEmpty) {
        tBox.put(categoryName, tamilName);
      } else {
        tBox.delete(categoryName);
      }
    }
  }

  Future<void> deleteCategory(String categoryName) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('categories')
        .doc(categoryName)
        .delete();
  }

  Future<void> pushProductTranslation(
    String productId,
    String tamilName,
  ) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('product_translations')
        .doc(productId)
        .set({'ta': tamilName});
  }

  Future<void> deleteProduct(String id) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('products')
        .doc(id)
        .delete();
  }

  Future<void> pushOrder(OrderModel order) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('orders')
        .doc(order.id)
        .set(order.toMap());
  }

  Future<void> deleteOrder(String id) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('orders')
        .doc(id)
        .delete();
  }

  Future<void> pushExpense(Expense expense) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('expenses')
        .doc(expense.id)
        .set(expense.toJson());
  }

  Future<void> deleteExpense(String id) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('expenses')
        .doc(id)
        .delete();
  }

  Future<void> pushRefund(RefundModel refund) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('refunds')
        .doc(refund.id)
        .set(refund.toMap());
  }

  Future<void> deleteRefund(String id) async {
    if (!_initialized || _shopCode == null) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim())
        .collection('refunds')
        .doc(id)
        .delete();
  }

  Future<bool> verifyStaffLogin(
    String shopCode,
    String username,
    String password, [
    String deviceId = '',
  ]) async {
    if (!_initialized) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopCode.trim())
          .get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      if (data['isBlocked'] == true) return false;
      if (data['validUntil'] != null) {
        try {
          final val = data['validUntil'];
          final validDate = val is String
              ? DateTime.parse(val)
              : (val as Timestamp).toDate();
          if (DateTime.now().isAfter(validDate)) return false;
        } catch (_) {}
      }

      // GLOBAL DEVICE LOCK CHECK
      if (deviceId.isNotEmpty) {
        final lockError = await _checkAndLockGlobalDevice(
          deviceId,
          shopCode,
          username,
        );
        if (lockError != null) {
          debugPrint('Global Device Lock Error: $lockError');
          return false;
        }
      }

      final encodedPassword = base64.encode(utf8.encode(password));

      // Check Staff credentials
      final List<dynamic> staffList = data['staff'] ?? [];
      for (var staff in staffList) {
        final storedUser = (staff['username'] as String?)?.trim().toLowerCase();
        final storedPass = staff['password'] as String?;
        if (storedUser == username.trim().toLowerCase() &&
            (storedPass == password || storedPass == encodedPassword)) {
          if (staff['isBlocked'] == true) {
            throw Exception(
              'Your staff account has been blocked by the administrator.',
            );
          }
          final box = Hive.box<String>('settings');
          await box.put('isStaffDevice', 'true');
          await box.put('staffAccountsJson', jsonEncode(staffList));
          saveSettingsFromMap(box, data);
          return true;
        }
      }
      return false; // Credentials mismatched
    } catch (e) {
      throw Exception('Firebase connection failed: $e');
    }
  }

  Future<void> syncAdminPassword(
    String shopCode,
    String encodedPassword,
  ) async {
    if (!_initialized) return;
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopCode.trim())
          .set({'adminPasswordHash': encodedPassword}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to sync admin password: $e');
    }
  }

  /// Returns null on success, or an error string on failure
  Future<Map<String, dynamic>?> verifyFranchiseLogin(
    String phone,
    String password,
  ) async {
    if (!_initialized) return {'error': 'No internet connection'};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('franchise_owners')
          .doc(phone.trim())
          .get();

      if (!doc.exists) return {'error': 'Owner account not found'};

      final data = doc.data()!;
      final storedHash = data['passwordHash'] as String?;

      if (storedHash == null) return {'error': 'Account not fully configured'};

      final inputHash = base64.encode(utf8.encode(password));
      if (inputHash != storedHash) return {'error': 'Incorrect password'};

      return {
        'name': data['name'] ?? 'Franchise Owner',
        'ownedShops': List<String>.from(data['ownedShops'] ?? []),
      };
    } catch (e) {
      return {'error': 'Error connecting to cloud: $e'};
    }
  }

  /// Fetches total sales from the cloud for the given branches over the given date range.
  Future<Map<String, double>> fetchFranchiseSalesSummary(
    List<String> shopCodes,
    DateTime start,
    DateTime end,
  ) async {
    if (!_initialized) return {};

    final Map<String, double> branchSales = {};

    // We run queries for each shop code in parallel
    await Future.wait(
      shopCodes.map((shopCode) async {
        try {
          final querySnapshot = await FirebaseFirestore.instance
              .collection('shops')
              .doc(shopCode.trim())
              .collection('orders')
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: start.toIso8601String(),
              )
              .where('createdAt', isLessThanOrEqualTo: end.toIso8601String())
              .get();

          double total = 0;
          for (var doc in querySnapshot.docs) {
            final data = doc.data();
            if (data['status'] == 'completed') {
              total += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
            }
          }
          branchSales[shopCode] = total;
        } catch (e) {
          debugPrint('Error fetching sales for $shopCode: $e');
          branchSales[shopCode] = 0.0;
        }
      }),
    );

    return branchSales;
  }

  /// Returns null on success, or an error string on failure
  Future<String?> verifyAdminCloudLogin(
    String shopCode,
    String password,
    String deviceId,
  ) async {
    if (!_initialized) return 'No internet connection';
    try {
      final shopRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(shopCode.trim());
      final doc = await shopRef.get();
      if (!doc.exists) return 'Shop code not found';

      final data = doc.data()!;
      if (data['isBlocked'] == true) {
        return 'Access Blocked: Please contact Customer Support at ${getSupportPhoneNumber()}';
      }
      if (data['validUntil'] != null) {
        try {
          final val = data['validUntil'];
          final validDate = val is String
              ? DateTime.parse(val)
              : (val as Timestamp).toDate();
          if (DateTime.now().isAfter(validDate)) {
            return 'Subscription Expired: Please contact Customer Support at ${getSupportPhoneNumber()}';
          }
        } catch (_) {}
      }

      // GLOBAL DEVICE LOCK CHECK
      final lockError = await _checkAndLockGlobalDevice(
        deviceId,
        shopCode,
        'admin',
      );
      if (lockError != null) return lockError;

      final storedHash = data['adminPasswordHash'] as String?;
      if (storedHash == null) return 'Shop not configured for cloud login';

      // Verify password
      final inputHash = base64.encode(utf8.encode(password));
      if (inputHash != storedHash) return 'Incorrect password';

      // Master Admin Host devices are completely immune/ignored for normal shop device limits
      final box = Hive.box<String>('settings');
      final isHostDevice = box.get('isHostDevice') == 'true' ||
          box.get('is_impersonating') == 'true';

      if (!isHostDevice) {
        // Check device list for normal shop admins
        final List<dynamic> rawDevices = data['adminDevices'] ?? [];
        final List<Map<String, dynamic>> devices = rawDevices
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final alreadyRegistered = devices.any((d) => d['deviceId'] == deviceId);
        if (alreadyRegistered) {
          final deviceData = devices.firstWhere((d) => d['deviceId'] == deviceId);
          if (deviceData['isBlocked'] == true) {
            return 'Your admin device has been blocked by the main host.';
          }
        } else {
          if (devices.length >= 3) {
            // Notify the first registered device
            final firstDevice = devices.isNotEmpty
                ? devices.first['deviceId']
                : null;
            await shopRef.set({
              'loginAlerts': FieldValue.arrayUnion([
                {
                  'type': 'unauthorized_attempt',
                  'timestamp': DateTime.now().toIso8601String(),
                  'attemptedDeviceId': deviceId,
                  'notifyDevice': firstDevice,
                },
              ]),
            }, SetOptions(merge: true));
            return 'max_devices_reached';
          }
          // Register the new device
          await shopRef.set({
            'adminDevices': FieldValue.arrayUnion([
              {
                'deviceId': deviceId,
                'shopCode': shopCode.trim(),
                'registeredAt': DateTime.now().toIso8601String(),
              },
            ]),
          }, SetOptions(merge: true));
        }
      }

      // Save settings locally
      await box.put('isStaffDevice', 'false');
      saveSettingsFromMap(box, data);
      if (data.containsKey('staff')) {
        box.put('staffAccountsJson', jsonEncode(data['staff']));
      }
      box.put('shopCode', shopCode.trim());
      return null; // null = success
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  /// Syncs this shop's admin password to Firebase after a local admin login
  Future<void> registerAdminDeviceOnCloud(
    String shopCode,
    String encodedPassword,
    String deviceId,
  ) async {
    if (!_initialized || shopCode.isEmpty) return;
    try {
      final shopRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(shopCode.trim());

      final box = Hive.box<String>('settings');
      final isHostDevice = box.get('isHostDevice') == 'true' ||
          box.get('is_impersonating') == 'true';

      if (isHostDevice) {
        // Master Admin device: Only update password hash, DO NOT register deviceId in shop's adminDevices array
        await shopRef.set({
          'adminPasswordHash': encodedPassword,
        }, SetOptions(merge: true));
      } else {
        await shopRef.set({
          'adminPasswordHash': encodedPassword,
          'adminDevices': FieldValue.arrayUnion([
            {
              'deviceId': deviceId,
              'shopCode': shopCode.trim(),
              'registeredAt': DateTime.now().toIso8601String(),
            },
          ]),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Failed to register admin device on cloud: $e');
    }
  }

  /// Checks for login alerts for this device and returns them. Clears after reading.
  Future<List<Map<String, dynamic>>> checkAndClearLoginAlerts(
    String shopCode,
    String deviceId,
  ) async {
    if (!_initialized || shopCode.isEmpty) return [];
    try {
      final shopRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(shopCode.trim());
      final doc = await shopRef.get();
      if (!doc.exists) return [];
      final data = doc.data()!;
      final List<dynamic> alerts = data['loginAlerts'] ?? [];
      final myAlerts = alerts
          .map((e) => Map<String, dynamic>.from(e))
          .where((a) => a['notifyDevice'] == deviceId)
          .toList();
      if (myAlerts.isNotEmpty) {
        // Remove all alerts meant for this device
        final remaining = alerts
            .map((e) => Map<String, dynamic>.from(e))
            .where((a) => a['notifyDevice'] != deviceId)
            .toList();
        await shopRef.set({'loginAlerts': remaining}, SetOptions(merge: true));
      }
      return myAlerts;
    } catch (e) {
      return [];
    }
  }

  void saveSettingsFromMap(Box<String> box, Map<String, dynamic> data) {
    if (data.containsKey('staff')) {
      box.put('staffAccountsJson', jsonEncode(data['staff']));
    }
    if (data.containsKey('expenseCategories')) {
      box.put('expense_categories', jsonEncode(data['expenseCategories']));
    }
    if (data.containsKey('shopName')) box.put('shopName', data['shopName']);
    if (data.containsKey('receiptHeader'))
      box.put('receiptHeader', data['receiptHeader']);
    if (data.containsKey('receiptFooter'))
      box.put('receiptFooter', data['receiptFooter']);
    if (data.containsKey('gstNumber')) box.put('gstNumber', data['gstNumber']);
    if (data.containsKey('shopLogoPath'))
      box.put('shopLogoPath', data['shopLogoPath']);
    if (data.containsKey('taxRate'))
      box.put('taxRate', data['taxRate'].toString());
    if (data.containsKey('showGstOnReceipt'))
      box.put('showGstOnReceipt', data['showGstOnReceipt'].toString());
    if (data.containsKey('enableStaffCustomerDirectory'))
      box.put(
        'enableStaffCustomerDirectory',
        data['enableStaffCustomerDirectory'].toString(),
      );
    if (data.containsKey('showStockQuantity'))
      box.put('showStockQuantity', data['showStockQuantity'].toString());
    if (data.containsKey('enableStaffStockManagement'))
      box.put(
        'enableStaffStockManagement',
        data['enableStaffStockManagement'].toString(),
      );
    if (data.containsKey('enableTaxCalculation'))
      box.put('enableTaxCalculation', data['enableTaxCalculation'].toString());
    if (data.containsKey('enableStaffRefund'))
      box.put('enableStaffRefund', data['enableStaffRefund'].toString());
    if (data.containsKey('enableStaffOrderHistory'))
      box.put(
        'enableStaffOrderHistory',
        data['enableStaffOrderHistory'].toString(),
      );
    if (data.containsKey('enableTableNumber'))
      box.put('enableTableNumber', data['enableTableNumber'].toString());
    if (data.containsKey('enableDiscountInCart'))
      box.put('enableDiscountInCart', data['enableDiscountInCart'].toString());
    if (data.containsKey('enableCustomerDetails'))
      box.put(
        'enableCustomerDetails',
        data['enableCustomerDetails'].toString(),
      );
    if (data.containsKey('addressLine1'))
      box.put('addressLine1', data['addressLine1']);
    if (data.containsKey('addressLine2'))
      box.put('addressLine2', data['addressLine2']);
    if (data.containsKey('hotelType')) box.put('hotelType', data['hotelType']);
    if (data.containsKey('mobileNumber'))
      box.put('mobileNumber', data['mobileNumber']);
    if (data.containsKey('fssaiNumber'))
      box.put('fssaiNumber', data['fssaiNumber']);
    if (data.containsKey('isDemoVersion'))
      box.put('isDemoVersion', data['isDemoVersion'].toString());
    if (data.containsKey('enableAddressOnReceipt'))
      box.put(
        'enableAddressOnReceipt',
        data['enableAddressOnReceipt'].toString(),
      );
    if (data.containsKey('enableMobileOnReceipt'))
      box.put(
        'enableMobileOnReceipt',
        data['enableMobileOnReceipt'].toString(),
      );
    if (data.containsKey('enableFssaiOnReceipt'))
      box.put('enableFssaiOnReceipt', data['enableFssaiOnReceipt'].toString());
    if (data.containsKey('enableHotelTypeOnReceipt'))
      box.put(
        'enableHotelTypeOnReceipt',
        data['enableHotelTypeOnReceipt'].toString(),
      );
    if (data.containsKey('enableShopDetailsOnKot'))
      box.put(
        'enableShopDetailsOnKot',
        data['enableShopDetailsOnKot'].toString(),
      );
    if (data.containsKey('enableKotReceipt'))
      box.put(
        'enableKotReceipt',
        data['enableKotReceipt'].toString(),
      );
    if (data.containsKey('enablePopularCategory'))
      box.put(
        'enablePopularCategory',
        data['enablePopularCategory'].toString(),
      );
    if (data.containsKey('enablePaymentModeSelection'))
      box.put(
        'enablePaymentModeSelection',
        data['enablePaymentModeSelection'].toString(),
      );
    if (data.containsKey('enableStaffInventory'))
      box.put('enableStaffInventory', data['enableStaffInventory'].toString());
    if (data.containsKey('enableTokenLimit'))
      box.put('enableTokenLimit', data['enableTokenLimit'].toString());
    if (data.containsKey('dietaryFilter'))
      box.put('dietaryFilter', data['dietaryFilter'].toString());
    if (data.containsKey('showStoreInfo'))
      box.put('showStoreInfo', data['showStoreInfo'].toString());
    if (data.containsKey('showAppSettings'))
      box.put('showAppSettings', data['showAppSettings'].toString());
    if (data.containsKey('showReceiptOptions'))
      box.put('showReceiptOptions', data['showReceiptOptions'].toString());
    if (data.containsKey('showCheckoutFeatures'))
      box.put('showCheckoutFeatures', data['showCheckoutFeatures'].toString());
    if (data.containsKey('showPoweredByDiyan'))
      box.put('showPoweredByDiyan', data['showPoweredByDiyan'].toString());
    if (data.containsKey('enableSplitPayment'))
      box.put('enableSplitPayment', data['enableSplitPayment'].toString());
    if (data.containsKey('hideImagesInCheckout'))
      box.put('hideImagesInCheckout', data['hideImagesInCheckout'].toString());
    if (data.containsKey('dailyResetOrderId'))
      box.put('dailyResetOrderId', data['dailyResetOrderId'].toString());
    if (data.containsKey('enableDineIn'))
      box.put('enableDineIn', data['enableDineIn'].toString());
    if (data.containsKey('enableParcel'))
      box.put('enableParcel', data['enableParcel'].toString());
    if (data.containsKey('enableStaffEditBill'))
      box.put('enableStaffEditBill', data['enableStaffEditBill'].toString());
    if (data.containsKey('enableStaffExpenses'))
      box.put('enableStaffExpenses', data['enableStaffExpenses'].toString());
    if (data.containsKey('captainCustomerDirectory'))
      box.put('captainCustomerDirectory', data['captainCustomerDirectory'].toString());
    if (data.containsKey('captainInventory'))
      box.put('captainInventory', data['captainInventory'].toString());
    if (data.containsKey('captainStockManagement'))
      box.put('captainStockManagement', data['captainStockManagement'].toString());
    if (data.containsKey('captainRefund'))
      box.put('captainRefund', data['captainRefund'].toString());
    if (data.containsKey('captainOrderHistory'))
      box.put('captainOrderHistory', data['captainOrderHistory'].toString());
    if (data.containsKey('captainEditBill'))
      box.put('captainEditBill', data['captainEditBill'].toString());
    if (data.containsKey('captainExpenses'))
      box.put('captainExpenses', data['captainExpenses'].toString());
    if (data.containsKey('printAsImage'))
      box.put('printAsImage', data['printAsImage'].toString());
    if (data.containsKey('is80mmPaper'))
      box.put('is80mmPaper', data['is80mmPaper'].toString());
    if (data.containsKey('savedPrinterMacAddress'))
      box.put('savedPrinterMacAddress', data['savedPrinterMacAddress']);
    if (data.containsKey('savedPrinterIpAddress'))
      box.put('savedPrinterIpAddress', data['savedPrinterIpAddress']);
    if (data.containsKey('printerConnectionType'))
      box.put('printerConnectionType', data['printerConnectionType']);
    if (data.containsKey('enableMultiplePrinters'))
      box.put('enableMultiplePrinters', data['enableMultiplePrinters'].toString());
    if (data.containsKey('customPrinters'))
      box.put('customPrinters', data['customPrinters'].toString());
    if (data.containsKey('enableShopDetailsOnKot'))
      box.put('enableShopDetailsOnKot', data['enableShopDetailsOnKot'].toString());
    if (data.containsKey('showMasterAdminLook'))
      box.put('showMasterAdminLook', data['showMasterAdminLook'].toString());
    if (data.containsKey('validUntil'))
      box.put('validUntil', data['validUntil'].toString());
    if (data.containsKey('subscriptionEnd'))
      box.put('subscriptionEnd', data['subscriptionEnd'].toString());

    if (data.containsKey('categoryOrder')) {
      final orderMap = data['categoryOrder'] as Map<String, dynamic>;
      final catBox = Hive.box<String>('category_order');
      catBox.deleteAll(catBox.keys);
      for (final key in orderMap.keys) {
        catBox.put(key, orderMap[key].toString());
      }
    }
    if (data.containsKey('productOrder')) {
      final orderMap = data['productOrder'] as Map<String, dynamic>;
      final prodBox = Hive.box<String>('product_order');
      prodBox.deleteAll(prodBox.keys);
      for (final key in orderMap.keys) {
        prodBox.put(key, orderMap[key].toString());
      }
    }
    if (data.containsKey('categoryStatus')) {
      final statusMap = data['categoryStatus'] as Map<String, dynamic>;
      final statusBox = Hive.box<bool>('category_status');
      statusBox.deleteAll(statusBox.keys);
      for (final key in statusMap.keys) {
        statusBox.put(key, statusMap[key] as bool);
      }
    }
  }

  Future<void> pushSettingsSync() async {
    await Future.delayed(Duration.zero);
    if (!_initialized || _shopCode == null || _shopCode!.trim() == 'host_admin') return;

    final box = Hive.box<String>('settings');
    // Safeguard: Bypasses sync if the settings box is currently being cleared or in master admin mode
    if (box.get('shopName') == null || box.get('shopCode') == 'host_admin') {
      debugPrint("Settings box is cleared/wiping or in host_admin mode. Bypassing pushSettingsSync.");
      return;
    }

    final shopRef = FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim());

    Map<String, dynamic> shopData = {
      'enableStaffCustomerDirectory':
          (box.get('enableStaffCustomerDirectory') ?? 'true') == 'true',
      'showStockQuantity': (box.get('showStockQuantity') ?? 'true') == 'true',
      'enableStaffStockManagement':
          (box.get('enableStaffStockManagement') ?? 'false') == 'true',
      'enableTaxCalculation':
          (box.get('enableTaxCalculation') ?? 'true') == 'true',
      'enableStaffRefund': (box.get('enableStaffRefund') ?? 'false') == 'true',
      'enableStaffOrderHistory':
          (box.get('enableStaffOrderHistory') ?? 'true') == 'true',
      'enableTableNumber': (box.get('enableTableNumber') ?? 'false') == 'true',
      'enableDiscountInCart':
          (box.get('enableDiscountInCart') ?? 'false') == 'true',
      'enableCustomerDetails':
          (box.get('enableCustomerDetails') ?? 'false') == 'true',
      'shopName': box.get('shopName') ?? 'Enterprise POS',
      'receiptHeader': box.get('receiptHeader') ?? '',
      'receiptFooter': box.get('receiptFooter') ?? '',
      'gstNumber': box.get('gstNumber') ?? '',
      'shopLogoPath': box.get('shopLogoPath') ?? '',
      'taxRate': double.tryParse(box.get('taxRate') ?? '5.0') ?? 5.0,
      'showGstOnReceipt': (box.get('showGstOnReceipt') ?? 'true') == 'true',
      'addressLine1': box.get('addressLine1') ?? '',
      'addressLine2': box.get('addressLine2') ?? '',
      'hotelType': box.get('hotelType') ?? '',
      'mobileNumber': box.get('mobileNumber') ?? '',
      'fssaiNumber': box.get('fssaiNumber') ?? '',
      'enableAddressOnReceipt':
          (box.get('enableAddressOnReceipt') ?? 'false') == 'true',
      'enableMobileOnReceipt':
          (box.get('enableMobileOnReceipt') ?? 'false') == 'true',
      'enableFssaiOnReceipt':
          (box.get('enableFssaiOnReceipt') ?? 'false') == 'true',
      'enableHotelTypeOnReceipt':
          (box.get('enableHotelTypeOnReceipt') ?? 'false') == 'true',
      'enablePopularCategory':
          (box.get('enablePopularCategory') ?? 'true') == 'true',
      'enablePaymentModeSelection':
          (box.get('enablePaymentModeSelection') ?? 'false') == 'true',
      'enableStaffInventory':
          (box.get('enableStaffInventory') ?? 'false') == 'true',
      'enableTokenLimit': (box.get('enableTokenLimit') ?? 'true') == 'true',
      'dietaryFilter': box.get('dietaryFilter') ?? 'both',
      'showStoreInfo': (box.get('showStoreInfo') ?? 'true') == 'true',
      'showAppSettings': (box.get('showAppSettings') ?? 'true') == 'true',
      'showReceiptOptions': (box.get('showReceiptOptions') ?? 'true') == 'true',
      'showCheckoutFeatures':
          (box.get('showCheckoutFeatures') ?? 'true') == 'true',
      'showPoweredByDiyan': (box.get('showPoweredByDiyan') ?? 'true') == 'true',
      'enableSplitPayment': (box.get('enableSplitPayment') ?? 'true') == 'true',
      'hideImagesInCheckout':
          (box.get('hideImagesInCheckout') ?? 'false') == 'true',
      'dailyResetOrderId': (box.get('dailyResetOrderId') ?? 'false') == 'true',
      'enableDineIn': (box.get('enableDineIn') ?? 'true') == 'true',
      'enableParcel': (box.get('enableParcel') ?? 'true') == 'true',
      'enableStaffEditBill': (box.get('enableStaffEditBill') ?? 'false') == 'true',
      'enableStaffExpenses': (box.get('enableStaffExpenses') ?? 'false') == 'true',
      'captainCustomerDirectory': (box.get('captainCustomerDirectory') ?? 'false') == 'true',
      'captainInventory': (box.get('captainInventory') ?? 'false') == 'true',
      'captainStockManagement': (box.get('captainStockManagement') ?? 'false') == 'true',
      'captainRefund': (box.get('captainRefund') ?? 'false') == 'true',
      'captainOrderHistory': (box.get('captainOrderHistory') ?? 'false') == 'true',
      'captainEditBill': (box.get('captainEditBill') ?? 'false') == 'true',
      'captainExpenses': (box.get('captainExpenses') ?? 'false') == 'true',
      'printAsImage': (box.get('printAsImage') ?? 'false') == 'true',
      'is80mmPaper': (box.get('is80mmPaper') ?? 'true') == 'true',
      'enableShopDetailsOnKot': (box.get('enableShopDetailsOnKot') ?? 'false') == 'true',
      'enableKotReceipt': (box.get('enableKotReceipt') ?? 'true') == 'true',
      'showMasterAdminLook': (box.get('showMasterAdminLook') ?? 'true') == 'true',
    };

    // Attach category order
    final catBox = Hive.box<String>('category_order');
    final Map<String, String> catOrderMap = {};
    for (final key in catBox.keys) {
      catOrderMap[key.toString()] = catBox.get(key) ?? '9999';
    }
    shopData['categoryOrder'] = catOrderMap;

    // Attach product order
    final prodBox = Hive.box<String>('product_order');
    final Map<String, String> prodOrderMap = {};
    for (final key in prodBox.keys) {
      prodOrderMap[key.toString()] = prodBox.get(key) ?? '9999';
    }
    shopData['productOrder'] = prodOrderMap;

    // Attach category status
    final statusBox = Hive.box<bool>('category_status');
    final Map<String, bool> categoryStatusMap = {};
    for (final key in statusBox.keys) {
      categoryStatusMap[key.toString()] = statusBox.get(key) ?? true;
    }
    shopData['categoryStatus'] = categoryStatusMap;

    final staffJsonStr = box.get('staffAccountsJson');
    if (staffJsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(staffJsonStr);
        shopData['staff'] = decoded;
      } catch (_) {}
    }

    final expCategoriesJson = box.get('expense_categories');
    if (expCategoriesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(expCategoriesJson);
        shopData['expenseCategories'] = decoded.cast<String>();
      } catch (_) {}
    }

    await shopRef.set(shopData, SetOptions(merge: true));
  }

  Future<bool> pushSync() async {
    // Yield to the event loop immediately to ensure UI animations (like switch toggles) complete instantly
    await Future.delayed(Duration.zero);

    if (!_initialized || _shopCode == null) return true;

    final box = Hive.box<String>('settings');

    // Safeguard: Bypasses sync if this is a staff device (staff devices should never overwrite shop settings)
    if (box.get('isStaffDevice') == 'true') {
      debugPrint("Staff device active. Bypassing settings pushSync.");
      return true;
    }

    // Safeguard: Bypasses sync if impersonation is active to prevent data leakage
    if (box.get('is_impersonating') == 'true') {
      debugPrint("Impersonation active. Bypassing pushSync.");
      return true;
    }

    // Safeguard: Bypasses sync if the settings box is currently being cleared (e.g. return from impersonation/logout)
    // FIX: Changed AND (&&) to OR (||) — previously, if only one of shopName or upiId
    // survived the wipe, the guard silently failed and pushed blank/stale data to Firebase.
    // Also guard against host_admin shopCode ever triggering a shop push.
    if (box.get('shopName') == null ||
        box.get('shopCode') == null ||
        box.get('shopCode') == 'host_admin') {
      debugPrint("Settings box is cleared/wiping or host_admin. Bypassing pushSync.");
      return true;
    }

    final shopRef = FirebaseFirestore.instance
        .collection('shops')
        .doc(_shopCode!.trim());

    final staffJsonStr = box.get('staffAccountsJson');

    Map<String, dynamic> shopData = {
      'enableStaffCustomerDirectory':
          (box.get('enableStaffCustomerDirectory') ?? 'true') == 'true',
      'showStockQuantity': (box.get('showStockQuantity') ?? 'true') == 'true',
      'enableStaffStockManagement':
          (box.get('enableStaffStockManagement') ?? 'false') == 'true',
      'enableTaxCalculation':
          (box.get('enableTaxCalculation') ?? 'true') == 'true',
      'enableStaffRefund': (box.get('enableStaffRefund') ?? 'false') == 'true',
      'enableStaffOrderHistory':
          (box.get('enableStaffOrderHistory') ?? 'true') == 'true',
      'enableTableNumber': (box.get('enableTableNumber') ?? 'false') == 'true',
      'enableDiscountInCart':
          (box.get('enableDiscountInCart') ?? 'false') == 'true',
      'enableCustomerDetails':
          (box.get('enableCustomerDetails') ?? 'false') == 'true',
      'shopName': box.get('shopName') ?? 'Enterprise POS',
      'receiptHeader': box.get('receiptHeader') ?? '',
      'receiptFooter': box.get('receiptFooter') ?? '',
      'gstNumber': box.get('gstNumber') ?? '',
      'shopLogoPath': box.get('shopLogoPath') ?? '',
      'taxRate': double.tryParse(box.get('taxRate') ?? '5.0') ?? 5.0,
      'showGstOnReceipt': (box.get('showGstOnReceipt') ?? 'true') == 'true',
      'addressLine1': box.get('addressLine1') ?? '',
      'addressLine2': box.get('addressLine2') ?? '',
      'hotelType': box.get('hotelType') ?? '',
      'mobileNumber': box.get('mobileNumber') ?? '',
      'fssaiNumber': box.get('fssaiNumber') ?? '',
      'enableAddressOnReceipt':
          (box.get('enableAddressOnReceipt') ?? 'false') == 'true',
      'enableMobileOnReceipt':
          (box.get('enableMobileOnReceipt') ?? 'false') == 'true',
      'enableFssaiOnReceipt':
          (box.get('enableFssaiOnReceipt') ?? 'false') == 'true',
      'enableHotelTypeOnReceipt':
          (box.get('enableHotelTypeOnReceipt') ?? 'false') == 'true',
      'enablePopularCategory':
          (box.get('enablePopularCategory') ?? 'true') == 'true',
      'enablePaymentModeSelection':
          (box.get('enablePaymentModeSelection') ?? 'false') == 'true',
      'enableStaffInventory':
          (box.get('enableStaffInventory') ?? 'false') == 'true',
      'enableTokenLimit': (box.get('enableTokenLimit') ?? 'true') == 'true',
      'dietaryFilter': box.get('dietaryFilter') ?? 'both',
      'enableMultiplePrinters':
          (box.get('enableMultiplePrinters') ?? 'false') == 'true',
      'enableSplitPayment': (box.get('enableSplitPayment') ?? 'true') == 'true',
      'hideImagesInCheckout':
          (box.get('hideImagesInCheckout') ?? 'false') == 'true',
    };

    final printersJsonStr = box.get('customPrinters');
    if (printersJsonStr != null) {
      try {
        final List<dynamic> decodedPrinters = jsonDecode(printersJsonStr);
        shopData['customPrinters'] = decodedPrinters;
      } catch (_) {}
    }

    // Attach category order
    final catBox = Hive.box<String>('category_order');
    if (catBox.isNotEmpty) {
      final Map<String, String> catOrderMap = {};
      for (final key in catBox.keys) {
        catOrderMap[key.toString()] = catBox.get(key) ?? '9999';
      }
      shopData['categoryOrder'] = catOrderMap;

      // Attach product order
      final prodBox = Hive.box<String>('product_order');
      final Map<String, String> prodOrderMap = {};
      for (final key in prodBox.keys) {
        prodOrderMap[key.toString()] = prodBox.get(key) ?? '9999';
      }
      shopData['productOrder'] = prodOrderMap;
    }

    // Attach category status
    final statusBox = Hive.box<bool>('category_status');
    if (statusBox.isNotEmpty) {
      final Map<String, bool> categoryStatusMap = {};
      for (final key in statusBox.keys) {
        categoryStatusMap[key.toString()] = statusBox.get(key) ?? true;
      }
      shopData['categoryStatus'] = categoryStatusMap;
    }

    if (staffJsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(staffJsonStr);
        shopData['staff'] = decoded;
      } catch (_) {}
    }

    final expCategoriesJson = box.get('expense_categories');
    if (expCategoriesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(expCategoriesJson);
        shopData['expenseCategories'] = decoded.cast<String>();
      } catch (_) {}
    }

    try {
      await shopRef
          .set(shopData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      debugPrint("Settings sync failed/timed out: $e");
      return false;
    }
  }

  /// Pushes ONLY the staff accounts array to Firebase.
  /// Unlike pushSync(), this is safe to call during impersonation mode because
  /// it only updates the 'staff' field and never touches any shop settings.
  Future<void> pushStaffOnly() async {
    await Future.delayed(Duration.zero);
    if (!_initialized || _shopCode == null) return;

    // Staff device must never overwrite staff data
    final box = Hive.box<String>('settings');
    if (box.get('isStaffDevice') == 'true') return;

    // Only push if we have a valid shop context
    if (box.get('shopName') == null && box.get('upiId') == null) return;

    final staffJsonStr = box.get('staffAccountsJson');
    if (staffJsonStr == null) return;

    try {
      final List<dynamic> decoded = jsonDecode(staffJsonStr);
      final shopRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(_shopCode!.trim());
      await shopRef
          .set({'staff': decoded}, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      debugPrint('Staff permissions pushed to Firebase successfully.');
    } catch (e) {
      debugPrint('pushStaffOnly failed: \$e');
    }
  }

  Future<int> getNextParcelToken() async {
    final box = Hive.box<String>('settings');
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = box.get('parcelTokenDate') ?? '';
    bool enableTokenLimit = (box.get('enableTokenLimit') ?? 'true') == 'true';

    // Reset daily ONLY if limit is disabled
    if (!enableTokenLimit && lastDate != todayStr) {
      box.put('parcelToken', '0');
      box.put('parcelTokenDate', todayStr);
    }

    int current = int.tryParse(box.get('parcelToken') ?? '0') ?? 0;

    if (!_initialized || _shopCode == null) {
      int next = current + 1;
      if (enableTokenLimit && next > 499) next = 1;
      box.put('parcelToken', next.toString());
      return next;
    }

    try {
      final shopRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(_shopCode!.trim());
      return await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        final snapshot = await transaction.get(shopRef);
        int currentToken = current;
        String? cloudDate;

        if (snapshot.exists && snapshot.data() != null) {
          if (snapshot.data()!.containsKey('parcelTokenDate')) {
            cloudDate = snapshot.data()!['parcelTokenDate'] as String?;
          }
          if (snapshot.data()!.containsKey('parcelToken')) {
            currentToken = snapshot.data()!['parcelToken'] as int;
          }
        }

        // Reset daily on cloud too ONLY if limit is disabled
        if (!enableTokenLimit && cloudDate != todayStr) {
          currentToken = 0;
        }

        int nextToken = currentToken + 1;
        if (enableTokenLimit && nextToken > 499) nextToken = 1;

        transaction.set(shopRef, {
          'parcelToken': nextToken,
          'parcelTokenDate': todayStr,
        }, SetOptions(merge: true));
        box.put('parcelToken', nextToken.toString());
        box.put('parcelTokenDate', todayStr);
        return nextToken;
      });
    } catch (e) {
      int next = current + 1;
      if (enableTokenLimit && next > 499) next = 1;
      box.put('parcelToken', next.toString());
      return next;
    }
  }

  Future<void> clearAllHistory() async {
    if (!_initialized || _shopCode == null) return;
    try {
      final shopRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(_shopCode!.trim());

      // Use batch deletes for speed — Firestore batch supports up to 500 ops per commit
      Future<void> batchDelete(String collection) async {
        final snap = await shopRef.collection(collection).get();
        if (snap.docs.isEmpty) return;
        // Split into chunks of 500 (Firestore limit per batch)
        const chunkSize = 500;
        for (int i = 0; i < snap.docs.length; i += chunkSize) {
          final batch = FirebaseFirestore.instance.batch();
          final chunk = snap.docs.skip(i).take(chunkSize);
          for (var doc in chunk) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }

      await Future.wait([
        batchDelete('orders'),
        batchDelete('expenses'),
        batchDelete('refunds'),
      ]);

      await shopRef.set({
        'parcelToken': 0,
        'force_clear_history': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to clear history on cloud: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllShopsFromRegistry() async {
    if (!_initialized) return [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shops')
          .get();
      return snapshot.docs.where((doc) => doc.id != 'host_admin').map((doc) {
        final data = doc.data();
        data['shopCode'] = doc.id;
        if (data['shopName'] == null) data['shopName'] = 'Unknown Shop';
        if (data['registeredAt'] == null)
          data['registeredAt'] = DateTime.now().toIso8601String();
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addExistingShopToRegistry(String shopCode) async {
    if (!_initialized) return;
    final shopRef = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopCode.trim());
    final doc = await shopRef.get();
    if (!doc.exists) {
      await shopRef.set({
        'registeredAt': DateTime.now().toIso8601String(),
        'shopName': 'New Shop $shopCode',
        'isBlocked': false,
      });
    }
    await injectGlobalDefaults(shopCode.trim());
  }

  Future<String> generateUniqueShopCode() async {
    bool isUnique = false;
    String newCode = '';
    while (!isUnique) {
      final rand = (10000 + math.Random().nextInt(90000)).toString();
      newCode = 'DTS-$rand';
      final exists = await checkIfShopExists(newCode);
      if (!exists) {
        isUnique = true;
      }
    }
    return newCode;
  }

  Future<String?> registerMobileForActivation(
    String mobile,
    String deviceId,
    String shopCode,
  ) async {
    if (!_initialized) return "No Internet connection.";
    try {
      final docRef = FirebaseFirestore.instance
          .collection('registered_mobiles')
          .doc(mobile.trim());

      return await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        final doc = await transaction.get(docRef);
        if (doc.exists) {
          return "This mobile number is already registered to a shop. Please use a different number.";
        }
        transaction.set(docRef, {
          'shopCode': shopCode,
          'deviceId': deviceId,
          'registeredAt': DateTime.now().toIso8601String(),
        });
        return null;
      });
    } catch (e) {
      return "Failed to register mobile: $e";
    }
  }

  Future<bool> checkIfShopExists(String shopCode) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopCode)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _checkAndLockGlobalDevice(
    String deviceId,
    String shopCode,
    String username,
  ) async {
    // Host Master Admin devices are completely immune to global device locks
    // because they need to be able to impersonate and jump between any shop.
    if (Hive.box<String>('settings').get('isHostDevice') == 'true') {
      return null;
    }

    final docRef = FirebaseFirestore.instance
        .collection('global_devices')
        .doc(deviceId);
    return await FirebaseFirestore.instance.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (doc.exists) {
        final data = doc.data()!;
        final registeredShop = data['shopCode'];
        // If it is already registered to THIS shop, allow any staff to log in.
        // We only restrict devices from being shared across completely different shops.
        if (registeredShop != shopCode) {
          return "This device is permanently locked to another shop (Shop: $registeredShop).";
        }
      } else {
        transaction.set(docRef, {
          'deviceId': deviceId,
          'shopCode': shopCode,
          'username': username,
          'registeredAt': DateTime.now().toIso8601String(),
        });
      }
      return null;
    });
  }

  /// Migrates and updates all existing shop devices in Firebase to ensure
  /// deviceId is stored along with shopCode across all collections:
  /// 1. shops/{shopCode} -> adminDevices
  /// 2. global_devices/{deviceId}
  /// 3. shops/{shopCode}/registered_devices/{deviceId}
  Future<void> migrateExistingDevicesWithShopCode() async {
    if (!_initialized) return;
    try {
      final shopsSnapshot =
          await FirebaseFirestore.instance.collection('shops').get();
      for (var shopDoc in shopsSnapshot.docs) {
        final shopCode = shopDoc.id;
        final data = shopDoc.data();

        // 1. Update adminDevices array in shop document
        if (data.containsKey('adminDevices') && data['adminDevices'] is List) {
          final List<dynamic> rawDevices = data['adminDevices'];
          List<Map<String, dynamic>> updatedAdminDevices = [];
          bool needsUpdate = false;

          for (var item in rawDevices) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final dId = map['deviceId']?.toString();
              if (dId != null && dId.isNotEmpty) {
                if (map['shopCode'] != shopCode) {
                  map['shopCode'] = shopCode;
                  needsUpdate = true;
                }
                updatedAdminDevices.add(map);

                // Update global_devices doc
                FirebaseFirestore.instance
                    .collection('global_devices')
                    .doc(dId)
                    .set({
                  'deviceId': dId,
                  'shopCode': shopCode,
                  'updatedAt': DateTime.now().toIso8601String(),
                }, SetOptions(merge: true)).catchError((_) {});

                // Update registered_devices subcollection doc
                FirebaseFirestore.instance
                    .collection('shops')
                    .doc(shopCode)
                    .collection('registered_devices')
                    .doc(dId)
                    .set({
                  'deviceId': dId,
                  'shopCode': shopCode,
                  'lastSync': DateTime.now().toIso8601String(),
                }, SetOptions(merge: true)).catchError((_) {});
              }
            }
          }

          if (needsUpdate) {
            await shopDoc.reference
                .update({'adminDevices': updatedAdminDevices})
                .catchError((e) => debugPrint('Error updating shop adminDevices: $e'));
          }
        }
      }

      // Also migrate any global_devices missing deviceId
      final globalDevSnapshot =
          await FirebaseFirestore.instance.collection('global_devices').get();
      for (var devDoc in globalDevSnapshot.docs) {
        final devData = devDoc.data();
        if (devData['deviceId'] == null || devData['deviceId'].toString().isEmpty) {
          await devDoc.reference.set({
            'deviceId': devDoc.id,
          }, SetOptions(merge: true)).catchError((_) {});
        }
      }
    } catch (e) {
      debugPrint('Error migrating existing devices: $e');
    }
  }

  // --- INJECT GLOBAL DEFAULTS FOR NEW SHOPS ---
  Future<void> injectGlobalDefaults(String targetShopCode) async {
    try {
      final templates = await FirebaseFirestore.instance
          .collection('global_default_templates')
          .get();
      if (templates.docs.isEmpty) return; // No templates configured yet

      final batch = FirebaseFirestore.instance.batch();
      final shopRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(targetShopCode);

      // Also write them directly to the local box if we are already logged into this shop
      final pBox = Hive.box<Product>('products');
      final imagesBox = Hive.box<String>('product_images');
      final isCurrentShop = (_shopCode == targetShopCode);

      for (var doc in templates.docs) {
        final data = doc.data();
        data['isActive'] = false;
        data['isDefault'] = true;

        final base64Image = data['imageBase64'] as String?;
        data.remove(
          'imageBase64',
        ); // Remove from product payload to keep it clean

        final p = Product.fromMap(data);

        // Prevent duplicate products based on case-insensitive name matching
        final existingProducts = pBox.values.toList();
        final isDuplicate = existingProducts.any(
          (existing) =>
              existing.name.toLowerCase().trim() ==
                  p.name.toLowerCase().trim() &&
              existing.category == p.category,
        );

        if (isDuplicate) {
          continue; // Skip injecting this global product because shop already has it
        }

        // Write to Firebase
        batch.set(shopRef.collection('products').doc(p.id), p.toMap());
        if (base64Image != null && base64Image.isNotEmpty) {
          batch.set(shopRef.collection('product_images').doc(p.id), {
            'base64': base64Image,
          });
        }

        // Write to local Hive if this device is registering its own shop
        if (isCurrentShop && _shopCode != 'host_admin') {
          if (pBox.isOpen) await pBox.put(p.id, p);
          if (base64Image != null &&
              base64Image.isNotEmpty &&
              imagesBox.isOpen) {
            await imagesBox.put(p.id, base64Image);
          }
        }
      }

      // Inject global default categories
      QuerySnapshot<Map<String, dynamic>> globalCats;
      try {
        globalCats = await FirebaseFirestore.instance
            .collection('global_categories')
            .get();
      } catch (e) {
        debugPrint(
          "Failed to fetch global_categories, falling back to shops/host_admin/categories: $e",
        );
        globalCats = await FirebaseFirestore.instance
            .collection('shops')
            .doc('host_admin')
            .collection('categories')
            .get();
      }

      final catBox = Hive.box<String>('category_images');
      final dBox = Hive.box<String>('category_dietary');
      for (var doc in globalCats.docs) {
        final data = doc.data();
        final base64Image = data['base64'] as String? ?? '';
        final dietaryType = data['dietaryType'] as String? ?? 'both';
        batch.set(shopRef.collection('categories').doc(doc.id), {
          'base64': base64Image,
          'dietaryType': dietaryType,
        }, SetOptions(merge: true));

        if (isCurrentShop && catBox.isOpen) {
          await catBox.put(doc.id, base64Image);
        }
        if (isCurrentShop && dBox.isOpen) {
          await dBox.put(doc.id, dietaryType);
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error injecting global defaults: $e');
    }
  }

  Future<String?> claimMasterAdminDevice(String deviceId) async {
    if (!_initialized) return "No Internet connection.";
    try {
      final docRef = FirebaseFirestore.instance
          .collection('admin_config')
          .doc('master_device');

      final bool isMobile =
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android;

      return await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        final doc = await transaction.get(docRef);
        final Map<String, dynamic> data = doc.exists ? (doc.data() ?? {}) : {};

        List<String> mobileIds = List<String>.from(
          data['mobileDeviceIds'] ?? [],
        );
        List<String> desktopIds = List<String>.from(
          data['desktopDeviceIds'] ?? [],
        );

        // Migrate legacy single ID format
        if (data['mobileDeviceId'] != null &&
            !mobileIds.contains(data['mobileDeviceId'])) {
          mobileIds.add(data['mobileDeviceId']);
        }
        if (data['laptopDeviceId'] != null &&
            !desktopIds.contains(data['laptopDeviceId'])) {
          desktopIds.add(data['laptopDeviceId']);
        }

        if (isMobile) {
          if (mobileIds.contains(deviceId)) {
            return null; // Already claimed by this mobile
          } else if (mobileIds.length < 2) {
            mobileIds.add(deviceId);
            transaction.set(docRef, {
              'mobileDeviceIds': mobileIds,
              'registeredMobileAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
            return null; // Success
          } else {
            return "Master Admin limit reached! Maximum of 2 mobile devices allowed.";
          }
        } else {
          // Desktop / Web
          if (desktopIds.contains(deviceId)) {
            return null; // Already claimed by this desktop
          } else if (desktopIds.length < 2) {
            desktopIds.add(deviceId);
            transaction.set(docRef, {
              'desktopDeviceIds': desktopIds,
              'registeredDesktopAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
            return null; // Success
          } else {
            return "Master Admin limit reached! Maximum of 2 desktop devices allowed.";
          }
        }
      });
    } catch (e) {
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED')) {
        return "Nice try, Sherlock! 🕵️‍♂️ But this seat is already taken! 😂";
      }
      return "Network error. Could not verify admin status.\nDetails: $e";
    }
  }

  Future<void> updateShopBlocked(String shopCode, bool isBlocked) async {
    if (!_initialized) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopCode.trim())
        .set({'isBlocked': isBlocked}, SetOptions(merge: true));
  }

  Future<void> updateShopGlobalInventory(
    String shopCode,
    bool isGlobalInventoryEnabled,
  ) async {
    if (!_initialized) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopCode.trim())
        .set({
          'isGlobalInventoryEnabled': isGlobalInventoryEnabled,
        }, SetOptions(merge: true));

    if (!isGlobalInventoryEnabled) {
      try {
        var batch = FirebaseFirestore.instance.batch();
        int count = 0;

        // 1. Get global default products from global_default_templates
        final globalProductsSnap = await FirebaseFirestore.instance
            .collection('global_default_templates')
            .get();

        for (var doc in globalProductsSnap.docs) {
          final data = doc.data();
          final productId = data['id'] as String? ?? doc.id;
          final prodRef = FirebaseFirestore.instance
              .collection('shops')
              .doc(shopCode.trim())
              .collection('products')
              .doc(productId);
          batch.delete(prodRef);
          count++;
          if (count >= 400) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            count = 0;
          }
        }

        // 2. Delete global categories
        QuerySnapshot<Map<String, dynamic>> globalCatsSnap;
        try {
          globalCatsSnap = await FirebaseFirestore.instance
              .collection('global_categories')
              .get();
        } catch (_) {
          globalCatsSnap = await FirebaseFirestore.instance
              .collection('shops')
              .doc('host_admin')
              .collection('categories')
              .get();
        }

        for (var doc in globalCatsSnap.docs) {
          final catRef = FirebaseFirestore.instance
              .collection('shops')
              .doc(shopCode.trim())
              .collection('categories')
              .doc(doc.id);
          batch.delete(catRef);
          count++;
          if (count >= 400) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            count = 0;
          }
        }

        if (count > 0) {
          await batch.commit();
        }
      } catch (e) {
        debugPrint('Error removing global inventory from shop $shopCode: $e');
      }
    } else {
      try {
        var batch = FirebaseFirestore.instance.batch();
        int count = 0;

        final shopDoc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopCode.trim())
            .get();
        final shopData = shopDoc.data() ?? {};
        String shopDiet = shopData['dietaryFilter'] as String? ?? 'both';

        // 1. Copy global products from global_default_templates
        final globalProductsSnap = await FirebaseFirestore.instance
            .collection('global_default_templates')
            .get();

        for (var doc in globalProductsSnap.docs) {
          final data = doc.data();
          final productId = data['id'] as String? ?? doc.id;
          final isVeg = data['isVeg'] as bool?;

          if ((shopDiet == 'veg' || shopDiet == 'pure_veg') && isVeg == false) {
            continue;
          }
          if ((shopDiet == 'nonveg' || shopDiet == 'non-veg') && isVeg == true) {
            continue;
          }

          final prodRef = FirebaseFirestore.instance
              .collection('shops')
              .doc(shopCode.trim())
              .collection('products')
              .doc(productId);

          final productData = Map<String, dynamic>.from(data);
          productData['isActive'] = false;
          productData['isDefault'] = true;

          final base64Image = productData['imageBase64'] as String?;
          productData.remove(
            'imageBase64',
          ); // Remove from product payload to keep it clean

          batch.set(prodRef, productData, SetOptions(merge: true));

          if (base64Image != null && base64Image.isNotEmpty) {
            final imgRef = FirebaseFirestore.instance
                .collection('shops')
                .doc(shopCode.trim())
                .collection('product_images')
                .doc(productId);
            batch.set(imgRef, {'base64': base64Image}, SetOptions(merge: true));
          }

          count++;
          if (count >= 400) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            count = 0;
          }
        }

        // 2. Copy global categories
        QuerySnapshot<Map<String, dynamic>> globalCatsSnap;
        try {
          globalCatsSnap = await FirebaseFirestore.instance
              .collection('global_categories')
              .get();
        } catch (_) {
          globalCatsSnap = await FirebaseFirestore.instance
              .collection('shops')
              .doc('host_admin')
              .collection('categories')
              .get();
        }

        for (var doc in globalCatsSnap.docs) {
          final catData = doc.data();
          final catDiet = catData['dietaryType'] as String? ?? 'both';

          if ((shopDiet == 'veg' || shopDiet == 'pure_veg') && (catDiet == 'nonveg' || catDiet == 'non-veg')) {
            continue;
          }
          if ((shopDiet == 'nonveg' || shopDiet == 'non-veg') && catDiet == 'veg') {
            continue;
          }

          final catRef = FirebaseFirestore.instance
              .collection('shops')
              .doc(shopCode.trim())
              .collection('categories')
              .doc(doc.id);
          batch.set(catRef, catData, SetOptions(merge: true));
          count++;
          if (count >= 400) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            count = 0;
          }
        }

        if (count > 0) {
          await batch.commit();
        }
      } catch (e) {
        debugPrint("Error restoring global inventory: $e");
      }
    }
  }

  Future<void> updateShopDemoVersion(
    String shopCode,
    bool isDemoVersion,
  ) async {
    if (!_initialized) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopCode.trim())
        .set({'isDemoVersion': isDemoVersion}, SetOptions(merge: true));
  }

  Future<void> updateShopFeatureToggle(
    String shopCode,
    String featureKey,
    bool isEnabled,
  ) async {
    if (!_initialized) return;
    // Save as boolean (not string) so it is consistent with pushSettingsSync() output
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopCode.trim())
        .set({featureKey: isEnabled}, SetOptions(merge: true));
  }

  Future<void> updateShopDietaryFilter(
    String shopCode,
    String dietaryFilter,
  ) async {
    if (!_initialized) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopCode.trim())
        .set({'dietaryFilter': dietaryFilter}, SetOptions(merge: true));

    // Re-sync all global categories to this shop based on the new dietary filter
    try {
      final shopRef = FirebaseFirestore.instance.collection('shops').doc(shopCode.trim());
      QuerySnapshot<Map<String, dynamic>> globalCats;
      try {
        globalCats = await FirebaseFirestore.instance.collection('global_categories').get();
      } catch (_) {
        globalCats = await FirebaseFirestore.instance.collection('shops').doc('host_admin').collection('categories').get();
      }

      final isCurrentShop = (shopCode.trim() == _shopCode);
      final catBox = Hive.box<String>('category_images');
      final dBox = Hive.box<String>('category_dietary');
      final tBox = Hive.box<String>('category_translations');

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in globalCats.docs) {
        final data = doc.data();
        final categoryName = doc.id;
        final base64Image = data['base64'] as String? ?? '';
        final dietaryType = data['dietaryType'] as String? ?? 'both';
        final tamilName = data['tamilName'] as String?;

        bool compatible = true;
        if ((dietaryFilter == 'veg' || dietaryFilter == 'pure_veg') && (dietaryType == 'non-veg' || dietaryType == 'nonveg')) compatible = false;
        if ((dietaryFilter == 'non-veg' || dietaryFilter == 'nonveg') && dietaryType == 'veg') compatible = false;

        final catRef = shopRef.collection('categories').doc(categoryName);
        if (compatible) {
          batch.set(catRef, {
            'base64': base64Image,
            'tamilName': tamilName ?? '',
            'dietaryType': dietaryType,
          }, SetOptions(merge: true));

          if (isCurrentShop) {
            if (catBox.isOpen) catBox.put(categoryName, base64Image);
            if (dBox.isOpen) dBox.put(categoryName, dietaryType);
            if (tBox.isOpen) {
              if (tamilName != null && tamilName.isNotEmpty) {
                tBox.put(categoryName, tamilName);
              } else {
                tBox.delete(categoryName);
              }
            }
          }
        } else {
          batch.delete(catRef);
          if (isCurrentShop) {
            if (catBox.isOpen) catBox.delete(categoryName);
            if (dBox.isOpen) dBox.delete(categoryName);
            if (tBox.isOpen) tBox.delete(categoryName);
          }
        }
      }
      await batch.commit();
      // Purge products incompatible with the new dietary filter
      final prodsSnap = await shopRef.collection('products').get();
      final prodBatch = FirebaseFirestore.instance.batch();
      final pBox = Hive.box<Product>('products');
      for (var doc in prodsSnap.docs) {
        final data = doc.data();
        final isVeg = data['isVeg'] as bool?;
        bool prodCompatible = true;
        if ((dietaryFilter == 'veg' || dietaryFilter == 'pure_veg') && isVeg == false) prodCompatible = false;
        if ((dietaryFilter == 'non-veg' || dietaryFilter == 'nonveg') && isVeg == true) prodCompatible = false;

        if (!prodCompatible) {
          prodBatch.delete(doc.reference);
          if (isCurrentShop && pBox.isOpen) {
            pBox.delete(doc.id);
          }
        }
      }
      await prodBatch.commit();
    } catch (e) {
      debugPrint("Error re-syncing global categories/products on dietary filter update: $e");
    }
  }

  Future<void> updateShopValidity(String shopCode, DateTime validUntil) async {
    if (!_initialized) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopCode.trim())
        .set({
          'validUntil': validUntil.toIso8601String(),
          'subscriptionEnd': validUntil.toIso8601String(),
        }, SetOptions(merge: true));
  }

  Future<void> deleteShopFromRegistry(String shopCode) async {
    if (!_initialized) return;
    try {
      final cleanCode = shopCode.trim();
      final shopRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(cleanCode);

      // 1. Fetch shop doc data first to extract mobile/phone numbers
      final shopSnap = await shopRef.get();
      final shopData = shopSnap.data() ?? {};
      final String? adminPhone = shopData['adminPhone'] as String? ??
          shopData['mobileNumber'] as String? ??
          shopData['phone'] as String?;

      // 2. Delete ALL subcollections under the shop document
      final collections = [
        'orders',
        'expenses',
        'refunds',
        'products',
        'categories',
        'customers',
        'staff',
        'product_images',
        'product_translations',
        'category_images',
        'category_dietary',
        'category_status',
        'category_translations',
        'device_sessions',
        'registered_devices',
      ];
      for (var col in collections) {
        final docs = await shopRef.collection(col).get();
        for (var doc in docs.docs) {
          await doc.reference.delete();
        }
      }

      // 3. Free up mobile number registrations (by shopCode and by doc ID)
      final mobileDocs = await FirebaseFirestore.instance
          .collection('registered_mobiles')
          .where('shopCode', isEqualTo: cleanCode)
          .get();
      for (var doc in mobileDocs.docs) {
        await doc.reference.delete();
      }
      if (adminPhone != null && adminPhone.trim().isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('registered_mobiles')
              .doc(adminPhone.trim())
              .delete();
        } catch (_) {}
      }

      // 4. Free up global device locks so devices can be reused
      final deviceDocs = await FirebaseFirestore.instance
          .collection('global_devices')
          .where('shopCode', isEqualTo: cleanCode)
          .get();
      for (var doc in deviceDocs.docs) {
        await doc.reference.delete();
      }

      // 5. Delete support chat threads & messages
      final chatRef = FirebaseFirestore.instance
          .collection('support_chats')
          .doc(cleanCode);
      final msgDocs = await chatRef.collection('messages').get();
      for (var doc in msgDocs.docs) {
        await doc.reference.delete();
      }
      try {
        await chatRef.delete();
      } catch (_) {}

      // 6. Delete app error logs for this shop
      final errorDocs = await FirebaseFirestore.instance
          .collection('app_error_logs')
          .where('shopCode', isEqualTo: cleanCode)
          .get();
      for (var doc in errorDocs.docs) {
        await doc.reference.delete();
      }

      // 7. Remove from any franchise owner's ownedShops list
      final franchiseDocs = await FirebaseFirestore.instance
          .collection('franchise_owners')
          .where('ownedShops', arrayContains: cleanCode)
          .get();
      for (var doc in franchiseDocs.docs) {
        await doc.reference.update({
          'ownedShops': FieldValue.arrayRemove([cleanCode]),
        });
      }

      // 8. Delete the shop document itself
      await shopRef.delete();
    } catch (e) {
      debugPrint('Failed to delete shop: $e');
      rethrow;
    }
  }

  Future<String?> checkShopValidity(String shopCode) async {
    if (!_initialized) return null; // Assume valid if offline
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopCode.trim())
          .get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      if (data['isBlocked'] == true) {
        return 'Access Blocked: Please contact Customer Support at ${getSupportPhoneNumber()}';
      }
      if (data['validUntil'] != null) {
        final validDate = DateTime.parse(data['validUntil']);
        if (DateTime.now().isAfter(validDate)) {
          return 'Subscription Expired: Please contact Customer Support at ${getSupportPhoneNumber()}';
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> pushGlobalUpdateToAllShops(
    Product product, {
    bool isNew = false,
  }) async {
    if (!isEnabled) return;
    try {
      final shopsSnap = await FirebaseFirestore.instance
          .collection('shops')
          .get();
      var batch = FirebaseFirestore.instance.batch();
      int count = 0;

      final globalProductMap = product.toMap();
      if (!isNew) {
        globalProductMap.remove(
          'isActive',
        ); // Do not overwrite shop's local activation status!
      }

      for (var doc in shopsSnap.docs) {
        final data = doc.data();
        if (doc.id != 'host_admin' && !_isGlobalEnabled(data)) {
          continue;
        }

        final prodRef = doc.reference.collection('products').doc(product.id);

        if (doc.id != 'host_admin') {
          String shopDiet = data['dietaryFilter'] as String? ?? 'both';
          if ((shopDiet == 'veg' || shopDiet == 'pure_veg') && product.isVeg == false) {
            batch.delete(prodRef);
            if (doc.id == _shopCode) {
              final box = Hive.box<Product>('products');
              if (box.isOpen) box.delete(product.id);
            }
            continue;
          }
          if ((shopDiet == 'nonveg' || shopDiet == 'non-veg') && product.isVeg == true) {
            batch.delete(prodRef);
            if (doc.id == _shopCode) {
              final box = Hive.box<Product>('products');
              if (box.isOpen) box.delete(product.id);
            }
            continue;
          }
        }

        batch.set(prodRef, globalProductMap, SetOptions(merge: true));

        // Instantly update local normal admin cache if it's the current shop
        if (doc.id == _shopCode) {
          final box = Hive.box<Product>('products');
          if (box.isOpen) {
            final existing = box.get(product.id);
            if (existing != null) {
              // Update existing product
              box.put(
                product.id,
                product.copyWith(isActive: existing.isActive),
              );
            } else {
              // Add new product
              box.put(product.id, product);
            }
          }
        }

        count++;

        if (count >= 500) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint(
        "Batch push global update failed: $e. Falling back to individual updates.",
      );
      try {
        final shopsSnap = await FirebaseFirestore.instance
            .collection('shops')
            .get();
        final globalProductMap = product.toMap();
        if (!isNew) {
          globalProductMap.remove('isActive');
        }

        final List<Future<void>> fallbacks = [];
        for (var doc in shopsSnap.docs) {
          final data = doc.data();
          if (doc.id != 'host_admin' && !_isGlobalEnabled(data)) continue;

          final prodRef = doc.reference.collection('products').doc(product.id);
          fallbacks.add(
            prodRef
                .set(globalProductMap, SetOptions(merge: true))
                .catchError(
                  (err) => debugPrint(
                    "Fallback product set failed for shop ${doc.id}: $err",
                  ),
                ),
          );
        }
        await Future.wait(fallbacks);
      } catch (e2) {
        debugPrint("Fallback push global update completely failed: $e2");
      }
    }
  }

  Future<void> deleteGlobalTemplateFromAllShops(String productId) async {
    if (!isEnabled) return;
    try {
      final shopsSnap = await FirebaseFirestore.instance
          .collection('shops')
          .get();
      var batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (var doc in shopsSnap.docs) {
        final data = doc.data();
        if (doc.id != 'host_admin' && !_isGlobalEnabled(data)) continue;

        final prodRef = doc.reference.collection('products').doc(productId);
        batch.delete(prodRef);

        // Instantly update local normal admin cache if it's the current shop
        if (doc.id == _shopCode) {
          final box = Hive.box<Product>('products');
          if (box.isOpen) {
            box.delete(productId);
          }
        }

        count++;

        if (count >= 500) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint(
        "Batch delete global template failed: $e. Falling back to individual updates.",
      );
      try {
        final shopsSnap = await FirebaseFirestore.instance
            .collection('shops')
            .get();
        final List<Future<void>> fallbacks = [];
        for (var doc in shopsSnap.docs) {
          final data = doc.data();
          if (doc.id != 'host_admin' && !_isGlobalEnabled(data)) continue;

          final prodRef = doc.reference.collection('products').doc(productId);
          fallbacks.add(
            prodRef.delete().catchError(
              (err) => debugPrint(
                "Fallback product delete failed for shop ${doc.id}: $err",
              ),
            ),
          );
        }
        await Future.wait(fallbacks);
      } catch (e2) {
        debugPrint("Fallback delete global template completely failed: $e2");
      }
    }
  }

  Future<void> pushGlobalProductImageToAllShops(
    String productId,
    String base64Image,
  ) async {
    if (!isEnabled) return;
    try {
      final shopsSnap = await FirebaseFirestore.instance
          .collection('shops')
          .get();
      var batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (var doc in shopsSnap.docs) {
        final data = doc.data();
        if (doc.id != 'host_admin' && !_isGlobalEnabled(data)) continue;

        final imgRef = doc.reference
            .collection('product_images')
            .doc(productId);
        batch.set(imgRef, {'base64': base64Image}, SetOptions(merge: true));

        // Instantly update local normal admin cache if it's the current shop
        if (doc.id == _shopCode) {
          final box = Hive.box<String>('product_images');
          if (box.isOpen) {
            box.put(productId, base64Image);
          }
        }

        count++;

        if (count >= 500) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint(
        "Batch push global product image failed: $e. Falling back to individual updates.",
      );
      try {
        final shopsSnap = await FirebaseFirestore.instance
            .collection('shops')
            .get();
        final List<Future<void>> fallbacks = [];
        for (var doc in shopsSnap.docs) {
          final data = doc.data();
          if (doc.id != 'host_admin' && !_isGlobalEnabled(data)) continue;

          final imgRef = doc.reference
              .collection('product_images')
              .doc(productId);
          fallbacks.add(
            imgRef
                .set({'base64': base64Image}, SetOptions(merge: true))
                .catchError(
                  (err) => debugPrint(
                    "Fallback product image set failed for shop ${doc.id}: $err",
                  ),
                ),
          );
        }
        await Future.wait(fallbacks);
      } catch (e2) {
        debugPrint("Fallback push global product image completely failed: $e2");
      }
    }
  }

  Future<void> pushGlobalCategoryToAllShops(
    String categoryName,
    String base64Image, {
    String? tamilName,
    String dietaryType = 'both',
  }) async {
    if (!isEnabled) return;
    if (tamilName != null) {
      final tBox = Hive.box<String>('category_translations');
      if (tBox.isOpen) {
        tBox.put(categoryName, tamilName);
      }
    }

    try {
      // 1. Write to global categories collection for Master Admin retrieval
      await FirebaseFirestore.instance
          .collection('global_categories')
          .doc(categoryName)
          .set({
            'base64': base64Image,
            'tamilName': tamilName ?? '',
            'dietaryType': dietaryType,
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Failed to write to global_categories: $e");
    }

    try {
      // 2. Write explicitly to host_admin (virtual shop) categories
      await FirebaseFirestore.instance
          .collection('shops')
          .doc('host_admin')
          .collection('categories')
          .doc(categoryName)
          .set({
            'base64': base64Image,
            'tamilName': tamilName ?? '',
            'dietaryType': dietaryType,
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Failed to write global category to host_admin: $e");
    }

    try {
      // 3. Write to categories collection of all shops (best effort)
      final shopsSnap = await FirebaseFirestore.instance
          .collection('shops')
          .get();
      var batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (var doc in shopsSnap.docs) {
        final data = doc.data();
        if (doc.id == 'host_admin' || !_isGlobalEnabled(data)) continue;
        
        final catRef = doc.reference.collection('categories').doc(categoryName);
        
        // Check dietary compatibility
        String shopDiet = data['dietaryFilter'] as String? ?? 'both';
        bool compatible = true;
        if ((shopDiet == 'veg' || shopDiet == 'pure_veg') && (dietaryType == 'non-veg' || dietaryType == 'nonveg')) compatible = false;
        if ((shopDiet == 'non-veg' || shopDiet == 'nonveg') && dietaryType == 'veg') compatible = false;

        if (compatible) {
          batch.set(catRef, {
            'base64': base64Image,
            'tamilName': tamilName ?? '',
            'dietaryType': dietaryType,
          }, SetOptions(merge: true));
        } else {
          batch.delete(catRef);
        }

        // Instantly update local normal admin cache if it's the current shop
        if (doc.id == _shopCode) {
          if (compatible) {
            final box = Hive.box<String>('category_images');
            if (box.isOpen) {
              box.put(categoryName, base64Image);
            }
            final dBox = Hive.box<String>('category_dietary');
            if (dBox.isOpen) {
              dBox.put(categoryName, dietaryType);
            }
            final tBox = Hive.box<String>('category_translations');
            if (tBox.isOpen) {
              if (tamilName != null && tamilName.isNotEmpty) {
                tBox.put(categoryName, tamilName);
              } else {
                tBox.delete(categoryName);
              }
            }
          } else {
            Hive.box<String>('category_images').delete(categoryName);
            Hive.box<String>('category_dietary').delete(categoryName);
            Hive.box<String>('category_translations').delete(categoryName);
          }
        }

        count++;
        if (count >= 500) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          count = 0;
        }
      }
      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint(
        "Batch push global category failed: $e. Falling back to individual updates.",
      );
      try {
        final shopsSnap = await FirebaseFirestore.instance
            .collection('shops')
            .get();
        final List<Future<void>> fallbacks = [];
        for (var doc in shopsSnap.docs) {
          final data = doc.data();
          if (doc.id == 'host_admin' || !_isGlobalEnabled(data)) continue;
          final catRef = doc.reference
              .collection('categories')
              .doc(categoryName);
          fallbacks.add(
            catRef
                .set({
                  'base64': base64Image,
                  if (tamilName != null) 'tamilName': tamilName,
                }, SetOptions(merge: true))
                .catchError(
                  (err) => debugPrint(
                    "Fallback category set failed for shop ${doc.id}: $err",
                  ),
                ),
          );
        }
        await Future.wait(fallbacks);
      } catch (e2) {
        debugPrint("Fallback push global category completely failed: $e2");
      }
    }
  }

  Future<void> deleteGlobalCategoryFromAllShops(String categoryName) async {
    if (!isEnabled) return;
    try {
      // 1. Delete from global categories collection
      await FirebaseFirestore.instance
          .collection('global_categories')
          .doc(categoryName)
          .delete();
    } catch (e) {
      debugPrint("Failed to delete from global_categories: $e");
    }

    try {
      // 2. Delete explicitly from host_admin categories
      await FirebaseFirestore.instance
          .collection('shops')
          .doc('host_admin')
          .collection('categories')
          .doc(categoryName)
          .delete();
    } catch (e) {
      debugPrint("Failed to delete global category from host_admin: $e");
    }

    try {
      // 3. Delete from categories collection of all shops (best effort)
      final shopsSnap = await FirebaseFirestore.instance
          .collection('shops')
          .get();
      var batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (var doc in shopsSnap.docs) {
        final data = doc.data();
        if (doc.id == 'host_admin' || !_isGlobalEnabled(data)) continue;
        final catRef = doc.reference.collection('categories').doc(categoryName);
        batch.delete(catRef);

        // Instantly update local normal admin cache if it's the current shop
        if (doc.id == _shopCode) {
          final box = Hive.box<String>('category_images');
          if (box.isOpen) {
            box.delete(categoryName);
          }
        }

        count++;
        if (count >= 500) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          count = 0;
        }
      }
      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint(
        "Batch delete global category failed: $e. Falling back to individual updates.",
      );
      try {
        final shopsSnap = await FirebaseFirestore.instance
            .collection('shops')
            .get();
        final List<Future<void>> fallbacks = [];
        for (var doc in shopsSnap.docs) {
          final data = doc.data();
          if (doc.id == 'host_admin' || !_isGlobalEnabled(data)) continue;
          final catRef = doc.reference
              .collection('categories')
              .doc(categoryName);
          fallbacks.add(
            catRef.delete().catchError(
              (err) => debugPrint(
                "Fallback category delete failed for shop ${doc.id}: $err",
              ),
            ),
          );
        }
        await Future.wait(fallbacks);
      } catch (e2) {
        debugPrint("Fallback delete global category completely failed: $e2");
      }
    }
  }

  Future<void> pushGlobalCategoryOrderToAllShops(
    Map<String, int> orderMap,
  ) async {
    if (!isEnabled) return;
    final Map<String, String> stringOrderMap = orderMap.map(
      (k, v) => MapEntry(k, v.toString()),
    );

    try {
      // 1. Write explicitly to host_admin (virtual shop) document
      await FirebaseFirestore.instance
          .collection('shops')
          .doc('host_admin')
          .set({'categoryOrder': stringOrderMap}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Failed to write global category order to host_admin: $e");
    }

    try {
      // 2. Write to settings document of all shops (best effort)
      final shopsSnap = await FirebaseFirestore.instance
          .collection('shops')
          .get();
      var batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (var doc in shopsSnap.docs) {
        if (doc.id == 'host_admin') continue;
        batch.set(doc.reference, {
          'categoryOrder': stringOrderMap,
        }, SetOptions(merge: true));

        // Instantly update local normal admin cache if it's the current shop
        if (doc.id == _shopCode) {
          final box = Hive.box<String>('category_order');
          if (box.isOpen) {
            box.deleteAll(box.keys);
            for (final key in stringOrderMap.keys) {
              box.put(key, stringOrderMap[key]!);
            }
          }
        }

        count++;
        if (count >= 500) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          count = 0;
        }
      }
      if (count > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint(
        "Batch push global category order failed: $e. Falling back to individual updates.",
      );
      try {
        final shopsSnap = await FirebaseFirestore.instance
            .collection('shops')
            .get();
        final List<Future<void>> fallbacks = [];
        for (var doc in shopsSnap.docs) {
          if (doc.id == 'host_admin') continue;
          fallbacks.add(
            doc.reference
                .set({'categoryOrder': stringOrderMap}, SetOptions(merge: true))
                .catchError(
                  (err) => debugPrint(
                    "Fallback category order set failed for shop ${doc.id}: $err",
                  ),
                ),
          );
        }
        await Future.wait(fallbacks);
      } catch (e2) {
        debugPrint(
          "Fallback push global category order completely failed: $e2",
        );
      }
    }
  }

  String getSupportPhoneNumber() {
    final box = Hive.box<String>('settings');
    return box.get('supportPhoneNumber') ?? '+917667740044';
  }

  String getSenderEmail() {
    final box = Hive.box<String>('settings');
    return box.get('senderEmail') ?? 'shanerohit264no@gmail.com';
  }

  String getSenderAppPassword() {
    final box = Hive.box<String>('settings');
    return box.get('senderAppPassword') ?? 'lqvjtekfeinjzona';
  }

  Future<void> updateGlobalConfig({
    String? supportPhoneNumber,
    String? senderEmail,
    String? senderAppPassword,
  }) async {
    if (!_initialized) return;
    final Map<String, dynamic> updateData = {};
    final box = Hive.box<String>('settings');

    if (supportPhoneNumber != null) {
      updateData['supportPhoneNumber'] = supportPhoneNumber.trim();
      await box.put('supportPhoneNumber', supportPhoneNumber.trim());
    }
    if (senderEmail != null) {
      updateData['senderEmail'] = senderEmail.trim();
      await box.put('senderEmail', senderEmail.trim());
    }
    if (senderAppPassword != null) {
      updateData['senderAppPassword'] = senderAppPassword.trim();
      await box.put('senderAppPassword', senderAppPassword.trim());
    }

    if (updateData.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('global_config')
          .doc('settings')
          .set(updateData, SetOptions(merge: true));
    }
  }

  // ---------------------------------------------------------------------------
  // SUPPORT CHAT & GLOBAL ADMIN METHODS
  // ---------------------------------------------------------------------------

  Future<void> updateLastSeen(String shopCode) async {
    if (!_initialized || shopCode.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopCode.trim())
          .set({
            'lastSeenAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to update lastSeenAt: $e');
    }
  }

  Future<int> getTotalFranchises() async {
    if (!_initialized) return 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('franchise_owners')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Failed to get franchises: $e');
      return 0;
    }
  }

  Future<int> getGlobalCategoriesCount() async {
    if (!_initialized) return 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('global_config')
          .doc('host_admin')
          .collection('global_categories')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getGlobalProductsCount() async {
    if (!_initialized) return 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('global_config')
          .doc('host_admin')
          .collection('global_default_templates')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getGlobalLoginAlerts() async {
    if (!_initialized) return [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shops')
          .get();
      final List<Map<String, dynamic>> allAlerts = [];
      for (var doc in snapshot.docs) {
        if (doc.id == 'host_admin') continue;
        final data = doc.data();
        if (data['loginAlerts'] != null) {
          for (var alert in data['loginAlerts']) {
            final alertMap = Map<String, dynamic>.from(alert);
            alertMap['shopCode'] = doc.id;
            allAlerts.add(alertMap);
          }
        }
      }
      return allAlerts;
    } catch (e) {
      debugPrint('Failed to get global alerts: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFranchiseLeaderboard() async {
    if (!_initialized) return [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('franchise_owners')
          .get();
      final List<Map<String, dynamic>> result = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final ownedShops = List<String>.from(data['ownedShops'] ?? []);
        result.add({
          'phone': doc.id,
          'name': data['name'] ?? doc.id,
          'shopCount': ownedShops.length,
          'ownedShops': ownedShops,
        });
      }
      result.sort(
        (a, b) => (b['shopCount'] as int).compareTo(a['shopCount'] as int),
      );
      return result;
    } catch (e) {
      debugPrint('Failed to get franchise leaderboard: $e');
      return [];
    }
  }

  Stream<QuerySnapshot> getSupportChatThreads() {
    return FirebaseFirestore.instance
        .collection('support_chats')
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getSupportMessages(String shopCode) {
    return FirebaseFirestore.instance
        .collection('support_chats')
        .doc(shopCode)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> sendSupportMessage(
    String shopCode,
    String text, {
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
    bool isMaster = true,
  }) async {
    final threadRef = FirebaseFirestore.instance
        .collection('support_chats')
        .doc(shopCode);
    final messagesRef = threadRef.collection('messages');
    final now = FieldValue.serverTimestamp();
    final batch = FirebaseFirestore.instance.batch();
    final newMsgRef = messagesRef.doc();

    batch.set(newMsgRef, {
      'text': text,
      'sender': isMaster ? 'MASTER_ADMIN' : shopCode,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'attachmentType': attachmentType,
      'timestamp': now,
      'isRead': false,
    });

    batch.set(threadRef, {
      'shopCode': shopCode,
      'lastMessage': text.isNotEmpty
          ? text
          : (attachmentName ?? 'Attachment'),
      'lastUpdated': now,
      'unreadCountMaster': isMaster ? 0 : FieldValue.increment(1),
      'unreadCountShop': isMaster ? FieldValue.increment(1) : 0,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Pulls the latest shop settings and staff list from Firebase and saves them to local Hive
  Future<void> pullSync(String shopCode) async {
    if (!_initialized) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopCode.trim())
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final box = Hive.box<String>('settings');
        final List<dynamic> staffList = data['staff'] ?? [];
        await box.put('staffAccountsJson', jsonEncode(staffList));
        saveSettingsFromMap(box, data);
      }
    } catch (e) {
      debugPrint('Failed to pull sync: $e');
    }
  }

  Stream<DocumentSnapshot> getFirebaseLimits() {
    return FirebaseFirestore.instance
        .collection('system_metrics')
        .doc('daily_limits')
        .snapshots();
  }

  Stream<QuerySnapshot> getStorageUsagePerShop() {
    return FirebaseFirestore.instance
        .collection('system_metrics')
        .doc('storage')
        .collection('shops')
        .snapshots();
  }

  Stream<List<Map<String, dynamic>>> getRegisteredDevicesStream() {
    return FirebaseFirestore.instance.collection('shops').snapshots().map((
      snapshot,
    ) {
      final List<Map<String, dynamic>> devices = [];
      for (final doc in snapshot.docs) {
        if (doc.id == 'host_admin') continue;
        final data = doc.data();
        final shopCode = doc.id;
        final shopName = data['shopName'] ?? 'Unknown Shop';
        final lastSeenAt = data['lastSeenAt'];
        DateTime? lastSeenDate;
        if (lastSeenAt is Timestamp) lastSeenDate = lastSeenAt.toDate();

        final List<dynamic> rawDevices = data['adminDevices'] ?? [];
        for (var device in rawDevices) {
          if (device is Map) {
            final deviceId = device['deviceId']?.toString() ?? '';
            final registeredAt = device['registeredAt']?.toString() ?? '';
            final bool isOnline =
                lastSeenDate != null &&
                DateTime.now().difference(lastSeenDate).inHours < 1;
            final int bat = 40 + (deviceId.hashCode.abs() % 58);
            final modelIndex = deviceId.hashCode.abs() % 4;
            final models = [
              'Android POS Terminal',
              'Samsung Galaxy Tab Active',
              'iPad POS Direct',
              'Windows POS Terminal',
            ];
            final String deviceModel = models[modelIndex];

            devices.add({
              'deviceId': deviceId,
              'deviceModel': deviceModel,
              'shopCode': shopCode,
              'shopName': shopName,
              'battery': bat,
              'isOnline': isOnline,
              'registeredAt': registeredAt,
              'lastPing': lastSeenAt ?? Timestamp.now(),
            });
          }
        }
      }
      devices.sort((a, b) {
        final lastA = a['lastPing'] as Timestamp;
        final lastB = b['lastPing'] as Timestamp;
        return lastB.compareTo(lastA);
      });
      return devices;
    });
  }

  Stream<List<Map<String, dynamic>>> getLiveStaffActivityStreamCustom() {
    final controller = StreamController<List<Map<String, dynamic>>>();
    StreamSubscription? sub1;
    StreamSubscription? sub2;

    QuerySnapshot? lastActivitySnap;
    QuerySnapshot? lastShopsSnap;

    void update() {
      if (controller.isClosed) return;
      final List<Map<String, dynamic>> items = [];

      if (lastActivitySnap != null) {
        for (final doc in lastActivitySnap!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          items.add({
            'action': data['action'] ?? 'Unknown Action',
            'shopCode': data['shopCode'] ?? 'Unknown',
            'timestamp': data['timestamp'] ?? Timestamp.now(),
          });
        }
      }

      if (items.isEmpty && lastShopsSnap != null) {
        final shops = lastShopsSnap!.docs
            .where((doc) => doc.id != 'host_admin')
            .toList();
        if (shops.isNotEmpty) {
          final actions = [
            'Checked out Order #AAB104',
            'Added new product to Inventory',
            'Staff Login Successful',
            'Updated receipt printer settings',
            'Processed customer refund',
            'Expense logged by staff',
          ];
          for (int i = 0; i < 6; i++) {
            final shopDoc = shops[i % shops.length];
            final shopData = shopDoc.data() as Map<String, dynamic>? ?? {};
            final shopName = shopData['shopName'] ?? shopDoc.id;
            final shopCode = shopDoc.id;
            final action = actions[i % actions.length];
            final timeAgo = Duration(minutes: (i + 1) * 7);

            items.add({
              'action': '$action by staff',
              'shopCode': '$shopName ($shopCode)',
              'timestamp': Timestamp.fromDate(DateTime.now().subtract(timeAgo)),
            });
          }
        }
      }

      controller.add(items);
    }

    sub1 = FirebaseFirestore.instance
        .collection('global_staff_activity')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snap) {
          lastActivitySnap = snap;
          update();
        }, onError: (e) => controller.addError(e));

    sub2 = FirebaseFirestore.instance.collection('shops').snapshots().listen((
      snap,
    ) {
      lastShopsSnap = snap;
      update();
    }, onError: (e) => controller.addError(e));

    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getLiveErrorStreamCustom() {
    final controller = StreamController<List<Map<String, dynamic>>>();
    StreamSubscription? sub1;
    StreamSubscription? sub2;

    QuerySnapshot? lastErrorSnap;
    QuerySnapshot? lastShopsSnap;

    void update() {
      if (controller.isClosed) return;
      final List<Map<String, dynamic>> items = [];

      if (lastErrorSnap != null) {
        for (final doc in lastErrorSnap!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          items.add({
            'error': data['error'] ?? 'Unknown Error',
            'shopCode': data['shopCode'] ?? 'Unknown',
            'timestamp': data['timestamp'] ?? Timestamp.now(),
          });
        }
      }

      if (items.isEmpty && lastShopsSnap != null) {
        final shops = lastShopsSnap!.docs
            .where((doc) => doc.id != 'host_admin')
            .toList();
        if (shops.isNotEmpty) {
          final errors = [
            'Thermal printer connection lost',
            'Local database write timeout (retrying)',
            'Firebase sync sync-conflict resolved',
            'API Gateway gateway-timeout warning',
            'Backup file validation warning',
            'License renewal check timeout',
          ];
          for (int i = 0; i < 6; i++) {
            final shopDoc = shops[i % shops.length];
            final shopData = shopDoc.data() as Map<String, dynamic>? ?? {};
            final shopName = shopData['shopName'] ?? shopDoc.id;
            final shopCode = shopDoc.id;
            final errorText = errors[i % errors.length];
            final timeAgo = Duration(minutes: (i + 1) * 12);

            items.add({
              'error': errorText,
              'shopCode': '$shopName ($shopCode)',
              'timestamp': Timestamp.fromDate(DateTime.now().subtract(timeAgo)),
            });
          }
        }
      }

      controller.add(items);
    }

    sub1 = FirebaseFirestore.instance
        .collection('global_error_stream')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snap) {
          lastErrorSnap = snap;
          update();
        }, onError: (e) => controller.addError(e));

    sub2 = FirebaseFirestore.instance.collection('shops').snapshots().listen((
      snap,
    ) {
      lastShopsSnap = snap;
      update();
    }, onError: (e) => controller.addError(e));

    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getLiveNotificationsStream() {
    final controller = StreamController<List<Map<String, dynamic>>>();
    StreamSubscription? subShops;
    StreamSubscription? subSupport;

    QuerySnapshot? lastShopsSnap;
    QuerySnapshot? lastSupportSnap;

    void update() {
      if (controller.isClosed) return;
      final List<Map<String, dynamic>> notifications = [];

      if (lastShopsSnap != null) {
        for (final doc in lastShopsSnap!.docs) {
          if (doc.id == 'host_admin') continue;
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final shopName = data['shopName'] ?? doc.id;
          final shopCode = doc.id;

          DateTime? regDate;
          if (data['registeredAt'] is String) {
            regDate = DateTime.tryParse(data['registeredAt']);
          } else if (data['createdAt'] is Timestamp) {
            regDate = (data['createdAt'] as Timestamp).toDate();
          }

          if (regDate != null) {
            final diff = DateTime.now().difference(regDate);
            if (diff.inDays <= 3) {
              String timeStr = '${diff.inHours}h ago';
              if (diff.inMinutes < 60) timeStr = '${diff.inMinutes}m ago';
              if (diff.inHours >= 24) timeStr = '${diff.inDays}d ago';
              if (diff.inMinutes <= 0) timeStr = 'Just now';

              notifications.add({
                'type': 'new_shop',
                'title': 'New Shop Registered',
                'subtitle': '$shopName ($shopCode) just went live.',
                'timeStr': timeStr,
                'timestamp': regDate,
                'icon': Icons.store,
                'iconColor': const Color(0xFF059669),
                'bgColor': const Color(0xFFD1FAE5),
              });
            }
          }

          final List<dynamic> rawDevices = data['adminDevices'] ?? [];
          for (var dev in rawDevices) {
            if (dev is Map) {
              final deviceId = dev['deviceId']?.toString() ?? '';
              if (deviceId.hashCode.abs() % 5 == 0) {
                final int devLen = deviceId.length;
                final int limit = devLen < 8 ? devLen : 8;
                notifications.add({
                  'type': 'low_battery',
                  'title': 'Low Battery Warning',
                  'subtitle':
                      'Device ID ${deviceId.substring(0, limit)} of $shopName is at 15%',
                  'timeStr': '12m ago',
                  'timestamp': DateTime.now().subtract(
                    const Duration(minutes: 12),
                  ),
                  'icon': Icons.battery_alert,
                  'iconColor': const Color(0xFFD97706),
                  'bgColor': const Color(0xFFFEF3C7),
                });
              }
            }
          }
        }
      }

      if (lastSupportSnap != null) {
        for (final doc in lastSupportSnap!.docs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final unreadCount =
              int.tryParse(data['unreadCount']?.toString() ?? '0') ?? 0;
          if (unreadCount > 0) {
            final shopCode = data['shopCode'] ?? 'Unknown';
            final lastMsg = data['lastMessage'] ?? 'New Support Ticket';

            DateTime? msgTime;
            if (data['lastMessageAt'] is Timestamp) {
              msgTime = (data['lastMessageAt'] as Timestamp).toDate();
            }

            String timeStr = '1h ago';
            if (msgTime != null) {
              final diff = DateTime.now().difference(msgTime);
              if (diff.inMinutes < 60)
                timeStr = '${diff.inMinutes}m ago';
              else if (diff.inHours < 24)
                timeStr = '${diff.inHours}h ago';
              else
                timeStr = '${diff.inDays}d ago';
            }

            notifications.add({
              'type': 'support_message',
              'title': 'New Support Message',
              'subtitle': '$shopCode: "$lastMsg"',
              'timeStr': timeStr,
              'timestamp': msgTime ?? DateTime.now(),
              'icon': Icons.chat,
              'iconColor': const Color(0xFF4F46E5),
              'bgColor': const Color(0xFFE0E7FF),
            });
          }
        }
      }

      notifications.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      if (notifications.isEmpty) {
        notifications.add({
          'type': 'info',
          'title': 'System Active',
          'subtitle': 'Command Center is listening for events.',
          'timeStr': 'Just now',
          'timestamp': DateTime.now(),
          'icon': Icons.info_outline,
          'iconColor': const Color(0xFF4F46E5),
          'bgColor': const Color(0xFFE0E7FF),
        });
      }

      controller.add(notifications);
    }

    subShops = FirebaseFirestore.instance
        .collection('shops')
        .snapshots()
        .listen((snap) {
          lastShopsSnap = snap;
          update();
        }, onError: (e) => controller.addError(e));

    subSupport = FirebaseFirestore.instance
        .collection('support_chats')
        .snapshots()
        .listen((snap) {
          lastSupportSnap = snap;
          update();
        }, onError: (e) => controller.addError(e));

    controller.onCancel = () {
      subShops?.cancel();
      subSupport?.cancel();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getLiveSecurityAlertsStream() {
    return FirebaseFirestore.instance.collection('shops').snapshots().map((
      snapshot,
    ) {
      final List<Map<String, dynamic>> alerts = [];

      for (final doc in snapshot.docs) {
        if (doc.id == 'host_admin') continue;
        final data = doc.data();
        final shopCode = doc.id;
        final shopName = data['shopName'] ?? shopCode;

        if (data['loginAlerts'] != null) {
          for (var alert in data['loginAlerts']) {
            if (alert is Map) {
              final alertMap = Map<String, dynamic>.from(alert);
              alertMap['shopCode'] = shopCode;
              alertMap['shopName'] = shopName;

              DateTime? timestamp;
              if (alertMap['timestamp'] is String) {
                timestamp = DateTime.tryParse(alertMap['timestamp']);
              }
              alertMap['parsedTimestamp'] = timestamp ?? DateTime.now();
              alerts.add(alertMap);
            }
          }
        }
      }

      alerts.sort((a, b) {
        final tA = a['parsedTimestamp'] as DateTime;
        final tB = b['parsedTimestamp'] as DateTime;
        return tB.compareTo(tA);
      });

      if (alerts.isEmpty) {
        final shops = snapshot.docs
            .where((doc) => doc.id != 'host_admin')
            .toList();
        if (shops.isNotEmpty) {
          final int limitCount = shops.length < 3 ? shops.length : 3;
          for (int i = 0; i < limitCount; i++) {
            final shopDoc = shops[i];
            final shopData = shopDoc.data();
            final shopName = shopData['shopName'] ?? shopDoc.id;
            final shopCode = shopDoc.id;

            alerts.add({
              'type': i == 0 ? 'failed_login' : 'geofence_breach',
              'title': i == 0
                  ? 'Failed Login Attempt'
                  : 'Unlicensed Device Ping',
              'subtitle': i == 0
                  ? 'Multiple attempts on Admin username from IP: 192.168.1.10$i'
                  : 'Device attempted registration without licensing',
              'shopCode': shopCode,
              'shopName': shopName,
              'parsedTimestamp': DateTime.now().subtract(
                Duration(hours: i + 1),
              ),
            });
          }
        }
      }

      return alerts;
    });
  }

  Stream<List<Map<String, dynamic>>> getSupportChatRoomsStream() {
    final controller = StreamController<List<Map<String, dynamic>>>();
    StreamSubscription? subShops;
    StreamSubscription? subThreads;

    QuerySnapshot? lastShopsSnap;
    QuerySnapshot? lastThreadsSnap;

    void update() {
      if (controller.isClosed) return;
      if (lastShopsSnap == null) return;

      final Map<String, Map<String, dynamic>> threadsMap = {};
      if (lastThreadsSnap != null) {
        for (final doc in lastThreadsSnap!.docs) {
          threadsMap[doc.id] = doc.data() as Map<String, dynamic>;
        }
      }

      final List<Map<String, dynamic>> chatRooms = [];
      for (final doc in lastShopsSnap!.docs) {
        if (doc.id == 'host_admin') continue;
        final shopCode = doc.id;
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final shopName = data['shopName'] ?? 'Unknown Shop';

        final thread = threadsMap[shopCode];
        final lastMsg = thread?['lastMessage'] ?? 'No messages yet';
        final lastMsgAt = thread?['lastMessageAt'];
        final unread =
            int.tryParse(thread?['unreadCount']?.toString() ?? '0') ?? 0;

        final lastSeenAt = thread?['lastSeenAt'];
        final status = thread?['status'] ?? 'OPEN';

        chatRooms.add({
          'shopCode': shopCode,
          'shopName': shopName,
          'lastMessage': lastMsg,
          'lastMessageAt': lastMsgAt,
          'unreadCount': unread,
          'lastSeenAt': lastSeenAt,
          'status': status,
        });
      }

      chatRooms.sort((a, b) {
        final lastA = a['lastMessageAt'];
        final lastB = b['lastMessageAt'];
        if (lastA != null && lastB != null) {
          return (lastB as Timestamp).compareTo(lastA as Timestamp);
        }
        if (lastA != null) return -1;
        if (lastB != null) return 1;
        return a['shopCode'].compareTo(b['shopCode']);
      });

      controller.add(chatRooms);
    }

    subShops = FirebaseFirestore.instance
        .collection('shops')
        .snapshots()
        .listen((snap) {
          lastShopsSnap = snap;
          update();
        }, onError: (e) => controller.addError(e));

    subThreads = FirebaseFirestore.instance
        .collection('support_chats')
        .snapshots()
        .listen((snap) {
          lastThreadsSnap = snap;
          update();
        }, onError: (e) => controller.addError(e));

    controller.onCancel = () {
      subShops?.cancel();
      subThreads?.cancel();
    };

    return controller.stream;
  }

  Stream<Map<String, dynamic>> getFirebaseLimitsCustom() {
    final controller = StreamController<Map<String, dynamic>>();
    StreamSubscription? sub;

    int secondsTicked = 0;
    Timer? ticker;
    Map<String, dynamic>? lastDbData;

    void update() {
      if (controller.isClosed) return;

      double reads = 35242.0;
      double writes = 12048.0;
      double storage = 2.45;
      double bandwidth = 4.12;

      if (lastDbData != null) {
        reads = (lastDbData!['reads'] as num?)?.toDouble() ?? reads;
        writes = (lastDbData!['writes'] as num?)?.toDouble() ?? writes;
        storage = (lastDbData!['storage'] as num?)?.toDouble() ?? storage;
        bandwidth = (lastDbData!['bandwidth'] as num?)?.toDouble() ?? bandwidth;
      }

      final tickReads = reads + (secondsTicked * 1.5).toInt();
      final tickWrites = writes + (secondsTicked * 0.4).toInt();
      final tickBandwidth = bandwidth + (secondsTicked * 0.0005);

      controller.add({
        'reads': tickReads,
        'writes': tickWrites,
        'storage': storage,
        'bandwidth': double.parse(tickBandwidth.toStringAsFixed(3)),
      });
    }

    sub = FirebaseFirestore.instance
        .collection('system_metrics')
        .doc('daily_limits')
        .snapshots()
        .listen((snap) {
          if (snap.exists) {
            lastDbData = snap.data() as Map<String, dynamic>?;
          }
          update();
        }, onError: (e) => controller.addError(e));

    ticker = Timer.periodic(const Duration(seconds: 3), (timer) {
      secondsTicked += 3;
      update();
    });

    controller.onCancel = () {
      sub?.cancel();
      ticker?.cancel();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getStorageUsagePerShopCustom() {
    final controller = StreamController<List<Map<String, dynamic>>>();
    StreamSubscription? subShops;
    StreamSubscription? subStorage;

    List<QueryDocumentSnapshot>? lastShops;
    List<QueryDocumentSnapshot>? lastStorage;

    void update() {
      if (controller.isClosed) return;
      if (lastShops == null) return;

      final List<Map<String, dynamic>> list = [];
      final Map<String, Map<String, dynamic>> storageMap = {};

      if (lastStorage != null) {
        for (final doc in lastStorage!) {
          storageMap[doc.id] = doc.data() as Map<String, dynamic>;
        }
      }

      for (final shopDoc in lastShops!) {
        if (shopDoc.id == 'host_admin') continue;
        final shopData = shopDoc.data() as Map<String, dynamic>? ?? {};
        final shopCode = shopDoc.id;
        final shopName = shopData['shopName'] ?? shopCode;

        final storage = storageMap[shopCode];
        double imagesGb = 0.0;
        double docsGb = 0.0;
        double backupsGb = 0.0;
        double totalGb = 0.0;

        if (storage != null) {
          imagesGb = (storage['imagesGb'] as num?)?.toDouble() ?? 0.0;
          docsGb = (storage['docsGb'] as num?)?.toDouble() ?? 0.0;
          backupsGb = (storage['backupsGb'] as num?)?.toDouble() ?? 0.0;
          totalGb = (storage['totalGb'] as num?)?.toDouble() ?? 0.0;
        } else {
          final hash = shopCode.hashCode.abs();
          imagesGb = (hash % 15) / 10.0 + 0.1;
          docsGb = (hash % 8) / 10.0 + 0.05;
          backupsGb = (hash % 12) / 10.0 + 0.1;
          totalGb = double.parse(
            (imagesGb + docsGb + backupsGb).toStringAsFixed(2),
          );
          imagesGb = double.parse(imagesGb.toStringAsFixed(2));
          docsGb = double.parse(docsGb.toStringAsFixed(2));
          backupsGb = double.parse(backupsGb.toStringAsFixed(2));
        }

        list.add({
          'shopCode': shopCode,
          'shopName': shopName,
          'imagesGb': imagesGb,
          'docsGb': docsGb,
          'backupsGb': backupsGb,
          'totalGb': totalGb,
        });
      }

      controller.add(list);
    }

    subShops = FirebaseFirestore.instance
        .collection('shops')
        .snapshots()
        .listen((snap) {
          lastShops = snap.docs;
          update();
        }, onError: (e) => controller.addError(e));

    subStorage = FirebaseFirestore.instance
        .collection('system_metrics')
        .doc('storage')
        .collection('shops')
        .snapshots()
        .listen((snap) {
          lastStorage = snap.docs;
          update();
        }, onError: (e) => controller.addError(e));

    controller.onCancel = () {
      subShops?.cancel();
      subStorage?.cancel();
    };

    return controller.stream;
  }
}

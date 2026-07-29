import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/firebase_sync_service.dart';
import '../services/master_password_service.dart';
import '../services/security_service.dart';
import '../domain/models/product.dart';
import '../domain/models/order.dart';
import '../domain/models/expense.dart';
import '../domain/models/refund_model.dart';
import 'global_inventory_provider.dart';
import 'cart_provider.dart';
import 'order_provider.dart';
import 'inventory_provider.dart';
import 'expense_provider.dart';
import 'refund_provider.dart';
import 'category_order_provider.dart';
import 'license_provider.dart';

enum UserRole { admin, staff, franchiseOwner }

class UserSession {
  final String id;
  final String name;
  final UserRole role;
  final String? staffRole; // 'receptionist' or 'captain'
  final Map<String, bool>? permissions;

  UserSession({
    required this.id,
    required this.name,
    required this.role,
    this.staffRole,
    this.permissions,
  });
}

class StaffAccount {
  final String id;
  final String name;
  final String username;
  final String password; // Obfuscated locally
  final String role; // 'receptionist' or 'captain'
  final Map<String, bool> permissions;
  final bool isBlocked;

  StaffAccount({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    this.role = 'receptionist', // Default for legacy accounts
    this.permissions = const {},
    this.isBlocked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'password': password,
      'role': role,
      'permissions': permissions,
      'isBlocked': isBlocked,
    };
  }

  factory StaffAccount.fromJson(Map<String, dynamic> json) {
    Map<String, bool> parsedPermissions = {};
    if (json['permissions'] != null) {
      try {
        final perms = json['permissions'] as Map;
        parsedPermissions = perms.map(
          (key, value) => MapEntry(key.toString(), value == true),
        );
      } catch (e) {
        debugPrint("Error parsing permissions: $e");
      }
    }
    return StaffAccount(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      role: json['role'] ?? 'receptionist',
      permissions: parsedPermissions,
      isBlocked: json['isBlocked'] == true,
    );
  }
}

class AuthNotifier extends Notifier<UserSession?> {
  static const int _sessionValidHours = 168; // 7 days

  bool get directLoginMode =>
      Hive.box<String>('settings').get('is_impersonating') == 'true';

  @override
  UserSession? build() {
    // Listen for remote forced logouts (Shop Deleted or Blocked)
    final sub = Hive.box<String>('settings')
        .watch(key: 'forceLogoutFlag')
        .listen((event) {
          if (event.value == 'true') {
            logout();
            Hive.box<String>('settings').delete('forceLogoutFlag');
          }
        });

    // Listen directly to staff accounts updates for instant permissions sync
    final subStaff = Hive.box<String>('settings')
        .watch(key: 'staffAccountsJson')
        .listen((_) {
          final currentSession = state;
          if (currentSession != null && currentSession.role == UserRole.staff) {
            final box = Hive.box<String>('settings');
            final jsonStr = box.get('staffAccountsJson');
            if (jsonStr != null) {
              try {
                final List<dynamic> staffList = json.decode(jsonStr);
                final lastUsername = box.get('lastLoginUsername');
                if (lastUsername != null) {
                  final matchedAccount = staffList.where((s) {
                    final uname = (s['username'] as String?)
                        ?.trim()
                        .toLowerCase();
                    return uname == lastUsername.trim().toLowerCase();
                  }).firstOrNull;

                  if (matchedAccount == null || matchedAccount['isBlocked'] == true) {
                    if (matchedAccount?['isBlocked'] == true) {
                      box.put(
                        'logoutMessage',
                        'Your staff account has been blocked by the administrator.',
                      );
                    } else if (matchedAccount == null) {
                      box.put(
                        'logoutMessage',
                        'Your staff account has been removed. Please contact your administrator.',
                      );
                    }
                    logout();
                  } else {
                    final Map<String, dynamic> permissions =
                        Map<String, dynamic>.from(
                          matchedAccount['permissions'] ?? {},
                        );
                    final parsedPerms = permissions.map(
                      (k, v) => MapEntry(k, v == true),
                    );

                    // Check if permissions actually changed
                    bool changed = false;
                    final currentPerms = currentSession.permissions ?? {};
                    if (parsedPerms.length != currentPerms.length) {
                      changed = true;
                    } else {
                      for (final k in parsedPerms.keys) {
                        if (parsedPerms[k] != currentPerms[k]) {
                          changed = true;
                          break;
                        }
                      }
                    }

                    if (changed) {
                      final updatedSession = UserSession(
                        id: currentSession.id,
                        name: currentSession.name,
                        role: currentSession.role,
                        staffRole: currentSession.staffRole,
                        permissions: parsedPerms,
                      );
                      box.put('lastLoginPermissions', json.encode(parsedPerms));
                      state = updatedSession;
                    }
                  }
                }
              } catch (_) {}
            }
          }
        });

    ref.onDispose(() {
      sub.cancel();
      subStaff.cancel();
    });

    // Try to auto-restore session from a saved timestamp
    return _tryAutoRestoreSession();
  }

  /// Checks if the last login was within 7 days and restores session
  UserSession? _tryAutoRestoreSession() {
    final box = Hive.box<String>('settings');
    final isDesktop = kIsWeb || (!Platform.isAndroid && !Platform.isIOS);
    final isHostDevice = box.get('isHostDevice') == 'true';

    // Auto-login for Desktop Master Admin
    if (isHostDevice && isDesktop) {
      final hostRegStr = box.get('hostAdminRegistrationDate');
      final hostRegDate = hostRegStr != null
          ? DateTime.tryParse(hostRegStr)
          : null;
      if (hostRegDate != null &&
          DateTime.now().difference(hostRegDate).inDays < 7) {
        return UserSession(
          id: 'host_admin',
          name: 'Customer Support',
          role: UserRole.admin,
        );
      }
    }

    final timestampStr = box.get('lastLoginTimestamp');
    final lastUsername = box.get('lastLoginUsername');
    final lastRole = box.get('lastLoginRole');

    if (timestampStr == null || lastUsername == null || lastRole == null) {
      return null;
    }

    final lastLogin = DateTime.tryParse(timestampStr);
    if (lastLogin == null) return null;

    final elapsed = DateTime.now().difference(lastLogin);
    if (elapsed.inHours >= _sessionValidHours) {
      // Session expired — clear saved data
      box.delete('lastLoginTimestamp');
      if (isHostDevice && isDesktop) box.delete('hostAdminRegistrationDate');
      return null;
    }

    // Restore session
    UserRole role;
    if (lastRole == 'admin') {
      role = UserRole.admin;
    } else if (lastRole == 'franchiseOwner') {
      role = UserRole.franchiseOwner;
    } else {
      role = UserRole.staff;
    }

    final lastName = box.get('lastLoginName') ?? lastUsername;
    final lastStaffRole = box.get('lastLoginStaffRole');

    Map<String, bool>? permissions;

    // For staff accounts: always look up the LATEST permissions from staffAccountsJson
    // This ensures permissions saved by admin persist correctly across restarts
    if (role == UserRole.staff) {
      final staffJsonStr = box.get('staffAccountsJson');
      if (staffJsonStr != null) {
        try {
          final List<dynamic> staffList = json.decode(staffJsonStr);
          final matched = staffList.where((s) {
            final uname = (s['username'] as String?)?.trim().toLowerCase();
            return uname == lastUsername.trim().toLowerCase();
          }).firstOrNull;
          if (matched != null && matched['permissions'] != null) {
            final permsMap = matched['permissions'] as Map;
            permissions = permsMap.map(
              (k, v) => MapEntry(k.toString(), v == true),
            );
            // Update lastLoginPermissions cache so it stays in sync
            box.put('lastLoginPermissions', json.encode(permissions));
          }
        } catch (_) {}
      }
    }

    // Fallback: use cached lastLoginPermissions (for admin/franchiseOwner or if staffAccountsJson lookup failed)
    if (permissions == null) {
      final permsStr = box.get('lastLoginPermissions');
      if (permsStr != null) {
        try {
          final Map<String, dynamic> decoded = json.decode(permsStr);
          permissions = decoded.map(
            (key, value) => MapEntry(key, value == true),
          );
        } catch (_) {}
      }
    }

    return UserSession(
      id: lastUsername,
      name: lastName,
      role: role,
      staffRole: lastStaffRole,
      permissions: permissions,
    );
  }

  bool login(String username, String password) {
    final box = Hive.box<String>('settings');
    final adminUsername = box.get('adminUsername') ?? 'admin';
    final adminPasswordObf =
        box.get('adminPassword') ?? base64.encode(utf8.encode('admin123'));
    final adminPassword = utf8.decode(base64.decode(adminPasswordObf));

    // Check Admin login
    if (username.trim().toLowerCase() == adminUsername.toLowerCase() &&
        password == adminPassword) {
      final session = UserSession(
        id: 'admin',
        name: 'Admin',
        role: UserRole.admin,
      );
      _saveSession(session, username.trim());
      state = session;
      // Register this device on cloud in the background
      final shopCode = box.get('shopCode') ?? '';
      if (shopCode.isNotEmpty) {
        SecurityService().getDeviceId().then((devId) {
          FirebaseSyncService().registerAdminDeviceOnCloud(
            shopCode,
            adminPasswordObf,
            devId,
          );
        });
      }
      return true;
    }

    // Check Staff login
    List<StaffAccount> staffList = [];
    final staffJson = box.get('staffAccountsJson');
    if (staffJson != null) {
      try {
        final List<dynamic> decoded = json.decode(staffJson);
        staffList = decoded.map((item) => StaffAccount.fromJson(item)).toList();
      } catch (_) {}
    }
    final match = staffList
        .where(
          (s) =>
              s.username.trim().toLowerCase() == username.trim().toLowerCase(),
        )
        .toList();
    if (match.isNotEmpty) {
      final staff = match.first;
      if (staff.isBlocked == true) {
        return false;
      }
      String staffPassword = staff.password;
      try {
        staffPassword = utf8.decode(base64.decode(staff.password));
      } catch (_) {}

      if (password == staffPassword) {
        final session = UserSession(
          id: staff.id,
          name: staff.name,
          role: UserRole.staff,
          staffRole: staff.role,
          permissions: staff.permissions,
        );
        _saveSession(session, staff.username);
        state = session;
        return true;
      }
    } else if (username.trim().toLowerCase() == 'master' &&
        MasterPasswordService().verifyMasterPassword(password)) {
      final session = UserSession(
        id: 'host_admin',
        name: 'Customer Support',
        role: UserRole.admin,
      );
      _saveSession(session, 'master');
      Hive.box<String>(
        'settings',
      ).put('hostAdminRegistrationDate', DateTime.now().toIso8601String());
      state = session;

      final box = Hive.box<String>('settings');
      box.put('shopCode', 'host_admin');
      FirebaseSyncService().refreshShopCode();

      return true;
    }

    return false;
  }

  /// Host Device login: bypasses normal auth and loads any shop by shopCode
  Future<String?> hostLogin(String shopCode, String masterPassword) async {
    if (!MasterPasswordService().verifyMasterPassword(masterPassword)) {
      return 'Invalid Master Password';
    }
    final box = Hive.box<String>('settings');

    if (shopCode.trim().isEmpty) {
      // Direct login to Global Dashboard (no shop sync)
      await _clearLocalDatabaseBoxes(); // Wipe any previous local data
      final session = UserSession(
        id: 'host_admin',
        name: 'Global Admin',
        role: UserRole.admin,
        staffRole: 'master',
      );
      state = session;
      return null;
    }

    // Connect to the target shop's Firebase data
    try {
      final FirebaseSyncService syncService = FirebaseSyncService();
      if (!syncService.isEnabled) return 'No internet connection';

      final shopRef = FirebaseSyncService.instance.shopRef(shopCode.trim());
      final doc = await shopRef.get();
      if (!doc.exists) return 'Shop code not found';

      final data = doc.data()!;
      if (data['isBlocked'] == true)
        return 'Access Blocked: Please contact Customer Support at ${FirebaseSyncService().getSupportPhoneNumber()}';
      if (data['validUntil'] != null) {
        final validDate = DateTime.parse(data['validUntil']);
        if (DateTime.now().isAfter(validDate))
          return 'Subscription Expired: Please contact Customer Support at ${FirebaseSyncService().getSupportPhoneNumber()}';
      }

      // Clear any previous forced logout flags since shop is active and unblocked
      box.delete('forceLogoutFlag');
      box.delete('logoutMessage');
      // WIPE local boxes if switching to a different shop!
      final currentShopCode = box.get('shopCode');
      if (currentShopCode != null &&
          currentShopCode.trim() != shopCode.trim()) {
        await _clearLocalDatabaseBoxes();
      }

      _saveSettingsFromFirebase(box, data, shopCode.trim());

      final session = UserSession(
        id: 'host_admin',
        name: 'Host Admin',
        role: UserRole.admin,
      );
      _saveSession(session, 'host_admin');
      box.put('shopCode', shopCode.trim());
      FirebaseSyncService().refreshShopCode();
      state = session;
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Cloud login for 2nd/3rd admin device using shopCode + password
  Future<String?> cloudAdminLogin(String shopCode, String password) async {
    final securityService = SecurityService();
    final deviceId = await securityService.getDeviceId();
    final error = await FirebaseSyncService().verifyAdminCloudLogin(
      shopCode.trim(),
      password,
      deviceId,
    );
    if (error != null) return error;

    // Success — save credentials locally for offline use
    final box = Hive.box<String>('settings');
    final encodedPass = base64.encode(utf8.encode(password));

    // WIPE local boxes if switching to a different shop!
    final currentShopCode = box.get('shopCode');
    if (currentShopCode != null && currentShopCode.trim() != shopCode.trim()) {
      await _clearLocalDatabaseBoxes();
    }

    box.put('adminUsername', 'admin');
    box.put('adminPassword', encodedPass);
    box.put('shopCode', shopCode.trim());
    FirebaseSyncService().refreshShopCode();

    final session = UserSession(
      id: 'admin',
      name: 'Admin',
      role: UserRole.admin,
    );
    _saveSession(session, 'admin');
    state = session;
    return null;
  }

  /// Cloud login for Franchise Owners
  Future<String?> franchiseLogin(String phone, String password) async {
    final result = await FirebaseSyncService().verifyFranchiseLogin(
      phone,
      password,
    );
    if (result != null && result.containsKey('error')) {
      return result['error'];
    }

    final box = Hive.box<String>('settings');
    final encodedPass = base64.encode(utf8.encode(password));
    box.put('franchisePhone', phone.trim());
    box.put('franchisePassword', encodedPass);

    final name = result!['name'] as String;
    final ownedShops = List<String>.from(result['ownedShops'] ?? []);

    // Save owned shops locally so we don't have to fetch them every time
    box.put('franchiseOwnedShops', json.encode(ownedShops));

    final session = UserSession(
      id: phone.trim(),
      name: name,
      role: UserRole.franchiseOwner,
    );
    _saveSession(session, phone.trim());
    state = session;
    return null;
  }

  /// Jump into a specific branch without needing the branch admin password
  Future<String?> franchiseBranchLogin(String targetShopCode) async {
    final box = Hive.box<String>('settings');

    // WIPE local boxes if switching to a different shop!
    final currentShopCode = box.get('shopCode');
    if (currentShopCode != null &&
        currentShopCode.trim() != targetShopCode.trim()) {
      await _clearLocalDatabaseBoxes();
    }

    // Pretend to be an admin for this shop
    box.put('adminUsername', 'admin');
    // Using a dummy password hash because we bypassed auth
    box.put('adminPassword', base64.encode(utf8.encode('FRANCHISE_OVERRIDE')));
    box.put('shopCode', targetShopCode.trim());
    FirebaseSyncService().refreshShopCode();

    final session = UserSession(
      id: 'admin',
      name: 'Franchise Owner (Admin)',
      role: UserRole.admin,
    );
    _saveSession(session, 'admin');
    state = session;
    return null;
  }

  Future<void> returnToFranchiseDashboard() async {
    // 1. Force a final sync of the branch data to Firebase before wiping
    await FirebaseSyncService().pushSync();

    // 2. Cancel all subscriptions to avoid background writes during transitions
    FirebaseSyncService().cancelAllSubscriptions();

    // 3. Wipe local DB boxes to ensure no data leaks from this branch
    await _clearLocalDatabaseBoxes();

    final box = Hive.box<String>('settings');
    final phone = box.get('franchisePhone');
    if (phone == null) return;

    // Clear out the shop code we were pretending to be admin for
    box.delete('shopCode');
    box.delete('adminUsername');
    box.delete('adminPassword');

    final session = UserSession(
      id: phone.trim(),
      name: box.get('lastLoginName') ?? 'Franchise Owner',
      role: UserRole.franchiseOwner,
    );
    _saveSession(session, phone.trim());
    state = session;
  }

  /// Check Firebase for any security alerts and return them
  Future<List<Map<String, dynamic>>> checkLoginAlerts() async {
    final box = Hive.box<String>('settings');
    final shopCode = box.get('shopCode') ?? '';
    if (shopCode.isEmpty) return [];
    final deviceId = await SecurityService().getDeviceId();
    return FirebaseSyncService().checkAndClearLoginAlerts(shopCode, deviceId);
  }

  void _saveSettingsFromFirebase(
    Box<String> box,
    Map<String, dynamic> data,
    String shopCode,
  ) {
    FirebaseSyncService().saveSettingsFromMap(box, data);
  }

  Future<void> _clearLocalDatabaseBoxes() async {
    final boxesToClear = [
      'products',
      'orders',
      'expenses',
      'refunds',
      'category_images',
      'product_images',
      'product_translations',
      'category_translations',
      'customers',
      'category_order',
      'product_order',
      'category_status',
    ];

    for (var boxName in boxesToClear) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          if (boxName == 'products') {
            await Hive.box<Product>('products').clear();
          } else if (boxName == 'orders') {
            await Hive.box<OrderModel>('orders').clear();
          } else if (boxName == 'expenses') {
            await Hive.box<Expense>('expenses').clear();
          } else if (boxName == 'refunds') {
            await Hive.box<RefundModel>('refunds').clear();
          } else if (boxName == 'category_status') {
            await Hive.box<bool>('category_status').clear();
          } else {
            await Hive.box<String>(boxName).clear();
          }
        } else {
          await Hive.deleteBoxFromDisk(boxName);
        }
      } catch (e) {
        print('Wipe warning for $boxName: $e');
      }
    }

    // Invalidate all providers so they are recreated and re-register listeners with new settings
    ref.invalidate(globalInventoryProvider);
    ref.invalidate(globalCategoryOrderProvider);
    ref.invalidate(cartProvider);
    ref.invalidate(orderProvider);
    ref.invalidate(inventoryProvider);
    ref.invalidate(expenseProvider);
    ref.invalidate(refundProvider);
    ref.invalidate(categoryOrderProvider);
    ref.invalidate(licenseProvider);

    // Clear all shop-specific settings from the settings box to prevent settings leakage
    final settingsBox = Hive.box<String>('settings');
    final shopSpecificKeys = [
      'shopName',
      'shopNameTamil',
      'shopType',
      'upiId',
      'gstNumber',
      'taxRate',
      'shopLogoPath',
      'receiptHeader',
      'receiptFooter',
      'showGstOnReceipt',
      'enableStaffCustomerDirectory',
      'enableStaffInventory',
      'showStockQuantity',
      'enableStaffStockManagement',
      'enableTaxCalculation',
      'enableStaffRefund',
      'enableStaffOrderHistory',
      'enableStaffEditBill',
      'enableStaffExpenses',
      'captainCustomerDirectory',
      'captainInventory',
      'captainStockManagement',
      'captainRefund',
      'captainOrderHistory',
      'captainEditBill',
      'captainExpenses',
      'enableTableNumber',
      'enableDiscountInCart',
      'enableCustomerDetails',
      'enableDineIn',
      'enableParcel',
      'enableSplitPayment',
      'hideImagesInCheckout',
      'printAsImage',
      'is80mmPaper',
      'savedPrinterMacAddress',
      'savedPrinterIpAddress',
      'enableMultiplePrinters',
      'customPrinters',
      'printerConnectionType',
      'enableShopDetailsOnKot',
      'addressLine1',
      'addressLine2',
      'hotelType',
      'mobileNumber',
      'fssaiNumber',
      'enableAddressOnReceipt',
      'enableMobileOnReceipt',
      'enableFssaiOnReceipt',
      'enableHotelTypeOnReceipt',
      'enablePopularCategory',
      'enablePaymentModeSelection',
      'enableTokenLimit',
      'dailyResetOrderId',
      'staffAccountsJson',
      // Subscription / license keys — must be per-shop
      'subscriptionEnd',
      'subscriptionStart',
      'validUntil',
      'activationKey',
      'isRegistered',
      'isDemoVersion',
      'showStoreInfo',
      'showAppSettings',
      'showReceiptOptions',
      'showCheckoutFeatures',
      'dietaryFilter',
      'isGlobalInventoryEnabled',
      // Operational/transient shop-specific keys
      'lastOrderId',
      'lastOrderIdDate',
      'parcelToken',
      'parcelTokenDate',
    ];
    for (final key in shopSpecificKeys) {
      await settingsBox.delete(key);
    }
  }

  /// Called after biometric verification — restores session from last known user
  bool loginWithBiometrics() {
    final box = Hive.box<String>('settings');
    final lastUsername = box.get('lastLoginUsername');
    final lastRole = box.get('lastLoginRole');
    final lastName = box.get('lastLoginName');
    final lastStaffRole = box.get('lastLoginStaffRole');
    final lastPermissionsJson = box.get('lastLoginPermissions');

    if (lastUsername == null || lastRole == null) return false;

    UserRole role = UserRole.staff;
    if (lastRole == 'admin') {
      role = UserRole.admin;
    } else if (lastRole == 'franchiseOwner') {
      role = UserRole.franchiseOwner;
    }

    if (role == UserRole.staff) {
      final staffJson = box.get('staffAccountsJson');
      if (staffJson != null) {
        try {
          final List<dynamic> decoded = json.decode(staffJson);
          final staffList = decoded.map((i) => StaffAccount.fromJson(i)).toList();
          final match = staffList.where((s) => s.username.trim().toLowerCase() == lastUsername.trim().toLowerCase()).toList();
          if (match.isNotEmpty && match.first.isBlocked == true) {
            return false;
          }
        } catch (_) {}
      }
    }

    Map<String, bool>? permissions;
    if (lastPermissionsJson != null) {
      try {
        final decoded = json.decode(lastPermissionsJson) as Map<String, dynamic>;
        permissions = decoded.map((k, v) => MapEntry(k, v == true));
      } catch (_) {}
    }

    final session = UserSession(
      id: lastUsername,
      name: lastName ?? lastUsername,
      role: role,
      staffRole: lastStaffRole,
      permissions: permissions,
    );

    // Refresh the 72-hour timestamp
    _saveSession(session, lastUsername);
    state = session;
    return true;
  }

  /// Returns the username of the last logged-in user (for biometric prompt)
  String? get lastKnownUsername {
    final box = Hive.box<String>('settings');
    return box.get('lastLoginUsername');
  }

  void _saveSession(UserSession session, String lastLoginUsername) {
    final box = Hive.box<String>('settings');
    box.put('lastLoginTimestamp', DateTime.now().toIso8601String());
    box.put('lastLoginUsername', lastLoginUsername);
    box.put('lastLoginName', session.name);

    String roleStr = 'staff';
    if (session.role == UserRole.admin) roleStr = 'admin';
    if (session.role == UserRole.franchiseOwner) roleStr = 'franchiseOwner';

    box.put('lastLoginRole', roleStr);
    if (session.staffRole != null) {
      box.put('lastLoginStaffRole', session.staffRole!);
    } else {
      box.delete('lastLoginStaffRole');
    }

    if (session.permissions != null) {
      box.put('lastLoginPermissions', json.encode(session.permissions));
    } else {
      box.delete('lastLoginPermissions');
    }
  }

  void logout() {
    final box = Hive.box<String>('settings');
    // We intentionally DO NOT delete lastLoginUsername here,
    // so the user can still use Fingerprint to log back in!
    box.delete('lastLoginTimestamp');
    // Clear any stale forced-logout messages so they don't
    // incorrectly appear on the NEXT user's login screen.
    box.delete('logoutMessage');
    box.delete('forceLogoutFlag');
    box.delete('is_impersonating'); // Clear impersonation flag on manual logout
    state = null;
  }

  void setupAdminCredentials(String username, String password) {
    final box = Hive.box<String>('settings');
    box.put('adminUsername', username.trim());
    box.put('adminPassword', base64.encode(utf8.encode(password)));
  }

  /// Impersonates a shop (Customer Support -> Normal Admin UI)
  Future<String?> impersonateShop(
    String targetShopCode, {
    String targetUserId = 'admin',
    UserRole role = UserRole.admin,
  }) async {
    final box = Hive.box<String>('settings');

    // 1. Force a final sync of the current shop's data ONLY if valid shop
    final currentShop = box.get('shopCode');
    if (currentShop != null && currentShop != 'host_admin') {
      await FirebaseSyncService().pushSync();
    }

    // 2. Connect to the target shop's Firebase data to ensure it exists
    try {
      final FirebaseSyncService syncService = FirebaseSyncService();
      if (!syncService.isEnabled) return 'No internet connection';

      final shopRef = FirebaseSyncService.instance.shopRef(
        targetShopCode.trim(),
      );
      final doc = await shopRef.get();
      if (!doc.exists) return 'Shop code not found';

      // 3. Cancel active background subscriptions before wiping the database
      FirebaseSyncService().cancelAllSubscriptions();

      // 4. Wipe local DB safely
      await _clearLocalDatabaseBoxes();

      // 5. Save settings from Firebase
      final data = doc.data()!;
      _saveSettingsFromFirebase(box, data, targetShopCode.trim());

      // 5. Set new shop code and flag
      box.put('shopCode', targetShopCode.trim());
      box.put('is_impersonating', 'true');
      FirebaseSyncService().refreshShopCode();

      // 6. Switch session to standard admin (or staff)
      final session = UserSession(
        id: targetUserId,
        name: role == UserRole.admin
            ? 'Admin ($targetShopCode)'
            : '$targetUserId ($targetShopCode)',
        role: role,
      );
      _saveSession(session, targetUserId);
      state = session;
      return null;
    } catch (e) {
      return 'Error impersonating shop: $e';
    }
  }

  void impersonateStaffInSameShop(
    String targetUserId,
    String staffName,
    UserRole role,
  ) {
    final box = Hive.box<String>('settings');
    final shopCode = box.get('shopCode') ?? '';

    final session = UserSession(
      id: targetUserId,
      name: role == UserRole.admin
          ? 'Admin ($shopCode)'
          : '$staffName ($shopCode)',
      role: role,
    );
    _saveSession(session, targetUserId);
    state = session;
  }

  Future<String?> returnToMasterAdmin() async {
    final box = Hive.box<String>('settings');

    // 1. Force a final sync of the impersonated shop's data to Firebase before wiping
    final currentShop = box.get('shopCode');
    if (currentShop != null && currentShop != 'host_admin') {
      await FirebaseSyncService().pushSync();
    }

    // 2. Cancel active background subscriptions before wiping the database
    FirebaseSyncService().cancelAllSubscriptions();

    // 3. Wipe local DB
    await _clearLocalDatabaseBoxes();

    // 4. Set host_admin shop code first.
    // IMPORTANT: Keep is_impersonating=true until AFTER refreshShopCode() is called.
    // This blocks pushSync() inside refreshShopCode() from firing during the
    // critical window when the Hive box is empty/wiped. Delete the flag right after.
    box.delete('logoutMessage');
    box.delete('forceLogoutFlag');
    box.put('shopCode', 'host_admin');
    box.put('is_impersonating', 'true'); // Keep flag alive to block pushSync
    FirebaseSyncService().refreshShopCode();
    box.delete('is_impersonating'); // Now safe to delete — refreshShopCode already ran

    // 5. Restore Customer Support session
    final session = UserSession(
      id: 'host_admin',
      name: 'Global Admin',
      role: UserRole.admin,
    );
    _saveSession(session, 'host_admin');
    state = session;
    return null;
  }
}

final authProvider = NotifierProvider<AuthNotifier, UserSession?>(() {
  return AuthNotifier();
});

class StaffAccountsNotifier extends Notifier<List<StaffAccount>> {
  @override
  List<StaffAccount> build() {
    final box = Hive.box<String>('settings');
    final sub = box.watch(key: 'staffAccountsJson').listen((_) {
      state = _loadStaff(box);
    });
    ref.onDispose(() => sub.cancel());
    return _loadStaff(box);
  }

  List<StaffAccount> _loadStaff(Box<String> box) {
    final jsonStr = box.get('staffAccountsJson');
    if (jsonStr == null) return [];
    try {
      final List<dynamic> decoded = json.decode(jsonStr);
      return decoded.map((item) => StaffAccount.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  String? addStaffAccount(
    String name,
    String username,
    String password,
    String role,
  ) {
    final trimmedUsername = username.trim().toLowerCase();
    if (state.any((s) => s.username.trim().toLowerCase() == trimmedUsername)) {
      return 'Staff username "$username" already exists!';
    }

    final newAccount = StaffAccount(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      username: username.trim(),
      password: base64.encode(utf8.encode(password)),
      role: role,
    );

    final updated = [...state, newAccount];
    _save(updated);
    return null;
  }

  void removeStaffAccount(String id) {
    final updated = state.where((s) => s.id != id).toList();
    _save(updated);
  }

  void updateStaffPassword(String id, String newPassword) {
    final updated = state.map((s) {
      if (s.id == id) {
        return StaffAccount(
          id: s.id,
          name: s.name,
          username: s.username,
          password: base64.encode(utf8.encode(newPassword)),
          role: s.role,
          permissions: s.permissions,
          isBlocked: s.isBlocked,
        );
      }
      return s;
    }).toList();
    _save(updated);
  }

  void updateStaffPermissions(String id, Map<String, bool> permissions) {
    final updated = state.map((s) {
      if (s.id == id) {
        return StaffAccount(
          id: s.id,
          name: s.name,
          username: s.username,
          password: s.password,
          role: s.role,
          permissions: permissions,
          isBlocked: s.isBlocked,
        );
      }
      return s;
    }).toList();
    _save(updated);
  }

  void toggleBlockStaffAccount(String id) {
    final updated = state.map((s) {
      if (s.id == id) {
        return StaffAccount(
          id: s.id,
          name: s.name,
          username: s.username,
          password: s.password,
          role: s.role,
          permissions: s.permissions,
          isBlocked: !s.isBlocked,
        );
      }
      return s;
    }).toList();
    _save(updated);
  }

  void _save(List<StaffAccount> list) {
    final box = Hive.box<String>('settings');
    final jsonStr = json.encode(list.map((s) => s.toJson()).toList());
    box.put('staffAccountsJson', jsonStr);
    state = list;
    // Use pushStaffOnly so permissions are always pushed to Firebase,
    // even during impersonation mode (safe — only updates the 'staff' field)
    FirebaseSyncService().pushStaffOnly();
  }
}

final staffAccountsProvider =
    NotifierProvider<StaffAccountsNotifier, List<StaffAccount>>(() {
      return StaffAccountsNotifier();
    });

extension UserSessionPermissions on UserSession {
  bool get hasCustomerDirectory =>
      role == UserRole.admin || (permissions?['customerDirectory'] ?? false);
  bool get hasInventory =>
      role == UserRole.admin || (permissions?['inventory'] ?? false);
  bool get hasStockManagement =>
      role == UserRole.admin || (permissions?['stockManagement'] ?? false);
  bool get hasRefund =>
      role == UserRole.admin || (permissions?['refund'] ?? false);
  bool get hasOrderHistory =>
      role == UserRole.admin || (permissions?['orderHistory'] ?? false);
  bool get hasEditBill =>
      role == UserRole.admin || (permissions?['editBill'] ?? false);
  bool get hasExpenses =>
      role == UserRole.admin || (permissions?['expenses'] ?? false);
}

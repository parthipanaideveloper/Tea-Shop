import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'domain/models/product.dart';
import 'domain/models/order.dart';
import 'domain/models/expense.dart';
import 'domain/models/refund_model.dart';
import 'providers/auth_provider.dart';
import 'providers/license_provider.dart';
import 'presentation/auth/register_screen.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/subscription_expired_screen.dart';
import 'presentation/auth/security_lock_screen.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/staff/staff_workspace_screen.dart';
import 'presentation/franchise/franchise_branch_selection_screen.dart';
import 'presentation/splash/splash_screen.dart';
import 'package:flutter/foundation.dart';
import 'services/firebase_sync_service.dart';
import 'services/security_service.dart';
import 'core/services/app_error_logger.dart';
import 'core/utils/ui_utils.dart';

Future<Box<T>> _openEncryptedBoxSafe<T>(String name, HiveAesCipher cipher) async {
  try {
    return await Hive.openBox<T>(name, encryptionCipher: cipher);
  } catch (e) {
    debugPrint('Safe Hive: Failed to open $name ($e). Resetting box...');
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (_) {}
    return await Hive.openBox<T>(name, encryptionCipher: cipher);
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Setup Global Error Listeners
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      AppErrorLogger.logError(
        details.exceptionAsString(),
        stackTrace: details.stack,
        context: 'FlutterFramework',
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppErrorLogger.logError(error, stackTrace: stack, context: 'AsyncPlatform');
      return true;
    };

    // Initialize Hive
    await Hive.initFlutter();

    // Open settings box early for Firebase Sync
    await Hive.openBox<String>('settings');

    final settingsBox = Hive.box<String>('settings');
    if (settingsBox.get('devicePrefix') == null) {
      final rnd = math.Random();
      final c1 = String.fromCharCode(65 + rnd.nextInt(26));
      final c2 = String.fromCharCode(65 + rnd.nextInt(26));
      await settingsBox.put('devicePrefix', '$c1$c2');
    }

    // Register Adapters
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(OrderAdapter());
    Hive.registerAdapter(ExpenseAdapter());
    Hive.registerAdapter(RefundModelAdapter());

    // Run security validation on startup before opening databases
    final securityService = SecurityService();
    final securityStatus = await securityService.checkAppIntegrity();

    // If a critical threat is found, boot into security lockdown directly
    if (securityStatus.hasThreat) {
      runApp(
        MaterialApp(
          title: 'DTS-POS',
          theme: AppTheme.enterpriseTheme,
          debugShowCheckedModeBanner: false,
          home: SecurityLockScreen(threatMessage: securityStatus.threatMessage),
        ),
      );
      return;
    }

    // Generate dynamic encryption key based on Android ID hardware fingerprint
    final deviceId = await securityService.getDeviceId();

    // Pad device ID to fit 32-byte key size needed by HiveAesCipher
    final rawKey = deviceId.padRight(32, 'DTS_SECURE_SALT').substring(0, 32);
    final encryptionKey = Uint8List.fromList(rawKey.codeUnits);

    // Open encrypted boxes safely to protect against cloning / database copy
    final cipher = HiveAesCipher(encryptionKey);
    await _openEncryptedBoxSafe<Product>('products', cipher);
    await _openEncryptedBoxSafe<OrderModel>('orders', cipher);
    await _openEncryptedBoxSafe<Expense>('expenses', cipher);
    await _openEncryptedBoxSafe<RefundModel>('refunds', cipher);

    // Store settings unencrypted or encrypted (using unencrypted for app metadata config lookup)
    // Settings box already opened above
    await Hive.openBox<String>('category_images');
    await Hive.openBox<String>('category_dietary');
    await Hive.openBox<bool>('category_status');
    await Hive.openBox<String>('product_images');
    await Hive.openBox<String>('product_translations');
    await Hive.openBox<String>('category_translations');
    await Hive.openBox<String>('customers');
    await Hive.openBox<String>('category_order');
    await Hive.openBox<String>('product_order');

    // Initialize Firebase safely (all boxes must be open before sync listeners start)
    // We initialize it in the background so it does not block the UI from opening if it hangs
    FirebaseSyncService().initialize().catchError((e) {
      debugPrint("Firebase async initialization error: $e");
    });

    runApp(const ProviderScope(child: POSApp()));
  } catch (e, stack) {
    try {
      final tempDir = Directory.systemTemp;
      final logFile = File('${tempDir.path}/dts_pos_crash_log.txt');
      logFile.writeAsStringSync('CRASH ERROR: $e\nSTACKTRACE: $stack\n');
    } catch (_) {}
    rethrow;
  }
}

class POSApp extends ConsumerStatefulWidget {
  const POSApp({super.key});

  @override
  ConsumerState<POSApp> createState() => _POSAppState();
}

class _POSAppState extends ConsumerState<POSApp> {
  bool _showSplash = true;

  bool _isSubscriptionExpired(LicenseState license) {
    // Hardcoded per user request: "free trial with no end date logic"
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseProvider);
    final session = ref.watch(authProvider);

    final isMasterAdmin = session?.id == 'host_admin';

    return ValueListenableBuilder<Box<String>>(
      valueListenable: Hive.box<String>(
        'settings',
      ).listenable(keys: ['subscriptionEnd', 'validUntil', 'isHostDevice']),
      builder: (context, box, child) {
        final subEndStr = box.get('subscriptionEnd');
        final validUntilStr = box.get('validUntil');

        DateTime? expirationDate;
        if (validUntilStr != null && validUntilStr.isNotEmpty) {
          expirationDate = DateTime.tryParse(validUntilStr);
        } else if (subEndStr != null && subEndStr.isNotEmpty) {
          expirationDate = DateTime.tryParse(subEndStr);
        }

        bool isExpired = false;
        if (expirationDate != null && DateTime.now().isAfter(expirationDate)) {
          // Host admin bypasses expiration lock so they can fix it
          if (!isMasterAdmin) {
            isExpired = true;
          }
        }

        Widget currentScreen;
        if (box.get('isHostDevice') == 'true') {
          // Customer Support bypasses registration screen entirely
          if (session == null) {
            currentScreen = const LoginScreen();
          } else if (session.role == UserRole.admin) {
            currentScreen = const HomeScreen();
          } else {
            currentScreen = const StaffWorkspaceScreen();
          }
        } else if (!license.isRegistered) {
          currentScreen = const RegisterScreen();
        } else if (session == null) {
          currentScreen = const LoginScreen();
        } else if (isExpired) {
          currentScreen = const SubscriptionExpiredScreen();
        } else {
          if (session.role == UserRole.franchiseOwner) {
            currentScreen = const FranchiseBranchSelectionScreen();
          } else if (session.role == UserRole.admin) {
            currentScreen = const HomeScreen();
          } else {
            currentScreen = const StaffWorkspaceScreen();
          }
        }

        if (_showSplash) {
          currentScreen = SplashScreen(
            onComplete: () {
              if (mounted) {
                setState(() {
                  _showSplash = false;
                });
              }
            },
          );
        }

        return MaterialApp(
          title: 'DTS-POS',
          theme: AppTheme.enterpriseTheme,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
            },
          ),
          debugShowCheckedModeBanner: false,
          navigatorKey: UiUtils.navigatorKey,
          scaffoldMessengerKey: UiUtils.scaffoldMessengerKey,
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey<bool>(_showSplash),
              child: currentScreen,
            ),
          ),
        );
      },
    );
  }
}

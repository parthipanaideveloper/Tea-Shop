import 'package:pos/core/utils/notification_helper.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pos/core/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/license_provider.dart';
import '../../core/extensions/string_extensions.dart';
import '../inventory/inventory_screen.dart';
import '../checkout/checkout_screen.dart';
import '../../providers/cart_provider.dart';
import '../analytics/analytics_screen.dart';
import 'dashboard_screen.dart';
import '../settings/settings_screen.dart';
import 'package:pos/presentation/settings/printer_settings_screen.dart';
import '../admin/staff_management_screen.dart';
import '../admin/license_settings_screen.dart';
import '../master_admin/master_admin_screen.dart';
import '../master_admin/support_settings_screen.dart';
import '../master_admin/global_inventory_screen.dart';
import '../master_admin/master_admin_shell.dart';
import 'franchise_management_screen.dart';
import '../../providers/printer_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/firebase_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'desktop_dashboard_shell.dart';
import '../../core/hardware/printer_service.dart';
import '../../providers/order_provider.dart';
import '../../domain/models/order.dart';
import '../../domain/models/cart_item.dart';
import '../../domain/models/product.dart';
import '../../providers/inventory_provider.dart';

class NavigationNotifier extends Notifier<String> {
  @override
  String build() => 'overview';
}
final globalNavigationProvider = NotifierProvider<NavigationNotifier, String>(() => NavigationNotifier());

enum NumpadState { awaitingItem, awaitingQuantity }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final List<String> _navigationHistory = ['overview'];
  bool _hasAttemptedAutoConnect = false;
  NumpadState _numpadState = NumpadState.awaitingItem;
  Product? _selectedProduct;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoConnectPrinter();
      _checkSubscriptionAlert();
      _pingLastSeen();
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final char = event.character;
      
      // Enter Key
      if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _processInstantKey('Enter');
        return true;
      }
      
      // Clear/Reset Key (Backspace or 0)
      if (event.logicalKey == LogicalKeyboardKey.backspace || char == '0' || event.logicalKey == LogicalKeyboardKey.digit0 || event.logicalKey == LogicalKeyboardKey.numpad0) {
        _processInstantKey('Clear');
        return true;
      }

      // Check digits 1-9
      if (char != null && char.length == 1 && int.tryParse(char) != null && char != '0') {
         _processInstantKey(char);
         return true;
      }

      // Fallback for logical keys if character is null
      if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) { _processInstantKey('1'); return true; }
      if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) { _processInstantKey('2'); return true; }
      if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) { _processInstantKey('3'); return true; }
      if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) { _processInstantKey('4'); return true; }
      if (event.logicalKey == LogicalKeyboardKey.digit5 || event.logicalKey == LogicalKeyboardKey.numpad5) { _processInstantKey('5'); return true; }
      if (event.logicalKey == LogicalKeyboardKey.digit6 || event.logicalKey == LogicalKeyboardKey.numpad6) { _processInstantKey('6'); return true; }
      if (event.logicalKey == LogicalKeyboardKey.digit7 || event.logicalKey == LogicalKeyboardKey.numpad7) { _processInstantKey('7'); return true; }
      if (event.logicalKey == LogicalKeyboardKey.digit8 || event.logicalKey == LogicalKeyboardKey.numpad8) { _processInstantKey('8'); return true; }
      if (event.logicalKey == LogicalKeyboardKey.digit9 || event.logicalKey == LogicalKeyboardKey.numpad9) { _processInstantKey('9'); return true; }
    }
    return false;
  }

  void _processInstantKey(String key) async {
    if (key == 'Clear') {
       _numpadState = NumpadState.awaitingItem;
       _selectedProduct = null;
       ref.read(cartProvider.notifier).clearCart();
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart Cleared!'), backgroundColor: Colors.red));
       }
       return;
    }

    if (key == 'Enter') {
       _processCheckoutAndPrint();
       return;
    }

    // It's a number key (1-9)
    if (_numpadState == NumpadState.awaitingItem) {
        final allProducts = ref.read(inventoryProvider);
        Product? targetProduct;
        switch (key) {
          case '1': targetProduct = allProducts.where((p) => p.name.contains('Coffee') && !p.name.contains('Parcel')).firstOrNull; break;
          case '2': targetProduct = allProducts.where((p) => p.name.contains('Single Tea')).firstOrNull; break;
          case '3': targetProduct = allProducts.where((p) => p.name.contains('Ginger Tea')).firstOrNull; break;
          case '4': targetProduct = allProducts.where((p) => p.name == 'Parcel Tea').firstOrNull; break;
          case '5': targetProduct = allProducts.where((p) => p.name.contains('Parcel Coffee')).firstOrNull; break;
          case '6': targetProduct = allProducts.where((p) => p.name.contains('Cool Drink Small')).firstOrNull; break;
          case '7': targetProduct = allProducts.where((p) => p.name.contains('Water Bottle 10')).firstOrNull; break;
        }

        if (targetProduct != null) {
            _selectedProduct = targetProduct;
            _numpadState = NumpadState.awaitingQuantity;
            if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${targetProduct.name} Selected. Enter Quantity.'), backgroundColor: Colors.orange, duration: const Duration(milliseconds: 1000)));
            }
        }
    } else if (_numpadState == NumpadState.awaitingQuantity) {
        int? qty = int.tryParse(key);
        if (qty != null && qty > 0 && _selectedProduct != null) {
            // Add to cart N times
            for (int i = 0; i < qty; i++) {
               ref.read(cartProvider.notifier).addProduct(_selectedProduct!);
            }
            
            // Ensure we are on Checkout screen
            final currentRoute = ref.read(globalNavigationProvider);
            if (currentRoute != 'checkout') {
               ref.read(globalNavigationProvider.notifier).state = 'checkout';
               setState(() {
                 _navigationHistory.remove('checkout');
                 _navigationHistory.add('checkout');
               });
            }

            if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $qty x \${_selectedProduct!.name}'), backgroundColor: Colors.blueAccent, duration: const Duration(milliseconds: 1000)));
            }
            
            // Reset state for next item
            _selectedProduct = null;
            _numpadState = NumpadState.awaitingItem;
        }
    }
  }

  Future<void> _processCheckoutAndPrint() async {
      final cartState = ref.read(cartProvider);
      if (cartState.items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty!'), backgroundColor: Colors.red));
        }
        return;
      }

      final orderNotifier = ref.read(orderProvider.notifier);
      final newOrderId = orderNotifier.generateNextOrderId();
      final session = ref.read(authProvider);
      final staffName = session?.name ?? 'Admin';
      
      final subtotal = cartState.subtotal;
      
      // Save order
      await orderNotifier.saveOrder(
        items: cartState.items,
        total: subtotal,
        subtotal: subtotal,
        tax: 0,
        discount: 0,
        paymentMode: 'CASH',
        paymentStatus: 'PAID',
        customerName: '',
        customerPhone: '',
        staffName: staffName,
        orderType: 'DINE',
        dineTableNo: '',
        id: newOrderId,
      );

      // Print Simple Receipt
      final settings = ref.read(settingsProvider);
      final receiptBytes = await PrinterService.generateReceiptBytes(
        items: cartState.items,
        subtotal: subtotal,
        tax: 0,
        discount: 0,
        total: subtotal,
        shopName: settings.shopName,
        receiptHeader: '',
        receiptFooter: '',
        showGstOnReceipt: false,
        gstNumber: '',
        isUnpaid: false,
        orderId: newOrderId,
        tableNo: '',
        orderType: 'DINE',
        customerName: '',
        customerPhone: '',
        printAsImage: settings.printAsImage,
        is80mmPaper: settings.is80mmPaper,
        parcelToken: null,
        addressLine1: '',
        addressLine2: '',
        hotelType: '',
        mobileNumber: '',
        fssaiNumber: '',
        enableAddressOnReceipt: false,
        enableMobileOnReceipt: false,
        enableFssaiOnReceipt: false,
        enableHotelTypeOnReceipt: false,
      );

      if (receiptBytes != null) {
        await ref.read(printerProvider.notifier).printReceipt(receiptBytes);
      }

      // Reset everything
      ref.read(cartProvider.notifier).clearCart();
      _numpadState = NumpadState.awaitingItem;
      _selectedProduct = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order Checked Out & Printed!'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 1500),
          )
        );
      }
  }

  /// Tells Firestore this shop is active right now — powers the Live Network Pulse on master admin dashboard.
  void _pingLastSeen() {
    final shopCode = Hive.box<String>('settings').get('shopCode') ?? '';
    if (shopCode.isNotEmpty) {
      FirebaseSyncService().updateLastSeen(shopCode);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tryAutoConnectPrinter(force: true);
      _pingLastSeen(); // Refresh pulse whenever app comes back to foreground
    }
  }

  Future<void> _checkSubscriptionAlert() async {
    final license = ref.read(licenseProvider);
    if (!license.isRegistered) return;

    DateTime? expirationDate;
    if (license.subscriptionEnd != null) {
      expirationDate = license.subscriptionEnd;
    } else if (license.trialStartDate != null) {
      expirationDate = license.trialStartDate!.add(const Duration(days: 14));
    }
    if (expirationDate == null) return;

    final daysRemaining = expirationDate.difference(DateTime.now()).inDays;
    if (![7, 5, 3, 1].contains(daysRemaining)) return;

    final box = Hive.box<String>('settings');
    final todayStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final key = 'alertCount_$todayStr';
    final countStr = box.get(key) ?? '0';
    final count = int.tryParse(countStr) ?? 0;

    if (count < 3) {
      await box.put(key, (count + 1).toString());
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 32),
                const SizedBox(width: 8),
                const Text(
                  'Subscription Alert',
                  style: TextStyle(color: Colors.red)),
              ]),
            content: Text(
              'Your POS Subscription will expire in $daysRemaining days!\n\nPlease contact the administrator to renew your license and avoid system lockout.',
              style: const TextStyle(fontSize: 16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16))));
      }
    }
  }

  Future<void> _tryAutoConnectPrinter({bool force = false}) async {
    if (_hasAttemptedAutoConnect && !force) return;
    _hasAttemptedAutoConnect = true;

    // Check if already connected before attempting
    final printerState = ref.read(printerProvider);
    if (printerState.connectedDevice != null) return;

    final connected = await ref.read(printerProvider.notifier).autoConnect();
    if (!connected && mounted && !force) {
      final settings = ref.read(settingsProvider);
      if (settings.savedPrinterMacAddress == null ||
          settings.savedPrinterMacAddress!.isEmpty) {
        NotificationHelper.showCenter(context, 'Printer Not Connected! Please pair the printer device.', isError: true);
      } else {
        NotificationHelper.showCenter(context, 'Please pair the printer device. Auto-connect failed.', isError: true);
      }
    }
  }

  int _routeToIndex(String route, bool showInventory) {
    switch (route) {
      case 'overview': return 0;
      case 'checkout': return 1;
      case 'inventory': return showInventory ? 2 : -1;
      case 'analytics': return showInventory ? 3 : 2;
      default: return 0;
    }
  }

  String _indexToRoute(int index, bool showInventory) {
    if (index == 0) return 'overview';
    if (index == 1) return 'checkout';
    if (showInventory) {
      if (index == 2) return 'inventory';
      if (index == 3) return 'analytics';
    } else {
      if (index == 2) return 'analytics';
    }
    return 'overview';
  }

  void _onNavigate(int index) {
    final showInventory = ref.read(authProvider)?.hasInventory == true;
    final currentRoute = ref.read(globalNavigationProvider);
    final newRoute = _indexToRoute(index, showInventory);
    if (currentRoute == newRoute) return;
    
    ref.read(globalNavigationProvider.notifier).state = newRoute;
    setState(() {
      _navigationHistory.remove(newRoute);
      _navigationHistory.add(newRoute);
    });
    // Reset cart to initial DINE/PARCEL screen when leaving checkout
    ref.read(cartProvider.notifier).clearCart();
  }

  List<Widget> _getScreens(bool showInventory) => [
    DashboardScreen(onNavigate: _onNavigate),
    const CheckoutScreen(),
    if (showInventory) const InventoryScreen(),
    const AnalyticsScreen(),
  ];

  Widget? _buildSubscriptionWarningBanner() {
    final license = ref.watch(licenseProvider);
    if (!license.isRegistered) return null;

    int daysRemaining = 0;
    bool isTrial = true;
    bool isExpired = false;

    if (license.subscriptionEnd != null) {
      isTrial = false;
      daysRemaining = license.subscriptionEnd!
          .difference(DateTime.now())
          .inDays;
      if (daysRemaining < 0) isExpired = true;
    } else if (license.trialStartDate != null) {
      isTrial = true;
      final trialEnd = license.trialStartDate!.add(const Duration(days: 14));
      daysRemaining = trialEnd.difference(DateTime.now()).inDays;
      if (daysRemaining < 0) isExpired = true;
    }

    if (isExpired) return null; // Handled by global gate
    if (daysRemaining > 30) return null; // No warnings needed

    Color bannerColor;
    Color textColor;
    IconData icon;
    String message;

    if (daysRemaining <= 2) {
      bannerColor = Colors.red.shade50;
      textColor = Colors.red.shade900;
      icon = Icons.warning_amber_rounded;
      message = isTrial
          ? 'URGENT: 14-Day Free Trial expires in $daysRemaining days! Please activate a license.'
          : 'URGENT: POS Subscription expires in $daysRemaining days! Please contact support to renew.';
    } else if (daysRemaining <= 7) {
      bannerColor = Colors.orange.shade50;
      textColor = Colors.orange.shade900;
      icon = Icons.warning_amber_rounded;
      message = isTrial
          ? 'Warning: 14-Day Free Trial expires in $daysRemaining days. Activate soon to avoid lockout.'
          : 'Warning: POS Subscription expires in $daysRemaining days. Renew soon to avoid lockout.';
    } else {
      bannerColor = Colors.amber.shade50;
      textColor = Colors.amber.shade900;
      icon = Icons.info_outline;
      message = isTrial
          ? 'Notice: 14-Day Free Trial expires in $daysRemaining days.'
          : 'Notice: POS Subscription expires in $daysRemaining days. Please contact support to renew.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: bannerColor,
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 13))),
        ]));
  }

  // Local getLogoProvider removed in favor of UiUtils

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(authProvider);
    
    final isMasterAdmin = session?.id == 'host_admin' || Hive.box<String>('settings').get('is_impersonating') == 'true';
    final isFranchiseOwner = Hive.box<String>('settings').get('franchisePhone') != null && session?.role == UserRole.admin;

    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;
    final useNavigationRail = screenWidth >= 600 || isLandscape;
    final showSidebarLabels = false;


    final isDesktopWidth = MediaQuery.of(context).size.width >= 1024;
    final isDesktopPlatform = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    
    if (session?.id == 'host_admin' && Hive.box<String>('settings').get('is_impersonating') != 'true') {
      return const MasterAdminShell();
    }
    
    if (isDesktopPlatform && isDesktopWidth) {
      return const DesktopDashboardShell();
    }


    // Auto-hide system status bar in landscape for max space
    if (isLandscape) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    final warningBanner = _buildSubscriptionWarningBanner();

    final currentRoute = ref.watch(globalNavigationProvider);
    final showInventoryForNav = session?.hasInventory == true;
    final int selectedIndex = _routeToIndex(currentRoute, showInventoryForNav);

    final activeColor = switch (selectedIndex) {
      0 => Colors.blueAccent,
      1 => Colors.teal,
      2 => Colors.orange,
      3 => Colors.deepPurple,
      _ => Colors.blueAccent,
    };

    final String pageTitle = switch (selectedIndex) {
      0 => 'Dashboard'.tr(ref.watch(languageProvider)),
      1 => 'Checkout'.tr(ref.watch(languageProvider)),
      2 => 'Inventory'.tr(ref.watch(languageProvider)),
      3 => 'Reports & Analytics'.tr(ref.watch(languageProvider)),
      _ => '',
    };

    // The Global AppBar Fixed at the Top
    final appBar = AppBar(
      backgroundColor: false ? Colors.transparent : const Color(0xFF0EA5E9), // Premium Light Blue
      elevation: 0,
      toolbarHeight: isLandscape ? 36 : 56,
      centerTitle: true,
      iconTheme: IconThemeData(color: false ? const Color(0xFF1E293B) : Colors.white),
      leading: (currentRoute == 'overview' || false)
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (_navigationHistory.length > 1) {
                  setState(() {
                    _navigationHistory.removeLast();
                    ref.read(globalNavigationProvider.notifier).state = _navigationHistory.last;
                  });
                } else {
                  ref.read(globalNavigationProvider.notifier).state = 'overview';
                  setState(() => _navigationHistory.add('overview'));
                }
              },
            ),
      title: false
          ? const Text(
              '👑 CUSTOMER SUPPORT',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                letterSpacing: 1.5,
                fontSize: 20))
          : Text(
              pageTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 20)),
      actions: [
        if (true)
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Colors.white),
            tooltip: 'Printer Setup',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()));
            },
          ),
        if (true)
          GestureDetector(
            onTap: () {
              Navigator.popUntil(context, (route) => route.isFirst);
              _onNavigate(0); // Navigate to Dashboard
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 4.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: UiUtils.getLogoProvider(settings.shopLogoPath),
                child: settings.shopLogoPath == null || settings.shopLogoPath!.isEmpty
                    ? const Icon(Icons.store, color: Color(0xFF64748B), size: 16)
                    : null,
              ),
            ),
          )
      ],
    );

    // The Global App Drawer with System Options
    // Premium App Drawer
    final drawer = Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          if (false)
            // Clean Customer Support Drawer Header
            Container(
              padding: const EdgeInsets.only(top: 60, bottom: 24, left: 24, right: 24),
              width: double.infinity,
              color: Colors.black,
              child: const Text(
                '👑 CUSTOMER SUPPORT',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)))
          else
            // Premium Header for Normal Admin
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 20, left: 24, right: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                      ]),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      backgroundImage: UiUtils.getLogoProvider(settings.shopLogoPath),
                      child: settings.shopLogoPath == null
                          ? Icon(
                              Icons.store,
                              color: Theme.of(context).colorScheme.primary,
                              size: 32)
                          : null)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.shopName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            'Code: ${Hive.box<String>('settings').get('shopCode') ?? 'Not Set'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600))),
                      ])),
                ])),
          
          // Drawer Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (isFranchiseOwner) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
                    child: Text(
                      'FRANCHISE DASHBOARD',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2))),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.swap_horiz, color: Colors.blue, size: 20)),
                      title: const Text(
                        'Switch Branch',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                      hoverColor: Colors.blue.withOpacity(0.05),
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(authProvider.notifier).returnToFranchiseDashboard();
                      })),
                  const Divider(height: 24),
                ],

                if (false) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
                    child: Text(
                      'CUSTOMER SUPPORT',
                      style: TextStyle(
                        color: Colors.deepPurple.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2))),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.inventory_2_rounded, color: Colors.deepPurple, size: 20)),
                      title: const Text(
                        'Global Inventory',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                      hoverColor: Colors.deepPurple.withOpacity(0.05),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GlobalInventoryScreen()));
                      })),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.business_center, color: Colors.deepPurple, size: 20)),
                      title: const Text(
                        'Manage Franchise Owners',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                      hoverColor: Colors.deepPurple.withOpacity(0.05),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FranchiseManagementScreen()));
                      })),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.store_mall_directory_rounded, color: Colors.redAccent, size: 20)),
                      title: const Text(
                        'Shop Management',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                      hoverColor: Colors.redAccent.withValues(alpha: 0.05),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MasterAdminScreen(directLoginMode: false)));
                      })),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.login_rounded, color: Colors.blue, size: 20)),
                      title: const Text(
                        'View Shops Console',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                      hoverColor: Colors.blue.withValues(alpha: 0.05),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MasterAdminScreen(directLoginMode: true)));
                      })),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
                    child: Text(
                      'MAIN NAVIGATION',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2))),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.dashboard_rounded, color: Colors.blueAccent, size: 20)),
                      title: const Text(
                        'Dashboard',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                      hoverColor: Colors.blueAccent.withValues(alpha: 0.05),
                      onTap: () {
                        Navigator.pop(context);
                        _onNavigate(0);
                      })),
                  
                  const SizedBox(height: 16),
                  if (ref.watch(authProvider)?.role == UserRole.admin) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
                      child: Text(
                        'MANAGEMENT',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2))),
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.people_rounded, color: Colors.orange, size: 20)),
                        title: const Text(
                          'Staff Management',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                        hoverColor: Colors.orange.withValues(alpha: 0.05),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const StaffManagementScreen()));
                        })),

                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.print_rounded, color: Colors.teal, size: 20)),
                        title: const Text(
                          'Printer Setup',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                        hoverColor: Colors.teal.withValues(alpha: 0.05),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()));
                        })),
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade600.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.settings_rounded, color: Colors.grey.shade700, size: 20)),
                        title: const Text(
                          'Settings',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                        hoverColor: Colors.grey.withValues(alpha: 0.05),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        })),
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.workspace_premium_rounded, color: Colors.green, size: 20)),
                        title: const Text(
                          'Subscription & License',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                        hoverColor: Colors.green.withValues(alpha: 0.05),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LicenseSettingsScreen()));
                        })),
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.backup_rounded, color: Colors.blue, size: 20)),
                        title: const Text(
                          'Backup Database',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                        trailing: const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.grey),
                        hoverColor: Colors.blue.withValues(alpha: 0.05),
                        onTap: () async {
                          Navigator.pop(context);
                          NotificationHelper.showCenter(context, 'Starting database backup...', isError: false);
                          await FirebaseSyncService().pushSync();
                          if (context.mounted) {
                            NotificationHelper.showCenter(context, 'Database backed up successfully!', isError: false);
                          }
                        })),
                  ],
                ],
                
                if (Hive.box<String>('settings').get('is_impersonating') == 'true') ...[
                  const Divider(height: 32),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Impersonating:\n${Hive.box<String>('settings').get('shopCode') ?? ''}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.amber.shade900))),
                          ]),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade900,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                          onPressed: () async {
                            Navigator.pop(context); // close drawer
                            
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator()));
                            
                            final error = await ref.read(authProvider.notifier).returnToMasterAdmin();
                            
                            if (context.mounted) {
                              Navigator.pop(context); // Close loading indicator
                              if (error != null) {
                                NotificationHelper.showCenter(context, error, isError: true);
                              } else {
                                NotificationHelper.showCenter(context, 'Returned to Customer Support', isError: false);
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              }
                            }
                          },
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text(
                            'Exit Impersonation',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                      ])),
                ],

                const SizedBox(height: 16),
                if (isMasterAdmin)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.settings, color: Colors.amber, size: 20)),
                      title: const Text(
                        'Customer Support Settings',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                      hoverColor: Colors.amber.withOpacity(0.05),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SupportSettingsScreen()));
                      })),

                const Divider(height: 32),
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20)),
                    title: const Text(
                      'Logout',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.redAccent)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                    hoverColor: Colors.redAccent.withValues(alpha: 0.05),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Log Out'),
                          content: const Text(
                            'Are you sure you want to log out of Admin mode?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white),
                              onPressed: () {
                                ref.read(authProvider.notifier).logout();
                                Navigator.pop(context);
                              },
                              child: const Text('Log Out')),
                          ]));
                    })),
              ])),
          
          // Footer removed as requested
        ]));

    final showInventory = ref.watch(authProvider)?.hasInventory == true;
    final currentScreens = _getScreens(showInventory);
    
    // Fallback to dashboard if out of bounds or missing
    final activeIndex = (selectedIndex >= 0 && selectedIndex < currentScreens.length) ? selectedIndex : 0;

    final mainScaffold = useNavigationRail
        ? Scaffold(
            appBar: isLandscape ? null : appBar,
            drawer: drawer,
            body: Column(
              children: [
                if (warningBanner != null) warningBanner,
                Expanded(
                  child: Row(
                    children: [
                      if (true)
                        Builder(
                          builder: (ctx) => _PopOutSidebar(
                            selectedIndex: activeIndex,
                            onDestinationSelected: _onNavigate,
                            activeColor: activeColor,
                            isLandscape: isLandscape,
                            onOpenDrawer: () => Scaffold.of(ctx).openDrawer(),
                            showInventory: showInventory,
                            language: ref.watch(languageProvider),
                            showLabels: showSidebarLabels,
                          ),
                        ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.05, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey<int>(activeIndex),
                            child: currentScreens[activeIndex],
                          ),
                        ),
                      ),
                    ])),
              ]))
        : Scaffold(
            appBar: isLandscape ? null : appBar,
            drawer: drawer,
            body: Column(
              children: [
                if (warningBanner != null) warningBanner,
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(activeIndex),
                      child: currentScreens[activeIndex],
                    ),
                  ),
                ),
              ]),
            bottomNavigationBar: false ? null : NavigationBar(
                selectedIndex: activeIndex,
                onDestinationSelected: _onNavigate,
                backgroundColor: Colors.white,
                indicatorColor: activeColor.withOpacity(0.15),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: Icon(
                      Icons.home,
                      color: activeIndex == 0 ? activeColor : null),
                    label: 'Dashboard'.tr(ref.watch(languageProvider))),
                  NavigationDestination(
                    icon: const Icon(Icons.point_of_sale_outlined),
                    selectedIcon: Icon(
                      Icons.point_of_sale,
                      color: activeIndex == 1 ? activeColor : null),
                    label: 'Checkout'.tr(ref.watch(languageProvider))),
                  if (showInventory)
                    NavigationDestination(
                      icon: const Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(
                        Icons.inventory_2,
                        color: activeIndex == 2 ? activeColor : null),
                      label: 'Inventory'.tr(ref.watch(languageProvider))),
                  NavigationDestination(
                    icon: const Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(
                      Icons.bar_chart,
                      color: activeIndex == (showInventory ? 3 : 2)
                          ? activeColor
                          : null),
                    label: 'Analytics'.tr(ref.watch(languageProvider))),
              ]));

    return PopScope(
      canPop: activeIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        setState(() {
          _navigationHistory.removeLast();
          ref.read(globalNavigationProvider.notifier).state = _navigationHistory.last;
        });
      },
      child: mainScaffold);
  }
}

class _PopOutSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Color activeColor;
  final bool isLandscape;
  final VoidCallback onOpenDrawer;
  final bool showInventory;
  final String language;
  final bool showLabels;

  const _PopOutSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.activeColor,
    required this.isLandscape,
    required this.onOpenDrawer,
    required this.showInventory,
    required this.language,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = [
      {'icon': Icons.home_outlined, 'activeIcon': Icons.home, 'label': 'Dashboard'.tr(language), 'color': Colors.blue},
      {'icon': Icons.point_of_sale_outlined, 'activeIcon': Icons.point_of_sale, 'label': 'Checkout'.tr(language), 'color': Colors.teal},
      if (showInventory)
        {'icon': Icons.inventory_2_outlined, 'activeIcon': Icons.inventory_2, 'label': 'Inventory'.tr(language), 'color': Colors.grey.shade600},
      {'icon': Icons.bar_chart_outlined, 'activeIcon': Icons.bar_chart, 'label': 'Analytics'.tr(language), 'color': Colors.grey.shade600},
    ];

    return Container(
      width: showLabels ? 90 : 70,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // Soft gray background
        border: Border(
          right: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
        ),
      ),
      child: Column(
        children: [
          if (isLandscape)
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
              child: IconButton(
                icon: const Icon(Icons.menu, color: Colors.black87),
                onPressed: onOpenDrawer,
              ),
            )
          else
            const SizedBox(height: 32),
            
          ...List.generate(destinations.length, (index) {
            final isSelected = selectedIndex == index;
            final dest = destinations[index];
            final itemColor = dest['color'] as Color;
            
            return GestureDetector(
              onTap: () => onDestinationSelected(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  height: showLabels ? 75 : 60,
                  width: double.infinity,
                  transform: isSelected ? (Matrix4.identity()..translate(0.0, -2.0)) : Matrix4.identity(),
                  decoration: BoxDecoration(
                    color: isSelected ? itemColor.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? itemColor.withOpacity(0.3) : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: itemColor.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? dest['activeIcon'] as IconData : dest['icon'] as IconData,
                        color: isSelected ? itemColor : Colors.black87,
                        size: isSelected ? 26 : 24,
                      ),
                      if (showLabels) ...[
                        const SizedBox(height: 6),
                        Text(
                          dest['label'] as String,
                          style: TextStyle(
                            color: isSelected ? itemColor : Colors.black87,
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

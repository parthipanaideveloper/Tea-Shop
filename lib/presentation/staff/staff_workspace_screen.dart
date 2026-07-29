import 'package:pos/core/utils/notification_helper.dart';
import 'package:pos/core/utils/ui_utils.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../checkout/checkout_screen.dart';
import '../customers/customers_screen.dart';
import '../settings/printer_settings_screen.dart';
import '../refund/refund_screen.dart';
import 'quick_stock_edit_screen.dart';
import 'staff_order_history_screen.dart';
import '../../services/firebase_sync_service.dart';
import '../../providers/printer_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/language_provider.dart';
import '../../core/extensions/string_extensions.dart';
import '../inventory/inventory_screen.dart';
import '../expenses/expense_adder_screen.dart';

class StaffBillingScreen extends ConsumerStatefulWidget {
  const StaffBillingScreen({super.key});

  @override
  ConsumerState<StaffBillingScreen> createState() => _StaffBillingScreenState();
}

class _StaffBillingScreenState extends ConsumerState<StaffBillingScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    return Scaffold(
      appBar: isLandscape
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: theme.colorScheme.primary),
              title: Text(
                'Checkout Billing Terminal'.tr(ref.watch(languageProvider)),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                  fontSize: 20)),
              actions: [
                GestureDetector(
                  onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: UiUtils.getLogoProvider(ref.watch(settingsProvider).shopLogoPath),
                      child: ref.watch(settingsProvider).shopLogoPath == null || ref.watch(settingsProvider).shopLogoPath!.isEmpty
                          ? const Icon(Icons.store, color: Color(0xFF64748B), size: 16)
                          : null,
                    ),
                  ),
                )
              ]),
      body: SafeArea(
        child: Stack(
          children: [
            const CheckoutScreen(),
            if (isLandscape)
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                  color: Colors.grey.shade700,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 2))),
          ])));
  }
}

class StaffWorkspaceScreen extends ConsumerStatefulWidget {
  const StaffWorkspaceScreen({super.key});

  @override
  ConsumerState<StaffWorkspaceScreen> createState() =>
      _StaffWorkspaceScreenState();
}

class _StaffWorkspaceScreenState extends ConsumerState<StaffWorkspaceScreen> {
  bool _hasAttemptedAutoConnect = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoConnectPrinter();
    });
  }

  Future<void> _tryAutoConnectPrinter() async {
    if (_hasAttemptedAutoConnect) return;
    _hasAttemptedAutoConnect = true;

    final connected = await ref.read(printerProvider.notifier).autoConnect();
    if (!connected && mounted) {
      final settings = ref.read(settingsProvider);
      if (settings.savedPrinterMacAddress == null ||
          settings.savedPrinterMacAddress!.isEmpty) {
        NotificationHelper.showCenter(context, 'Printer Not Connected! Please pair the printer device.', isError: true);
      } else {
        NotificationHelper.showCenter(context, 'Please pair the printer device. Auto-connect failed.', isError: true);
      }
    }
  }

  ImageProvider? _getLogoProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.length < 255 && File(path).existsSync()) {
      return FileImage(File(path));
    }
    try {
      return MemoryImage(base64Decode(path));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(authProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isMobileLandscape =
        isLandscape && MediaQuery.of(context).size.shortestSide < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        toolbarHeight: isMobileLandscape ? 40 : 64,
        backgroundColor: const Color(0xFF0F172A), // Enterprise Slate-900
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFF1E293B),
            height: 1.0,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 1),
                ]),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: _getLogoProvider(settings.shopLogoPath),
                child: settings.shopLogoPath == null
                    ? Icon(
                        Icons.store,
                        color: theme.colorScheme.primary,
                        size: 20)
                    : null)),
            const SizedBox(width: 12),
            Text(
              settings.shopName.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white,
                fontSize: 18,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2)),
                ])),
          ]),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: ref.read(authProvider.notifier).directLoginMode ? const Color(0xFFEF4444).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: Icon(
                ref.read(authProvider.notifier).directLoginMode ? Icons.exit_to_app : Icons.logout,
                color: ref.read(authProvider.notifier).directLoginMode ? const Color(0xFFEF4444) : Colors.white,
                size: 22,
              ),
              tooltip: ref.read(authProvider.notifier).directLoginMode ? 'Exit Impersonation' : 'Log Out',
              onPressed: () {
                if (ref.read(authProvider.notifier).directLoginMode) {
                  ref.read(authProvider.notifier).returnToMasterAdmin();
                } else {
                  ref.read(authProvider.notifier).logout();
                }
              })),
          const SizedBox(width: 4),
        ]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFF1F5F9),
                      child: Icon(Icons.person_outline, color: Color(0xFF64748B), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Hello, '.tr(ref.watch(languageProvider)) + '${(session?.name ?? "Staff").split('(')[0].trim()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'POS Terminal'.tr(ref.watch(languageProvider)),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terminal Operations'.tr(ref.watch(languageProvider)),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'EN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: ref.watch(languageProvider) == 'en'
                              ? theme.colorScheme.primary
                              : Colors.grey)),
                      Switch(
                        value: ref.watch(languageProvider) == 'ta',
                        onChanged: (val) {
                          ref
                              .read(languageProvider.notifier)
                              .setLanguage(val ? 'ta' : 'en');
                        },
                        activeColor: theme.colorScheme.primary),
                      Text(
                        'தமிழ்',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: ref.watch(languageProvider) == 'ta'
                              ? theme.colorScheme.primary
                              : Colors.grey)),
                    ]),
                ]),
              const SizedBox(height: 12),

              // Staff Action Cards Layout
              // Staff Action Cards Layout
              Expanded(
                child: Builder(
                  builder: (context) {
                    final customerDir = session?.hasCustomerDirectory == true;
                    final inventory = session?.hasInventory == true;
                    final stock = session?.hasStockManagement == true;
                    final refund = session?.hasRefund == true;
                    final orderHistory = session?.hasOrderHistory == true;
                    final expenses = session?.hasExpenses == true;

                    final int activeCardCount =
                        2 + // Billing and Printer
                        (customerDir ? 1 : 0) +
                        (inventory ? 1 : 0) +
                        (stock ? 1 : 0) +
                        (refund ? 1 : 0) +
                        (orderHistory ? 1 : 0) +
                        (expenses ? 1 : 0);
                    final bool isLandscape = activeCardCount <= 3;

                    final cards = [
                      // Billing Terminal Card
                      _buildActionCard(
                        context: context,
                        isLandscape: isLandscape,
                        title: 'Billing Terminal'.tr(
                          ref.watch(languageProvider)),
                        icon: Icons.point_of_sale,
                        color1: Colors.teal.shade500,
                        color2: Colors.teal.shade700,
                        onTap: () {
                          ref.read(cartProvider.notifier).clearCart();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StaffBillingScreen()));
                        }),
                      // Inventory Management Card (Conditional)
                      if (inventory)
                        _buildActionCard(
                          context: context,
                          isLandscape: isLandscape,
                          title: 'Inventory Management'.tr(
                            ref.watch(languageProvider)),
                          icon: Icons.category_outlined,
                          color1: Colors.deepPurple.shade500,
                          color2: Colors.deepPurple.shade700,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InventoryScreen()));
                          }),
                      // Customer Management Card (Conditional)
                      if (customerDir)
                        _buildActionCard(
                          context: context,
                          isLandscape: isLandscape,
                          title: 'Customers Directory'.tr(
                            ref.watch(languageProvider)),
                          icon: Icons.people_outline,
                          color1: Colors.blue.shade500,
                          color2: Colors.blue.shade700,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CustomersScreen()));
                          }),
                      // Quick Stock Adjustment Card
                      if (stock)
                        _buildActionCard(
                          context: context,
                          isLandscape: isLandscape,
                          title: 'Quick Stock Adjustment'.tr(
                            ref.watch(languageProvider)),
                          icon: Icons.inventory_2_outlined,
                          color1: Colors.orange.shade500,
                          color2: Colors.orange.shade700,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const QuickStockEditScreen()));
                          }),
                      // Printer Setup Card
                      _buildActionCard(
                        context: context,
                        isLandscape: isLandscape,
                        title: 'Printer Configuration'.tr(
                          ref.watch(languageProvider)),
                        icon: Icons.print_outlined,
                        color1: Colors.purple.shade500,
                        color2: Colors.purple.shade700,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrinterSettingsScreen()));
                        }),
                      // Order History Card
                      if (orderHistory)
                        _buildActionCard(
                          context: context,
                          isLandscape: isLandscape,
                          title: 'My Order History'.tr(
                            ref.watch(languageProvider)),
                          icon: Icons.receipt_long_outlined,
                          color1: Colors.pink.shade400,
                          color2: Colors.pink.shade600,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StaffOrderHistoryScreen()));
                          }),
                      // Refund Card
                      if (refund)
                        _buildActionCard(
                          context: context,
                          isLandscape: isLandscape,
                          title: 'Refunds / Returns'.tr(
                            ref.watch(languageProvider)),
                          icon: Icons.assignment_return,
                          color1: Colors.red.shade500,
                          color2: Colors.red.shade700,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RefundScreen()));
                          }),
                      // Expenses Card
                      if (expenses)
                        _buildActionCard(
                          context: context,
                          isLandscape: isLandscape,
                          title: 'Add Expense'.tr(
                            ref.watch(languageProvider)),
                          icon: Icons.account_balance_wallet,
                          color1: const Color(0xFFE11D48),
                          color2: const Color(0xFFBE123C),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ExpenseAdderScreen()));
                          }),
                    ];

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isLandscape ? 350 : 220,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isLandscape ? 3.0 : 1.1,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, index) => cards[index],
                    );
                  })),
              const SizedBox(height: 16),
            ]))));
  }

  Widget _buildActionCard({
    required BuildContext context,
    required bool isLandscape,
    required String title,
    required IconData icon,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color1.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color1.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          highlightColor: const Color(0xFFF8FAFC),
          splashColor: color1.withValues(alpha: 0.1),
          child: isLandscape
              ? Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color1.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color1, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFFCBD5E1), size: 16),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color1.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color1, size: 28),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Color(0xFFE2E8F0), size: 14),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}


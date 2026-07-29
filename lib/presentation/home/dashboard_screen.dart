import 'package:pos/core/utils/notification_helper.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'franchise_management_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../master_admin/master_admin_overview_screen.dart';
import '../../core/extensions/string_extensions.dart';
import '../../providers/settings_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/language_provider.dart';
import '../customers/customers_screen.dart';
import '../checkout/checkout_screen.dart';
import '../inventory/inventory_screen.dart';
import '../expenses/expense_tracker_screen.dart';
import '../expenses/expense_adder_screen.dart';
import '../refund/refund_screen.dart';
import '../admin/staff_management_screen.dart';
import '../staff_reports/staff_reports_screen.dart';
import '../analytics/product_performance_screen.dart';
import '../refund/refund_history_screen.dart';
import '../admin/auditing_logs_screen.dart';
import '../master_admin/master_admin_screen.dart';
import '../master_admin/global_inventory_screen.dart';
import '../master_admin/support_settings_screen.dart';
import '../master_admin/support_chat_screen.dart';
import '../../services/firebase_sync_service.dart';
import '../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'expiring_shops_screen.dart';
import '../../domain/models/product.dart';
import 'desktop_overview_dashboard.dart';

class DashboardScreen extends ConsumerWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final inventory = ref.watch(inventoryProvider);
    final theme = Theme.of(context);
    final session = ref.watch(authProvider);
    
    final settingsBox = Hive.box<String>('settings');
    final showStockQuantity = (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
    final showStockAlerts = showStockQuantity &&
        (session?.hasStockManagement == true);

    // Filter stock alerts
    final outOfStockProducts = showStockAlerts
        ? inventory.where((p) => p.stockCount == 0).toList()
        : <Product>[];
    final lowStockProducts = showStockAlerts
        ? inventory.where((p) => p.stockCount > 0 && p.stockCount <= 5).toList()
        : <Product>[];

    final isAdmin = session?.role == UserRole.admin;
    final staffRole = (session?.staffRole ?? '').toLowerCase().trim();
    final isCaptain = staffRole == 'captain';
    final isReceptionist = !isCaptain;
    final isMasterAdmin =
        session?.id == 'host_admin' && settings.showMasterAdminLook;
    final enableRefund = session?.hasRefund == true;

    List<Widget> _buildDashboardCards() {
      // 4-Card Overhaul for Master/Host Admin Look
      if (session?.id == 'host_admin' &&
          ref.watch(settingsProvider).showMasterAdminLook) {
        return [
          _RowMenuCard(
            title: 'Shop Management'.tr(ref.watch(languageProvider)),
            icon: Icons.store_mall_directory,
            colors: const [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterAdminScreen(directLoginMode: false)));
            }),
          _RowMenuCard(
            title: 'Franchise Management',
            icon: Icons.business_center,
            colors: const [
              Color(0xFF059669),
              Color(0xFF047857),
            ], // Emerald Green
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FranchiseManagementScreen()));
            }),
          _RowMenuCard(
            title: 'Global Inventory'.tr(ref.watch(languageProvider)),
            icon: Icons.inventory_2,
            colors: const [Color(0xFFEA580C), Color(0xFFD97706)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GlobalInventoryScreen()));
            }),
          _RowMenuCard(
            title: 'View Shops Console'.tr(ref.watch(languageProvider)),
            icon: Icons.login,
            colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const MasterAdminScreen(directLoginMode: true)));
            }),
        ];
      }

      List<Widget> cards = [];

      // Option 1: Create Bill (Always visible)
      cards.add(
        _SquareMenuCard(
          title: 'Billing Terminal'.tr(ref.watch(languageProvider)),
          icon: Icons.point_of_sale,
          colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          onTap: () => onNavigate(1)));

      // Option 2: Inventory (Visible if Admin or Staff Stock Management is enabled or if we just want them to see it)
      cards.add(
        _SquareMenuCard(
          title: 'Inventory'.tr(ref.watch(languageProvider)),
          icon: Icons.inventory_2,
          colors: const [Color(0xFFEA580C), Color(0xFFD97706)],
          onTap: () => onNavigate(2)));

      // Option 5: Customers (Always visible, or controlled by setting)
      if (session?.hasCustomerDirectory == true) {
        cards.add(
          _SquareMenuCard(
            title: 'Customers'.tr(ref.watch(languageProvider)),
            icon: Icons.people,
            colors: const [Color(0xFF0F766E), Color(0xFF0D9488)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersScreen()));
            }));
      }

      // Option 9: Refunds (Visible to Admin, or Staff if enabled)
      if (enableRefund) {
        cards.add(
          _SquareMenuCard(
            title: 'Refunds'.tr(ref.watch(languageProvider)),
            icon: Icons.assignment_return,
            colors: const [Color(0xFFDC2626), Color(0xFFB91C1C)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RefundScreen()));
            }));
      }

      // Option: Expense Adder (Visible to Staff if enabled)
      final canAddExpenses = session?.hasExpenses == true;

      if (canAddExpenses && !isAdmin) {
        // Admin already has the Tracker card which handles adding
        cards.add(
          _SquareMenuCard(
            title: 'Add Expense'.tr(ref.watch(languageProvider)),
            icon: Icons.account_balance_wallet,
            colors: const [Color(0xFFE11D48), Color(0xFFBE123C)], // Rose colors
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseAdderScreen()));
            }));
      }

      if (isAdmin) {
        // Option 3: Analytics
        cards.add(
          _SquareMenuCard(
            title: 'Sales Overview'.tr(ref.watch(languageProvider)),
            icon: Icons.receipt_long,
            colors: const [Color(0xFF7C3AED), Color(0xFF6D28D9)],
            onTap: () => onNavigate(3)));

        // Option 6: Expenses
        cards.add(
          _SquareMenuCard(
            title: 'Expenses'.tr(ref.watch(languageProvider)),
            icon: Icons.account_balance_wallet,
            colors: const [Color(0xFF059669), Color(0xFF047857)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ExpenseTrackerScreen()));
            }));

        // Option 7: Staff Reports
        cards.add(
          _SquareMenuCard(
            title: 'Staff Reports'.tr(ref.watch(languageProvider)),
            icon: Icons.badge,
            colors: const [Color(0xFF0284C7), Color(0xFF0369A1)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffReportsScreen()));
            }));

        // Option 8: Product Performance
        cards.add(
          _SquareMenuCard(
            title: 'Product Performance'.tr(ref.watch(languageProvider)),
            icon: Icons.trending_up,
            colors: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductPerformanceScreen()));
            }));

        // Option 10: Refund History
        cards.add(
          _SquareMenuCard(
            title: 'Refund History'.tr(ref.watch(languageProvider)),
            icon: Icons.history,
            colors: const [Color(0xFF9333EA), Color(0xFF7E22CE)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RefundHistoryScreen()));
            }));

        // Option 11: Auditing Logs
        cards.add(
          _SquareMenuCard(
            title: 'Auditing Logs'.tr(ref.watch(languageProvider)),
            icon: Icons.security,
            colors: const [
              Color(0xFFD97706),
              Color(0xFFB45309),
            ], // Orange colors
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuditingLogsScreen()));
            }));

        // Option 12: Support Ticket (Only for normal admins)
        if (session?.id != 'host_admin') {
          cards.add(
            _SquareMenuCard(
              title: 'Support Ticket'.tr(ref.watch(languageProvider)),
              icon: Icons.forum_outlined,
              colors: const [
                Color(0xFF4F46E5),
                Color(0xFF3730A3),
              ], // Indigo theme matching support chat accent
              onTap: () {
                final shopCode = Hive.box<String>('settings').get('shopCode') ?? 'Unknown';
                final shopName = settings.shopName;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupportChatScreen(
                      clientShopCode: shopCode,
                      clientShopName: shopName,
                    ),
                  ),
                );
              }));
        }
      }

      // Option 11: Customer Support (Only for host_admin)
      if (session?.id == 'host_admin' &&
          !ref.read(authProvider.notifier).directLoginMode &&
          ref.watch(settingsProvider).showMasterAdminLook) {
        cards.insert(
          0,
          _SquareMenuCard(
            title: 'Shop Management'.tr(ref.watch(languageProvider)),
            icon: Icons.store_mall_directory,
            colors: const [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MasterAdminScreen()));
            }));
      }

      return cards;
    }

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isMasterAdmin
          ? AppBar(
              title: Text('Master Admin Dashboard'.tr(ref.watch(languageProvider))),
              backgroundColor: Colors.black,
              foregroundColor: Colors.amber,
              centerTitle: true,
            )
          : null,
      drawer: isMasterAdmin
          ? Drawer(
              backgroundColor: Colors.white,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(top: 60, bottom: 24, left: 24, right: 24),
                    width: double.infinity,
                    color: Colors.black,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 5))],
                            image: const DecorationImage(image: AssetImage('assets/images/master_command_logo.png'), fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text('COMMAND', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                        const SizedBox(height: 2),
                        const Text('Center', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: [
                        ListTile(
                          leading: const Icon(Icons.store_mall_directory, color: Colors.red),
                          title: const Text('Shop Management', style: TextStyle(fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterAdminScreen(directLoginMode: false)));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.business_center, color: Colors.green),
                          title: const Text('Franchise Management', style: TextStyle(fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const FranchiseManagementScreen()));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.inventory_2, color: Colors.orange),
                          title: const Text('Global Inventory', style: TextStyle(fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalInventoryScreen()));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.login, color: Colors.blue),
                          title: const Text('View Shops Console', style: TextStyle(fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterAdminScreen(directLoginMode: true)));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.settings, color: Colors.grey),
                          title: const Text('Support Settings', style: TextStyle(fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportSettingsScreen()));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vertically stacked menu items
                Expanded(
                  child: ListView(
                    children: [
                      if (isMasterAdmin)
                        GridView.extent(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          maxCrossAxisExtent: 320,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.4,
                          children: [
                            _SquareMenuCard(
                              title: 'Shop Management',
                              icon: Icons.store_mall_directory,
                              colors: const [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterAdminScreen(directLoginMode: false)));
                              },
                            ),
                            _SquareMenuCard(
                              title: 'Franchise Management',
                              icon: Icons.business_center,
                              colors: const [Color(0xFF059669), Color(0xFF047857)],
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const FranchiseManagementScreen()));
                              },
                            ),
                            _SquareMenuCard(
                              title: 'Global Inventory',
                              icon: Icons.inventory_2,
                              colors: const [Color(0xFFEA580C), Color(0xFFD97706)],
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalInventoryScreen()));
                              },
                            ),
                            _SquareMenuCard(
                              title: 'View Shops Console',
                              icon: Icons.login,
                              colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterAdminScreen(directLoginMode: true)));
                              },
                            ),
                            _SquareMenuCard(
                              title: 'Support Settings',
                              icon: Icons.settings,
                              colors: const [Color(0xFF4B5563), Color(0xFF374151)],
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportSettingsScreen()));
                              },
                            ),
                          ],
                        )
                      else
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: MediaQuery.of(context).orientation == Orientation.landscape
                              ? (MediaQuery.of(context).size.width > 800 ? 5 : 4)
                              : (isAdmin ? (MediaQuery.of(context).size.width > 600 ? 4 : 2) : 4),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: isAdmin ? 1.0 : 0.85,
                          children: _buildDashboardCards()),
                      const SizedBox(height: 40),

                      if (isMasterAdmin) ...[
                        Text(
                          '⚠️ Expiring Shops',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                        const SizedBox(height: 10),
                        _ExpiringShopsWidget(),
                        const SizedBox(height: 24),
                      ] else if (showStockAlerts) ...[
                        // Inventory Stock Alerts Section
                        Text(
                          '⚠️ ${'Stock Level Alerts'.tr(ref.watch(languageProvider))}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                        const SizedBox(height: 10),
                        if (outOfStockProducts.isEmpty &&
                            lowStockProducts.isEmpty)
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                            color: const Color(0xFFF0FDF4),
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 14.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'All items are well stocked!',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                                ])))
                        else
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  // Out of Stock list
                                  if (outOfStockProducts.isNotEmpty) ...[
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: outOfStockProducts.length,
                                      itemBuilder: (context, idx) {
                                        final prod = outOfStockProducts[idx];
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.red.shade50,
                                            child: const Icon(
                                              Icons.error_outline,
                                              color: Colors.red)),
                                          title: Text(
                                            prod.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                          subtitle: Text(
                                            prod.category,
                                            style: const TextStyle(
                                              fontSize: 12)),
                                          trailing: const Text(
                                            'OUT OF STOCK',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)));
                                      }),
                                    if (lowStockProducts.isNotEmpty)
                                      const Divider(),
                                  ],
                                  // Low Stock list
                                  if (lowStockProducts.isNotEmpty) ...[
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: lowStockProducts.length,
                                      itemBuilder: (context, idx) {
                                        final prod = lowStockProducts[idx];
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                Colors.orange.shade50,
                                            child: const Icon(
                                              Icons.warning_amber,
                                              color: Colors.orange)),
                                          title: Text(
                                            prod.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                          subtitle: Text(
                                            prod.category,
                                            style: const TextStyle(
                                              fontSize: 12)),
                                          trailing: Text(
                                            'ONLY ${prod.stockCount} LEFT',
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)));
                                      }),
                                  ],
                                ]))),
                        const SizedBox(height: 24),
                      ],
                      if (Hive.box<String>(
                            'settings').get('is_impersonating') ==
                          'true') ...[
                        const SizedBox(height: 16),
                        const _ImpersonationBanner(),
                        const SizedBox(height: 16),
                      ],
                    ])),
              ])))));
  }
}

class _RowMenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _RowMenuCard({
    required this.title,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4)),
        ]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 28)),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5))),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 20),
              ])))));
  }
}

class _SquareMenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _SquareMenuCard({
    required this.title,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4)),
        ]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 36)),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5))),
              ])))));
  }
}

class _ImpersonationBanner extends ConsumerWidget {
  const _ImpersonationBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopCode = Hive.box<String>('settings').get('shopCode') ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Currently impersonating: $shopCode',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber))),
            TextButton.icon(
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      const Center(child: CircularProgressIndicator()));
                final error = await ref
                    .read(authProvider.notifier)
                    .returnToMasterAdmin();
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
              icon: const Icon(Icons.exit_to_app, color: Colors.amber),
              label: const Text(
                'Exit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber))),
          ])));
  }
}

class _ExpiringShopsWidget extends StatefulWidget {
  const _ExpiringShopsWidget({super.key});

  @override
  State<_ExpiringShopsWidget> createState() => _ExpiringShopsWidgetState();
}

class _ExpiringShopsWidgetState extends State<_ExpiringShopsWidget> {
  List<Map<String, dynamic>> _expiringShops = [];
  bool _isLoading = true;

  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _listenToExpiringShops();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listenToExpiringShops() {
    try {
      _sub = FirebaseFirestore.instance.collection('shops').snapshots().listen((
        snap) {
        final now = DateTime.now();

        List<Map<String, dynamic>> shops = [];
        for (var doc in snap.docs) {
          if (doc.id == 'host_admin') continue;
          final data = doc.data();
          final validUntilStr = data['validUntil'];
          if (validUntilStr != null) {
            final validUntil = DateTime.parse(validUntilStr);
            final diff = validUntil.difference(now).inDays;

            shops.add({
              'shopCode': doc.id,
              'validUntil': validUntil,
              'daysLeft': diff,
              'shopName': data['shopName'] ?? doc.id,
            });
          }
        }

        // Sort by days left (ascending)
        shops.sort(
          (a, b) => (a['daysLeft'] as int).compareTo(b['daysLeft'] as int));

        // Take top 6 expiring shops
        if (shops.length > 6) {
          shops = shops.sublist(0, 6);
        }

        if (mounted) {
          setState(() {
            _expiringShops = shops;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Error listening to expiring shops: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_expiringShops.isEmpty) {
      return const SizedBox.shrink(); // Hide if no shops
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4)),
        ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Low Validity Shops',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                  ]),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExpiringShopsScreen()));
                  },
                  child: const Text('See All')),
              ])),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _expiringShops.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final shop = _expiringShops[index];
              final daysLeft = shop['daysLeft'] as int;

              Color statusColor;
              if (daysLeft < 0) {
                statusColor = Colors.red;
              } else if (daysLeft <= 30) {
                statusColor = Colors.orange;
              } else {
                statusColor = Colors.green;
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(
                    daysLeft < 0 ? Icons.block : Icons.timer,
                    color: statusColor)),
                title: Text(
                  shop['shopName'],
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Code: ${shop['shopCode']}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5))),
                  child: Text(
                    daysLeft < 0 ? 'Expired' : '$daysLeft days left',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12))));
            }),
        ]));
  }
}

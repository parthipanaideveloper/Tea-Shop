import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:file_picker/file_picker.dart' as fp;

// Providers
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/refund_provider.dart';
import '../../providers/printer_provider.dart';
import '../../core/utils/ui_utils.dart';


// Screens
import 'desktop_overview_dashboard.dart';
import '../checkout/checkout_screen.dart';
import '../inventory/inventory_screen.dart';
import '../customers/customers_screen.dart';
import '../analytics/analytics_screen.dart';
import '../expenses/expense_tracker_screen.dart';
import '../analytics/product_performance_screen.dart';
import '../staff_reports/staff_reports_screen.dart';
import '../refund/refund_screen.dart';
import '../refund/refund_history_screen.dart';
import '../admin/staff_management_screen.dart';
import '../admin/auditing_logs_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/printer_settings_screen.dart';

// Neumorphic Widgets
import '../widgets/neumorphic_widgets.dart';

// Services
import '../../services/backup_service.dart';
import '../../core/utils/notification_helper.dart';

class DesktopDashboardShell extends ConsumerStatefulWidget {
  const DesktopDashboardShell({super.key});

  @override
  ConsumerState<DesktopDashboardShell> createState() => _DesktopDashboardShellState();
}

class _DesktopDashboardShellState extends ConsumerState<DesktopDashboardShell> {
  String _currentRoute = 'overview';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(authProvider);
    final language = ref.watch(languageProvider);
    final theme = Theme.of(context);
    final isImpersonating = Hive.box<String>('settings').get('is_impersonating') == 'true';

    // Sidebar items layout configuration
    return Scaffold(
      backgroundColor: NeumorphicTheme.background,
      body: Row(
        children: [
          // ----------------------------------------------------
          // 1. FIXED LEFT SIDEBAR
          // ----------------------------------------------------
          _buildSidebar(settings, session, language),

          // ----------------------------------------------------
          // MAIN VIEWPORT (HEADER + CONTENT)
          // ----------------------------------------------------
          Expanded(
            child: Column(
              children: [
                // 2. FIXED TOP HEADER
                if (_currentRoute == 'overview')
                  _buildHeader(settings, session, language),

                // 3. SCROLLABLE CONTENT AREA
                Expanded(
                  child: Container(
                    color: NeumorphicTheme.background,
                    child: Theme(
                      data: ThemeData(
                        useMaterial3: true,
                        brightness: Brightness.light,
                        scaffoldBackgroundColor: NeumorphicTheme.background,
                        primaryColor: NeumorphicTheme.primary,
                        colorScheme: ColorScheme.fromSeed(
                          seedColor: NeumorphicTheme.primary,
                          primary: NeumorphicTheme.primary,
                          secondary: const Color(0xFF10B981),
                          surface: Colors.white,
                        ),
                        cardTheme: CardThemeData(
                          color: const Color(0xFF0F172A),
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                          ),
                        ),
                        elevatedButtonTheme: ElevatedButtonThemeData(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NeumorphicTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ).copyWith(
                            overlayColor: WidgetStateProperty.resolveWith<Color?>(
                              (states) {
                                if (states.contains(WidgetState.hovered)) {
                                  return Colors.white.withOpacity(0.12);
                                }
                                if (states.contains(WidgetState.pressed)) {
                                  return Colors.white.withOpacity(0.2);
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        outlinedButtonTheme: OutlinedButtonThemeData(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NeumorphicTheme.textPrimary,
                            side: const BorderSide(color: Color(0xFFD1D9E6), width: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ).copyWith(
                            backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                              (states) {
                                if (states.contains(WidgetState.hovered)) {
                                  return Colors.white;
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          hintStyle: const TextStyle(color: NeumorphicTheme.textSecondary, fontSize: 13),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFD1D9E6), width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFD1D9E6), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: NeumorphicTheme.primary, width: 1.5),
                          ),
                        ),
                        dataTableTheme: DataTableThemeData(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                          dataRowColor: WidgetStateProperty.all(Colors.white),
                          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 12),
                          dataTextStyle: const TextStyle(color: NeumorphicTheme.textPrimary, fontSize: 13),
                          horizontalMargin: 16,
                          columnSpacing: 18,
                        ),
                        dividerTheme: const DividerThemeData(
                          color: Color(0xFFE2E8F0),
                          thickness: 1,
                          space: 1,
                        ),
                        dialogTheme: DialogThemeData(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      child: _buildContentArea(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sidebar widget
  Widget _buildSidebar(SettingsState settings, UserSession? session, String language) {
    final isImpersonating = Hive.box<String>('settings').get('is_impersonating') == 'true';
    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // Soft gray background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(2, 0),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo & Shop Name Area
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 24, left: 24, right: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundImage: AssetImage('assets/images/pos_logo.png'),
                    backgroundColor: Colors.transparent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.shopName.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session?.role == UserRole.admin ? 'Administrator' : 'POS Terminal',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Navigation Links list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                _buildSidebarItem(
                  label: 'Overview',
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  route: 'overview',
                ),
                const SizedBox(height: 20),

                _buildCategoryHeader('OPERATIONS'),
                _buildSidebarItem(
                  label: 'Billing Terminal',
                  icon: Icons.point_of_sale_outlined,
                  activeIcon: Icons.point_of_sale,
                  route: 'billing',
                ),
                _buildSidebarItem(
                  label: 'Inventory',
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2,
                  route: 'inventory',
                ),
                _buildSidebarItem(
                  label: 'Customers',
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  route: 'customers',
                ),
                const SizedBox(height: 20),

                _buildCategoryHeader('REPORTS & ANALYTICS'),
                _buildSidebarItem(
                  label: 'Sales Overview',
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  route: 'sales',
                ),
                _buildSidebarItem(
                  label: 'Expenses',
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet,
                  route: 'expenses',
                ),
                _buildSidebarItem(
                  label: 'Product Performance',
                  icon: Icons.auto_graph,
                  activeIcon: Icons.auto_graph,
                  route: 'performance',
                ),
                _buildSidebarItem(
                  label: 'Staff Reports',
                  icon: Icons.badge_outlined,
                  activeIcon: Icons.badge,
                  route: 'staff',
                ),
                const SizedBox(height: 20),

                _buildCategoryHeader('FINANCE'),
                _buildSidebarItem(
                  label: 'Refunds',
                  icon: Icons.assignment_return_outlined,
                  activeIcon: Icons.assignment_return,
                  route: 'refunds',
                ),
                _buildSidebarItem(
                  label: 'Refund History',
                  icon: Icons.history_edu_outlined,
                  activeIcon: Icons.history_edu,
                  route: 'refund_history',
                ),
                const SizedBox(height: 20),

                _buildCategoryHeader('SYSTEM'),
                _buildSidebarItem(
                  label: 'Users & Roles',
                  icon: Icons.manage_accounts_outlined,
                  activeIcon: Icons.manage_accounts,
                  route: 'users',
                ),
                _buildSidebarItem(
                  label: 'Audit Logs',
                  icon: Icons.history_toggle_off,
                  activeIcon: Icons.history_toggle_off,
                  route: 'audit',
                ),
                _buildSidebarItem(
                  label: 'Settings',
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  route: 'settings',
                ),
                _buildSidebarItem(
                  label: 'Printer Setup',
                  icon: Icons.print_outlined,
                  activeIcon: Icons.print,
                  route: 'printer_setup',
                ),
                _buildSidebarItem(
                  label: 'Backup & Restore',
                  icon: Icons.cloud_done_outlined,
                  activeIcon: Icons.cloud_done,
                  route: 'backup',
                ),
              ],
            ),
          ),

          // Logout or Exit Impersonation Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: () {
                if (isImpersonating) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Exit Impersonation'),
                      content: const Text('Are you sure you want to exit impersonation and return to Customer Support?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator()),
                            );
                            final error = await ref.read(authProvider.notifier).returnToMasterAdmin();
                            if (context.mounted) {
                              Navigator.pop(context); // close loader
                              if (error != null) {
                                NotificationHelper.showCenter(context, error, isError: true);
                              } else {
                                NotificationHelper.showCenter(context, 'Returned to Customer Support', isError: false);
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                          child: const Text('Exit', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                } else {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Log Out'),
                      content: const Text('Are you sure you want to log out from this terminal?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(authProvider.notifier).logout();
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Log Out', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isImpersonating 
                      ? Colors.amber.withOpacity(0.08)
                      : const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isImpersonating
                        ? Colors.amber.withOpacity(0.2)
                        : const Color(0xFFEF4444).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isImpersonating ? Icons.exit_to_app : Icons.logout_rounded,
                      color: isImpersonating ? const Color(0xFFB45309) : const Color(0xFFDC2626),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isImpersonating ? 'Exit Impersonation' : 'Terminal Logout',
                      style: TextStyle(
                        color: isImpersonating ? const Color(0xFFB45309) : const Color(0xFFDC2626),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, bottom: 6, top: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Sidebar item component
  Widget _buildSidebarItem({
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required String route,
  }) {
    final bool isActive = _currentRoute == route;

    final Color iconAccentColor = switch (route) {
      'overview' => Colors.blue.shade600,
      'billing' || 'checkout' => Colors.indigo.shade600,
      'inventory' => Colors.orange.shade600,
      'customers' => Colors.teal.shade600,
      'sales' || 'performance' || 'staff' => Colors.purple.shade600,
      'expenses' => Colors.amber.shade800,
      'refunds' || 'refund_history' => Colors.red.shade600,
      _ => Colors.blue.shade600,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      child: InkWell(
        onTap: () => setState(() => _currentRoute = route),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? iconAccentColor.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: iconAccentColor.withOpacity(0.18), width: 1.0)
                : Border.all(color: Colors.transparent, width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive 
                        ? iconAccentColor.withOpacity(0.3) 
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                    if (isActive)
                      BoxShadow(
                        color: iconAccentColor.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? iconAccentColor : iconAccentColor.withOpacity(0.7),
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: isActive ? const Color(0xFF0F172A) : const Color(0xFF475569),
                  ),
                ),
              ),
              if (isActive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: iconAccentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconAccentColor.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ]
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Command Center Header
  Widget _buildHeader(SettingsState settings, UserSession? session, String language) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.75),
                const Color(0xFFF8FAFC).withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.03),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Search box
              Container(
                width: 320,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: const InputDecoration(
                          hintText: 'Search terminal command...',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ),

              // Command Info & Date
              Row(
                children: [
                  // System Info pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: Color(0xFF2563EB), size: 14),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEE, dd MMMM yyyy').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Notification Icon
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 20),
                      onPressed: () {
                        setState(() => _currentRoute = 'notifications');
                      },
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Profile Area
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            session?.name ?? 'Admin Operator',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            session?.role == UserRole.admin ? 'Administrator' : 'Staff Member',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFDBEAFE),
                          child: Text(
                            (session?.name ?? 'A')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Swapping main content widgets
  Widget _buildContentArea() {
    switch (_currentRoute) {
      case 'overview':
        return DesktopOverviewDashboard(
          onNavigate: (route) {
            setState(() => _currentRoute = route);
          },
          onOpenAddProduct: () => setState(() => _currentRoute = 'inventory'),
          onOpenAddCustomer: () => setState(() => _currentRoute = 'customers'),
        );
      case 'billing':
      case 'checkout':
        return const CheckoutScreen();
      case 'inventory':
        return const InventoryScreen();
      case 'customers':
        return const CustomersScreen();
      case 'sales':
        return const AnalyticsScreen();
      case 'expenses':
        return const ExpenseTrackerScreen();
      case 'performance':
        return const ProductPerformanceScreen();
      case 'staff':
        return const StaffReportsScreen();
      case 'refunds':
        return const RefundScreen();
      case 'refund_history':
        return const RefundHistoryScreen();
      case 'users':
        return const StaffManagementScreen();
      case 'audit':
        return const AuditingLogsScreen();
      case 'settings':
        return const SettingsScreen();
      case 'printer_setup':
        return const PrinterSettingsScreen();
      case 'notifications':
        return DesktopNotificationsScreen(
          onNavigate: (route) {
            setState(() => _currentRoute = route);
          },
        );
      case 'backup':
        return const BackupRestoreScreen();
      default:
        return Center(
          child: Text('Screen $_currentRoute under active construction.'),
        );
    }
  }
}

// ----------------------------------------------------
// DEDICATED BACKUP & RESTORE VIEW
// ----------------------------------------------------
class BackupRestoreScreen extends ConsumerWidget {
  const BackupRestoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Database Backup & Restore',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: NeumorphicTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Export or restore your transaction records, settings, and product list offline.',
            style: TextStyle(fontSize: 13, color: NeumorphicTheme.textSecondary),
          ),
          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Export panel
              Expanded(
                child: NeumorphicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.download_rounded, color: Colors.blue, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Export Offline Backup',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NeumorphicTheme.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This exports all your orders, expenses, and product catalog into a secure encrypted backup file (.dts). The file is saved directly into your device Downloads folder.',
                        style: TextStyle(fontSize: 12, color: NeumorphicTheme.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      NeumorphicButton(
                        color: Colors.blue.shade50,
                        onTap: () async {
                          NotificationHelper.showCenter(context, 'Starting database backup...', isError: false);
                          try {
                            final backupService = BackupService();
                            final shopName = Hive.box<String>('settings').get('shopName') ?? 'Shop';
                            final path = await backupService.exportBackup(shopName);
                            if (!context.mounted) return;
                            if (path != null) {
                              NotificationHelper.showCenter(context, 'Backup successfully exported to:\n$path', isError: false);
                            } else {
                              NotificationHelper.showCenter(context, 'Failed to export backup.', isError: true);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              NotificationHelper.showCenter(context, 'Permission error. Failed to export database.', isError: true);
                            }
                          }
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, color: Colors.blue, size: 16),
                            SizedBox(width: 8),
                            Text('Export Database Now', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 28),

              // Import panel
              Expanded(
                child: NeumorphicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.upload_rounded, color: Colors.green, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Restore from Backup File',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NeumorphicTheme.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Select a valid DTS POS encrypted backup file (.dts) from your local computer to restore your system data. WARNING: This will overwrite your current local records.',
                        style: TextStyle(fontSize: 12, color: NeumorphicTheme.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      NeumorphicButton(
                        color: Colors.green.shade50,
                        onTap: () async {
                          try {
                            final result = await fp.FilePicker.pickFiles(type: fp.FileType.any);
                            if (!context.mounted) return;
                            if (result != null && result.files.single.path != null) {
                              final file = File(result.files.single.path!);
                              final backupService = BackupService();
                              final success = await backupService.importBackup(file);
                              if (!context.mounted) return;
                              if (success) {
                                NotificationHelper.showCenter(context, 'Database restored successfully! ≡ƒÄë Please restart the app.', isError: false);
                              } else {
                                NotificationHelper.showCenter(context, 'Failed to restore. Invalid or tampered backup file.', isError: true);
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              NotificationHelper.showCenter(context, 'Restore canceled or failed.', isError: true);
                            }
                          }
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file_outlined, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Text('Select Backup File', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// DEDICATED SYSTEM NOTIFICATIONS SCREEN
// ----------------------------------------------------
class DesktopNotificationsScreen extends ConsumerWidget {
  final Function(String)? onNavigate;
  const DesktopNotificationsScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderProvider);
    final inventory = ref.watch(inventoryProvider);
    final refunds = ref.watch(refundProvider);
    final printer = ref.watch(printerProvider);

    final List<Map<String, dynamic>> alerts = [];

    // 1. Printer Notification
    if (printer.connectedDevice == null) {
      alerts.add({
        'title': 'Printer Warning',
        'desc': 'No thermal printer is currently configured. Print receipts may fail.',
        'type': 'warning',
        'time': 'System Status',
        'icon': Icons.print_disabled_rounded,
        'color': Colors.orange,
        'route': 'printer_setup',
      });
    } else {
      alerts.add({
        'title': 'Printer Active',
        'desc': 'Connected to ${printer.connectedDevice!.name} successfully.',
        'type': 'success',
        'time': 'System Status',
        'icon': Icons.print_rounded,
        'color': Colors.green,
        'route': 'printer_setup',
      });
    }

    // 2. Low/Out of Stock Alerts
    final outOfStock = inventory.where((p) => p.trackInventory && p.stockCount == 0).toList();
    final lowStock = inventory.where((p) => p.trackInventory && p.stockCount > 0 && p.stockCount <= 5).toList();

    for (final p in outOfStock) {
      alerts.add({
        'title': 'Out of Stock Alert',
        'desc': '${p.name} is completely out of stock! Please restock immediately.',
        'type': 'alert',
        'time': 'Inventory Alert',
        'icon': Icons.block_flipped,
        'color': Colors.red,
      });
    }

    for (final p in lowStock) {
      alerts.add({
        'title': 'Low Stock Warning',
        'desc': '${p.name} has only ${p.stockCount} items remaining in inventory.',
        'type': 'warning',
        'time': 'Inventory Warning',
        'icon': Icons.warning_amber_rounded,
        'color': Colors.orange,
      });
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 3. Today's orders
    final todayOrders = orders.where((o) => DateFormat('yyyy-MM-dd').format(o.date) == todayStr).toList();
    for (final o in todayOrders) {
      alerts.add({
        'title': o.isVoided ? 'Sale Voided' : 'Sale Completed',
        'desc': 'Order #${o.id} processed by ${o.staffName.isEmpty ? 'Admin' : o.staffName} - Γé╣${o.total.toStringAsFixed(2)}',
        'type': o.isVoided ? 'alert' : 'info',
        'time': DateFormat('hh:mm a').format(o.date),
        'icon': o.isVoided ? Icons.assignment_return_outlined : Icons.point_of_sale_rounded,
        'color': o.isVoided ? Colors.red : Colors.blue,
      });
    }

    // 4. Today's refunds
    final todayRefunds = refunds.where((r) => DateFormat('yyyy-MM-dd').format(r.date) == todayStr).toList();
    for (final r in todayRefunds) {
      alerts.add({
        'title': 'Refund Processed',
        'desc': 'Ref: ${r.originalOrderId} refunded Γé╣${r.amountRefunded.toStringAsFixed(2)} - ${r.reason}',
        'type': 'info',
        'time': DateFormat('hh:mm a').format(r.date),
        'icon': Icons.monetization_on_outlined,
        'color': Colors.indigo,
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Notifications',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: NeumorphicTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total: ${alerts.length} alerts and logs requiring review',
                    style: const TextStyle(fontSize: 12, color: NeumorphicTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (alerts.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'All systems healthy',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: NeumorphicTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No unresolved warnings or system alerts at this time.',
                    style: TextStyle(fontSize: 12, color: NeumorphicTheme.textSecondary),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = alerts[index];
                final Color color = item['color'];
                final String? route = item['route'];

                Widget card = NeumorphicCard(
                  borderColor: color.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item['icon'], color: color, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'],
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: NeumorphicTheme.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['desc'],
                                style: const TextStyle(fontSize: 12, color: NeumorphicTheme.textSecondary, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          item['time'],
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: NeumorphicTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );

                if (route != null) {
                  card = GestureDetector(
                    onTap: () => onNavigate?.call(route),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: card,
                    ),
                  );
                }

                return card;
              },
            ),
        ],
      ),
    );
  }
}

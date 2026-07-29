import 'package:flutter/material.dart';
import 'master_admin_overview_screen.dart';
import 'master_admin_screen.dart';
import '../home/franchise_management_screen.dart';
import 'global_inventory_screen.dart';
import 'support_settings_screen.dart';
import 'live_device_health_screen.dart';
import 'live_error_stream_screen.dart';
import 'master_admin_error_logs_screen.dart';
import 'live_staff_activity_screen.dart';
import 'support_chat_screen.dart';
import 'shop_users_console_screen.dart'; // contains ShopUsersConsoleDialog
import 'live_network_pulse_screen.dart';
import 'firebase_storage_usage_screen.dart';
import 'firebase_limits_screen.dart';
import 'daywise_registrations_screen.dart';
import 'security_alerts_screen.dart';
import 'notifications_screen.dart';
import '../widgets/premium_shine.dart';
import '../widgets/global_search_overlay.dart';
import '../widgets/security_alerts_dropdown.dart';
import '../widgets/notifications_dropdown.dart';

const kMasterWorkspaceColor = Color(
  0xFFF0F4F8,
); // Soft bright background for neumorphism
const kMasterSidebarColor = Color(0xFFFFFFFF); // Premium surface
const kMasterIndicator = Color(0xFF4F46E5); // Indigo accent
const kMasterAccent = Color(0xFF10B981); // Emerald green for success/active

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class MasterAdminShell extends StatefulWidget {
  final int initialIndex;

  const MasterAdminShell({super.key, this.initialIndex = 0});

  @override
  State<MasterAdminShell> createState() => _MasterAdminShellState();
}

class _MasterAdminShellState extends State<MasterAdminShell> {
  late int _selectedIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  ShopRegistryEntry? _selectedShop;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onNavigate(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _pushScreen(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  List<Widget> _buildScreens(bool isDesktop) {
    final openDrawerCallback = !isDesktop
        ? () => _scaffoldKey.currentState?.openDrawer()
        : null;

    return [
      MasterAdminOverviewScreen(
        onNavigateToShops: () => _onNavigate(3),
        onNavigateToPulse: () => _onNavigate(1),
        onNavigateToFranchises: () => _onNavigate(4),
        onNavigateToSupport: () => _onNavigate(2),
        onNavigateToDevices: () => _onNavigate(11), // LiveDeviceHealthScreen
        onNavigateToErrors: () => _onNavigate(6), // App Error Logs Tab
        onNavigateToActivity: () => _onNavigate(13), // LiveStaffActivityScreen
        onNavigateToRegistrations: () =>
            _onNavigate(14), // Daywise Registrations
        onOpenDrawer: openDrawerCallback,
      ),
      LiveNetworkPulseScreen(
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
      ),
      SupportChatScreen(onOpenDrawer: openDrawerCallback, hideAppBar: true),
      MasterAdminScreen(
        directLoginMode: false,
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
        onSelectShop: (shop) {
          setState(() {
            _selectedShop = shop;
            _selectedIndex = 17;
          });
        },
      ),
      FranchiseManagementScreen(
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
      ),
      GlobalInventoryScreen(onOpenDrawer: openDrawerCallback, hideAppBar: true),
      MasterAdminErrorLogsScreen(
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
      ),
      FirebaseStorageUsageScreen(
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
      ),
      FirebaseLimitsScreen(onOpenDrawer: openDrawerCallback, hideAppBar: true),
      MasterAdminScreen(
        directLoginMode: true,
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
        onSelectShop: (shop) {
          showDialog(
            context: context,
            builder: (ctx) => ShopUsersConsoleDialog(shop: shop),
          );
        },
      ),
      SupportSettingsScreen(onOpenDrawer: openDrawerCallback, hideAppBar: true),

      // HIDDEN NAV ITEMS (Accessible via Overview Screen but keeps Sidebar visible)
      LiveDeviceHealthScreen(
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
      ), // Index 11
      LiveErrorStreamScreen(
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
      ), // Index 12
      LiveStaffActivityScreen(
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
      ), // Index 13
      DaywiseRegistrationsScreen(
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
      ), // Index 14
      // DEDICATED ALERTS & NOTIFICATION PAGES (Indices 15 & 16)
      SecurityAlertsScreen(
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
      ), // Index 15
      NotificationsScreen(
        onOpenDrawer: openDrawerCallback,
        hideAppBar: true,
      ), // Index 16
      // DEDICATED NESTED SHOP ACTION SCREEN (Index 17)
      _selectedShop != null
          ? ShopActionScreen(
              shop: _selectedShop!,
              onRefresh: () {},
              onBack: () {
                setState(() {
                  _selectedShop = null;
                });
                _onNavigate(3); // Go back to Shop Management
              },
            )
          : const Scaffold(body: Center(child: Text("No shop selected"))),
    ];
  }

  static const List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Overview Dashboard',
    ),
    _NavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: 'Live Network Pulse',
    ),
    _NavItem(
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum,
      label: 'Support Tickets',
    ),
    _NavItem(
      icon: Icons.store_mall_directory_outlined,
      activeIcon: Icons.store_mall_directory,
      label: 'Shop Management',
    ),
    _NavItem(
      icon: Icons.business_center_outlined,
      activeIcon: Icons.business_center,
      label: 'Franchise Management',
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      label: 'Global Inventory',
    ),
    _NavItem(
      icon: Icons.bug_report_outlined,
      activeIcon: Icons.bug_report,
      label: 'App Error Logs 🚨',
    ),
    _NavItem(
      icon: Icons.sd_storage_outlined,
      activeIcon: Icons.sd_storage,
      label: 'Storage Usage',
    ),
    _NavItem(
      icon: Icons.speed_outlined,
      activeIcon: Icons.speed,
      label: 'Firebase Limits',
    ),
    _NavItem(
      icon: Icons.login_outlined,
      activeIcon: Icons.login,
      label: 'View Shops Console',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Support Settings',
    ),
  ];

  /// Logo + name header block for the sidebar
  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
      width: double.infinity,
      color: kMasterSidebarColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Generated Premium Logo with Circular Shine
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  image: const DecorationImage(
                    image: AssetImage(
                      'assets/images/new_master_admin_logo.png',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const Positioned.fill(
                child: PremiumShineCardOverlay(borderRadius: 36),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'MASTER ADMIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Command Center',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF4F46E5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Section divider between logo block and nav items
  Widget _buildSidebarDivider() {
    return Container(
      color: kMasterSidebarColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: const Color(0xFFF3F4F6))),
        ],
      ),
    );
  }

  /// A single custom nav item tile with box highlight on selection
  Widget _buildNavTile(int index, bool extended, {VoidCallback? onTap}) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () => _onNavigate(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: isSelected
              ? (Matrix4.identity()..translate(8.0, 0.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: kMasterIndicator.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(4, 4),
                    ),
                  ]
                : [],
            border: Border.all(
              color: isSelected
                  ? kMasterIndicator.withValues(alpha: 0.2)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected ? kMasterIndicator : const Color(0xFF6B7280),
                size: 20,
              ),
              if (extended) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected
                          ? kMasterIndicator
                          : const Color(0xFF4B5563),
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerContent() {
    return Column(
      children: [
        _buildSidebarHeader(),
        _buildSidebarDivider(),
        Expanded(
          child: Container(
            color: kMasterSidebarColor,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                return _buildNavTile(
                  index,
                  true,
                  onTap: () {
                    _onNavigate(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _getPageName(int index) {
    if (index >= 0 && index < _navItems.length) {
      return _navItems[index].label;
    }
    switch (index) {
      case 10:
        return 'Live Device Health';
      case 11:
        return 'Live Error Stream';
      case 12:
        return 'Live Staff Activity';
      case 13:
        return 'Daywise Registrations';
      case 14:
        return 'Security Alerts';
      case 15:
        return 'Notifications';
      case 16:
        return _selectedShop != null
            ? 'Shop Console: ${_selectedShop!.shopCode}'
            : 'Shop Console';
      default:
        return 'Command Center';
    }
  }

  Widget _buildTopBar(bool isDesktop) {
    return Container(
      margin: EdgeInsets.fromLTRB(isDesktop ? 0 : 16, 16, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(4, 4),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 16,
            offset: Offset(-4, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isDesktop && _selectedIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          // Global Search area or Back button + Title
          if (_selectedIndex == 0) ...[
            SizedBox(
              width: isDesktop ? 320 : 200,
              child: InkWell(
                onTap: () {
                  showGeneralDialog(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: '',
                    pageBuilder: (_, __, ___) => GlobalSearchOverlay(
                      onClose: () => Navigator.pop(context),
                      onSelectShop: (shopEntry) {
                        setState(() {
                          _selectedShop = shopEntry;
                          _selectedIndex = 16;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: kMasterWorkspaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: Color(0xFF9CA3AF),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isDesktop
                              ? 'Search shops, devices, or staff...'
                              : 'Search...',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
          ] else ...[
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF4B5563),
              ),
              onPressed: () => _onNavigate(0),
              tooltip: 'Back to Dashboard',
            ),
            const SizedBox(width: 8),
            Text(
              _getPageName(_selectedIndex),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1E293B),
              ),
            ),
            const Spacer(),
          ],
          if (isDesktop) ...[
            const SizedBox(width: 16),
            // System Health Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'All Systems Operational',
                    style: TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(width: isDesktop ? 16 : 8),
          // Actions
          if (isDesktop)
            IconButton(
              icon: const Icon(Icons.security, color: Color(0xFF4B5563)),
              onPressed: () async {
                final res = await showDialog<String>(
                  context: context,
                  builder: (_) => const Dialog(
                    backgroundColor: Colors.transparent,
                    child: SecurityAlertsDropdown(),
                  ),
                );
                if (res == 'view_all') {
                  _onNavigate(14);
                }
              },
            ),
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: Color(0xFF4B5563),
            ),
            onPressed: () async {
              final res = await showDialog<String>(
                context: context,
                builder: (_) => const Dialog(
                  backgroundColor: Colors.transparent,
                  child: NotificationsDropdown(),
                ),
              );
              if (res == 'view_all') {
                _onNavigate(15);
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: isDesktop ? 8 : 12),
          // Profile
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: kMasterAccent,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'MA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.of(context).size.width >=
        1024; // Update to 1024 for more breathing room

    final screens = _buildScreens(isDesktop);
    final activeScreen = screens[_selectedIndex];

    final animatedScreen = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 150),
      switchInCurve: Curves.decelerate,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.015),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_selectedIndex),
        child: activeScreen,
      ),
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: kMasterWorkspaceColor,
        body: Row(
          children: [
            // Floating Sidebar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: 260,
                decoration: BoxDecoration(
                  color: kMasterSidebarColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 24,
                      offset: const Offset(6, 6),
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      blurRadius: 24,
                      offset: Offset(-6, -6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildSidebarHeader(),
                    _buildSidebarDivider(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _navItems.length,
                        itemBuilder: (context, index) =>
                            _buildNavTile(index, true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Main content area
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(true),
                  Expanded(child: animatedScreen),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile / Tablet layout
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kMasterWorkspaceColor,
      drawer: Drawer(
        backgroundColor: kMasterSidebarColor,
        child: _buildDrawerContent(),
      ),
      body: Column(
        children: [
          SafeArea(bottom: false, child: _buildTopBar(false)),
          Expanded(child: animatedScreen),
        ],
      ),
    );
  }
}

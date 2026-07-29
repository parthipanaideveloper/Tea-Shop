import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/firebase_sync_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../home/franchise_management_screen.dart';
import 'support_settings_screen.dart';
import 'master_admin_shell.dart'; // for kMasterWorkspaceColor

class ShopRegistryEntry {
  final String shopCode;
  final String shopName;
  final DateTime registeredAt;
  DateTime? validUntil;
  bool isBlocked;
  bool isGlobalInventoryEnabled;
  bool isDemoVersion;
  bool showStoreInfo;
  bool showAppSettings;
  bool showReceiptOptions;
  bool showCheckoutFeatures;
  bool showPoweredByDiyan;
  String dietaryFilter;

  ShopRegistryEntry({
    required this.shopCode,
    required this.shopName,
    required this.registeredAt,
    this.validUntil,
    this.isBlocked = false,
    this.isGlobalInventoryEnabled = false,
    this.isDemoVersion = false,
    this.showStoreInfo = true,
    this.showAppSettings = true,
    this.showReceiptOptions = true,
    this.showCheckoutFeatures = true,
    this.showPoweredByDiyan = true,
    this.dietaryFilter = 'both',
  });

  bool get isExpired =>
      validUntil != null && DateTime.now().isAfter(validUntil!);

  String get statusLabel {
    if (isBlocked) return 'BLOCKED';
    if (isExpired) return 'EXPIRED';
    if (validUntil == null) return 'UNLIMITED';
    final daysLeft = validUntil!.difference(DateTime.now()).inDays;
    if (daysLeft <= 7) return 'EXPIRING SOON';
    return 'ACTIVE';
  }

  Color get statusColor {
    if (isBlocked) return Colors.red;
    if (isExpired) return Colors.orange;
    if (validUntil == null) return Colors.blue;
    final daysLeft = validUntil!.difference(DateTime.now()).inDays;
    if (daysLeft <= 7) return Colors.orange;
    return Colors.green;
  }
}

class MasterAdminScreen extends ConsumerStatefulWidget {
  final bool directLoginMode;
  final VoidCallback? onOpenDrawer;
  final ValueChanged<ShopRegistryEntry>? onSelectShop;

  final bool hideAppBar;

  const MasterAdminScreen({
    super.key,
    this.directLoginMode = false,
    this.onOpenDrawer,
    this.onSelectShop,
    this.hideAppBar = false,
  });

  @override
  ConsumerState<MasterAdminScreen> createState() => _MasterAdminScreenState();
}

class _MasterAdminScreenState extends ConsumerState<MasterAdminScreen> {
  List<ShopRegistryEntry> _shops = [];
  bool _loading = true;
  String? _error;

  StreamSubscription? _shopSub;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  @override
  void dispose() {
    _shopSub?.cancel();
    super.dispose();
  }

  Future<void> _loadShops() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    _shopSub?.cancel();
    _shopSub = FirebaseFirestore.instance
        .collection('shops')
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;

            final rawShops = snapshot.docs
                .where((doc) => doc.id != 'host_admin')
                .map((doc) {
                  final data = doc.data();
                  data['shopCode'] = doc.id;
                  if (data['shopName'] == null)
                    data['shopName'] = 'Unknown Shop';
                  if (data['registeredAt'] == null) {
                    data['registeredAt'] = DateTime.now().toIso8601String();
                  }
                  return data;
                })
                .toList();

            final shops = rawShops
                .map(
                  (data) => ShopRegistryEntry(
                    shopCode: data['shopCode'],
                    shopName: data['shopName'],
                    registeredAt: DateTime.parse(data['registeredAt']),
                    validUntil: data['validUntil'] != null
                        ? DateTime.parse(data['validUntil'])
                        : null,
                    isBlocked: data['isBlocked'] ?? false,
                    isGlobalInventoryEnabled:
                        data['isGlobalInventoryEnabled'] ?? false,
                    isDemoVersion:
                        data['isDemoVersion'] == true ||
                        data['isDemoVersion'] == 'true',
                    showStoreInfo:
                        data['showStoreInfo'] != 'false' &&
                        data['showStoreInfo'] != false,
                    showPoweredByDiyan:
                        data['showPoweredByDiyan'] != 'false' &&
                        data['showPoweredByDiyan'] != false,
                    showAppSettings:
                        data['showAppSettings'] != 'false' &&
                        data['showAppSettings'] != false,
                    showReceiptOptions:
                        data['showReceiptOptions'] != 'false' &&
                        data['showReceiptOptions'] != false,
                    showCheckoutFeatures:
                        data['showCheckoutFeatures'] != 'false' &&
                        data['showCheckoutFeatures'] != false,
                    dietaryFilter: data['dietaryFilter'] ?? 'both',
                  ),
                )
                .toList();

            setState(() {
              _shops = shops;
              _loading = false;
            });
          },
          onError: (e) {
            if (mounted) {
              setState(() {
                _error = e.toString();
                _loading = false;
              });
            }
          },
        );
  }

  Future<void> _addShopManually() async {
    final codeCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Add Shop to Registry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: codeCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Shop Code (e.g. DTS-10492)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.store),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (confirmed == true && codeCtrl.text.trim().isNotEmpty) {
      try {
        await FirebaseSyncService().addExistingShopToRegistry(
          codeCtrl.text.trim(),
        );
        _loadShops();
        if (mounted) {
          NotificationHelper.showCenter(
            context,
            'Shop added to registry!',
            isError: false,
          );
        }
      } catch (e) {
        if (mounted) {
          NotificationHelper.showCenter(context, 'Error: $e', isError: true);
        }
      }
    }
  }

  void _showShopActions(ShopRegistryEntry shop) {
    if (widget.onSelectShop != null) {
      widget.onSelectShop!(shop);
    } else {
      if (widget.directLoginMode) {
        _directLoginAsShop(shop);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) =>
                ShopActionScreen(shop: shop, onRefresh: _loadShops),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    return Scaffold(
      backgroundColor: kMasterWorkspaceColor,
      drawer: (isDesktop || widget.onOpenDrawer != null)
          ? null
          : Drawer(
              backgroundColor: kMasterWorkspaceColor,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(
                      top: 60,
                      bottom: 24,
                      left: 24,
                      right: 24,
                    ),
                    width: double.infinity,
                    color: const Color(0xFF4F46E5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.support_agent,
                          color: Colors.white,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'SUPPORT SETTINGS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Console configuration'.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 12,
                            bottom: 8,
                            top: 4,
                          ),
                          child: Text(
                            'GLOBAL CONFIGURATION',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: kMasterWorkspaceColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.white,
                                blurRadius: 4,
                                offset: Offset(-2, -2),
                              ),
                              BoxShadow(
                                color: Color(0xFFD1D9E6),
                                blurRadius: 4,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF4F46E5,
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.settings,
                                color: Color(0xFF4F46E5),
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'Customer Support Settings',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF334155),
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SupportSettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: Text(
                widget.directLoginMode
                    ? 'View Shops Console'
                    : 'Shop Management',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              centerTitle: true,
              backgroundColor: kMasterWorkspaceColor,
              elevation: 0,
              foregroundColor: const Color(0xFF1E293B),
              iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
              actionsIconTheme: const IconThemeData(color: Color(0xFF1E293B)),
              automaticallyImplyLeading: !(widget.directLoginMode && isDesktop),
              leading:
                  (widget.onOpenDrawer != null &&
                      !(widget.directLoginMode && isDesktop))
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: widget.onOpenDrawer,
                    )
                  : null,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadShops,
                  tooltip: 'Refresh',
                ),
                if (!widget.directLoginMode)
                  IconButton(
                    icon: const Icon(Icons.add_business),
                    onPressed: _addShopManually,
                    tooltip: 'Add Existing Shop',
                  ),
              ],
            ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading shops from Firestore...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load shops',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadShops,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _shops.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.store_mall_directory_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No shops registered yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'New shops auto-register when they sign up',
                    style: TextStyle(color: Colors.grey),
                  ),
                  if (!widget.directLoginMode) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _addShopManually,
                      icon: const Icon(Icons.add_business),
                      label: const Text('Add Existing Shop'),
                    ),
                  ],
                ],
              ),
            )
          : Column(
              children: [
                if (!widget.directLoginMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: kMasterWorkspaceColor,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 768;
                        if (isDesktop) {
                          return Row(
                            children: [
                              Expanded(
                                child: _SummaryChip(
                                  label: 'Total Shops',
                                  value: '${_shops.length}',
                                  color: const Color(0xFF4F46E5),
                                  icon: Icons.store_mall_directory_rounded,
                                ),
                              ),
                              Expanded(
                                child: _SummaryChip(
                                  label: 'Active',
                                  value:
                                      '${_shops.where((s) => !s.isBlocked && !s.isExpired).length}',
                                  color: const Color(0xFF10B981),
                                  icon: Icons.check_circle_rounded,
                                ),
                              ),
                              Expanded(
                                child: _SummaryChip(
                                  label: 'Expiring',
                                  value:
                                      '${_shops.where((s) => !s.isBlocked && !s.isExpired && s.validUntil != null && s.validUntil!.difference(DateTime.now()).inDays <= 30).length}',
                                  color: const Color(0xFFF59E0B),
                                  icon: Icons.warning_rounded,
                                ),
                              ),
                              Expanded(
                                child: _SummaryChip(
                                  label: 'Blocked',
                                  value:
                                      '${_shops.where((s) => s.isBlocked).length}',
                                  color: const Color(0xFFEF4444),
                                  icon: Icons.block_rounded,
                                ),
                              ),
                            ],
                          );
                        } else {
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 2.2,
                            children: [
                              _SummaryChip(
                                label: 'Total',
                                value: '${_shops.length}',
                                color: const Color(0xFF4F46E5),
                                icon: Icons.store_mall_directory_rounded,
                              ),
                              _SummaryChip(
                                label: 'Active',
                                value:
                                    '${_shops.where((s) => !s.isBlocked && !s.isExpired).length}',
                                color: const Color(0xFF10B981),
                                icon: Icons.check_circle_rounded,
                              ),
                              _SummaryChip(
                                label: 'Expiring',
                                value:
                                    '${_shops.where((s) => !s.isBlocked && !s.isExpired && s.validUntil != null && s.validUntil!.difference(DateTime.now()).inDays <= 30).length}',
                                color: const Color(0xFFF59E0B),
                                icon: Icons.warning_rounded,
                              ),
                              _SummaryChip(
                                label: 'Blocked',
                                value:
                                    '${_shops.where((s) => s.isBlocked).length}',
                                color: const Color(0xFFEF4444),
                                icon: Icons.block_rounded,
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 768;
                      if (isDesktop) {
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 400,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: widget.directLoginMode
                                    ? 100
                                    : 200,
                              ),
                          itemCount: _shops.length,
                          itemBuilder: (context, index) {
                            final shop = _shops[index];
                            return _ShopCard(
                              shop: shop,
                              directLoginMode: widget.directLoginMode,
                              onTap: () => _showShopActions(shop),
                            );
                          },
                        );
                      } else {
                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _shops.length,
                          itemBuilder: (context, index) {
                            final shop = _shops[index];
                            return _ShopCard(
                              shop: shop,
                              directLoginMode: widget.directLoginMode,
                              onTap: () => _showShopActions(shop),
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _directLoginAsShop(ShopRegistryEntry shop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Impersonate Shop?'),
        content: Text(
          'Are you sure you want to impersonate "${shop.shopName}"?\n\nLocal data will be temporarily cleared and synced from this shop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Impersonate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final error = await ref
          .read(authProvider.notifier)
          .impersonateShop(shop.shopCode);

      if (mounted) {
        Navigator.pop(context); // Close loading indicator
        if (error != null) {
          NotificationHelper.showCenter(context, error, isError: true);
        } else {
          NotificationHelper.showCenter(
            context,
            'Now impersonating shop',
            isError: false,
          );
          Navigator.of(
            context,
          ).popUntil((route) => route.isFirst); // Go back to Home Screen
        }
      }
    }
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Gradient cardGradient = switch (label.toLowerCase()) {
      'total shops' || 'total' => const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'active' => const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'expiring' => const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'blocked' => const LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      _ => LinearGradient(
        colors: [color, color.withOpacity(0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatefulWidget {
  final ShopRegistryEntry shop;
  final VoidCallback onTap;
  final bool directLoginMode;
  const _ShopCard({
    required this.shop,
    required this.onTap,
    this.directLoginMode = false,
  });

  @override
  State<_ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<_ShopCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final onTap = widget.onTap;
    final directLoginMode = widget.directLoginMode;
    final fmt = DateFormat('dd MMM yyyy');

    final cardBgColor = _isHovered ? const Color(0xFFF1F5F9) : Colors.white;

    if (directLoginMode) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isHovered
                ? const [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 4,
                      offset: Offset(-1, -1),
                    ),
                    BoxShadow(
                      color: Color(0xFFC2CBDC),
                      blurRadius: 4,
                      offset: Offset(1, 1),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 10,
                      offset: Offset(-4, -4),
                    ),
                    BoxShadow(
                      color: Color(0xFFD1D9E6),
                      blurRadius: 10,
                      offset: Offset(4, 4),
                    ),
                  ],
            border: Border(
              left: BorderSide(
                color: shop.isBlocked
                    ? Colors.red
                    : (shop.isExpired
                          ? Colors.orange
                          : (shop.statusLabel == 'UNLIMITED'
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF10B981))),
                width: 5,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.store,
                        color: Color(0xFF4F46E5),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.shopName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shop.shopCode,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.login, color: Color(0xFF4F46E5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isHovered
              ? const [
                  BoxShadow(
                    color: Colors.white,
                    blurRadius: 4,
                    offset: Offset(-1, -1),
                  ),
                  BoxShadow(
                    color: Color(0xFFC2CBDC),
                    blurRadius: 4,
                    offset: Offset(1, 1),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Colors.white,
                    blurRadius: 10,
                    offset: Offset(-4, -4),
                  ),
                  BoxShadow(
                    color: Color(0xFFD1D9E6),
                    blurRadius: 10,
                    offset: Offset(4, 4),
                  ),
                ],
          border: Border(
            top: BorderSide(
              color: shop.isBlocked
                  ? Colors.red
                  : (shop.isExpired
                        ? Colors.orange
                        : (shop.statusLabel == 'UNLIMITED'
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF10B981))),
              width: 5,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isHovered
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.store,
                          color: Color(0xFF4F46E5),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.shopName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shop.shopCode,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: shop.statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: shop.statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          shop.statusLabel,
                          style: TextStyle(
                            color: shop.statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCell(
                          icon: Icons.calendar_today,
                          label: 'Registered',
                          value: fmt.format(shop.registeredAt),
                        ),
                      ),
                      Expanded(
                        child: _InfoCell(
                          icon: Icons.event_available,
                          label: 'Valid Until',
                          value: shop.validUntil != null
                              ? fmt.format(shop.validUntil!)
                              : 'Unlimited',
                          valueColor: shop.isExpired
                              ? Colors.red
                              : (shop.validUntil != null &&
                                        shop.validUntil!
                                                .difference(DateTime.now())
                                                .inDays <=
                                            30
                                    ? Colors.orange
                                    : null),
                        ),
                      ),
                      if (shop.validUntil != null && !shop.isExpired)
                        Expanded(
                          child: _InfoCell(
                            icon: Icons.timer,
                            label: 'Days Left',
                            value:
                                '${shop.validUntil!.difference(DateTime.now()).inDays}d',
                            valueColor:
                                shop.validUntil!
                                        .difference(DateTime.now())
                                        .inDays <=
                                    30
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Tap to manage',
                        style: TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Color(0xFF4F46E5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Screen for shop actions
class ShopActionScreen extends ConsumerStatefulWidget {
  final ShopRegistryEntry shop;
  final VoidCallback onRefresh;
  final VoidCallback? onBack;
  const ShopActionScreen({
    required this.shop,
    required this.onRefresh,
    this.onBack,
  });

  @override
  ConsumerState<ShopActionScreen> createState() => _ShopActionScreenState();
}

class _ShopActionScreenState extends ConsumerState<ShopActionScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Always reload fresh values from Firestore to prevent stale cached data
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reloadShopFromFirestore(),
    );
  }

  /// Fetches the latest shop document from Firestore and refreshes local state.
  /// This ensures toggling a value, navigating away, and coming back always shows the correct persisted value.
  Future<void> _reloadShopFromFirestore() async {
    if (!mounted) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shop.shopCode)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      setState(() {
        widget.shop.isDemoVersion =
            data['isDemoVersion'] == true || data['isDemoVersion'] == 'true';
        widget.shop.isGlobalInventoryEnabled =
            data['isGlobalInventoryEnabled'] == true ||
            data['isGlobalInventoryEnabled'] == 'true';
        widget.shop.isBlocked = data['isBlocked'] == true;
        // Feature visibility: default ON if key is absent
        widget.shop.showStoreInfo =
            data['showStoreInfo'] != false && data['showStoreInfo'] != 'false';
        widget.shop.showPoweredByDiyan =
            data['showPoweredByDiyan'] != false &&
            data['showPoweredByDiyan'] != 'false';
        widget.shop.showAppSettings =
            data['showAppSettings'] != false &&
            data['showAppSettings'] != 'false';
        widget.shop.showReceiptOptions =
            data['showReceiptOptions'] != false &&
            data['showReceiptOptions'] != 'false';
        widget.shop.showCheckoutFeatures =
            data['showCheckoutFeatures'] != false &&
            data['showCheckoutFeatures'] != 'false';
        widget.shop.dietaryFilter = data['dietaryFilter'] ?? 'both';
        if (data['validUntil'] != null) {
          widget.shop.validUntil = DateTime.tryParse(
            data['validUntil'].toString(),
          );
        } else if (data['subscriptionEnd'] != null) {
          widget.shop.validUntil = DateTime.tryParse(
            data['subscriptionEnd'].toString(),
          );
        }
      });
    } catch (e) {
      debugPrint('ShopActionScreen: failed to reload from Firestore: $e');
    }
  }

  Future<void> _setBlocked(bool blocked) async {
    setState(() => _loading = true);
    await FirebaseSyncService().updateShopBlocked(
      widget.shop.shopCode,
      blocked,
    );
    widget.shop.isBlocked = blocked;
    setState(() => _loading = false);
    widget.onRefresh();
  }

  Future<void> _setDemoVersion(bool demo) async {
    setState(() => _loading = true);
    await FirebaseSyncService().updateShopDemoVersion(
      widget.shop.shopCode,
      demo,
    );
    widget.shop.isDemoVersion = demo;
    setState(() => _loading = false);
    widget.onRefresh();
  }

  Future<void> _setGlobalInventory(bool enabled) async {
    setState(() => _loading = true);
    await FirebaseSyncService().updateShopGlobalInventory(
      widget.shop.shopCode,
      enabled,
    );
    widget.shop.isGlobalInventoryEnabled = enabled;
    setState(() => _loading = false);
    widget.onRefresh();
  }

  Future<void> _setFeatureToggle(
    String key,
    bool enabled,
    void Function(bool) updateLocal,
  ) async {
    setState(() => _loading = true);
    await FirebaseSyncService().updateShopFeatureToggle(
      widget.shop.shopCode,
      key,
      enabled,
    );
    updateLocal(enabled);

    // Save to local Hive box and update settingsProvider state instantly
    final box = Hive.box<String>('settings');
    box.put(key, enabled.toString());
    ref.read(settingsProvider.notifier).updateSettings();

    setState(() => _loading = false);
    widget.onRefresh();
  }

  Future<void> _confirmDietaryFilterChange(String selectedFilter) async {
    if (selectedFilter == widget.shop.dietaryFilter) return;

    final filterLabel = switch (selectedFilter) {
      'veg' => 'Veg Only 🌱',
      'nonveg' => 'Non-Veg Only 🍖',
      _ => 'Both (Veg & Non-Veg) 🥗',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 12),
            const Text(
              'Change Dietary Filter',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to update the dietary filter for "${widget.shop.shopName}" to:',
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedFilter == 'veg'
                        ? Icons.eco
                        : selectedFilter == 'nonveg'
                        ? Icons.set_meal
                        : Icons.restaurant,
                    color: selectedFilter == 'veg'
                        ? Colors.green
                        : selectedFilter == 'nonveg'
                        ? Colors.red
                        : const Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    filterLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: selectedFilter == 'veg'
                          ? Colors.green.shade800
                          : selectedFilter == 'nonveg'
                          ? Colors.red.shade800
                          : const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will update product visibility across all checkout terminals for this shop.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _setDietaryFilter(selectedFilter);
      if (mounted) {
        NotificationHelper.showCenter(
          context,
          'Dietary filter saved and updated to $filterLabel! ✅',
          isError: false,
        );
      }
    } else {
      setState(() {});
    }
  }

  Future<void> _setDietaryFilter(String filter) async {
    setState(() => _loading = true);
    await FirebaseSyncService().updateShopDietaryFilter(
      widget.shop.shopCode,
      filter,
    );
    widget.shop.dietaryFilter = filter;
    setState(() => _loading = false);
    widget.onRefresh();
  }

  Future<void> _extendValidity(int days) async {
    setState(() => _loading = true);
    final base =
        (widget.shop.validUntil != null &&
            widget.shop.validUntil!.isAfter(DateTime.now()))
        ? widget.shop.validUntil!
        : DateTime.now();
    final newDate = base.add(Duration(days: days));
    await FirebaseSyncService().updateShopValidity(
      widget.shop.shopCode,
      newDate,
    );
    widget.shop.validUntil = newDate;
    setState(() => _loading = false);
    widget.onRefresh();
    if (mounted) {
      NotificationHelper.showCenter(
        context,
        'Validity extended to ${DateFormat('dd MMM yyyy').format(newDate)}',
        isError: false,
      );
    }
  }

  Future<void> _pickCustomDate() async {
    final initial =
        widget.shop.validUntil ?? DateTime.now().add(const Duration(days: 30));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Set Validity Date',
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        helpText: 'Set Validity Time',
      );
      if (pickedTime != null) {
        final finalDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() => _loading = true);
        await FirebaseSyncService().updateShopValidity(
          widget.shop.shopCode,
          finalDateTime,
        );
        widget.shop.validUntil = finalDateTime;
        setState(() => _loading = false);
        widget.onRefresh();
        if (mounted) {
          NotificationHelper.showCenter(
            context,
            'Validity set to ${DateFormat('dd MMM yyyy, hh:mm a').format(finalDateTime)}',
            isError: false,
          );
        }
      }
    }
  }

  Future<void> _deleteShop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Shop?',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to completely delete "${widget.shop.shopName}" (${widget.shop.shopCode})?\n\nThis will remove all products, orders, expenses, and staff from Firebase permanently. This action CANNOT be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await FirebaseSyncService().deleteShopFromRegistry(
          widget.shop.shopCode,
        );
        if (mounted) {
          if (widget.onBack != null) {
            widget.onBack!();
          } else {
            Navigator.pop(context);
          }
          NotificationHelper.showCenter(
            context,
            'Shop deleted permanently.',
            isError: true,
          );
        }
        widget.onRefresh();
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          NotificationHelper.showCenter(
            context,
            'Error deleting shop: $e',
            isError: true,
          );
        }
      }
    }
  }

  Widget _buildNeumorphicTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Color iconColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kMasterWorkspaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
          BoxShadow(
            color: Color(0xFFD1D9E6),
            blurRadius: 6,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        value: value,
        activeColor: const Color(0xFF4F46E5),
        secondary: Icon(icon, color: iconColor),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNeumorphicFeatureTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: kMasterWorkspaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
          BoxShadow(
            color: Color(0xFFD1D9E6),
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
        value: value,
        activeColor: const Color(0xFF4F46E5),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildExtendBtn(String label, int days) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
          BoxShadow(
            color: Color(0xFFD1D9E6),
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(8),
      ),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: kMasterWorkspaceColor,
          foregroundColor: const Color(0xFF4F46E5),
          side: const BorderSide(color: Color(0xFF4F46E5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => _extendValidity(days),
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final fmt = DateFormat('dd MMM yyyy');

    final headerSection = [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kMasterWorkspaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.white,
              blurRadius: 6,
              offset: Offset(-3, -3),
            ),
            BoxShadow(
              color: Color(0xFFD1D9E6),
              blurRadius: 6,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.storefront,
                    color: Color(0xFF4F46E5),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.shopName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.qr_code,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            shop.shopCode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: shop.statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: shop.statusColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: shop.statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        shop.statusLabel.toUpperCase(),
                        style: TextStyle(
                          color: shop.statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (shop.validUntil != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.event_available,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Valid Until: ${fmt.format(shop.validUntil!)}',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: shop.isExpired
                          ? Colors.red.shade50
                          : (shop.validUntil!
                                        .difference(DateTime.now())
                                        .inDays <=
                                    30
                                ? Colors.amber.shade50
                                : Colors.green.shade50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      shop.isExpired
                          ? 'EXPIRED'
                          : '${shop.validUntil!.difference(DateTime.now()).inDays} Days Remaining',
                      style: TextStyle(
                        color: shop.isExpired
                            ? Colors.red.shade700
                            : (shop.validUntil!
                                          .difference(DateTime.now())
                                          .inDays <=
                                      30
                                  ? Colors.amber.shade900
                                  : Colors.green.shade700),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
    ];

    final coreSettings = [
      _buildNeumorphicTile(
        title: 'Block Access',
        subtitle: shop.isBlocked
            ? 'Shop is currently BLOCKED — login denied'
            : 'Shop has normal access',
        value: shop.isBlocked,
        icon: shop.isBlocked ? Icons.lock : Icons.lock_open,
        iconColor: shop.isBlocked ? Colors.red : Colors.green,
        onChanged: (val) => _setBlocked(val),
      ),
      _buildNeumorphicTile(
        title: 'Demo Version Mode',
        subtitle: shop.isDemoVersion
            ? 'App will show "This is a demo version" banner'
            : 'Normal production mode',
        value: shop.isDemoVersion,
        icon: shop.isDemoVersion ? Icons.info_outline : Icons.verified,
        iconColor: shop.isDemoVersion ? Colors.orange : Colors.blue,
        onChanged: (val) => _setDemoVersion(val),
      ),
      _buildNeumorphicTile(
        title: 'Global Inventory Database',
        subtitle: shop.isGlobalInventoryEnabled
            ? 'Shop syncs from Master Global Inventory'
            : 'Shop uses isolated Local Inventory',
        value: shop.isGlobalInventoryEnabled,
        icon: shop.isGlobalInventoryEnabled
            ? Icons.cloud_sync
            : Icons.cloud_off,
        iconColor: shop.isGlobalInventoryEnabled
            ? Colors.deepPurple
            : Colors.grey,
        onChanged: (val) => _setGlobalInventory(val),
      ),
    ];

    final featureSettings = [
      const Text(
        'App Features Visibility',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF1E293B),
        ),
      ),
      const SizedBox(height: 12),
      _buildNeumorphicFeatureTile(
        title: 'Store Information',
        value: shop.showStoreInfo,
        onChanged: (val) => _setFeatureToggle(
          'showStoreInfo',
          val,
          (v) => shop.showStoreInfo = v,
        ),
      ),
      _buildNeumorphicFeatureTile(
        title: 'App Settings',
        value: shop.showAppSettings,
        onChanged: (val) => _setFeatureToggle(
          'showAppSettings',
          val,
          (v) => shop.showAppSettings = v,
        ),
      ),
      _buildNeumorphicFeatureTile(
        title: 'Receipt Options',
        value: shop.showReceiptOptions,
        onChanged: (val) => _setFeatureToggle(
          'showReceiptOptions',
          val,
          (v) => shop.showReceiptOptions = v,
        ),
      ),
      _buildNeumorphicFeatureTile(
        title: 'Checkout & Payment Features',
        value: shop.showCheckoutFeatures,
        onChanged: (val) => _setFeatureToggle(
          'showCheckoutFeatures',
          val,
          (v) => shop.showCheckoutFeatures = v,
        ),
      ),
      const SizedBox(height: 12),
      _buildNeumorphicFeatureTile(
        title: 'Powered by DiyanTech Watermark',
        value: shop.showPoweredByDiyan,
        onChanged: (val) => _setFeatureToggle(
          'showPoweredByDiyan',
          val,
          (v) => shop.showPoweredByDiyan = v,
        ),
      ),
    ];

    final dietarySettings = [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kMasterWorkspaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.white,
              blurRadius: 6,
              offset: Offset(-3, -3),
            ),
            BoxShadow(
              color: Color(0xFFD1D9E6),
              blurRadius: 6,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    color: Color(0xFF4F46E5),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dietary Filter',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Select menu dietary rules for this shop',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: shop.dietaryFilter == 'veg'
                      ? Colors.green.shade100
                      : shop.dietaryFilter == 'nonveg'
                      ? Colors.red.shade100
                      : const Color(0xFFE0E7FF),
                  selectedForegroundColor: shop.dietaryFilter == 'veg'
                      ? Colors.green.shade800
                      : shop.dietaryFilter == 'nonveg'
                      ? Colors.red.shade800
                      : const Color(0xFF4F46E5),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                segments: const [
                  ButtonSegment(
                    value: 'both',
                    label: Text('Both'),
                    icon: Icon(Icons.restaurant, size: 18),
                  ),
                  ButtonSegment(
                    value: 'veg',
                    label: Text('Veg Only'),
                    icon: Icon(Icons.eco, size: 18),
                  ),
                  ButtonSegment(
                    value: 'nonveg',
                    label: Text('Non-Veg Only'),
                    icon: Icon(Icons.set_meal, size: 18),
                  ),
                ],
                selected: {shop.dietaryFilter},
                onSelectionChanged: (Set<String> newSelection) =>
                    _confirmDietaryFilterChange(newSelection.first),
              ),
            ),
          ],
        ),
      ),
    ];

    final actionSettings = [
      Container(
        decoration: BoxDecoration(
          boxShadow: const [
            BoxShadow(
              color: Colors.white,
              blurRadius: 4,
              offset: Offset(-2, -2),
            ),
            BoxShadow(
              color: Color(0xFFD1D9E6),
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(10),
        ),
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () async {
            setState(() => _loading = true);
            try {
              await FirebaseSyncService().injectGlobalDefaults(
                widget.shop.shopCode,
              );
              if (mounted)
                NotificationHelper.showCenter(
                  context,
                  'Global Inventory injected into "" successfully!',
                  isError: false,
                );
            } catch (e) {
              if (mounted)
                NotificationHelper.showCenter(
                  context,
                  'Failed to inject global inventory: ',
                  isError: true,
                );
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          icon: const Icon(Icons.sync),
          label: const Text(
            'Force Sync Global Inventory Defaults',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      const Divider(height: 36, color: Color(0xFFE2E8F0)),
      const Text(
        'Extend Validity',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF1E293B),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _buildExtendBtn('+30 Days', 30)),
          const SizedBox(width: 12),
          Expanded(child: _buildExtendBtn('+90 Days', 90)),
          const SizedBox(width: 12),
          Expanded(child: _buildExtendBtn('+365 Days', 365)),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(
          boxShadow: const [
            BoxShadow(
              color: Colors.white,
              blurRadius: 4,
              offset: Offset(-2, -2),
            ),
            BoxShadow(
              color: Color(0xFFD1D9E6),
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(10),
        ),
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: kMasterWorkspaceColor,
            foregroundColor: const Color(0xFF4F46E5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            side: const BorderSide(color: Color(0xFF4F46E5)),
          ),
          onPressed: _pickCustomDate,
          icon: const Icon(Icons.edit_calendar),
          label: const Text(
            'Set Custom Date',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      const Divider(height: 36, color: Color(0xFFE2E8F0)),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _deleteShop,
          icon: const Icon(Icons.delete_forever),
          label: const Text(
            'Delete Shop Permanently',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: kMasterWorkspaceColor,
      appBar: AppBar(
        title: const Text(
          'Manage Shop',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: kMasterWorkspaceColor,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        leading: BackButton(
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: isDesktop
                            ? Column(
                                children: [
                                  ...headerSection,
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ...coreSettings,
                                            const SizedBox(height: 24),
                                            ...dietarySettings,
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 48),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ...featureSettings,
                                            const SizedBox(height: 24),
                                            const Divider(
                                              height: 1,
                                              color: Color(0xFFE2E8F0),
                                            ),
                                            const SizedBox(height: 24),
                                            ...actionSettings,
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...headerSection,
                                  ...coreSettings,
                                  const SizedBox(height: 16),
                                  ...featureSettings,
                                  const SizedBox(height: 16),
                                  ...dietarySettings,
                                  const Divider(
                                    height: 36,
                                    color: Color(0xFFE2E8F0),
                                  ),
                                  ...actionSettings,
                                ],
                              ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math' as math;

// Providers
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/refund_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/printer_provider.dart';

// Models
import '../../domain/models/product.dart';

// Extensions & Utils
import '../../core/extensions/string_extensions.dart';
import '../../core/utils/notification_helper.dart';

// Neumorphic Widgets
import '../widgets/neumorphic_widgets.dart';

// Services
import '../../services/backup_service.dart';

class _PremiumSolidCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? color;
  final double borderRadius;

  const _PremiumSolidCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderColor,
    this.color,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            offset: const Offset(0, 6),
            blurRadius: 24,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

class DesktopOverviewDashboard extends ConsumerWidget {
  final Function(String) onNavigate;
  final VoidCallback onOpenAddProduct;
  final VoidCallback onOpenAddCustomer;

  const DesktopOverviewDashboard({
    super.key,
    required this.onNavigate,
    required this.onOpenAddProduct,
    required this.onOpenAddCustomer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderProvider);
    final inventory = ref.watch(inventoryProvider);
    final refunds = ref.watch(refundProvider);
    final staff = ref.watch(staffAccountsProvider);
    final printer = ref.watch(printerProvider);
    final language = ref.watch(languageProvider);
    final session = ref.watch(authProvider);

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat(
      'yyyy-MM-dd',
    ).format(now.subtract(const Duration(days: 1)));

    // ----------------------------------------------------
    // DATA COMPUTATIONS
    // ----------------------------------------------------

    // Today's & Yesterday's Orders (non-voided)
    final todayOrders = orders
        .where(
          (o) =>
              !o.isVoided && !o.isRefunded && !o.isDeleted &&
              !o.isDeleted &&
              DateFormat('yyyy-MM-dd').format(o.date.toLocal()) == todayStr,
        )
        .toList();
    final yesterdayOrders = orders
        .where(
          (o) =>
              !o.isVoided && !o.isRefunded && !o.isDeleted &&
              !o.isDeleted &&
              DateFormat('yyyy-MM-dd').format(o.date.toLocal()) == yesterdayStr,
        )
        .toList();

    // 1. Revenue Metrics
    final todayRevenue = todayOrders.fold<double>(
      0.0,
      (sum, o) => sum + o.total,
    );
    final yesterdayRevenue = yesterdayOrders.fold<double>(
      0.0,
      (sum, o) => sum + o.total,
    );
    final revenueTrend = yesterdayRevenue > 0
        ? ((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100
        : (todayRevenue > 0 ? 100.0 : 0.0);

    // 2. Transactions Metrics
    final todayTxCount = todayOrders.length;
    final yesterdayTxCount = yesterdayOrders.length;
    final txTrend = yesterdayTxCount > 0
        ? ((todayTxCount - yesterdayTxCount) / yesterdayTxCount) * 100
        : (todayTxCount > 0 ? 100.0 : 0.0);

    // 3. Customer Metrics (Unique customers in today's orders vs yesterday)
    final todayCustomers = todayOrders
        .map((o) => o.customerPhone.isEmpty ? o.customerName : o.customerPhone)
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;
    final yesterdayCustomers = yesterdayOrders
        .map((o) => o.customerPhone.isEmpty ? o.customerName : o.customerPhone)
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;
    final customerTrend = yesterdayCustomers > 0
        ? ((todayCustomers - yesterdayCustomers) / yesterdayCustomers) * 100
        : (todayCustomers > 0 ? 100.0 : 0.0);

    // 4. Inventory Health Metrics
    final totalProductsCount = inventory.length;
    final outOfStockProducts = inventory
        .where((p) => p.trackInventory && p.stockCount == 0)
        .toList();
    final lowStockProducts = inventory
        .where((p) => p.trackInventory && p.stockCount > 0 && p.stockCount <= 5)
        .toList();
    final healthyProductsCount = totalProductsCount - outOfStockProducts.length;
    final inventoryHealthRatio = totalProductsCount > 0
        ? (healthyProductsCount / totalProductsCount) * 100
        : 100.0;

    // Sparklines data (Last 7 days trends)
    List<double> get7DayRevenueHistory() {
      List<double> history = [];
      for (int i = 6; i >= 0; i--) {
        final dStr = DateFormat(
          'yyyy-MM-dd',
        ).format(now.subtract(Duration(days: i)));
        final dayRev = orders
            .where(
              (o) =>
                  !o.isVoided && !o.isRefunded && !o.isDeleted &&
                  DateFormat('yyyy-MM-dd').format(o.date.toLocal()) == dStr,
            )
            .fold<double>(0.0, (sum, o) => sum + o.total);
        history.add(dayRev);
      }
      return history;
    }

    List<double> get7DayTxHistory() {
      List<double> history = [];
      for (int i = 6; i >= 0; i--) {
        final dStr = DateFormat(
          'yyyy-MM-dd',
        ).format(now.subtract(Duration(days: i)));
        final count = orders
            .where(
              (o) =>
                  !o.isVoided && !o.isRefunded && !o.isDeleted &&
                  DateFormat('yyyy-MM-dd').format(o.date.toLocal()) == dStr,
            )
            .length;
        history.add(count.toDouble());
      }
      return history;
    }

    List<double> get7DayCustomerHistory() {
      List<double> history = [];
      for (int i = 6; i >= 0; i--) {
        final dStr = DateFormat(
          'yyyy-MM-dd',
        ).format(now.subtract(Duration(days: i)));
        final dailyOrders = orders
            .where(
              (o) =>
                  !o.isVoided && !o.isRefunded && !o.isDeleted &&
                  DateFormat('yyyy-MM-dd').format(o.date.toLocal()) == dStr,
            )
            .toList();
        final dailyCust = dailyOrders
            .map(
              (o) => o.customerPhone.isEmpty ? o.customerName : o.customerPhone,
            )
            .where((c) => c.isNotEmpty)
            .toSet()
            .length;
        history.add(dailyCust.toDouble());
      }
      return history;
    }

    List<double> getInventorySparklineData() {
      if (inventory.isEmpty) return [0.0, 0.0];
      final list = inventory.map((p) => p.stockCount.toDouble()).toList();
      if (list.length == 1) return [list[0], list[0]];
      return list.take(10).toList();
    }

    // 14-Day Sales curve data points
    List<Map<String, dynamic>> get14DayChartData() {
      List<Map<String, dynamic>> chartData = [];
      for (int i = 13; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final label = DateFormat('dd MMM').format(date);
        final dStr = DateFormat('yyyy-MM-dd').format(date);
        final dayRevenue = orders
            .where(
              (o) =>
                  !o.isVoided && !o.isRefunded && !o.isDeleted &&
                  DateFormat('yyyy-MM-dd').format(o.date.toLocal()) == dStr,
            )
            .fold<double>(0.0, (sum, o) => sum + o.total);
        chartData.add({'label': label, 'value': dayRevenue});
      }
      return chartData;
    }

    final chartPoints = get14DayChartData();

    // Payment Distribution - strictly today's orders
    double upiTotal = 0.0;
    double cashTotal = 0.0;
    double cardTotal = 0.0;
    for (var o in todayOrders) {
      final mode = o.paymentMode;
      if (mode.startsWith('Split|')) {
        final parts = mode.split('|');
        if (parts.length >= 3) {
          cashTotal += double.tryParse(parts[1]) ?? 0.0;
          upiTotal += double.tryParse(parts[2]) ?? 0.0;
        } else {
          cashTotal += o.total / 2;
          upiTotal += o.total / 2;
        }
      } else if (mode.toUpperCase().contains('UPI')) {
        upiTotal += o.total;
      } else if (mode.toUpperCase().contains('CASH')) {
        cashTotal += o.total;
      } else if (mode.toUpperCase().contains('CARD')) {
        cardTotal += o.total;
      } else {
        // Fallback
        cashTotal += o.total;
      }
    }
    final totalPayment = upiTotal + cashTotal + cardTotal;
    final upiPercent = totalPayment > 0 ? (upiTotal / totalPayment) : 0.0;
    final cashPercent = totalPayment > 0 ? (cashTotal / totalPayment) : 0.0;
    final cardPercent = totalPayment > 0 ? (cardTotal / totalPayment) : 0.0;

    // Top Products ranking
    Map<String, Map<String, dynamic>> productRanking = {};
    for (var o in todayOrders.where((o) => !o.isVoided && !o.isRefunded && !o.isDeleted)) {
      for (var item in o.parsedItems) {
        final id = item.product.id;
        if (!productRanking.containsKey(id)) {
          productRanking[id] = {
            'product': item.product,
            'qty': 0.0,
            'revenue': 0.0,
          };
        }
        productRanking[id]!['qty'] =
            (productRanking[id]!['qty'] as double) + item.quantity;
        productRanking[id]!['revenue'] =
            (productRanking[id]!['revenue'] as double) +
            (item.quantity * item.product.price);
      }
    }
    final rankedProducts = productRanking.values.toList()
      ..sort((a, b) => (b['qty'] as double).compareTo(a['qty'] as double));
    final topProducts = rankedProducts.take(5).toList();

    // Staff Performance aggregation (excluding master admin)
    Map<String, Map<String, dynamic>> staffMetrics = {};
    for (var s in staff) {
      staffMetrics[s.name] = {
        'name': s.name,
        'role': s.role,
        'sales': 0.0,
        'txCount': 0,
      };
    }
    for (var o in todayOrders.where((o) => !o.isVoided && !o.isRefunded && !o.isDeleted)) {
      final sName = o.staffName.trim().isEmpty ? 'Admin' : o.staffName;
      if (!staffMetrics.containsKey(sName)) {
        staffMetrics[sName] = {
          'name': sName,
          'role': 'Admin',
          'sales': 0.0,
          'txCount': 0,
        };
      }
      staffMetrics[sName]!['sales'] =
          (staffMetrics[sName]!['sales'] as double) + o.total;
      staffMetrics[sName]!['txCount'] =
          (staffMetrics[sName]!['txCount'] as int) + 1;
    }
    final staffRanked =
        staffMetrics.values.where((s) {
          final nameLower = s['name'].toString().toLowerCase();
          final roleLower = s['role'].toString().toLowerCase();
          return !nameLower.contains('master') &&
              !nameLower.contains('host_admin') &&
              !nameLower.contains('admin (') && // filter impersonating host admins
              !roleLower.contains('master');
        }).toList()..sort(
          (a, b) => (b['sales'] as double).compareTo(a['sales'] as double),
        );

    // Calculate top categories for today
    Map<String, double> categorySales = {};
    for (var o in todayOrders) {
      for (var item in o.parsedItems) {
        final cat = item.product.category.trim().isEmpty
            ? 'Uncategorized'
            : item.product.category;
        categorySales[cat] =
            (categorySales[cat] ?? 0.0) + (item.quantity * item.product.price);
      }
    }
    final rankedCategories = categorySales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Merged Activity Stream (Max 10 events, real telemetry where possible)
    List<Map<String, dynamic>> activities = [];
    final recentOrders = orders.length > 15
        ? orders.sublist(orders.length - 15)
        : orders;
    for (var o in recentOrders.reversed) {
      activities.add({
        'type': 'order',
        'title': 'Sale completed'.tr(language),
        'desc':
            'Order #${o.displayId} - ${o.customerName.isEmpty ? 'Walk-in Customer' : o.customerName}',
        'amount': o.total,
        'user': o.staffName.isEmpty ? 'Admin' : o.staffName,
        'date': o.date,
        'color': Colors.green,
        'icon': Icons.point_of_sale,
      });
    }
    final recentRefunds = refunds.length > 10
        ? refunds.sublist(refunds.length - 10)
        : refunds;
    for (var r in recentRefunds.reversed) {
      activities.add({
        'type': 'refund',
        'title': 'Refund processed'.tr(language),
        'desc': 'Ref: ${r.originalOrderId} - Reason: ${r.reason}',
        'amount': -r.amountRefunded,
        'user': r.staffName,
        'date': r.date,
        'color': Colors.red,
        'icon': Icons.assignment_return,
      });
    }
    for (var p in lowStockProducts.take(5)) {
      activities.add({
        'type': 'stock_warning',
        'title': 'Low stock warning'.tr(language),
        'desc': '${p.name} is running low (${p.stockCount} left)',
        'amount': null,
        'user': 'System',
        'date': now,
        'color': Colors.orange,
        'icon': Icons.warning_amber_rounded,
      });
    }
    for (var p in outOfStockProducts.take(5)) {
      activities.add({
        'type': 'stock_alert',
        'title': 'Out of stock'.tr(language),
        'desc': '${p.name} is out of stock!',
        'amount': null,
        'user': 'System',
        'date': now,
        'color': Colors.redAccent,
        'icon': Icons.block_flipped,
      });
    }
    activities.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );
    final displayActivities = activities.take(8).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------
          // 1. WELCOME SECTION
          // ----------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_getGreeting()}, ${session?.name ?? 'Operator'}! 👋',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Shift Active • POS Terminal Online • Store Code: ${Hive.box<String>('settings').get('shopCode') ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => onNavigate('printer_setup'),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: printer.connectedDevice != null
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: printer.connectedDevice != null
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFFDE68A),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: printer.connectedDevice != null
                                ? const Color(0xFF16803D)
                                : const Color(0xFFB45309),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          printer.connectedDevice != null
                              ? 'All Systems Operational'
                              : 'Printer Not Configured',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: printer.connectedDevice != null
                                ? const Color(0xFF16803D)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ----------------------------------------------------
          // QUICK ACTIONS SECTION
          // ----------------------------------------------------
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildHorizontalQuickActionItem(
                  label: 'New Sale',
                  icon: Icons.shopping_cart_outlined,
                  color: const Color(0xFF3B82F6),
                  onTap: () => onNavigate('billing'),
                  scale: 1.0,
                ),
                const SizedBox(width: 12),
                _buildHorizontalQuickActionItem(
                  label: 'Add Product',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => onNavigate('inventory'),
                  scale: 1.0,
                ),
                const SizedBox(width: 12),
                _buildHorizontalQuickActionItem(
                  label: 'Add Customer',
                  icon: Icons.person_add_alt_1_rounded,
                  color: const Color(0xFF14B8A6),
                  onTap: () => onNavigate('customers'),
                  scale: 1.0,
                ),
                const SizedBox(width: 12),
                _buildHorizontalQuickActionItem(
                  label: 'Expenses',
                  icon: Icons.currency_rupee_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () => onNavigate('expenses'),
                  scale: 1.0,
                ),
                const SizedBox(width: 12),
                _buildHorizontalQuickActionItem(
                  label: 'Sales Report',
                  icon: Icons.show_chart_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => onNavigate('sales'),
                  scale: 1.0,
                ),
                const SizedBox(width: 12),
                _buildHorizontalQuickActionItem(
                  label: 'System Settings',
                  icon: Icons.settings_rounded,
                  color: const Color(0xFF64748B),
                  onTap: () => onNavigate('settings'),
                  scale: 1.0,
                ),
                const SizedBox(width: 12),
                _buildHorizontalQuickActionItem(
                  label: 'Support Ticket',
                  icon: Icons.forum_outlined,
                  color: const Color(0xFF4F46E5),
                  onTap: () => onNavigate('support_ticket'),
                  scale: 1.0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ----------------------------------------------------
          // 2. KPI SECTION
          // ----------------------------------------------------
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width < 1400 ? 3 : 5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            children: [
              _buildKpiCard(
                title: 'Total Revenue',
                subtitle: 'Today',
                value: '₹${NumberFormat('#,##0.00').format(todayRevenue)}',
                trend: revenueTrend,
                sparkData: get7DayRevenueHistory(),
                icon: Icons.currency_rupee,
                iconColor: Colors.blue.shade600,
                cardBgColor: Colors.white,
                borderColor: Colors.blue.withOpacity(0.12),
              ),
              _buildKpiCard(
                title: 'Total Transactions',
                subtitle: 'Today',
                value: '${todayOrders.length}',
                trend: txTrend,
                sparkData: get7DayTxHistory(),
                icon: Icons.receipt_long,
                iconColor: Colors.green.shade600,
                cardBgColor: Colors.white,
                borderColor: Colors.green.withOpacity(0.12),
              ),
              _buildKpiCard(
                title: 'Active Customers',
                subtitle: 'Today',
                value:
                    '${get7DayCustomerHistory().isNotEmpty ? get7DayCustomerHistory().last.toInt() : 0}',
                trend: customerTrend,
                sparkData: get7DayCustomerHistory(),
                icon: Icons.people,
                iconColor: Colors.teal.shade600,
                cardBgColor: Colors.white,
                borderColor: Colors.teal.withOpacity(0.12),
              ),
              _buildKpiCard(
                title: 'Inventory Health',
                subtitle: 'Today',
                value: '${inventoryHealthRatio.toStringAsFixed(1)}%',
                trend: -(lowStockProducts.length + outOfStockProducts.length)
                    .toDouble(),
                trendText:
                    '${lowStockProducts.length + outOfStockProducts.length} Alerts',
                sparkData: getInventorySparklineData(),
                icon: Icons.inventory_2,
                iconColor: Colors.purple.shade600,
                cardBgColor: Colors.white,
                borderColor: Colors.purple.withOpacity(0.12),
              ),
              _buildKpiCard(
                title: 'Refunds Today',
                subtitle: 'Today',
                value:
                    '₹${NumberFormat('#,##0.00').format(refunds.where((r) => DateFormat('yyyy-MM-dd').format(r.date) == DateFormat('yyyy-MM-dd').format(now)).fold(0.0, (sum, r) => sum + r.amountRefunded))}',
                trend: 0.0,
                trendText: 'Stable',
                sparkData: [0, 0, 0, 0, 0, 0, 0],
                icon: Icons.replay,
                iconColor: Colors.orange.shade600,
                cardBgColor: Colors.white,
                borderColor: Colors.orange.withOpacity(0.12),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ----------------------------------------------------
          // 3. ANALYTICS & PAYMENT SECTION (Dual Column)
          // ----------------------------------------------------
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Main Curve Chart
                Expanded(
                  flex: 2,
                  child: _PremiumSolidCard(
                    borderColor: Colors.blue.withOpacity(0.12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardHeader(
                          title: 'Sales Overview'.tr(language),
                          buttonLabel: 'View Report',
                          onTap: () => onNavigate('sales'),
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.show_chart,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Live Telemetry',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 240,
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: CustomCurveChartPainter(
                              points: chartPoints,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 28),

                // Payment distribution donut chart
                Expanded(
                  child: _PremiumSolidCard(
                    borderColor: Colors.indigo.withOpacity(0.12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardHeader(
                          title: 'Payment Distribution'.tr(language),
                          buttonLabel: 'View Analytics',
                          onTap: () => onNavigate('sales'),
                          color: Colors.indigo,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              width: 130,
                              height: 130,
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: const Size(130, 130),
                                    painter: DonutChartPainter(
                                      cashPercent: cashPercent,
                                      upiPercent: upiPercent,
                                      cardPercent: cardPercent,
                                    ),
                                  ),
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Total',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${NumberFormat('#,##0.00').format(totalPayment)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildDonutLegendItem(
                                    'Cash Sales',
                                    cashPercent,
                                    cashTotal,
                                    const Color(0xFF10B981),
                                  ),
                                  _buildDonutLegendItem(
                                    'UPI Transactions',
                                    upiPercent,
                                    upiTotal,
                                    const Color(0xFF8B5CF6),
                                  ),
                                  _buildDonutLegendItem(
                                    'Card Settlements',
                                    cardPercent,
                                    cardTotal,
                                    const Color(0xFFF59E0B),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Average Order Value',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${NumberFormat('#,##0.00').format(todayTxCount == 0 ? 0 : todayRevenue / todayTxCount)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Orders Today',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$todayTxCount',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ----------------------------------------------------
          // NEW PREMIUM FEATURES (Staff, Categories, Peak Hours)
          // ----------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: _buildStaffLeaderboardCard(staffRanked, language),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildTopCategoriesCard(rankedCategories, language),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildPeakHoursCard(todayOrders, language),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ----------------------------------------------------
          // 4. BOTTOM AREA (Dual Column Layout)
          // ----------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (flex: 2) -> Top Products & Recent Activity side-by-side
              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTopProductsCard(
                        topProducts,
                        language,
                        onNavigate,
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: _buildRecentActivityCard(
                        displayActivities,
                        language,
                        onNavigate,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 28),

              // Right Column (flex: 1) -> Inventory Alerts
              Expanded(
                child: Column(
                  children: [
                    _buildInventoryAlertsCard(
                      lowStockProducts,
                      outOfStockProducts,
                      language,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper greet
  String _getGreeting() {
    final hr = DateTime.now().hour;
    if (hr < 12) return 'Good morning';
    if (hr < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildEmptyState(String msg) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, color: Colors.grey.shade400, size: 28),
            const SizedBox(height: 8),
            Text(
              msg,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutLegendItem(
    String label,
    double percent,
    double total,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '₹${NumberFormat('#,##0.00').format(total)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(
    List<dynamic> topProducts,
    String language,
    Function(String) onNavigate,
  ) {
    return _PremiumSolidCard(
      borderColor: Colors.teal.withOpacity(0.12),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            title: 'Top Products'.tr(language),
            buttonLabel: 'View Performance',
            onTap: () => onNavigate('performance'),
            color: Colors.teal,
          ),
          if (topProducts.isEmpty)
            _buildEmptyState('No products sold yet')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(topProducts.length, 4),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final pData = topProducts[index];
                final p = pData['product'] as Product;
                final qty = pData['qty'] as double;
                return Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFF64748B),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ${p.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Qty: ${qty.toInt()} • ₹${NumberFormat('#,##0.00').format(p.price)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 16,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(
    List<Map<String, dynamic>> displayActivities,
    String language,
    Function(String) onNavigate,
  ) {
    return _PremiumSolidCard(
      borderColor: Colors.purple.withOpacity(0.12),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            title: 'Recent Activity'.tr(language),
            buttonLabel: 'View Logs',
            onTap: () => onNavigate('audit'),
            color: Colors.purple,
          ),
          if (displayActivities.isEmpty)
            _buildEmptyState('No recent activity')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayActivities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final act = displayActivities[index];
                final type = act['type'] as String;
                final title = act['title'] as String;
                final desc = act['desc'] as String;
                final date = act['date'] as DateTime;
                final color = act['color'] as Color;
                final icon = act['icon'] as IconData;
                final amount = act['amount'] as double?;
                final user = act['user'] as String;

                Widget trailingWidget;
                if (type == 'stock_warning' || type == 'stock_alert') {
                  final badgeText = type == 'stock_warning' ? 'LOW' : 'OUT';
                  trailingWidget = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withOpacity(0.15)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  );
                } else if (amount != null) {
                  final isNegative = amount < 0;
                  final formattedAmount =
                      '${isNegative ? '-' : ''}₹${NumberFormat('#,##0.00').format(amount.abs())}';
                  trailingWidget = Text(
                    formattedAmount,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isNegative
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                  );
                } else {
                  trailingWidget = Text(
                    user,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  );
                }

                return Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$desc • ${DateFormat('hh:mm a').format(date)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    trailingWidget,
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInventoryAlertsCard(
    List<Product> lowStock,
    List<Product> outOfStock,
    String language,
  ) {
    return _PremiumSolidCard(
      borderColor: Colors.purple.withOpacity(0.12),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            title: 'Inventory Alerts'.tr(language),
            buttonLabel: 'View All',
            onTap: () => onNavigate('inventory'),
            color: Colors.purple,
          ),
          Row(
            children: [
              Expanded(
                child: _buildAlertBadge(
                  title: 'Low Stock Items',
                  value: '${lowStock.length}',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAlertBadge(
                  title: 'Out of Stock',
                  value: '${outOfStock.length}',
                  icon: Icons.cancel_presentation_rounded,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBadge({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(Function(String) onNavigate) {
    return _PremiumSolidCard(
      borderColor: Colors.blue.withOpacity(0.12),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view_rounded, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.05,
            children: [
              _buildQuickActionItem(
                label: 'New Sale',
                icon: Icons.shopping_cart_outlined,
                color: const Color(0xFF3B82F6),
                onTap: () => onNavigate('billing'),
              ),
              _buildQuickActionItem(
                label: 'Billing Terminal',
                icon: Icons.point_of_sale_outlined,
                color: const Color(0xFF10B981),
                onTap: () => onNavigate('billing'),
              ),
              _buildQuickActionItem(
                label: 'Add Product',
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFF8B5CF6),
                onTap: () => onNavigate('inventory'),
              ),
              _buildQuickActionItem(
                label: 'Add Customer',
                icon: Icons.person_add_alt_1_rounded,
                color: const Color(0xFF14B8A6),
                onTap: () => onNavigate('customers'),
              ),
              _buildQuickActionItem(
                label: 'Stock Update',
                icon: Icons.loop_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => onNavigate('inventory'),
              ),
              _buildQuickActionItem(
                label: 'Sales Overview',
                icon: Icons.show_chart_rounded,
                color: const Color(0xFF3B82F6),
                onTap: () => onNavigate('sales'),
              ),
              _buildQuickActionItem(
                label: 'Expenses',
                icon: Icons.currency_rupee_rounded,
                color: const Color(0xFFEF4444),
                onTap: () => onNavigate('expenses'),
              ),
              _buildQuickActionItem(
                label: 'Settings',
                icon: Icons.settings_rounded,
                color: const Color(0xFF64748B),
                onTap: () => onNavigate('settings'),
              ),
              _buildQuickActionItem(
                label: 'Support Ticket',
                icon: Icons.forum_outlined,
                color: const Color(0xFF4F46E5),
                onTap: () => onNavigate('support_ticket'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                offset: const Offset(0, 4),
                blurRadius: 12,
                spreadRadius: -2,
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.2), width: 1),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalQuickActionItem({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double scale,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 170 * scale,
          height: 60 * scale,
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 8 * scale,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                offset: const Offset(0, 6),
                blurRadius: 16,
                spreadRadius: -2,
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38 * scale,
                height: 38 * scale,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.2), width: 1),
                ),
                child: Icon(icon, color: color, size: 18 * scale),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF94A3B8),
          fontSize: 11,
        ),
      ),
    );
  }

  // Highlighted Header Row with View All Button
  Widget _buildCardHeader({
    required String title,
    required String buttonLabel,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: color.withOpacity(0.12), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              backgroundColor: color.withOpacity(0.08),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buttonLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 12, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Neumorphic KPI Card
  Widget _buildKpiCard({
    required String title,
    required String value,
    required double trend,
    required List<double> sparkData,
    required IconData icon,
    required Color iconColor,
    String? subtitle,
    String? trendText,
    Color? cardBgColor,
    Color? borderColor,
  }) {
    final isZero = trend == 0.0;
    final isPositive = trend > 0.0;

    String tText =
        trendText ??
        (isZero
            ? '0.0% vs Yesterday'
            : '${isPositive ? '+' : ''}${trend.toStringAsFixed(1)}% vs Yesterday');

    final Color badgeBg = isZero
        ? const Color(0xFFF1F5F9)
        : (isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2));
    final Color badgeText = isZero
        ? const Color(0xFF475569)
        : (isPositive ? const Color(0xFF15803D) : const Color(0xFFB91C1C));
    final IconData badgeIcon = isZero
        ? Icons.trending_flat
        : (isPositive
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded);

    return _PremiumSolidCard(
      padding: const EdgeInsets.only(top: 18, left: 18, right: 18, bottom: 0),
      color: cardBgColor,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 12,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, color: badgeText, size: 12),
                const SizedBox(width: 4),
                Text(
                  tText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeText,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 38,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(data: sparkData, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }

  // Inventory insights rows
  Widget _buildInventoryInsightItem(
    String label,
    int value,
    int total,
    Color color,
  ) {
    final double fraction = total > 0 ? value / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              '$value / $total',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: Colors.grey.shade100,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // Payment channel progress rows
  Widget _buildPaymentDistributionRow(
    String title,
    double fraction,
    double total,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            Text(
              '${(fraction * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: fraction,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              constraints: const BoxConstraints(minWidth: 60),
              alignment: Alignment.centerRight,
              child: Text(
                '₹${NumberFormat('#,##0').format(total)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // NEW PREMIUM FEATURES
  // ----------------------------------------------------

  Widget _buildStaffLeaderboardCard(
    List<dynamic> staffRanked,
    String language,
  ) {
    return _PremiumSolidCard(
      borderColor: Colors.amber.withOpacity(0.12),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.leaderboard_rounded,
                  color: Colors.amber,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Performance'.tr(language),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Live Leaderboard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (staffRanked.isEmpty)
            _buildEmptyState('No staff data yet')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(staffRanked.length, 3),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final s = staffRanked[index] as Map<String, dynamic>;
                final name = s['name'] as String;
                final sales = s['sales'] as double;

                final isTop = index == 0;

                return Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isTop ? Colors.amber : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isTop ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${NumberFormat.compact().format(sales)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isTop
                            ? Colors.amber.shade700
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopCategoriesCard(
    List<MapEntry<String, double>> rankedCategories,
    String language,
  ) {
    return _PremiumSolidCard(
      borderColor: Colors.deepOrange.withOpacity(0.12),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: Colors.deepOrange,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Categories'.tr(language),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Best Sellers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (rankedCategories.isEmpty)
            _buildEmptyState('No categories yet')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(rankedCategories.length, 3),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = rankedCategories[index];
                final maxSales = rankedCategories.first.value;
                final fraction = maxSales > 0 ? entry.value / maxSales : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${NumberFormat.compact().format(entry.value)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: Colors.deepOrange,
                        minHeight: 6,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPeakHoursCard(List<dynamic> todayOrders, String language) {
    // Calculate peak hours
    Map<int, int> orderCountByHour = {};
    for (int i = 0; i < 24; i++) orderCountByHour[i] = 0;

    for (var order in todayOrders) {
      if (order.date != null) {
        orderCountByHour[order.date.hour] =
            (orderCountByHour[order.date.hour] ?? 0) + 1;
      }
    }

    // Find max to scale bars
    int maxOrders = 1; // avoid division by zero
    for (var count in orderCountByHour.values) {
      if (count > maxOrders) maxOrders = count;
    }

    // Filter to business hours (e.g., 9 AM to 10 PM)
    List<int> businessHours = List.generate(
      14,
      (index) => index + 9,
    ); // 9 to 22

    return _PremiumSolidCard(
      borderColor: Colors.pink.withOpacity(0.12),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.pink.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.access_time_filled_rounded,
                      color: Colors.pink,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peak Hours Activity'.tr(language),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Today\'s Busy Times',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.pink.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.pink,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Live Tracking',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Bar Chart
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: businessHours.map((hour) {
                final count = orderCountByHour[hour] ?? 0;
                final fraction = count / maxOrders;
                final isPeak = count == maxOrders && count > 0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isPeak)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: Colors.pink,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PEAK',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 24,
                      height: 60 * fraction + (isPeak ? 20 : 4), // Min height 4
                      decoration: BoxDecoration(
                        color: isPeak
                            ? Colors.pink
                            : Colors.pink.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${hour > 12 ? hour - 12 : hour}${hour >= 12 ? 'p' : 'a'}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isPeak
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isPeak ? Colors.pink : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// CUSTOM PAINTERS (SPARKLINE & BEZIER CHART)
// ----------------------------------------------------

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (data.length <= 1) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    final maxVal = data.reduce(math.max);
    final minVal = data.reduce(math.min);
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    final dx = size.width / (data.length - 1);
    final path = Path();

    const paddingY = 4.0;
    final usableHeight = size.height - (paddingY * 2);

    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y =
          paddingY + usableHeight - ((data[i] - minVal) / range) * usableHeight;
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPointX = p0.dx + (p1.dx - p0.dx) / 2;
      path.cubicTo(controlPointX, p0.dy, controlPointX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.18), color.withOpacity(0.01)],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CustomCurveChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;

  CustomCurveChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxVal = points.map((p) => p['value'] as double).reduce(math.max);
    final effectiveMax = maxVal == 0 ? 1000.0 : maxVal * 1.15; // padding top

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines (4 intervals)
    for (int i = 0; i <= 4; i++) {
      final y = (size.height - 30) * (i / 4);
      canvas.drawLine(Offset(40, y), Offset(size.width, y), gridPaint);

      // Y-axis label
      final textSpan = TextSpan(
        text: '₹${NumberFormat.compact().format(effectiveMax * (1 - i / 4))}',
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    final widthOffset = size.width - 60;
    final dx = widthOffset / (points.length - 1);

    List<Offset> coordinates = [];
    for (int i = 0; i < points.length; i++) {
      final x = 40 + i * dx;
      final val = points[i]['value'] as double;
      final y = (size.height - 30) - (val / effectiveMax) * (size.height - 30);
      coordinates.add(Offset(x, y));
    }

    // Draw bezier path
    final curvePath = Path();
    curvePath.moveTo(coordinates[0].dx, coordinates[0].dy);

    for (int i = 0; i < coordinates.length - 1; i++) {
      final p0 = coordinates[i];
      final p1 = coordinates[i + 1];
      final controlPointX = p0.dx + (p1.dx - p0.dx) / 2;
      curvePath.cubicTo(
        controlPointX,
        p0.dy,
        controlPointX,
        p1.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Fill path (gradient underneath curve)
    final fillPath = Path.from(curvePath);
    fillPath.lineTo(coordinates.last.dx, size.height - 30);
    fillPath.lineTo(coordinates.first.dx, size.height - 30);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3B82F6).withOpacity(0.20),
          const Color(0xFF3B82F6).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height - 30))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw curve line
    final linePaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(curvePath, linePaint);

    // Draw dots and labels on the bottom
    for (int i = 0; i < coordinates.length; i++) {
      final pt = coordinates[i];
      final isLast = i == coordinates.length - 1;

      // Draw indicator dots for every 2nd point or the last point
      if (i % 2 == 0 || isLast) {
        final dotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = const Color(0xFF3B82F6)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(pt, 5, dotPaint);
        canvas.drawCircle(pt, 5, borderPaint);

        // Date labels on X axis
        final dateSpan = TextSpan(
          text: points[i]['label'] as String,
          style: TextStyle(
            color: isLast ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        );
        final datePainter = TextPainter(
          text: dateSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        datePainter.paint(canvas, Offset(pt.dx - 14, size.height - 20));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DonutChartPainter extends CustomPainter {
  final double cashPercent;
  final double upiPercent;
  final double cardPercent;

  DonutChartPainter({
    required this.cashPercent,
    required this.upiPercent,
    required this.cardPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 14.0;
    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2; // Start from top

    // Cash Sales (Green)
    if (cashPercent > 0) {
      paint.color = const Color(0xFF10B981);
      final sweepAngle = cashPercent * 2 * math.pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // UPI (Purple)
    if (upiPercent > 0) {
      paint.color = const Color(0xFF8B5CF6);
      final sweepAngle = upiPercent * 2 * math.pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Card (Orange)
    if (cardPercent > 0) {
      paint.color = const Color(0xFFF59E0B);
      final sweepAngle = cardPercent * 2 * math.pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // If total payment is 0, draw a full neutral gray donut
    if (cashPercent == 0 && upiPercent == 0 && cardPercent == 0) {
      paint.color = const Color(0xFFE2E8F0);
      canvas.drawArc(rect, startAngle, 2 * math.pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.cashPercent != cashPercent ||
        oldDelegate.upiPercent != upiPercent ||
        oldDelegate.cardPercent != cardPercent;
  }
}

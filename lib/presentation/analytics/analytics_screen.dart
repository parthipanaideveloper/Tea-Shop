import 'package:pos/core/utils/notification_helper.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import '../../providers/order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../domain/models/order.dart';
import 'widgets/order_details_dialog.dart';
import 'product_performance_screen.dart';
import '../../core/utils/export_utils.dart';
import '../widgets/neumorphic_widgets.dart';
import 'widgets/business_charts.dart';

enum SalesPeriod { daily, weekly, monthly, allTime, custom }

class AnalyticsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToHome;
  const AnalyticsScreen({super.key, this.onBackToHome});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  SalesPeriod _selectedPeriod = SalesPeriod.daily;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isGridView = false;
  String _selectedStaffFilter = 'All Staff';

  String _normalizeStaffName(String name) {
    if (name.contains(' (DTS-')) {
      return name.split(' (DTS-').first.trim();
    }
    return name;
  }

  String get _periodLabel {
    switch (_selectedPeriod) {
      case SalesPeriod.daily:
        return 'Today (Daily)';
      case SalesPeriod.weekly:
        return 'Last 7 Days (Weekly)';
      case SalesPeriod.monthly:
        return 'Last 30 Days (Monthly)';
      case SalesPeriod.allTime:
        return 'All Time';
      case SalesPeriod.custom:
        if (_customStartDate != null && _customEndDate != null) {
          final fmt = DateFormat('dd MMM yyyy');
          if (_customStartDate!.year == _customEndDate!.year &&
              _customStartDate!.month == _customEndDate!.month &&
              _customStartDate!.day == _customEndDate!.day) {
            return fmt.format(_customStartDate!);
          }
          return '${fmt.format(_customStartDate!)} - ${fmt.format(_customEndDate!)}';
        }
        return 'Custom Date';
    }
  }

  Future<void> _pickSingleDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedPeriod = SalesPeriod.custom;
        _customStartDate = DateTime(date.year, date.month, date.day);
        _customEndDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
      });
    }
  }

  Future<void> _pickDateRange() async {
    DateTime start = _customStartDate ?? DateTime.now();
    DateTime end = _customEndDate ?? DateTime.now();

    final DateTimeRange? pickedRange = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'Select Date Range',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(start),
                    ),
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.blue,
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: start,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateDialog(() {
                          start = picked;
                          if (end.isBefore(start)) {
                            end = start;
                          }
                        });
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(end),
                    ),
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.green,
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: end,
                        firstDate: start,
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateDialog(() {
                          end = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(
                      context,
                      DateTimeRange(start: start, end: end),
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _selectedPeriod = SalesPeriod.custom;
        _customStartDate = DateTime(
          pickedRange.start.year,
          pickedRange.start.month,
          pickedRange.start.day,
        );
        _customEndDate = DateTime(
          pickedRange.end.year,
          pickedRange.end.month,
          pickedRange.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orders = ref.watch(orderProvider);
    final shopName = ref.watch(settingsProvider).shopName;
    final now = DateTime.now();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    // Gather unique staff names
    final Set<String> rawStaffNames = {'All Staff'};
    for (final o in orders) {
      if (o.isDeleted) continue;
      final rawName = o.staffName.trim();
      if (rawName.isEmpty) continue;

      final normName = _normalizeStaffName(rawName);
      rawStaffNames.add(normName);
    }
    final staffDropdownItems = rawStaffNames.toList()..sort();

    // Ensure the selected filter still exists, otherwise reset to All Staff
    if (!staffDropdownItems.contains(_selectedStaffFilter)) {
      _selectedStaffFilter = 'All Staff';
    }

    // Filter orders based on the selected period (exclude soft-deleted orders)
    final filteredOrders = orders.where((order) {
      if (order.isDeleted) return false; // hide soft-deleted orders

      // Apply Staff Filter
      if (_selectedStaffFilter != 'All Staff') {
        if (_normalizeStaffName(order.staffName.trim()) !=
            _selectedStaffFilter) {
          return false;
        }
      }

      switch (_selectedPeriod) {
        case SalesPeriod.daily:
          final localDate = order.date.toLocal();
          return localDate.year == now.year &&
              localDate.month == now.month &&
              localDate.day == now.day;
        case SalesPeriod.weekly:
          final difference = now.difference(order.date).inDays;
          return difference <= 7;
        case SalesPeriod.monthly:
          final difference = now.difference(order.date).inDays;
          return difference <= 30;
        case SalesPeriod.allTime:
          return true;
        case SalesPeriod.custom:
          if (_customStartDate != null && _customEndDate != null) {
            final localDate = order.date.toLocal();
            return localDate.isAfter(
                  _customStartDate!.subtract(const Duration(seconds: 1)),
                ) &&
                localDate.isBefore(
                  _customEndDate!.add(const Duration(seconds: 1)),
                );
          }
          return true;
      }
    }).toList();

    // Compute metrics
    double grossRevenue = 0.0;
    double totalTax = 0.0;
    double totalDiscount = 0.0;
    double upiRevenue = 0.0;
    double cashRevenue = 0.0;
    double cardRevenue = 0.0;

    for (final order in filteredOrders) {
      if (order.isVoided || order.isRefunded || order.isDeleted) continue; // Exclude voided/refunded/deleted orders from calculations

      grossRevenue += order.total;
      totalTax += order.tax;
      totalDiscount += order.discount;
      final parts = order.paymentMode.split('|');
      final mode = parts[0].toUpperCase();
      if (mode == 'UPI') {
        upiRevenue += order.total;
      } else if (mode == 'CASH') {
        cashRevenue += order.total;
      } else if (mode == 'CARD') {
        cardRevenue += order.total;
      } else if (mode == 'SPLIT' && parts.length >= 3) {
        cashRevenue += double.tryParse(parts[1]) ?? 0.0;
        upiRevenue += double.tryParse(parts[2]) ?? 0.0;
      }
    }

    final totalOrdersCount = filteredOrders.where((o) => !o.isVoided && !o.isRefunded && !o.isDeleted).length;
    final averageOrderValue = totalOrdersCount > 0
        ? grossRevenue / totalOrdersCount
        : 0.0;

    final periodName = _periodLabel;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDesktop
            ? NeumorphicTheme.background
            : const Color(0xFFF8FAFC),
        appBar: null,
        body: Column(
          children: [
            Container(
              alignment: Alignment.center,
              color: isDesktop ? Colors.transparent : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 600 : double.infinity,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade600,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Sales'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.analytics_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Business Reports'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Sales Period Selector Header
            Container(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 600 : double.infinity,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'single') {
                              _pickSingleDate();
                            } else if (value == 'range') {
                              _pickDateRange();
                            } else {
                              setState(() {
                                _selectedPeriod = SalesPeriod.values.firstWhere(
                                  (e) => e.name == value,
                                );
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(
                                0.05,
                              ),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.2,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _periodLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: theme.colorScheme.primary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'daily',
                              child: Text('Today (Daily)'),
                            ),
                            PopupMenuItem(
                              value: 'weekly',
                              child: Text('Last 7 Days (Weekly)'),
                            ),
                            PopupMenuItem(
                              value: 'monthly',
                              child: Text('Last 30 Days (Monthly)'),
                            ),
                            PopupMenuItem(
                              value: 'allTime',
                              child: Text('All Time'),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'single',
                              child: Text('Select Specific Date...'),
                            ),
                            PopupMenuItem(
                              value: 'range',
                              child: Text('Select Date Range...'),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedStaffFilter,
                              icon: const Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.black54,
                              ),
                              isDense: true,
                              items: staffDropdownItems.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedStaffFilter = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isGridView ? Icons.view_list : Icons.grid_view,
                              size: 20,
                            ),
                            color: theme.colorScheme.primary,
                            onPressed: () {
                              setState(() {
                                _isGridView = !_isGridView;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Sales Transactions
                  _buildSalesTab(
                    context,
                    theme,
                    filteredOrders,
                    totalOrdersCount,
                  ),

                  _buildBusinessReportsTab(
                    context,
                    theme,
                    filteredOrders,
                    grossRevenue,
                    totalTax,
                    totalDiscount,
                    upiRevenue,
                    cashRevenue,
                    cardRevenue,
                    totalOrdersCount,
                    averageOrderValue,
                    periodName,
                    shopName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTab(
    BuildContext context,
    ThemeData theme,
    List<OrderModel> filteredOrders,
    int totalOrdersCount,
  ) {
    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No transactions recorded in this period.',
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    Widget _buildPaymentChip(String rawMode) {
      final parts = rawMode.split('|');
      final mode = parts[0];
      Color color;
      switch (mode) {
        case 'Cash':
          color = Colors.green;
          break;
        case 'UPI':
          color = Colors.blue;
          break;
        case 'Card':
          color = Colors.orange;
          break;
        case 'Split':
          color = Colors.purple;
          break;
        default:
          color = Colors.grey;
      }

      final chip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          mode.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      );

      if (mode == 'Split' && parts.length >= 3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            chip,
            const SizedBox(height: 2),
            Text(
              'Cash: ₹${parts[1]}',
              style: const TextStyle(fontSize: 9, color: Colors.black87),
            ),
            Text(
              'UPI: ₹${parts[2]}',
              style: const TextStyle(fontSize: 9, color: Colors.black87),
            ),
          ],
        );
      }

      return chip;
    }

    Widget listView;
    if (_isGridView) {
      listView = GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 450,
          childAspectRatio: 3.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          final timeStr = DateFormat(
            'MMM dd, yyyy - hh:mm a',
          ).format(order.date);

          final cardContent = ListTile(
            leading: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                order.resolvedOrderType == 'parcel' ? 'P' : 'D',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            title: Text(
              'Order #${order.displayId.toUpperCase()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: order.isVoided
                    ? Colors.red
                    : NeumorphicTheme.textPrimary,
                decoration: order.isVoided ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              order.isVoided ? 'VOIDED • ${order.voidReason}' : timeStr,
              style: TextStyle(
                color: order.isVoided
                    ? Colors.red.shade300
                    : NeumorphicTheme.textSecondary,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${order.total.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
                if (!order.isVoided) ...[
                  const SizedBox(height: 4),
                  _buildPaymentChip(order.paymentMode),
                ],
              ],
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => OrderDetailsDialog(order: order),
              );
            },
          );

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.green.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: cardContent,
          );
        },
      );
    } else {
      listView = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredOrders.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              final timeStr = DateFormat(
                'MMM dd, yyyy - hh:mm a',
              ).format(order.date);

              final cardContent = InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => OrderDetailsDialog(order: order),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.resolvedOrderType == 'parcel' ? 'P' : 'D',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order.displayId.toUpperCase()}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: order.isVoided ? Colors.red : null,
                                decoration: order.isVoided
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.isVoided
                                  ? 'VOIDED • ${order.voidReason}'
                                  : timeStr,
                              style: TextStyle(
                                fontSize: 13,
                                color: order.isVoided
                                    ? Colors.red.shade300
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${order.total.toStringAsFixed(2)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                                size: 18,
                              ),
                            ],
                          ),
                          if (!order.isVoided) ...[
                            const SizedBox(height: 6),
                            _buildPaymentChip(order.paymentMode),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.green.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                elevation: 4,
                shadowColor: Colors.black12,
                color: Colors.white,
                child: cardContent,
              );
            },
          ),
        ),
      );
    }

    return listView;
  }

  Widget _buildBusinessReportsTab(
    BuildContext context,
    ThemeData theme,
    List<OrderModel> filteredOrders,
    double grossRevenue,
    double totalTax,
    double totalDiscount,
    double upiRevenue,
    double cashRevenue,
    double cardRevenue,
    int totalOrdersCount,
    double averageOrderValue,
    String periodName,
    String shopName,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    List<OrderModel> trendOrders = filteredOrders;
    if (_selectedPeriod == SalesPeriod.daily) {
      final orders = ref.read(orderProvider);
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 2));
      final threeDaysAgoStart = DateTime(threeDaysAgo.year, threeDaysAgo.month, threeDaysAgo.day);
      trendOrders = orders.where((o) {
        if (o.isDeleted || o.isVoided) return false;
        if (_selectedStaffFilter != 'All Staff') {
          if (_normalizeStaffName(o.staffName.trim()) != _selectedStaffFilter) {
            return false;
          }
        }
        final localDate = o.date.toLocal();
        final dayStart = DateTime(localDate.year, localDate.month, localDate.day);
        return dayStart.isAfter(threeDaysAgoStart.subtract(const Duration(seconds: 1)));
      }).toList();
    }

    final mobileExportContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.download_for_offline,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Reports',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDesktop ? NeumorphicTheme.textPrimary : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Period: $periodName',
                  style: TextStyle(
                    color: isDesktop
                        ? NeumorphicTheme.textSecondary
                        : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Divider(height: 32),
        Text(
          'Export the business report data for $periodName in your preferred format. All files generated are fully structured.',
          style: TextStyle(
            color: isDesktop
                ? NeumorphicTheme.textSecondary
                : Colors.grey.shade600,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  backgroundColor: Colors.green.shade50,
                  side: BorderSide(color: Colors.green.shade300, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: filteredOrders.isEmpty
                    ? null
                    : () => _exportExcel(
                        filteredOrders,
                        grossRevenue,
                        totalTax,
                        totalDiscount,
                        upiRevenue,
                        cashRevenue,
                        cardRevenue,
                        totalOrdersCount,
                        averageOrderValue,
                        shopName,
                        periodName,
                      ),
                icon: const Icon(Icons.table_view),
                label: const Text(
                  'EXCEL REPORT',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  backgroundColor: Colors.red.shade50,
                  side: BorderSide(color: Colors.red.shade300, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: filteredOrders.isEmpty
                    ? null
                    : () => _exportPdfReport(
                        filteredOrders,
                        grossRevenue,
                        totalTax,
                        totalDiscount,
                        upiRevenue,
                        cashRevenue,
                        cardRevenue,
                        totalOrdersCount,
                        averageOrderValue,
                        shopName,
                        periodName,
                      ),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text(
                  'PDF REPORT',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final desktopExportContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.download_for_offline,
          color: theme.colorScheme.primary,
          size: 36,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export Reports',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: NeumorphicTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Export business report data for $periodName.',
                style: TextStyle(
                  color: NeumorphicTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green.shade700,
            backgroundColor: Colors.green.shade50,
            side: BorderSide(color: Colors.green.shade400, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: filteredOrders.isEmpty
              ? null
              : () => _exportExcel(
                  filteredOrders,
                  grossRevenue,
                  totalTax,
                  totalDiscount,
                  upiRevenue,
                  cashRevenue,
                  cardRevenue,
                  totalOrdersCount,
                  averageOrderValue,
                  shopName,
                  periodName,
                ),
          icon: const Icon(Icons.table_view),
          label: const Text(
            'EXCEL',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            backgroundColor: Colors.red.shade50,
            side: BorderSide(color: Colors.red.shade400, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: filteredOrders.isEmpty
              ? null
              : () => _exportPdfReport(
                  filteredOrders,
                  grossRevenue,
                  totalTax,
                  totalDiscount,
                  upiRevenue,
                  cashRevenue,
                  cardRevenue,
                  totalOrdersCount,
                  averageOrderValue,
                  shopName,
                  periodName,
                ),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text(
            'PDF',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );

    final exportContent = isDesktop
        ? desktopExportContent
        : mobileExportContent;

    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Metric cards row
        isDesktop
            ? Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Gross Revenue',
                      value: '₹${grossRevenue.toStringAsFixed(2)}',
                      icon: Icons.currency_rupee,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _MetricCard(
                      title: 'Total Orders',
                      value: '$totalOrdersCount',
                      icon: Icons.receipt_long,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _MetricCard(
                      title: 'Avg Order Value',
                      value: '₹${averageOrderValue.toStringAsFixed(2)}',
                      icon: Icons.analytics,
                      color: Colors.orange,
                    ),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Gross Revenue',
                              value: '₹${grossRevenue.toStringAsFixed(2)}',
                              icon: Icons.currency_rupee,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: 'Total Orders',
                              value: '$totalOrdersCount',
                              icon: Icons.receipt_long,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Avg Order Value',
                              value: '₹${averageOrderValue.toStringAsFixed(2)}',
                              icon: Icons.analytics,
                              color: Colors.orange,
                            ),
                          ),
                          if (isWide) ...[
                            const SizedBox(width: 12),
                            const Expanded(child: SizedBox()),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              ),
        const SizedBox(height: 24),

        const SizedBox(height: 32),

        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: RevenueTrendChart(
                  orders: trendOrders,
                  isDesktop: true,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: PaymentMethodsDonutChart(
                  upi: upiRevenue,
                  cash: cashRevenue,
                  card: cardRevenue,
                  isDesktop: true,
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RevenueTrendChart(orders: trendOrders, isDesktop: false),
              const SizedBox(height: 24),
              PaymentMethodsDonutChart(
                upi: upiRevenue,
                cash: cashRevenue,
                card: cardRevenue,
                isDesktop: false,
              ),
            ],
          ),

        const SizedBox(height: 32),

        // Export Section Card
        isDesktop
            ? NeumorphicCard(
                padding: const EdgeInsets.all(20.0),
                child: exportContent,
              )
            : Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: exportContent,
                ),
              ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1400 : double.infinity,
          ),
          child: mainContent,
        ),
      ),
    );
  }

  Future<void> _exportExcel(
    List<OrderModel> filteredOrders,
    double grossRevenue,
    double totalTax,
    double totalDiscount,
    double upiRevenue,
    double cashRevenue,
    double cardRevenue,
    int totalOrdersCount,
    double averageOrderValue,
    String shopName,
    String periodName,
  ) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sales Report'];
      excel.delete('Sheet1'); // Remove default sheet

      // Add Premium Headers
      ExportUtils.setupPremiumExcelHeader(
        sheet,
        shopName,
        'BUSINESS REPORT',
        'Period: $periodName',
      );

      final boldStyle = CellStyle(bold: true);

      // Performance Summary Section
      sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue(
        'PERFORMANCE SUMMARY',
      );
      sheet.cell(CellIndex.indexByString('A5')).cellStyle =
          ExportUtils.getExcelHeaderStyle();

      sheet.appendRow([
        TextCellValue('Gross Revenue'),
        DoubleCellValue(grossRevenue),
      ]);
      sheet.appendRow([
        TextCellValue('Total Tax Collected'),
        DoubleCellValue(totalTax),
      ]);
      sheet.appendRow([
        TextCellValue('Total Discount Given'),
        DoubleCellValue(totalDiscount),
      ]);
      sheet.appendRow([
        TextCellValue('Total Transactions'),
        DoubleCellValue(totalOrdersCount.toDouble()),
      ]);
      sheet.appendRow([
        TextCellValue('Average Order Value'),
        DoubleCellValue(averageOrderValue),
      ]);

      sheet.appendRow([TextCellValue('')]);

      // Payment Breakdown Section
      sheet.cell(CellIndex.indexByString('A10')).value = TextCellValue(
        'PAYMENT BREAKDOWN',
      );
      sheet.cell(CellIndex.indexByString('A10')).cellStyle =
          ExportUtils.getExcelHeaderStyle();

      sheet.appendRow([TextCellValue('UPI'), DoubleCellValue(upiRevenue)]);
      sheet.appendRow([TextCellValue('CASH'), DoubleCellValue(cashRevenue)]);
      sheet.appendRow([TextCellValue('CARD'), DoubleCellValue(cardRevenue)]);

      sheet.appendRow([TextCellValue('')]);

      // Order Details Section
      sheet.cell(CellIndex.indexByString('A15')).value = TextCellValue(
        'ORDER DETAILS',
      );
      sheet.cell(CellIndex.indexByString('A15')).cellStyle =
          ExportUtils.getExcelHeaderStyle();

      // The List Headings
      final headers = [
        TextCellValue('Order ID'),
        TextCellValue('Date'),
        TextCellValue('Customer Phone'),
        TextCellValue('Payment Mode'),
        TextCellValue('Subtotal'),
        TextCellValue('Tax'),
        TextCellValue('Discount'),
        TextCellValue('Total'),
      ];
      sheet.appendRow(headers);
      final headerRowIndex = 16;
      for (int i = 0; i < headers.length; i++) {
        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: i,
                    rowIndex: headerRowIndex,
                  ),
                )
                .cellStyle =
            ExportUtils.getExcelHeaderStyle();
      }

      for (final order in filteredOrders) {
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(order.date);
        sheet.appendRow([
          TextCellValue(order.displayId.toUpperCase()),
          TextCellValue(dateStr),
          TextCellValue(
            order.customerPhone.isNotEmpty ? order.customerPhone : 'N/A',
          ),
          TextCellValue(order.paymentMode),
          DoubleCellValue(order.subtotal),
          DoubleCellValue(order.tax),
          DoubleCellValue(order.discount),
          DoubleCellValue(order.total),
        ]);

        // Add items for this order
        for (final item in order.parsedItems) {
          sheet.appendRow([
            TextCellValue(''), // Indent under Order ID
            TextCellValue('-> Item:'),
            TextCellValue(item.product.name),
            TextCellValue('${item.quantity} x ${item.effectivePrice(order.resolvedOrderType)}'),
            TextCellValue(''),
            TextCellValue(''),
            TextCellValue(''),
            DoubleCellValue(item.effectiveTotal(order.resolvedOrderType)),
          ]);
        }
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/sales_${_selectedPeriod.name}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        );
        await tempFile.writeAsBytes(fileBytes);
        await Share.shareXFiles([
          XFile(tempFile.path),
        ], text: 'Sales Reports Export Excel');
      }
    } catch (e) {
      if (context.mounted) {
        NotificationHelper.showCenter(
          context,
          'Failed to export Excel: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _exportPdfReport(
    List<OrderModel> filteredOrders,
    double grossRevenue,
    double totalTax,
    double totalDiscount,
    double upiRevenue,
    double cashRevenue,
    double cardRevenue,
    int totalOrdersCount,
    double averageOrderValue,
    String shopName,
    String periodName,
  ) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => ExportUtils.buildPremiumPdfHeader(
            shopName,
            'BUSINESS REPORT',
            'Period: $periodName',
          ),
          footer: (context) => ExportUtils.buildPremiumPdfFooter(context),
          build: (pw.Context context) {
            return [
              pw.Text(
                'Performance Summary',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: ExportUtils.primaryColor,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: ExportUtils.getPdfHeaderDecoration(),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Metric',
                          style: ExportUtils.getPdfHeaderStyle(),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Value',
                          style: ExportUtils.getPdfHeaderStyle(),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Gross Revenue',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rs. ${grossRevenue.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: ExportUtils.bgLight,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Total Tax Collected',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rs. ${totalTax.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Total Discount Given',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rs. ${totalDiscount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: ExportUtils.bgLight,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Total Transactions',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '$totalOrdersCount',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Average Order Value',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rs. ${averageOrderValue.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Text(
                'Payment Breakdown',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: ExportUtils.primaryColor,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: ExportUtils.getPdfHeaderDecoration(),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Payment Mode',
                          style: ExportUtils.getPdfHeaderStyle(),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Amount Collected',
                          style: ExportUtils.getPdfHeaderStyle(),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'UPI QR Payments',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rs. ${upiRevenue.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: ExportUtils.bgLight,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Cash Payments',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rs. ${cashRevenue.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Card Payments',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Rs. ${cardRevenue.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Text(
                'Detailed Transaction Log',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: ExportUtils.primaryColor,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: ExportUtils.getPdfHeaderDecoration(),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Order ID',
                          style: ExportUtils.getPdfHeaderStyle(),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Date & Time',
                          style: ExportUtils.getPdfHeaderStyle(),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Mode',
                          style: ExportUtils.getPdfHeaderStyle(),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Total',
                          style: ExportUtils.getPdfHeaderStyle(),
                        ),
                      ),
                    ],
                  ),
                  ...filteredOrders.expand<pw.TableRow>((OrderModel order) {
                    final rows = <pw.TableRow>[];
                    rows.add(
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey100,
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              '#${order.displayId.toUpperCase()}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(order.date),
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              order.paymentMode,
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              'Rs. ${order.total.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    for (final item in order.parsedItems) {
                      rows.add(
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(''),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                '- ${item.product.name}',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey800,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                '${item.quantity} x ${item.effectivePrice(order.resolvedOrderType)}',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey800,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'Rs. ${item.effectiveTotal(order.resolvedOrderType).toStringAsFixed(2)}',
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return rows;
                  }).toList(),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'business_report_${_selectedPeriod.name}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        NotificationHelper.showCenter(
          context,
          'Failed to export PDF: $e',
          isError: true,
        );
      }
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final cardContent = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDesktop
                        ? NeumorphicTheme.textSecondary
                        : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDesktop
                        ? NeumorphicTheme.textPrimary
                        : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        padding: const EdgeInsets.all(20.0),
        child: cardContent,
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 1.2),
      ),
      color: Colors.white,
      child: Padding(padding: const EdgeInsets.all(16.0), child: cardContent),
    );
  }
}

class _PaymentModeCard extends StatelessWidget {
  final String mode;
  final double amount;
  final IconData icon;
  final Color color;

  const _PaymentModeCard({
    required this.mode,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final cardContent = Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          mode,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDesktop ? NeumorphicTheme.textSecondary : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDesktop ? NeumorphicTheme.textPrimary : Colors.black87,
          ),
        ),
      ],
    );

    if (isDesktop) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        padding: const EdgeInsets.all(20.0),
        child: cardContent,
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 1.2),
      ),
      color: Colors.white,
      child: Padding(padding: const EdgeInsets.all(12.0), child: cardContent),
    );
  }
}

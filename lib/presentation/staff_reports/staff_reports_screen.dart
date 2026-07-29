import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/models/order.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border;
import '../../domain/models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../analytics/widgets/order_details_dialog.dart';
import '../../core/utils/export_utils.dart';
import '../widgets/neumorphic_widgets.dart';

enum StaffReportPeriod { daily, weekly, monthly, custom }

class StaffReportsScreen extends ConsumerStatefulWidget {
  const StaffReportsScreen({super.key});

  @override
  ConsumerState<StaffReportsScreen> createState() => _StaffReportsScreenState();
}

class _StaffReportsScreenState extends ConsumerState<StaffReportsScreen> {
  StaffReportPeriod _selectedPeriod = StaffReportPeriod.monthly;
  DateTime? _customDate;
  String _selectedStaff = 'All Staff';

  Future<void> _pickCustomDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now());
    if (picked != null) {
      setState(() {
        _selectedPeriod = StaffReportPeriod.custom;
        _customDate = picked;
      });
    }
  }

  String _normalizeStaffName(String name) {
    if (name.contains(' (DTS-')) {
      return name.split(' (DTS-').first.trim();
    }
    return name;
  }

  List<OrderModel> _filterOrders(List<OrderModel> allOrders) {
    final now = DateTime.now();
    return allOrders.where((order) {
      // 1. Filter by Staff
      if (_selectedStaff != 'All Staff') {
        final orderStaffName = _normalizeStaffName(order.staffName);
        if (orderStaffName != _selectedStaff) {
          return false;
        }
      }

      // 2. Filter by Date
      final localDate = order.date.toLocal();
      switch (_selectedPeriod) {
        case StaffReportPeriod.daily:
          return localDate.year == now.year &&
              localDate.month == now.month &&
              localDate.day == now.day;
        case StaffReportPeriod.weekly:
          final weekAgo = now.subtract(const Duration(days: 7));
          return localDate.isAfter(weekAgo);
        case StaffReportPeriod.monthly:
          return localDate.year == now.year && localDate.month == now.month;
        case StaffReportPeriod.custom:
          if (_customDate == null) return true;
          return localDate.year == _customDate!.year &&
              localDate.month == _customDate!.month &&
              localDate.day == _customDate!.day;
      }
    }).toList();
  }

  Future<void> _exportToPdf(
    Map<String, List<OrderModel>> staffOrders,
    String shopName) async {
    final pdf = pw.Document();

    final periodName = switch (_selectedPeriod) {
      StaffReportPeriod.daily => 'Daily (Today)',
      StaffReportPeriod.weekly => 'Weekly (Last 7 Days)',
      StaffReportPeriod.monthly => 'Monthly (This Month)',
      StaffReportPeriod.custom =>
        'Custom Date (${_customDate != null ? DateFormat('MMM d, yyyy').format(_customDate!) : 'Unknown'})',
    };

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => ExportUtils.buildPremiumPdfHeader(shopName, 'STAFF PERFORMANCE REPORT', 'Period: $periodName'),
        footer: (context) => ExportUtils.buildPremiumPdfFooter(context),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];

          staffOrders.forEach((staffName, orders) {
            final totalSales = orders.fold<double>(0, (sum, o) => sum + o.total);
            
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: ExportUtils.bgLight,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Staff: $staffName', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: ExportUtils.primaryColor)),
                    pw.Text('Total Orders: ${orders.length} | Sales: Rs. ${totalSales.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  ]
                )
              ));
            widgets.add(pw.SizedBox(height: 8));

            widgets.add(
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: ExportUtils.getPdfHeaderDecoration(),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Order ID', style: ExportUtils.getPdfHeaderStyle())),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: ExportUtils.getPdfHeaderStyle())),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Amount', style: ExportUtils.getPdfHeaderStyle())),
                    ]),
                  ...orders.map((o) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('#${o.id.toUpperCase()}', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(DateFormat('dd MMM yyyy, hh:mm a').format(o.date), style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${o.total.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9))),
                      ]);
                  }),
                ]));
            widgets.add(pw.SizedBox(height: 20));
          });

          if (widgets.isEmpty) {
            widgets.add(pw.Center(child: pw.Text('No data available for this period.')));
          }

          return widgets;
        }));

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'staff_report_${_selectedPeriod.name}.pdf');
  }

  Future<void> _exportToExcel(
    Map<String, List<OrderModel>> staffOrders,
    String shopName) async {
    try {
      final periodName = switch (_selectedPeriod) {
        StaffReportPeriod.daily => 'Daily (Today)',
        StaffReportPeriod.weekly => 'Weekly (Last 7 Days)',
        StaffReportPeriod.monthly => 'Monthly (This Month)',
        StaffReportPeriod.custom =>
          'Custom Date (${_customDate != null ? DateFormat('MMM d, yyyy').format(_customDate!) : 'Unknown'})',
      };

      final excel = Excel.createExcel();
      final sheet = excel['Staff Report'];
      excel.delete('Sheet1');

      ExportUtils.setupPremiumExcelHeader(sheet, shopName, 'STAFF PERFORMANCE REPORT', 'Period: $periodName');
      
      final boldStyle = CellStyle(bold: true);

      sheet.appendRow([TextCellValue('')]);
      sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('STAFF DETAILS');
      sheet.cell(CellIndex.indexByString('A5')).cellStyle = ExportUtils.getExcelHeaderStyle();

      final headers = [
        TextCellValue('Staff Name'),
        TextCellValue('Order ID'),
        TextCellValue('Date'),
        TextCellValue('Total (Rs)'),
      ];
      sheet.appendRow(headers);
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 6)).cellStyle = ExportUtils.getExcelHeaderStyle();
      }

      staffOrders.forEach((staff, orders) {
        for (final o in orders) {
          final date = DateFormat('yyyy-MM-dd HH:mm').format(o.date);
          sheet.appendRow([
            TextCellValue(staff),
            TextCellValue(o.id.toUpperCase()),
            TextCellValue(date),
            DoubleCellValue(o.total),
          ]);
        }
      });

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${directory.path}/staff_report_$timestamp.xlsx');
        await file.writeAsBytes(fileBytes);
        
        await Share.shareXFiles([XFile(file.path)], subject: 'Staff Report');
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showCenter(
          context, 'Failed to export Excel', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allOrders = ref.watch(orderProvider);
    final shopName = ref.watch(settingsProvider).shopName;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final canPop = Navigator.canPop(context);

    // Extract unique staff names from settings and orders
    final Set<String> allStaffNames = {'All Staff', 'Admin'};

    bool _isStaffAllowed(String name) {
      final lower = name.toLowerCase();
      if (lower.contains('master') || lower.contains('host_admin') || lower.contains('admin (')) {
        return false;
      }
      return true;
    }

    // Add all registered staff
    final staffAccounts = ref.watch(staffAccountsProvider);
    for (var staff in staffAccounts) {
      if (_isStaffAllowed(staff.name)) {
        allStaffNames.add(_normalizeStaffName(staff.name));
      }
    }

    // Add staff from orders (in case they were deleted but have history)
    for (var order in allOrders) {
      if (_isStaffAllowed(order.staffName)) {
        allStaffNames.add(_normalizeStaffName(order.staffName));
      }
    }

    // Safely fallback if selected staff was deleted
    final currentSelectedStaff = allStaffNames.contains(_selectedStaff)
        ? _selectedStaff
        : 'All Staff';
    if (!allStaffNames.contains(_selectedStaff)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedStaff = 'All Staff');
      });
    }

    final filteredOrders = _filterOrders(allOrders);

    // Group filtered orders by staffName
    final Map<String, List<OrderModel>> staffOrders = {};
    for (var order in filteredOrders) {
      final staff = order.staffName;
      if (!_isStaffAllowed(staff)) continue; // Filter out host_admin and impersonations
      
      if (!staffOrders.containsKey(staff)) {
        staffOrders[staff] = [];
      }
      staffOrders[staff]!.add(order);
    }

    return Scaffold(
      backgroundColor: isDesktop ? NeumorphicTheme.background : const Color(0xFFF8FAFC),
      appBar: isDesktop ? null : AppBar(
        title: const Text(
          'Staff Reports',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBodyContent(
        context,
        isDesktop,
        theme,
        currentSelectedStaff,
        allStaffNames,
        staffOrders,
        shopName,
      ),
    );
  }

  Widget _buildPeriodChip(String label, StaffReportPeriod period) {
    final isSelected = _selectedPeriod == period;
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = period;
          });
        }
      },
      selectedColor: theme.colorScheme.primary.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.primary : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal));
  }

  Widget _buildBodyContent(
    BuildContext context,
    bool isDesktop,
    ThemeData theme,
    String currentSelectedStaff,
    Set<String> allStaffNames,
    Map<String, List<OrderModel>> staffOrders,
    String shopName,
  ) {
    return Column(
      children: [
        // Filter Header
        Container(
          color: NeumorphicTheme.background,
          padding: isDesktop
              ? const EdgeInsets.fromLTRB(28, 20, 28, 12)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: Container(
              constraints: isDesktop ? const BoxConstraints(maxWidth: 1000) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Staff Dropdown Filter
                  DropdownButtonFormField<String>(
                    value: currentSelectedStaff,
                    decoration: InputDecoration(
                      labelText: 'Filter by Staff',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12),
                      prefixIcon: const Icon(Icons.person_search)),
                    items: allStaffNames
                        .map(
                          (name) =>
                              DropdownMenuItem(value: name, child: Text(name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStaff = val);
                    }),
                  const SizedBox(height: 12),
                  // Period selector + Export
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPeriodChip('Today', StaffReportPeriod.daily),
                        const SizedBox(width: 8),
                        _buildPeriodChip('Last 7 Days', StaffReportPeriod.weekly),
                        const SizedBox(width: 8),
                        _buildPeriodChip('This Month', StaffReportPeriod.monthly),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _selectedPeriod == StaffReportPeriod.custom &&
                                        _customDate != null
                                    ? DateFormat(
                                        'MMM d, yyyy').format(_customDate!)
                                    : 'Custom Date'),
                            ]),
                          onPressed: _pickCustomDate,
                          backgroundColor:
                              _selectedPeriod == StaffReportPeriod.custom
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : Colors.white,
                          side: BorderSide(
                            color: _selectedPeriod == StaffReportPeriod.custom
                                ? theme.colorScheme.primary
                                : Colors.grey.shade300)),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.file_download_outlined, color: Colors.black87),
                          onSelected: (value) {
                            if (staffOrders.isEmpty) {
                              NotificationHelper.showCenter(context, 'No data to export for this period.', isError: false);
                              return;
                            }
                            if (value == 'pdf') {
                              _exportToPdf(staffOrders, shopName);
                            } else if (value == 'excel') {
                              _exportToExcel(staffOrders, shopName);
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(
                              value: 'pdf',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Export as PDF'),
                                ])),
                            const PopupMenuItem(
                              value: 'excel',
                              child: Row(
                                children: [
                                  Icon(Icons.table_chart, color: Colors.green, size: 20),
                                  SizedBox(width: 8),
                                  Text('Export as Excel (CSV)'),
                                ])),
                          ]),
                      ]),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Staff Reports List
        Expanded(
          child: Center(
            child: Container(
              constraints: isDesktop ? const BoxConstraints(maxWidth: 1000) : null,
              padding: isDesktop ? const EdgeInsets.symmetric(horizontal: 28) : EdgeInsets.zero,
              child: staffOrders.isEmpty
                  ? const Center(
                      child: Text('No orders found for this selection.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      itemCount: staffOrders.length,
                      itemBuilder: (context, index) {
                        final staffName = staffOrders.keys.elementAt(index);
                        final list = staffOrders[staffName]!;

                        final totalSales = list.fold(
                          0.0,
                          (sum, o) => sum + o.total);
                        final totalOrders = list.length;
                        final avatarColor = Colors.primaries[staffName.hashCode % Colors.primaries.length];

                        final cardContent = Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: avatarColor.withOpacity(0.1),
                              child: Text(
                                staffName.isNotEmpty
                                    ? staffName.substring(0, 1).toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: avatarColor,
                                  fontWeight: FontWeight.bold))),
                            title: Text(
                              staffName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDesktop ? NeumorphicTheme.textPrimary : const Color(0xFF1E293B))),
                            subtitle: Text(
                              '$totalOrders Orders • Total: ₹${totalSales.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDesktop ? NeumorphicTheme.textSecondary : const Color(0xFF64748B))),
                            children: [
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (context, i) {
                                  final o = list[i];
                                  return ListTile(
                                    title: Text(
                                      'Order #${o.displayId.toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDesktop ? NeumorphicTheme.textPrimary : const Color(0xFF1E293B))),
                                    subtitle: Text(
                                      DateFormat(
                                        'dd MMM yyyy, hh:mm a').format(o.date),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDesktop ? NeumorphicTheme.textSecondary : const Color(0xFF64748B))),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '₹${o.total.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDesktop ? NeumorphicTheme.textPrimary : const Color(0xFF1E293B))),
                                        if (o.paymentMode.startsWith('Split|')) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Cash: ₹${o.paymentMode.split('|')[1]} | UPI: ₹${o.paymentMode.split('|')[2]}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.purple.shade400,
                                            ),
                                          ),
                                        ] else ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            o.paymentMode,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: o.paymentMode.toUpperCase() == 'CASH' 
                                                  ? Colors.green.shade600 
                                                  : o.paymentMode.toUpperCase() == 'UPI' 
                                                      ? Colors.blue.shade600 
                                                      : Colors.orange.shade600,
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            OrderDetailsDialog(order: o));
                                    });
                                }),
                            ]),
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                          child: cardContent,
                        );
                      }),
            ),
          ),
        ),
      ],
    );
  }
}

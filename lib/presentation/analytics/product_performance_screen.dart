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
import 'package:excel/excel.dart' hide Border;
import '../../providers/order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/printer_provider.dart';
import '../../core/hardware/printer_service.dart';
import '../../domain/models/order.dart';
import '../../core/utils/export_utils.dart';
import '../widgets/neumorphic_widgets.dart';

enum ProductPerformancePeriod { daily, custom }

class ProductPerformanceScreen extends ConsumerStatefulWidget {
  const ProductPerformanceScreen({super.key});

  @override
  ConsumerState<ProductPerformanceScreen> createState() =>
      _ProductPerformanceScreenState();
}

class _ProductPerformanceScreenState
    extends ConsumerState<ProductPerformanceScreen> {
  ProductPerformancePeriod _selectedPeriod = ProductPerformancePeriod.daily;
  DateTime? _selectedSpecificDate;

  Future<void> _pickSpecificDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedSpecificDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Specific Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = ProductPerformancePeriod.custom;
        _selectedSpecificDate = picked;
      });
    }
  }

  List<OrderModel> _filterOrders(List<OrderModel> allOrders) {
    final now = DateTime.now();
    return allOrders.where((order) {
      if (order.isVoided || order.isRefunded || order.isDeleted) return false;
      if (order.paymentStatus != 'PAID') return false;
      final localDate = order.date.toLocal();

      switch (_selectedPeriod) {
        case ProductPerformancePeriod.daily:
          return localDate.year == now.year &&
              localDate.month == now.month &&
              localDate.day == now.day;
        case ProductPerformancePeriod.custom:
          if (_selectedSpecificDate == null) return true;
          return localDate.year == _selectedSpecificDate!.year &&
              localDate.month == _selectedSpecificDate!.month &&
              localDate.day == _selectedSpecificDate!.day;
      }
    }).toList();
  }

  String get _periodName {
    switch (_selectedPeriod) {
      case ProductPerformancePeriod.daily:
        return 'Daily (${DateFormat('dd MMM yyyy').format(DateTime.now())})';
      case ProductPerformancePeriod.custom:
        return _selectedSpecificDate != null
            ? DateFormat('dd MMM yyyy').format(_selectedSpecificDate!)
            : 'Select Specific Date';
    }
  }

  Future<void> _exportToPdf(
    List<MapEntry<String, Map<String, dynamic>>> sortedItems,
    String shopName,
    double netRevenue,
  ) async {
    final pdf = pw.Document();

    final periodName = _periodName;

    double totalRev = netRevenue;
    int totalUnits = 0;
    for (final e in sortedItems) {
      totalUnits += (e.value['count'] as num).toInt();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => ExportUtils.buildPremiumPdfHeader(
          shopName,
          'PRODUCT PERFORMANCE REPORT',
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
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
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
                        'Total Units Sold',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '$totalUnits',
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
                        'Total Revenue',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Rs. ${totalRev.toStringAsFixed(2)}',
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
              'Item Details',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: ExportUtils.primaryColor,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: ExportUtils.getPdfHeaderDecoration(),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Product Name',
                        style: ExportUtils.getPdfHeaderStyle(),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Units Sold',
                        style: ExportUtils.getPdfHeaderStyle(),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Revenue (Rs)',
                        style: ExportUtils.getPdfHeaderStyle(),
                      ),
                    ),
                  ],
                ),
                ...sortedItems.map((entry) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          entry.key,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          entry.value['count'].toString(),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          entry.value['revenue'].toStringAsFixed(2),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'product_performance_${_selectedPeriod.name}.pdf',
    );
  }

  Future<void> _printPdf(
    List<MapEntry<String, Map<String, dynamic>>> sortedItems,
    String shopName,
    double netRevenue,
  ) async {
    final periodName = _periodName;

    final settings = ref.read(settingsProvider);
    final printerNotifier = ref.read(printerProvider.notifier);

    try {
      final bytes = await PrinterService.generateProductPerformanceBytes(
        sortedItems: sortedItems,
        shopName: shopName,
        periodName: periodName,
        netRevenue: netRevenue,
        is80mmPaper: settings.is80mmPaper,
      );

      if (bytes.isNotEmpty) {
        await printerNotifier.printReceipt(bytes);
        if (mounted) {
          NotificationHelper.showCenter(
            context,
            'Printing Product Performance...',
          );
        }
      } else {
        if (mounted) {
          NotificationHelper.showCenter(
            context,
            'Failed to generate print data',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showCenter(
          context,
          'Error printing: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _exportToExcel(
    List<MapEntry<String, Map<String, dynamic>>> sortedItems,
    String shopName,
    double netRevenue,
  ) async {
    try {
      final periodName = _periodName;

      final excel = Excel.createExcel();
      final sheet = excel['Product Performance'];
      excel.delete('Sheet1'); // Remove default sheet

      // Add Premium Headers
      ExportUtils.setupPremiumExcelHeader(
        sheet,
        shopName,
        'PRODUCT PERFORMANCE REPORT',
        'Period: $periodName',
      );

      sheet.appendRow([TextCellValue('')]);

      // Performance Summary Section
      sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue(
        'PERFORMANCE SUMMARY',
      );
      sheet.cell(CellIndex.indexByString('A5')).cellStyle =
          ExportUtils.getExcelHeaderStyle();

      double totalRev = netRevenue;
      int totalUnits = 0;
      for (final e in sortedItems) {
        totalUnits += (e.value['count'] as num).toInt();
      }
      sheet.appendRow([
        TextCellValue('Total Revenue'),
        DoubleCellValue(totalRev),
      ]);
      sheet.appendRow([
        TextCellValue('Total Units Sold'),
        IntCellValue(totalUnits),
      ]);

      sheet.appendRow([TextCellValue('')]);

      // Item Details Section
      sheet.cell(CellIndex.indexByString('A10')).value = TextCellValue(
        'ITEM DETAILS',
      );
      sheet.cell(CellIndex.indexByString('A10')).cellStyle =
          ExportUtils.getExcelHeaderStyle();

      final headers = [
        TextCellValue('Product Name'),
        TextCellValue('Units Sold'),
        TextCellValue('Revenue (Rs)'),
      ];
      sheet.appendRow(headers);
      for (int i = 0; i < headers.length; i++) {
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 11))
                .cellStyle =
            ExportUtils.getExcelHeaderStyle();
      }

      for (final entry in sortedItems) {
        sheet.appendRow([
          TextCellValue(entry.key),
          IntCellValue((entry.value['count'] as num).toInt()),
          DoubleCellValue((entry.value['revenue'] as num).toDouble()),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File(
          '${directory.path}/product_performance_$timestamp.xlsx',
        );
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles([
          XFile(file.path),
        ], subject: 'Product Performance Report');
      }
    } catch (e) {
      if (mounted) {
        print('Excel export error: $e');
        NotificationHelper.showCenter(
          context,
          'Failed to export Excel: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allOrders = ref.watch(orderProvider);
    final shopName = ref.watch(settingsProvider).shopName;
    final filteredOrders = _filterOrders(allOrders);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    final Map<String, Map<String, dynamic>> itemStats = {};
    for (final order in filteredOrders) {
      final items = order.parsedItems;
      if (items.isEmpty) continue;

      final isParcel = order.resolvedOrderType == 'parcel';

      for (final item in items) {
        final name = item.product.name;
        if (!itemStats.containsKey(name)) {
          itemStats[name] = {
            'count': 0.0,
            'revenue': 0.0,
            'dine_count': 0.0,
            'dine_revenue': 0.0,
            'parcel_count': 0.0,
            'parcel_revenue': 0.0,
            'base_price': item.product.price,
            'parcel_price': item.product.price + (item.product.parcelAmount ?? 0.0),
          };
        }
        itemStats[name]!['count'] += item.quantity;
        
        final double itemRevenue = item.effectiveTotal(order.resolvedOrderType);
        itemStats[name]!['revenue'] += itemRevenue;

        if (isParcel) {
          itemStats[name]!['parcel_count'] += item.quantity;
          itemStats[name]!['parcel_revenue'] += itemRevenue;
        } else {
          itemStats[name]!['dine_count'] += item.quantity;
          itemStats[name]!['dine_revenue'] += itemRevenue;
        }
      }
    }

    final sortedItems = itemStats.entries.toList()
      ..sort(
        (a, b) => (b.value['count'] as num).compareTo(a.value['count'] as num),
      );

    double totalRevenue = filteredOrders.fold(
      0.0,
      (sum, order) => sum + order.total,
    );
    int totalUnits = 0;
    for (var entry in sortedItems) {
      totalUnits += (entry.value['count'] as num).toInt();
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDesktop
          ? NeumorphicTheme.background
          : const Color(0xFFF8FAFC),
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text(
                'Product Performance',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: const Color(0xFF0EA5E9),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
      body: Container(
        color: isDesktop ? NeumorphicTheme.background : const Color(0xFFF8FAFC),
        child: Column(
          children: [
            Container(
              color: NeumorphicTheme.background,
              padding: isDesktop
                  ? const EdgeInsets.fromLTRB(28, 20, 28, 12)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Container(
                  constraints: isDesktop
                      ? const BoxConstraints(maxWidth: 1000)
                      : null,
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              'Today',
                              ProductPerformancePeriod.daily,
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: Icon(
                                Icons.calendar_month,
                                size: 18,
                                color:
                                    _selectedPeriod ==
                                        ProductPerformancePeriod.custom
                                    ? theme.colorScheme.primary
                                    : Colors.black87,
                              ),
                              label: Text(
                                _selectedPeriod ==
                                            ProductPerformancePeriod.custom &&
                                        _selectedSpecificDate != null
                                    ? DateFormat(
                                        'dd MMM yyyy',
                                      ).format(_selectedSpecificDate!)
                                    : 'Select Date',
                                style: TextStyle(
                                  fontWeight:
                                      _selectedPeriod ==
                                          ProductPerformancePeriod.custom
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color:
                                      _selectedPeriod ==
                                          ProductPerformancePeriod.custom
                                      ? theme.colorScheme.primary
                                      : Colors.black87,
                                ),
                              ),
                              backgroundColor:
                                  _selectedPeriod ==
                                      ProductPerformancePeriod.custom
                                  ? theme.colorScheme.primary.withOpacity(0.1)
                                  : null,
                              onPressed: _pickSpecificDate,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.picture_as_pdf,
                                color: Colors.red,
                              ),
                              tooltip: 'Export as PDF',
                              onPressed: () =>
                                  _exportToPdf(sortedItems, shopName, totalRevenue),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.table_chart,
                                color: Colors.green,
                              ),
                              tooltip: 'Export as Excel',
                              onPressed: () =>
                                  _exportToExcel(sortedItems, shopName, totalRevenue),
                            ),
                            IconButton(
                              icon: const Icon(Icons.print, color: Colors.blue),
                              tooltip: 'Print Report',
                              onPressed: () => _printPdf(sortedItems, shopName, totalRevenue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Total Sales Summary Banner
            if (sortedItems.isNotEmpty)
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 28 : 16,
                      vertical: 8,
                    ),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.green.shade200),
                      ),
                      color: Colors.green.shade50,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          final double totalProductSales = sortedItems.fold(
                            0.0,
                            (sum, entry) => sum + (entry.value['revenue'] as num).toDouble(),
                          );
                          final double totalRoundOff = totalRevenue - totalProductSales;
                          _showReconciliationDialog(
                            context,
                            totalUnits,
                            totalProductSales,
                            totalRoundOff,
                            totalRevenue,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Units Sold',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$totalUnits',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Total Sales Amount',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '₹${totalRevenue.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.green.shade700,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: sortedItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No sales data for this period',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : isDesktop
                  ? GridView.builder(
                      padding: const EdgeInsets.all(28),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 340,
                            mainAxisExtent: 100,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                      itemCount: sortedItems.length,
                      itemBuilder: (context, index) {
                        final entry = sortedItems[index];
                        final name = entry.key;
                        final count = entry.value['count'];
                        final revenue = entry.value['revenue'];
                        final initial = name.isNotEmpty
                            ? name[0].toUpperCase()
                            : '?';
                        final avatarColor = Colors
                            .primaries[name.hashCode % Colors.primaries.length];

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.06),
                                offset: const Offset(0, 8),
                                blurRadius: 24,
                                spreadRadius: -2,
                              ),
                              BoxShadow(
                                color: const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.04),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showProductBreakdownDialog(context, name, entry.value),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: avatarColor.withOpacity(0.1),
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: avatarColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Units Sold: ${count % 1 == 0 ? count.toInt() : count}',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '₹${revenue % 1 == 0 ? revenue.toInt() : revenue.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const Text(
                                          'Revenue',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sortedItems.length,
                      itemBuilder: (context, index) {
                        final entry = sortedItems[index];
                        final name = entry.key;
                        final count = entry.value['count'];
                        final revenue = entry.value['revenue'];
                        final initial = name.isNotEmpty
                            ? name[0].toUpperCase()
                            : '?';
                        final avatarColor = Colors
                            .primaries[name.hashCode % Colors.primaries.length];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.04),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showProductBreakdownDialog(context, name, entry.value),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: avatarColor.withOpacity(0.1),
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: avatarColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Units Sold: ${count % 1 == 0 ? count.toInt() : count}',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Revenue',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${revenue % 1 == 0 ? revenue.toInt() : revenue.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ProductPerformancePeriod period) {
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
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _showProductBreakdownDialog(
    BuildContext context,
    String productName,
    Map<String, dynamic> stats,
  ) {
    final double dineCount = stats['dine_count'] ?? 0.0;
    final double dineRevenue = stats['dine_revenue'] ?? 0.0;
    final double parcelCount = stats['parcel_count'] ?? 0.0;
    final double parcelRevenue = stats['parcel_revenue'] ?? 0.0;
    final double totalCount = stats['count'] ?? 0.0;
    final double totalRevenue = stats['revenue'] ?? 0.0;
    final double basePrice = stats['base_price'] ?? 0.0;
    final double parcelPrice = stats['parcel_price'] ?? 0.0;

    final String dineQtyStr = dineCount % 1 == 0 ? '${dineCount.toInt()}' : '$dineCount';
    final String parcelQtyStr = parcelCount % 1 == 0 ? '${parcelCount.toInt()}' : '$parcelCount';
    final String totalQtyStr = totalCount % 1 == 0 ? '${totalCount.toInt()}' : '$totalCount';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.blue, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBreakdownRow(
                  title: 'Dine In',
                  quantity: dineQtyStr,
                  price: basePrice,
                  total: dineRevenue,
                  color: Colors.blue.shade700,
                  icon: Icons.restaurant,
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow(
                  title: 'Parcel',
                  quantity: parcelQtyStr,
                  price: parcelPrice,
                  total: parcelRevenue,
                  color: Colors.orange.shade700,
                  icon: Icons.takeout_dining,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(thickness: 1, color: Color(0xFFE2E8F0)),
                ),
                // Total Summary Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Units',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalQtyStr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Total Revenue',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${totalRevenue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBreakdownRow({
    required String title,
    required String quantity,
    required double price,
    required double total,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$quantity Units @ ₹${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReconciliationDialog(
    BuildContext context,
    int totalUnits,
    double productSales,
    double roundOff,
    double totalRevenue,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sales Reconciliation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                _buildReconciliationRow(
                  icon: Icons.shopping_bag_outlined,
                  color: Colors.blue,
                  title: 'Total Units Sold',
                  value: '$totalUnits Units',
                ),
                const SizedBox(height: 12),
                _buildReconciliationRow(
                  icon: Icons.fastfood_outlined,
                  color: Colors.orange,
                  title: 'Total Product Sales',
                  value: '₹${productSales.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 12),
                _buildReconciliationRow(
                  icon: Icons.auto_awesome_outlined,
                  color: Colors.purple,
                  title: 'Total Round Off',
                  value: '${roundOff >= 0 ? '+' : ''}₹${roundOff.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 16),
                const Divider(thickness: 1.5),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Final Total Sales',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      Text(
                        '₹${totalRevenue.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReconciliationRow({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

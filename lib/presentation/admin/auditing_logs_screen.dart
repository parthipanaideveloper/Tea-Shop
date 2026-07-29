import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import '../../providers/order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../domain/models/order.dart';
import '../../core/utils/ui_utils.dart';
import '../../core/utils/export_utils.dart';
import '../widgets/neumorphic_widgets.dart';

enum AuditLogFilter { today, weekly, monthly, custom }

class AuditingLogsScreen extends ConsumerStatefulWidget {
  const AuditingLogsScreen({super.key});

  @override
  ConsumerState<AuditingLogsScreen> createState() => _AuditingLogsScreenState();
}

class _AuditingLogsScreenState extends ConsumerState<AuditingLogsScreen> {
  AuditLogFilter _filter = AuditLogFilter.today;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allOrders = ref.watch(orderProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final canPop = Navigator.canPop(context);

    // Filter for anomaly orders (edited, deleted, voided, refunded)
    final allHistoryOrders = allOrders.toList();

    // Apply Date Filter
    final filtered = allHistoryOrders.where((o) {
      final now = DateTime.now();
      final date = o.date;

      switch (_filter) {
        case AuditLogFilter.today:
          return date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;
        case AuditLogFilter.weekly:
          final monday = _selectedDate.subtract(
            Duration(days: _selectedDate.weekday - 1),
          );
          final weekStart = DateTime(monday.year, monday.month, monday.day);
          final weekEnd = weekStart.add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
          );
          return date.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
              date.isBefore(weekEnd.add(const Duration(seconds: 1)));
        case AuditLogFilter.monthly:
          return date.year == _selectedDate.year &&
              date.month == _selectedDate.month;
        case AuditLogFilter.custom:
          if (_customRange != null) {
            return date.isAfter(
                  _customRange!.start.subtract(const Duration(seconds: 1)),
                ) &&
                date.isBefore(_customRange!.end.add(const Duration(days: 1)));
          }
          return true;
      }
    }).toList();

    // Sort by date descending
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    if (canPop)
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF0F172A),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    const Text(
                      'Auditing Logs',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.picture_as_pdf,
                        color: Color(0xFF0F172A),
                      ),
                      tooltip: 'Export PDF',
                      onPressed: () => _exportPdf(filtered),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.table_chart,
                        color: Color(0xFF0F172A),
                      ),
                      tooltip: 'Export Excel',
                      onPressed: () => _exportExcel(filtered),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<AuditLogFilter>(
                        style: SegmentedButton.styleFrom(
                          backgroundColor: Colors.white,
                          selectedForegroundColor: const Color(0xFF0F172A),
                          selectedBackgroundColor: const Color(0xFFDBEAFE),
                          side: const BorderSide(color: Color(0xFF94A3B8)),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: AuditLogFilter.today,
                            label: Text('Daily'),
                          ),
                          ButtonSegment(
                            value: AuditLogFilter.weekly,
                            label: Text('Weekly'),
                          ),
                          ButtonSegment(
                            value: AuditLogFilter.monthly,
                            label: Text('Monthly'),
                          ),
                          ButtonSegment(
                            value: AuditLogFilter.custom,
                            label: Text('Custom'),
                          ),
                        ],
                        selected: <AuditLogFilter>{_filter},
                        onSelectionChanged:
                            (Set<AuditLogFilter> newSelection) async {
                              final val = newSelection.first;
                              if (val == AuditLogFilter.custom) {
                                DateTime start =
                                    _customRange?.start ?? DateTime.now();
                                DateTime end =
                                    _customRange?.end ?? DateTime.now();

                                final DateTimeRange?
                                pickedRange = await showDialog<DateTimeRange>(
                                  context: context,
                                  builder: (context) {
                                    return StatefulBuilder(
                                      builder: (context, setStateDialog) {
                                        return AlertDialog(
                                          title: const Text(
                                            'Select Date Range',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                title: const Text('Start Date'),
                                                subtitle: Text(
                                                  DateFormat(
                                                    'EEEE, MMMM d, yyyy',
                                                  ).format(start),
                                                ),
                                                leading: const Icon(
                                                  Icons.calendar_today,
                                                  color: Colors.blue,
                                                ),
                                                onTap: () async {
                                                  final picked =
                                                      await showDatePicker(
                                                        context: context,
                                                        initialDate: start,
                                                        firstDate: DateTime(
                                                          2020,
                                                        ),
                                                        lastDate: DateTime(
                                                          2100,
                                                        ),
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
                                                  DateFormat(
                                                    'EEEE, MMMM d, yyyy',
                                                  ).format(end),
                                                ),
                                                leading: const Icon(
                                                  Icons.calendar_today,
                                                  color: Colors.green,
                                                ),
                                                onTap: () async {
                                                  final picked =
                                                      await showDatePicker(
                                                        context: context,
                                                        initialDate: end,
                                                        firstDate: start,
                                                        lastDate: DateTime(
                                                          2100,
                                                        ),
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
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: () {
                                                Navigator.pop(
                                                  context,
                                                  DateTimeRange(
                                                    start: start,
                                                    end: end,
                                                  ),
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
                                    _customRange = pickedRange;
                                    _filter = val;
                                  });
                                }
                              } else {
                                // Automatically filter based on current date
                                setState(() {
                                  _selectedDate = DateTime.now();
                                  _filter = val;
                                });
                              }
                            },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        if (_filter != AuditLogFilter.custom)
                          Text(
                            'Selected: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          )
                        else if (_customRange != null)
                          Text(
                            'Selected: ${DateFormat('dd MMM yyyy').format(_customRange!.start)} - ${DateFormat('dd MMM yyyy').format(_customRange!.end)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          )
                        else
                          Text(
                            'No date selected',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${filtered.length} records',
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No auditing logs for this period.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isGrid = constraints.maxWidth >= 800;

                      Widget buildAuditCard(order) {
                        Color bgColor = Colors.white;
                        Color borderColor = const Color(0xFFE2E8F0);
                        String statusText = '';
                        Color statusColor = Colors.black;
                        Color statusBgColor = Colors.black12;

                        if (order.isRefunded) {
                          bgColor = Colors.blue.shade50;
                          borderColor = Colors.blue.shade100;
                          statusText = 'REFUNDED';
                          statusColor = Colors.blue.shade800;
                          statusBgColor = Colors.blue.shade100;
                        } else if (order.isDeleted) {
                          bgColor = const Color(0xFFFFF1F2);
                          borderColor = const Color(0xFFFECDD3);
                          statusText = 'DELETED';
                          statusColor = const Color(0xFFE11D48);
                          statusBgColor = const Color(0xFFFFE4E6);
                        } else if (order.isVoided) {
                          bgColor = Colors.purple.shade50;
                          borderColor = Colors.purple.shade100;
                          statusText = 'VOIDED';
                          statusColor = Colors.purple;
                          statusBgColor = Colors.purple.shade100;
                        } else if (order.isEdited) {
                          bgColor = Colors.orange.shade50;
                          borderColor = Colors.orange.shade100;
                          statusText = 'EDITED';
                          statusColor = Colors.orange.shade800;
                          statusBgColor = Colors.orange.shade100;
                        } else {
                          bgColor = Colors.white;
                          borderColor = const Color(0xFFBBF7D0);
                          statusText = 'COMPLETED';
                          statusColor = const Color(0xFF16A34A);
                          statusBgColor = const Color(0xFFDCFCE7);
                        }

                        return Container(
                          margin: isGrid
                              ? EdgeInsets.zero
                              : const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: bgColor,
                            border: Border.all(color: borderColor, width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order #${order.displayId.toUpperCase()}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(order.date)}',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (order.editedAt != null)
                                      Text(
                                        'Edited: ${DateFormat('dd MMM yyyy, hh:mm a').format(order.editedAt!)}',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Staff: ${order.staffName}',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (order.voidReason.isNotEmpty)
                                      Text(
                                        'Void Reason: ${order.voidReason}',
                                        style: const TextStyle(
                                          color: Color(0xFFE11D48),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (order.editReason.isNotEmpty)
                                      Text(
                                        'Edit Info: ${order.editReason}',
                                        style: TextStyle(
                                          color: Colors.orange.shade800,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBgColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '₹${order.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      if (isGrid) {
                        return GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 420,
                                mainAxisExtent: 145,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) =>
                              buildAuditCard(filtered[index]),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            buildAuditCard(filtered[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(List<OrderModel> orders) async {
    final pdf = pw.Document();
    final settings = ref.read(settingsProvider);

    final periodName = switch (_filter) {
      AuditLogFilter.today => 'Daily (Today)',
      AuditLogFilter.weekly => 'Weekly',
      AuditLogFilter.monthly => 'Monthly',
      AuditLogFilter.custom => 'Custom Range',
    };

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => ExportUtils.buildPremiumPdfHeader(
          settings.shopName,
          'AUDITING LOGS',
          'Period: $periodName',
        ),
        footer: (context) => ExportUtils.buildPremiumPdfFooter(context),
        build: (context) => [
          pw.Text(
            'Audit Details',
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
                      'Order ID',
                      style: ExportUtils.getPdfHeaderStyle(),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Date',
                      style: ExportUtils.getPdfHeaderStyle(),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Staff',
                      style: ExportUtils.getPdfHeaderStyle(),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Status',
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
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Reason',
                      style: ExportUtils.getPdfHeaderStyle(),
                    ),
                  ),
                ],
              ),
              ...orders.map((o) {
                String status = '';
                if (o.isDeleted)
                  status = 'DELETED';
                else if (o.isVoided)
                  status = 'VOIDED';
                else if (o.isEdited)
                  status = 'EDITED';
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        o.id.toUpperCase(),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(o.date),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        o.staffName,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        status,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        o.total.toStringAsFixed(2),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        o.voidReason,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'auditing_logs_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _exportExcel(List<OrderModel> orders) async {
    try {
      final settings = ref.read(settingsProvider);
      final periodName = switch (_filter) {
        AuditLogFilter.today => 'Daily (Today)',
        AuditLogFilter.weekly => 'Weekly',
        AuditLogFilter.monthly => 'Monthly',
        AuditLogFilter.custom => 'Custom Range',
      };

      final excel = Excel.createExcel();
      final sheet = excel['Auditing Logs'];
      excel.delete('Sheet1');

      ExportUtils.setupPremiumExcelHeader(
        sheet,
        settings.shopName,
        'AUDITING LOGS',
        'Period: $periodName',
      );

      sheet.appendRow([TextCellValue('')]);
      sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue(
        'AUDIT DETAILS',
      );
      sheet.cell(CellIndex.indexByString('A5')).cellStyle =
          ExportUtils.getExcelHeaderStyle();

      final headers = [
        TextCellValue('Order ID'),
        TextCellValue('Date'),
        TextCellValue('Staff'),
        TextCellValue('Status'),
        TextCellValue('Total'),
        TextCellValue('Reason'),
      ];
      sheet.appendRow(headers);
      for (int i = 0; i < headers.length; i++) {
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 6))
                .cellStyle =
            ExportUtils.getExcelHeaderStyle();
      }

      for (var o in orders) {
        String status = '';
        if (o.isDeleted)
          status = 'DELETED';
        else if (o.isVoided)
          status = 'VOIDED';
        else if (o.isEdited)
          status = 'EDITED';

        sheet.appendRow([
          TextCellValue(o.id.toUpperCase()),
          TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(o.date)),
          TextCellValue(o.staffName),
          TextCellValue(status),
          DoubleCellValue(o.total),
          TextCellValue(o.voidReason),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/auditing_logs_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(path);
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(path)], text: 'Auditing Logs Excel');
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showSquarePopup(
          context,
          'Failed to save Excel: $e',
          isError: true,
        );
      }
    }
  }
}

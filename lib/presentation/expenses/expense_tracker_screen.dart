import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:fl_chart/fl_chart.dart';
import '../../domain/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/export_utils.dart';
import '../widgets/neumorphic_widgets.dart';

enum ExpensePeriod { daily, weekly, monthly, custom, customRange }

class ExpenseTrackerScreen extends ConsumerStatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  ConsumerState<ExpenseTrackerScreen> createState() =>
      _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends ConsumerState<ExpenseTrackerScreen> {
  String _selectedCategoryFilter = 'All';
  ExpensePeriod _selectedPeriod = ExpensePeriod.daily;
  DateTime? _customDate;
  DateTimeRange? _customRange;

  Future<void> _pickCustomDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now());
    if (picked != null) {
      setState(() {
        _selectedPeriod = ExpensePeriod.custom;
        _customDate = picked;
      });
    }
  }

  Future<void> _pickCustomRange() async {
    DateTime start = _customRange?.start ?? DateTime.now().subtract(const Duration(days: 7));
    DateTime end = _customRange?.end ?? DateTime.now();

    final DateTimeRange? pickedRange = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Date Range'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(start)),
                    leading: const Icon(Icons.calendar_today, color: Colors.blue),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: start,
                        firstDate: DateTime(2020),
                        lastDate: end,
                      );
                      if (picked != null) {
                        setStateDialog(() {
                          start = picked;
                          if (end.isBefore(start)) end = start;
                        });
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(end)),
                    leading: const Icon(Icons.calendar_today, color: Colors.green),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context, DateTimeRange(start: start, end: end)),
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
        _selectedPeriod = ExpensePeriod.customRange;
        _customRange = pickedRange;
      });
    }
  }

  List<Expense> _filterExpensesByPeriod(List<Expense> allExpenses) {
    final now = DateTime.now();
    return allExpenses.where((e) {
      final localDate = e.date.toLocal();
      switch (_selectedPeriod) {
        case ExpensePeriod.daily:
          return localDate.year == now.year &&
              localDate.month == now.month &&
              localDate.day == now.day;
        case ExpensePeriod.weekly:
          final weekAgo = now.subtract(const Duration(days: 7));
          return localDate.isAfter(weekAgo);
        case ExpensePeriod.monthly:
          return localDate.year == now.year && localDate.month == now.month;
        case ExpensePeriod.custom:
          if (_customDate == null) return true;
          return localDate.year == _customDate!.year &&
              localDate.month == _customDate!.month &&
              localDate.day == _customDate!.day;
        case ExpensePeriod.customRange:
          if (_customRange == null) return true;
          final start = _customRange!.start;
          final end = _customRange!.end;
          final startDay = DateTime(start.year, start.month, start.day);
          final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
          return localDate.isAfter(startDay.subtract(const Duration(seconds: 1))) &&
                 localDate.isBefore(endDay.add(const Duration(seconds: 1)));
      }
    }).toList();
  }

  Future<void> _exportToPdf(List<Expense> expenses, String shopName) async {
    final pdf = pw.Document();

    final periodName = switch (_selectedPeriod) {
      ExpensePeriod.daily => 'Daily (Today)',
      ExpensePeriod.weekly => 'Weekly (Last 7 Days)',
      ExpensePeriod.monthly => 'Monthly (This Month)',
      ExpensePeriod.custom =>
        'Custom Date (${_customDate != null ? DateFormat('MMM d, yyyy').format(_customDate!) : 'Unknown'})',
      ExpensePeriod.customRange =>
        'Custom Range (${_customRange != null ? "${DateFormat('MMM d').format(_customRange!.start)} - ${DateFormat('MMM d, yyyy').format(_customRange!.end)}" : 'Unknown'})',
    };

    final total = expenses.fold<double>(0, (sum, item) => sum + item.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => ExportUtils.buildPremiumPdfHeader(shopName, 'EXPENSE TRACKER REPORT', 'Period: $periodName'),
        footer: (context) => ExportUtils.buildPremiumPdfFooter(context),
        build: (pw.Context context) {
          return [
            pw.Text('Performance Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: ExportUtils.primaryColor)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: ExportUtils.getPdfHeaderDecoration(),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Metric', style: ExportUtils.getPdfHeaderStyle())),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Value', style: ExportUtils.getPdfHeaderStyle())),
                  ]),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Expenses', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs. ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  ]),
              ]
            ),
            pw.SizedBox(height: 20),

            pw.Text('Expense Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: ExportUtils.primaryColor)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: ExportUtils.getPdfHeaderDecoration(),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: ExportUtils.getPdfHeaderStyle())),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Category', style: ExportUtils.getPdfHeaderStyle())),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Title', style: ExportUtils.getPdfHeaderStyle())),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Amount (Rs)', style: ExportUtils.getPdfHeaderStyle())),
                  ]),
                ...expenses.map((e) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(DateFormat('dd MMM yyyy').format(e.date), style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(e.category, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(e.title, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(e.amount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9))),
                    ]);
                }),
              ]),
          ];
        }));

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'expense_report_${_selectedPeriod.name}.pdf');
  }

  Future<void> _exportToExcel(List<Expense> expenses, String shopName) async {
    try {
      final periodName = switch (_selectedPeriod) {
        ExpensePeriod.daily => 'Daily (Today)',
        ExpensePeriod.weekly => 'Weekly (Last 7 Days)',
        ExpensePeriod.monthly => 'Monthly (This Month)',
        ExpensePeriod.custom =>
          'Custom Date (${_customDate != null ? DateFormat('MMM d, yyyy').format(_customDate!) : 'Unknown'})',
        ExpensePeriod.customRange =>
          'Custom Range (${_customRange != null ? "${DateFormat('MMM d').format(_customRange!.start)} - ${DateFormat('MMM d, yyyy').format(_customRange!.end)}" : 'Unknown'})',
      };

      final excel = Excel.createExcel();
      final sheet = excel['Expense Report'];
      excel.delete('Sheet1');

      ExportUtils.setupPremiumExcelHeader(sheet, shopName, 'EXPENSE TRACKER REPORT', 'Period: $periodName');
      
      final boldStyle = CellStyle(bold: true);

      sheet.appendRow([TextCellValue('')]);
      
      // Performance Summary Section
      sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('PERFORMANCE SUMMARY');
      sheet.cell(CellIndex.indexByString('A5')).cellStyle = ExportUtils.getExcelHeaderStyle();

      final total = expenses.fold<double>(0, (sum, item) => sum + item.amount);
      sheet.appendRow([TextCellValue('Total Expenses'), DoubleCellValue(total)]);

      sheet.appendRow([TextCellValue('')]);
      
      // Expense Details Section
      sheet.cell(CellIndex.indexByString('A9')).value = TextCellValue('EXPENSE DETAILS');
      sheet.cell(CellIndex.indexByString('A9')).cellStyle = ExportUtils.getExcelHeaderStyle();

      final headers = [
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Title'),
        TextCellValue('Amount (Rs)'),
        TextCellValue('Notes'),
      ];
      sheet.appendRow(headers);
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 10)).cellStyle = ExportUtils.getExcelHeaderStyle();
      }

      for (final e in expenses) {
        final date = DateFormat('yyyy-MM-dd').format(e.date);
        sheet.appendRow([
          TextCellValue(date),
          TextCellValue(e.category),
          TextCellValue(e.title),
          DoubleCellValue(e.amount),
          TextCellValue(e.notes ?? ''),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/expense_report.xlsx');
        await file.writeAsBytes(fileBytes);
        await Share.shareXFiles([XFile(file.path)], subject: 'Expense Report');
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showCenter(
          context, 'Failed to export Excel', isError: true);
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Rent':
        return const Color(0xFF2563EB); // Blue
      case 'Salary':
        return const Color(0xFF0D9488); // Teal
      case 'Raw Materials':
      case 'Raw Materials & Supplies':
        return const Color(0xFFEA580C); // Orange
      case 'Utilities':
      case 'Utility Bills':
        return const Color(0xFF4F46E5); // Indigo
      case 'Fuel':
      case 'Travel & Transport':
        return const Color(0xFFD97706); // Amber
      case 'Marketing':
        return const Color(0xFFDB2777); // Pink
      case 'Staff Expenses':
        return const Color(0xFF8B5CF6); // Violet
      default:
        final hash = category.hashCode;
        final colors = [
          const Color(0xFF2563EB),
          const Color(0xFF0D9488),
          const Color(0xFFEA580C),
          const Color(0xFF4F46E5),
          const Color(0xFFD97706),
          const Color(0xFFDB2777),
          const Color(0xFF8B5CF6),
          const Color(0xFF059669),
          const Color(0xFFE11D48),
        ];
        return colors[hash.abs() % colors.length];
    }
  }

  void _showManageCategoriesDialog() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.category_outlined, color: Color(0xFF0EA5E9)),
              SizedBox(width: 8),
              Text('Manage Categories', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: Consumer(
              builder: (context, ref, child) {
                final categories = ref.watch(expenseCategoriesProvider);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textCtrl,
                            decoration: const InputDecoration(
                              labelText: 'New Category Name',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF059669), size: 36),
                          onPressed: () async {
                            final name = textCtrl.text.trim();
                            if (name.isNotEmpty) {
                              await ref.read(expenseCategoriesProvider.notifier).addCategory(name);
                              textCtrl.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          return ListTile(
                            title: Text(cat),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                  onPressed: () {
                                    final editCtrl = TextEditingController(text: cat);
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Edit Category'),
                                        content: TextField(
                                          controller: editCtrl,
                                          decoration: const InputDecoration(labelText: 'Category Name'),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('CANCEL'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              final newName = editCtrl.text.trim();
                                              if (newName.isNotEmpty) {
                                                await ref.read(expenseCategoriesProvider.notifier).editCategory(cat, newName);
                                                Navigator.pop(ctx);
                                              }
                                            },
                                            child: const Text('SAVE'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Category?'),
                                        content: Text('Are you sure you want to delete "$cat"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('CANCEL'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              await ref.read(expenseCategoriesProvider.notifier).removeCategory(cat);
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  void _addExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final categories = ref.read(expenseCategoriesProvider);
    String selectedCat = categories.isNotEmpty ? categories.first : 'Miscellaneous';
    DateTime selectedDate = DateTime.now();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.add_card, color: Color(0xFF059669)),
                  SizedBox(width: 8),
                  Text(
                    'Add New Expense',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ]),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title / Description',
                          hintText: 'e.g. Monthly Rent Payment',
                          border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter a description'
                            : null),
                      const SizedBox(height: 16),

                      // Amount
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          hintText: '0.00',
                          prefixText: '₹ ',
                          border: OutlineInputBorder()),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Enter amount';
                          final val = double.tryParse(v);
                          if (val == null || val <= 0)
                            return 'Enter a valid amount';
                          return null;
                        }),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedCat,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder()),
                        items: categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedCat = v);
                          }
                        }),
                      const SizedBox(height: 16),

                      // Date selector picker
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365)));
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.black54),
                            ]))),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Optional Notes',
                          border: OutlineInputBorder())),
                    ]))),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.black54))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newExpense = Expense(
                        id: const Uuid().v4(),
                        title: titleCtrl.text.trim(),
                        amount: double.parse(amountCtrl.text),
                        category: selectedCat,
                        date: selectedDate,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim());
                      await ref
                          .read(expenseProvider.notifier)
                          .addExpense(newExpense);
                      if (context.mounted) {
                        Navigator.pop(context);
                        NotificationHelper.showCenter(context, 'Expense logged successfully!', isError: false);
                      }
                    }
                  },
                  child: const Text('SAVE EXPENSE')),
              ]);
          });
      });
  }

  void _deleteConfirm(Expense exp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense Record?'),
        content: Text(
          'Are you sure you want to permanently delete "${exp.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await ref.read(expenseProvider.notifier).deleteExpense(exp.id);
              if (context.mounted) {
                Navigator.pop(context);
                NotificationHelper.showCenter(context, 'Expense record deleted.', isError: false);
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseProvider);
    final orders = ref.watch(orderProvider);
    final categories = ref.watch(expenseCategoriesProvider);
    final theme = Theme.of(context);
    final shopName = ref.watch(settingsProvider).shopName;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final canPop = Navigator.canPop(context);

    // Apply period filter
    final periodFiltered = _filterExpensesByPeriod(expenses);

    // Filter orders for the same period for P&L
    final now = DateTime.now();
    final periodOrders = orders.where((order) {
      if (order.isVoided || order.isRefunded || order.isDeleted) return false;
      if (order.paymentStatus != 'PAID') return false;
      final localDate = order.date.toLocal();
      switch (_selectedPeriod) {
        case ExpensePeriod.daily:
          return localDate.year == now.year &&
              localDate.month == now.month &&
              localDate.day == now.day;
        case ExpensePeriod.weekly:
          final weekAgo = now.subtract(const Duration(days: 7));
          return localDate.isAfter(weekAgo);
        case ExpensePeriod.monthly:
          return localDate.year == now.year && localDate.month == now.month;
        case ExpensePeriod.custom:
          if (_customDate == null) return true;
          return localDate.year == _customDate!.year &&
              localDate.month == _customDate!.month &&
              localDate.day == _customDate!.day;
        case ExpensePeriod.customRange:
          if (_customRange == null) return true;
          final start = _customRange!.start;
          final end = _customRange!.end;
          final startDay = DateTime(start.year, start.month, start.day);
          final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
          return localDate.isAfter(startDay.subtract(const Duration(seconds: 1))) &&
                 localDate.isBefore(endDay.add(const Duration(seconds: 1)));
      }
    }).toList();

    // Calculate totals for this period
    final totalMonthlyExpenses = periodFiltered.fold<double>(
      0,
      (sum, item) => sum + item.amount);
    final totalMonthlyRevenue = periodOrders.fold<double>(
      0,
      (sum, item) => sum + item.total);
    final profitOrLoss = totalMonthlyRevenue - totalMonthlyExpenses;

    // Apply category filter
    final finalFiltered = periodFiltered.where((e) {
      if (_selectedCategoryFilter == 'All') return true;
      return e.category == _selectedCategoryFilter;
    }).toList();

    // Group categories for analytics breakdown
    final Map<String, double> catBreakdown = {};
    for (final exp in periodFiltered) {
      catBreakdown[exp.category] =
          (catBreakdown[exp.category] ?? 0) + exp.amount;
    }

    // Sort categories by expenditure
    final sortedBreakdown = catBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: NeumorphicTheme.background,
      appBar: isDesktop ? null : AppBar(
        title: const Text(
          'Expense Tracker',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _buildBodyContent(
          context,
          isDesktop,
          theme,
          finalFiltered,
          periodFiltered,
          totalMonthlyRevenue,
          totalMonthlyExpenses,
          profitOrLoss,
          sortedBreakdown,
          shopName,
          categories,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        onPressed: _addExpenseDialog,
        child: const Icon(Icons.add)));
  }

  Widget _buildFilterChip(String category) {
    final isSelected = _selectedCategoryFilter == category;
    final primaryColor = const Color(0xFF059669);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 12.5)),
        selected: isSelected,
        selectedColor: primaryColor,
        backgroundColor: Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedCategoryFilter = category;
            });
          }
        }));
  }

  Widget _buildPeriodChip(String label, ExpensePeriod period) {
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
    List<Expense> finalFiltered,
    List<Expense> periodFiltered,
    double totalMonthlyRevenue,
    double totalMonthlyExpenses,
    double profitOrLoss,
    List<MapEntry<String, double>> sortedBreakdown,
    String shopName,
    List<String> categories,
  ) {
    return Column(
      children: [
        // Premium Header with total metrics & filter bar
        Container(
          color: NeumorphicTheme.background,
          padding: isDesktop
              ? const EdgeInsets.fromLTRB(28, 20, 28, 28)
              : const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Period selector (Scrollable Row to keep it on one line)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPeriodChip('Today', ExpensePeriod.daily),
                    const SizedBox(width: 8),
                    ActionChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          if (_selectedPeriod == ExpensePeriod.custom && _customDate != null) ...[
                            const SizedBox(width: 6),
                            Text(DateFormat('MMM d, yyyy').format(_customDate!)),
                          ]
                        ],
                      ),
                      tooltip: 'Pick specific date',
                      onPressed: _pickCustomDate,
                      backgroundColor: _selectedPeriod == ExpensePeriod.custom
                          ? theme.colorScheme.primary.withOpacity(0.1)
                          : Colors.white,
                      side: BorderSide(
                        color: _selectedPeriod == ExpensePeriod.custom
                            ? theme.colorScheme.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.date_range, size: 16),
                          if (_selectedPeriod == ExpensePeriod.customRange && _customRange != null) ...[
                            const SizedBox(width: 6),
                            Text('${DateFormat('MMM d').format(_customRange!.start)} - ${DateFormat('MMM d').format(_customRange!.end)}'),
                          ]
                        ],
                      ),
                      tooltip: 'Pick date range',
                      onPressed: _pickCustomRange,
                      backgroundColor: _selectedPeriod == ExpensePeriod.customRange
                          ? theme.colorScheme.primary.withOpacity(0.1)
                          : Colors.white,
                      side: BorderSide(
                        color: _selectedPeriod == ExpensePeriod.customRange
                            ? theme.colorScheme.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.file_download_outlined, color: Colors.black87),
                      onSelected: (value) {
                        if (value == 'pdf') {
                           _exportToPdf(finalFiltered, shopName);
                        } else if (value == 'excel') {
                          _exportToExcel(finalFiltered, shopName);
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
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.black87),
                      tooltip: 'Manage Categories',
                      onPressed: _showManageCategoriesDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Period P&L',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDesktop ? NeumorphicTheme.textPrimary : Colors.black87)),
                ]),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'REVENUE',
                        amount: totalMonthlyRevenue,
                        color: Colors.blue,
                        icon: Icons.trending_up,
                        isDesktop: isDesktop,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'EXPENSES',
                        amount: totalMonthlyExpenses,
                        color: Colors.red,
                        icon: Icons.trending_down,
                        isDesktop: isDesktop,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: profitOrLoss >= 0 ? 'PROFIT' : 'LOSS',
                        amount: profitOrLoss.abs(),
                        color: profitOrLoss >= 0 ? Colors.green : Colors.orange,
                        icon: profitOrLoss >= 0 ? Icons.account_balance_wallet : Icons.warning_amber_rounded,
                        isDesktop: isDesktop,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

            ])),

        // Filters Tab Selection
        Container(
          width: double.infinity,
          color: NeumorphicTheme.background,
          padding: isDesktop
              ? const EdgeInsets.symmetric(horizontal: 28, vertical: 12)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: isDesktop
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('All'),
                    ...categories.map((cat) => _buildFilterChip(cat)),
                  ])
              : Row(
                  children: [
                    InkWell(
                      onTap: _showFilterBottomSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF059669).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Category: $_selectedCategoryFilter',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        // Expense Records List
        Expanded(
          child: finalFiltered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wallet_outlined,
                        size: 56,
                        color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No expenses found',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text(
                        'Tap + to log an expense for this period.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400)),
                    ]))
              : isDesktop
                  ? GridView.builder(
                      padding: const EdgeInsets.all(28),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 340,
                        mainAxisExtent: 140,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: finalFiltered.length,
                      itemBuilder: (context, index) {
                        final item = finalFiltered[index];
                        final catColor = _getCategoryColor(item.category);
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                offset: const Offset(0, 8),
                                blurRadius: 24,
                                spreadRadius: -2,
                              ),
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: catColor.withOpacity(0.1),
                                      shape: BoxShape.circle),
                                    child: Icon(
                                      Icons.account_balance_wallet,
                                      color: catColor,
                                      size: 18)),
                                  Text(
                                    '-₹${item.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: Colors.redAccent)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B))),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.category} • ${DateFormat('dd MMM').format(item.date)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11))),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.black38),
                                    onPressed: () => _deleteConfirm(item),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                  itemCount: finalFiltered.length,
                  itemBuilder: (context, index) {
                    final item = finalFiltered[index];
                    final catColor = _getCategoryColor(item.category);

                    final cardContent = Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 14.0),
                      child: Row(
                        children: [
                          // Decorative category circle
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.1),
                              shape: BoxShape.circle),
                            child: Icon(
                              Icons.account_balance_wallet,
                              color: catColor,
                              size: 20)),
                          const SizedBox(width: 14),

                          // Expense Title and details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: isDesktop ? NeumorphicTheme.textPrimary : null)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      item.category,
                                      style: TextStyle(
                                        color: catColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•  ${DateFormat('dd MMM').format(item.date)}',
                                      style: TextStyle(
                                        color: isDesktop ? NeumorphicTheme.textSecondary : Colors.grey.shade500,
                                        fontSize: 11)),
                                  ]),
                                if (item.notes != null &&
                                    item.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.notes!,
                                    style: TextStyle(
                                      color: isDesktop ? NeumorphicTheme.textSecondary : Colors.grey.shade400,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic)),
                                ],
                              ])),

                          // Amount and Delete Action
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '-₹${item.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Colors.redAccent)),
                              const SizedBox(height: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.black38),
                                onPressed: () => _deleteConfirm(item),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero),
                            ]),
                        ],
                      ),
                    );


                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                            offset: const Offset(0, 8),
                            blurRadius: 24,
                            spreadRadius: -2,
                          ),
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: cardContent,
                      ),
                    );
                  }),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    required bool isDesktop,
  }) {
    final padding = isDesktop
        ? const EdgeInsets.all(18.0)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 12);
    final titleSize = isDesktop ? 12.0 : 10.0;
    final iconSize = isDesktop ? 16.0 : 13.0;
    final iconPadding = isDesktop ? 8.0 : 5.0;
    final amountSize = isDesktop ? 22.0 : 15.0;
    final spacing = isDesktop ? 16.0 : 8.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: iconSize),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: const Color(0xFF1E293B),
                  fontSize: amountSize,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(List<MapEntry<String, double>> sortedBreakdown, double totalExpenses) {
    if (totalExpenses == 0) return [];
    
    List<PieChartSectionData> sections = [];
    double otherTotal = 0;
    
    for (int i = 0; i < sortedBreakdown.length; i++) {
      final entry = sortedBreakdown[i];
      if (i < 5) {
        final pct = (entry.value / totalExpenses) * 100;
        sections.add(
          PieChartSectionData(
            color: _getCategoryColor(entry.key),
            value: entry.value,
            title: '${pct.toStringAsFixed(0)}%',
            radius: 40,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          )
        );
      } else {
        otherTotal += entry.value;
      }
    }
    
    if (otherTotal > 0) {
      final pct = (otherTotal / totalExpenses) * 100;
      sections.add(
        PieChartSectionData(
          color: Colors.grey,
          value: otherTotal,
          title: '${pct.toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        )
      );
    }
    
    return sections;
  }

  Widget _buildChartLegend(String title, double amount, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showFilterBottomSheet() {
    final categories = ref.read(expenseCategoriesProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter by Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildBottomSheetFilterItem('All'),
                    ...categories.map((cat) => _buildBottomSheetFilterItem(cat)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetFilterItem(String category) {
    final isSelected = _selectedCategoryFilter == category;
    final catColor = category == 'All' ? const Color(0xFF059669) : _getCategoryColor(category);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: catColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.account_balance_wallet, color: catColor, size: 18),
      ),
      title: Text(
        category,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF059669) : Colors.black87,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF059669)) : null,
      onTap: () {
        setState(() {
          _selectedCategoryFilter = category;
        });
        Navigator.pop(context);
      },
    );
  }
}

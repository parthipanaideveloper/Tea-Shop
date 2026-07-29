import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/refund_provider.dart';
import '../../core/extensions/string_extensions.dart';
import '../../providers/language_provider.dart';
import '../widgets/neumorphic_widgets.dart';

class RefundHistoryScreen extends ConsumerStatefulWidget {
  const RefundHistoryScreen({super.key});

  @override
  ConsumerState<RefundHistoryScreen> createState() => _RefundHistoryScreenState();
}

class _RefundHistoryScreenState extends ConsumerState<RefundHistoryScreen> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now());
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRefunds = ref.watch(refundProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    // Filter by selected date
    final filteredRefunds = allRefunds.where((r) {
      final localDate = r.date.toLocal();
      return localDate.year == _selectedDate.year &&
          localDate.month == _selectedDate.month &&
          localDate.day == _selectedDate.day;
    }).toList();

    // Sort descending
    filteredRefunds.sort((a, b) => b.date.compareTo(a.date));

    // Calculate Daily Status
    final double totalDailyRefunds = filteredRefunds.fold(0.0, (sum, r) => sum + r.amountRefunded);

    return Scaffold(
      backgroundColor: isDesktop ? NeumorphicTheme.background : const Color(0xFFF8FAFC),
      appBar: isDesktop ? null : AppBar(
        title: Text('Refund History'.tr(ref.watch(languageProvider)),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Container(
              constraints: isDesktop ? const BoxConstraints(maxWidth: 450) : null,
              margin: isDesktop ? const EdgeInsets.only(top: 20, bottom: 16) : EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isDesktop ? BorderRadius.circular(16) : BorderRadius.zero,
                border: isDesktop ? Border.all(color: const Color(0xFFE2E8F0), width: 1) : null,
                boxShadow: isDesktop ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                    spreadRadius: -1,
                  ),
                ] : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Summary',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF94A3B8))),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy').format(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B))),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _pickDate,
                                child: const Icon(Icons.edit_calendar_outlined, size: 20, color: Color(0xFF0EA5E9)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total Refunded',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8))),
                      const SizedBox(height: 4),
                      Text(
                        '₹ ${totalDailyRefunds.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                    ],
                  ),
                ],
              ),
            ),
            if (!isDesktop) const Divider(height: 1),
            
            Expanded(
              child: filteredRefunds.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text(
                            'No refunds for the selected date.',
                            style: TextStyle(color: Colors.grey)),
                        ]))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 340,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredRefunds.length,
                      itemBuilder: (context, index) {
                        final refund = filteredRefunds[index];
                        final redBorderColor = const Color(0xFFEF4444).withOpacity(0.4);

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: redBorderColor, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '₹ ${refund.amountRefunded.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.red)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8)),
                                      child: Text(
                                        DateFormat('hh:mm a').format(refund.date),
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                const Divider(color: Color(0xFFF1F5F9), height: 12),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.receipt_long,
                                      size: 16,
                                      color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('Order ID: ${refund.originalOrderId.toUpperCase()}',
                                          style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('Processed by: ${refund.staffName}',
                                          style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('Reason: ${refund.reason}',
                                          style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      })),
          ],
        ),
      ),
    );
  }
}

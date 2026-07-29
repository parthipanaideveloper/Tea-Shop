import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/order.dart';
import '../../providers/order_provider.dart';
import '../widgets/neumorphic_widgets.dart';
import 'settle_bill_dialog.dart';

class UnpaidBillsScreen extends ConsumerStatefulWidget {
  const UnpaidBillsScreen({super.key});

  @override
  ConsumerState<UnpaidBillsScreen> createState() => _UnpaidBillsScreenState();
}

class _UnpaidBillsScreenState extends ConsumerState<UnpaidBillsScreen> {
  void _settleOrder(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => SettleBillDialog(order: order));
  }

  @override
  Widget build(BuildContext context) {
    final allOrders = ref.watch(orderProvider);
    final unpaidOrders = allOrders
        .where((o) => o.paymentStatus == 'UNPAID' && !o.isVoided && !o.isDeleted)
        .toList();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: isDesktop ? NeumorphicTheme.background : const Color(0xFFF8FAFC),
      appBar: isDesktop ? null : AppBar(
        title: const Text(
          'Open Bills (Pending)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: unpaidOrders.isEmpty
              ? const Center(
                  child: Text(
                    'No open bills found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    childAspectRatio: 1.9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: unpaidOrders.length,
                  itemBuilder: (context, index) {
                    final order = unpaidOrders[index];
                    final formatter = DateFormat('dd MMM, hh:mm a');

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade300, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.orange.shade50,
                                child: Icon(
                                  Icons.receipt_long,
                                  size: 18,
                                  color: Colors.orange.shade700)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order #${order.displayId.toUpperCase()}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                      overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatter.format(order.date),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (order.customerName.isNotEmpty)
                            Text(
                              'Customer: ${order.customerName}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)
                          else
                            const SizedBox(height: 0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${order.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A))),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                  minimumSize: const Size(80, 32)),
                                onPressed: () => _settleOrder(order),
                                child: const Text(
                                  'Settle',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
      ),
    );
  }
}

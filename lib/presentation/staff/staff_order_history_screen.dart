import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../widgets/neumorphic_widgets.dart';
import '../analytics/widgets/order_details_dialog.dart';

class StaffOrderHistoryScreen extends ConsumerWidget {
  const StaffOrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    final allOrders = ref.watch(orderProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    final staffName = session?.name.trim() ?? '';

    // Filter orders for this staff member (case-insensitive, trimmed comparison).
    // If staffName is empty (session not resolved yet), show an empty list.
    final myOrders = staffName.isEmpty
        ? <dynamic>[]
        : allOrders
            .where((o) =>
                !o.isDeleted &&
                o.staffName.trim().toLowerCase() == staffName.toLowerCase())
            .toList();

    return Scaffold(
      backgroundColor: isDesktop ? NeumorphicTheme.background : const Color(0xFFF8FAFC),
      appBar: isDesktop ? null : AppBar(
        title: const Text(
          'My Order History',
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
        child: myOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No orders found.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    ]))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    childAspectRatio: 1.9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: myOrders.length,
                  itemBuilder: (context, index) {
                    final order = myOrders[index];
                    final dateStr = DateFormat('dd MMM, hh:mm a').format(order.date);
                    final borderColor = order.isVoided 
                        ? const Color(0xFFE2E8F0) 
                        : const Color(0xFF0EA5E9).withOpacity(0.4);

                    return InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => OrderDetailsDialog(order: order));
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 1.5),
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
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  child: const Icon(Icons.receipt, size: 18, color: Colors.blue)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order #${order.displayId.toUpperCase()}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: const Color(0xFF1E293B),
                                          decoration: order.isVoided ? TextDecoration.lineThrough : null),
                                        overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(
                                        dateStr,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${order.parsedItems.length} items',
                              style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₹${order.total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: order.isVoided ? Colors.grey : const Color(0xFF1E293B),
                                    decoration: order.isVoided ? TextDecoration.lineThrough : null)),
                                if (order.isVoided)
                                  const Text(
                                    'VOIDED',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold))
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'PAID',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
      ),
    );
  }
}

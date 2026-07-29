import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'customers_screen.dart';
import '../../providers/order_provider.dart';
import '../analytics/widgets/order_details_dialog.dart';
import '../widgets/neumorphic_widgets.dart';

class CustomerHistoryScreen extends ConsumerWidget {
  final Customer customer;
  final VoidCallback? onBack;

  const CustomerHistoryScreen({super.key, required this.customer, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allOrders = ref.watch(orderProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final canPop = onBack != null || Navigator.canPop(context);

    // Filter orders by phone or name
    final customerOrders = allOrders.where((order) {
      final phoneMatch =
          order.customerPhone.replaceAll(RegExp(r'[^0-9]'), '') ==
          customer.phone.replaceAll(RegExp(r'[^0-9]'), '');
      return phoneMatch;
    }).toList();

    return Scaffold(
      backgroundColor: isDesktop ? NeumorphicTheme.background : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '${customer.name}\'s History',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDesktop ? Colors.transparent : theme.colorScheme.primary,
        foregroundColor: isDesktop ? NeumorphicTheme.textPrimary : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: canPop,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (onBack != null) {
                    onBack!();
                  } else {
                    Navigator.of(context).pop();
                  }
                })
            : null,
      ),
      body: customerOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 64,
                    color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No purchase history found.',
                    style: TextStyle(color: Colors.grey.shade600)),
                ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: customerOrders.length,
              itemBuilder: (context, index) {
                final order = customerOrders[index];
                final formattedDate = DateFormat(
                  'dd MMM yyyy, hh:mm a').format(order.date);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.1),
                      child: Icon(
                        Icons.receipt_long,
                        color: theme.colorScheme.primary)),
                    title: Text(
                      '₹${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                    subtitle: Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12)),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => OrderDetailsDialog(order: order));
                    }));
              }));
  }
}

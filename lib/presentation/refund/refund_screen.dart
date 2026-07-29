import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../providers/order_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/refund_provider.dart';
import '../../providers/printer_provider.dart';
import '../../core/hardware/printer_service.dart';
import '../../domain/models/order.dart';
import '../../domain/models/cart_item.dart';
import '../widgets/neumorphic_widgets.dart';

class RefundScreen extends ConsumerStatefulWidget {
  const RefundScreen({super.key});

  @override
  ConsumerState<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends ConsumerState<RefundScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orders = ref.watch(orderProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    final filteredOrders = orders.where((order) {
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return order.id.toLowerCase().contains(query) ||
          order.paymentMode.toLowerCase().contains(query) ||
          order.total.toString().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: isDesktop
          ? NeumorphicTheme.background
          : const Color(0xFFF8FAFC),
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text(
                'Refund & Return',
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by Order ID, payment mode...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: filteredOrders.isEmpty
                  ? const Center(child: Text('No matching invoices found.'))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            childAspectRatio: 1.45,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        final dateStr = DateFormat(
                          'dd MMM, hh:mm a',
                        ).format(order.date);
                        final redBorderColor = const Color(
                          0xFFEF4444,
                        ).withOpacity(0.4);

                        return InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => RefundDialog(order: order),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: redBorderColor,
                                width: 1.5,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.red.shade50,
                                      child: const Icon(
                                        Icons.receipt,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Invoice #${order.displayId.toUpperCase()}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Color(0xFF1E293B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            dateStr,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        order.paymentMode.split('|').first,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          '₹${order.total.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.primary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Color(0xFF94A3B8),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
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
}

class RefundDialog extends ConsumerStatefulWidget {
  final OrderModel order;
  const RefundDialog({super.key, required this.order});

  @override
  ConsumerState<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends ConsumerState<RefundDialog> {
  final Map<String, int> _selectedItemsForRefund = {};

  void _confirmFullRefund(BuildContext context) {
    final settingsBox = Hive.box<String>('settings');
    final showStock =
        (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
    bool restockItems = showStock;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Cancel / Refund Order',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'This will delete the invoice from the transactions log and refund the money.',
                  ),
                  const SizedBox(height: 16),
                  if (showStock)
                    CheckboxListTile(
                      title: const Text('Restock Items (Return)'),
                      subtitle: const Text(
                        'Add purchased items back to inventory stock.',
                      ),
                      value: restockItems,
                      onChanged: (val) {
                        setDialogState(() {
                          restockItems = val ?? true;
                        });
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
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (restockItems) {
                      // Restock all items
                      final inventoryNotifier = ref.read(
                        inventoryProvider.notifier,
                      );
                      final allProducts = ref.read(inventoryProvider);

                      for (var item in widget.order.parsedItems) {
                        try {
                          final existingProduct = allProducts.firstWhere(
                            (p) => p.id == item.product.id,
                          );
                          final updatedProduct = existingProduct.copyWith(
                            stockCount:
                                existingProduct.stockCount +
                                item.quantity.ceil(),
                          );
                          inventoryNotifier.updateProduct(updatedProduct);
                        } catch (e) {
                          // Product deleted, skip restock
                        }
                      }
                    }

                    // Delete order
                    final refundedTotal = widget.order.total;
                    final orderId = widget.order.id;
                    await ref
                        .read(orderProvider.notifier)
                        .deleteOrder(widget.order.id);

                    // Log Refund
                    final session = ref.read(authProvider);
                    final err = await ref
                        .read(refundProvider.notifier)
                        .addRefund(
                          originalOrderId: orderId,
                          amountRefunded: refundedTotal,
                          staffName: session?.name ?? 'Admin',
                          reason: 'Full Order Refund',
                        );

                    if (err != null) {
                      if (context.mounted) {
                        NotificationHelper.showCenter(context, err, isError: true);
                      }
                      return;
                    }

                    if (context.mounted) {
                      Navigator.pop(context); // Close confirm dialog
                      Navigator.pop(context); // Close refund dialog
                      _showRefundAmountPopup(context, refundedTotal, orderId);
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmPartialRefund(BuildContext context) {
    final settingsBox = Hive.box<String>('settings');
    final showStock =
        (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
    bool restockItems = showStock;

    // Calculate total refund amount
    double totalRefundAmount = 0;
    List<String> refundedItemNames = [];

    for (var entry in _selectedItemsForRefund.entries) {
      final productId = entry.key;
      final returnQty = entry.value;
      final originalItem = widget.order.parsedItems.firstWhere(
        (i) => i.product.id == productId,
      );
      totalRefundAmount += originalItem.product.price * returnQty;
      refundedItemNames.add('${originalItem.product.name} x$returnQty');
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Refund Selected Items',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Total Amount to Refund: ₹ ${totalRefundAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Are you sure you want to process this return?'),
                  const SizedBox(height: 16),
                  if (showStock)
                    SwitchListTile(
                      title: const Text(
                        'Restock returned items',
                        style: TextStyle(fontSize: 14),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: restockItems,
                      onChanged: (val) {
                        setDialogState(() {
                          restockItems = val;
                        });
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
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (restockItems) {
                      final inventoryNotifier = ref.read(
                        inventoryProvider.notifier,
                      );
                      final allProducts = ref.read(inventoryProvider);

                      for (var entry in _selectedItemsForRefund.entries) {
                        final productId = entry.key;
                        final returnQty = entry.value;
                        try {
                          final existingProduct = allProducts.firstWhere(
                            (p) => p.id == productId,
                          );
                          final updatedProduct = existingProduct.copyWith(
                            stockCount: existingProduct.stockCount + returnQty,
                          );
                          inventoryNotifier.updateProduct(updatedProduct);
                        } catch (e) {
                          // Product deleted, skip restock
                        }
                      }
                    }

                    // Update order by subtracting quantities
                    final updatedItems = widget.order.parsedItems
                        .map((i) {
                          if (_selectedItemsForRefund.containsKey(
                            i.product.id,
                          )) {
                            final retQty =
                                _selectedItemsForRefund[i.product.id]!;
                            final newQty = i.quantity - retQty;
                            return CartItem(
                              product: i.product,
                              quantity: newQty.toDouble(),
                            );
                          }
                          return i;
                        })
                        .where((item) => item.quantity > 0)
                        .toList();

                    final session = ref.read(authProvider);

                    if (updatedItems.isEmpty) {
                      // All items were returned -> Delete the order, mark as refunded
                      await ref
                          .read(orderProvider.notifier)
                          .deleteOrder(widget.order.id, isRefund: true);
                    } else {
                      // Re-serialize order JSON
                      final newItemsJson = OrderModel.serializeItems(
                        updatedItems,
                        paymentMode: widget.order.paymentMode,
                      );

                      // Recalculate totals
                      final double newSubtotal = updatedItems.fold(
                        0.0,
                        (sum, i) => sum + i.total,
                      );
                      final double newTax =
                          newSubtotal *
                          widget.order.tax /
                          (widget.order.subtotal == 0
                              ? 1
                              : widget.order.subtotal);
                      final double newDiscount =
                          widget.order.discount *
                          newSubtotal /
                          (widget.order.subtotal == 0
                              ? 1
                              : widget.order.subtotal);
                      final double newTotal =
                          newSubtotal + newTax - newDiscount;

                      final updatedOrder = OrderModel(
                        id: widget.order.id,
                        total: newTotal,
                        subtotal: newSubtotal,
                        tax: newTax,
                        discount: newDiscount,
                        date: widget.order.date,
                        itemsJson: newItemsJson,
                      );

                      await ref
                          .read(orderProvider.notifier)
                          .updateOrder(updatedOrder);
                    }

                    // Log Refund
                    final err = await ref
                        .read(refundProvider.notifier)
                        .addRefund(
                          originalOrderId: widget.order.id,
                          amountRefunded: totalRefundAmount,
                          staffName: session?.name ?? 'Admin',
                          reason:
                              'Partial Return: ${refundedItemNames.join(', ')}',
                        );

                    if (err != null) {
                      if (context.mounted) {
                        NotificationHelper.showCenter(context, err, isError: true);
                      }
                      return;
                    }

                    if (context.mounted) {
                      final orderId = widget.order.id;
                      Navigator.pop(context); // Close confirm dialog
                      Navigator.pop(context); // Close refund details dialog
                      _showRefundAmountPopup(
                        context,
                        totalRefundAmount,
                        orderId,
                      );
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRefundAmountPopup(
    BuildContext context,
    double amount,
    String orderId,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Center(
          child: Icon(Icons.check_circle, color: Colors.green, size: 60),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Amount to Refund',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'திரும்ப அளிக்க வேண்டிய தொகை', // Tamil: Amount to refund
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Print Receipt'),
            onPressed: () async {
              final settings = ref.read(settingsProvider);
              final session = ref.read(authProvider);
              final bytes = await PrinterService.generateRefundReceiptBytes(
                orderId: orderId,
                refundAmount: amount,
                staffName: session?.name ?? 'Admin',
                shopName: settings.shopName,
                receiptFooter: settings.receiptFooter,
                printAsImage: settings.printAsImage,
                is80mmPaper: settings.is80mmPaper,
              );
              try {
                await ref.read(printerProvider.notifier).printReceipt(bytes);
                if (context.mounted) {
                  NotificationHelper.showCenter(
                    context,
                    'Refund Receipt Printed',
                    isError: false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  NotificationHelper.showCenter(
                    context,
                    e.toString(),
                    isError: true,
                  );
                }
              }
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.order.parsedItems;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFF8FAFC),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Invoice Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Header card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Invoice: #${widget.order.displayId.toUpperCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.order.paymentMode,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date & Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(widget.order.date)}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Full Transaction ID: ${widget.order.displayId.toUpperCase()}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items list header
            const Text(
              'Select Items to Return / Refund',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),

            // Items List
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final maxQty = item.quantity.floor();
                  final isSelected = _selectedItemsForRefund.containsKey(
                    item.product.id,
                  );
                  final selectedQty =
                      _selectedItemsForRefund[item.product.id] ?? 1;

                  return Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.red.shade50.withOpacity(0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: Colors.red,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedItemsForRefund[item.product.id] = 1;
                              } else {
                                _selectedItemsForRefund.remove(item.product.id);
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.quantity} Qty @ ₹${item.product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 22,
                                  color: Colors.red,
                                ),
                                onPressed: selectedQty > 1
                                    ? () {
                                        setState(() {
                                          _selectedItemsForRefund[item
                                                  .product
                                                  .id] =
                                              selectedQty - 1;
                                        });
                                      }
                                    : null,
                              ),
                              Text(
                                '$selectedQty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 22,
                                  color: Colors.red,
                                ),
                                onPressed: selectedQty < maxQty
                                    ? () {
                                        setState(() {
                                          _selectedItemsForRefund[item
                                                  .product
                                                  .id] =
                                              selectedQty + 1;
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _confirmFullRefund(context),
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text(
                      'FULL REFUND',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _selectedItemsForRefund.isEmpty
                        ? null
                        : () => _confirmPartialRefund(context),
                    icon: const Icon(Icons.assignment_return, size: 18),
                    label: const Text(
                      'REFUND SELECTED',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

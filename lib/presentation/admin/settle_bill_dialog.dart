import 'package:pos/core/utils/notification_helper.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/customer.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/customers_provider.dart';

class SettleBillDialog extends ConsumerStatefulWidget {
  final OrderModel order;
  const SettleBillDialog({super.key, required this.order});

  @override
  ConsumerState<SettleBillDialog> createState() => _SettleBillDialogState();
}

class _SettleBillDialogState extends ConsumerState<SettleBillDialog> {
  String _selectedMode = 'UPI';
  final TextEditingController _cashCtrl = TextEditingController();
  double _changeAmount = 0.0;
  bool _isBalanceDue = false;

  @override
  void initState() {
    super.initState();
    _cashCtrl.addListener(_onCashChanged);
    // Auto-fill cash amount
    _cashCtrl.text = widget.order.total.toStringAsFixed(2);
    _onCashChanged();
  }

  void _onCashChanged() {
    final val = double.tryParse(_cashCtrl.text.trim()) ?? 0.0;
    setState(() {
      final diff = val - widget.order.total;
      _changeAmount = diff.abs();
      _isBalanceDue = diff < -0.01; // Allow small float precision
    });
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final String upiUrl =
        'upi://pay?pa=${settings.upiId}&pn=${Uri.encodeComponent(settings.shopName)}&am=${widget.order.total.toStringAsFixed(2)}&cu=INR';

    return AlertDialog(
      title: const Text(
        'Complete Payment',
        style: TextStyle(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(fontSize: 14, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text(
                    'Rs. ${widget.order.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue)),
                ])),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['UPI', 'Cash', 'Card'].map((mode) {
                final isSelected = _selectedMode == mode;
                return ChoiceChip(
                  label: Text(
                    mode,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedMode = mode);
                  });
              }).toList()),
            const SizedBox(height: 24),

            if (_selectedMode == 'UPI') ...[
              // UPI QR Code Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    const Text(
                      'Scan to Pay via UPI',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: upiUrl,
                      version: QrVersions.auto,
                      size: 160.0,
                      backgroundColor: Colors.white),
                  ])),
            ] else if (_selectedMode == 'Cash') ...[
              TextField(
                controller: _cashCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount Received (?)',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              if (_cashCtrl.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isBalanceDue
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isBalanceDue
                          ? Colors.red.shade200
                          : Colors.green.shade200)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isBalanceDue ? 'Balance Due:' : 'Return Change:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isBalanceDue
                              ? Colors.red.shade700
                              : Colors.green.shade700)),
                      Text(
                        'Rs. ${_changeAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isBalanceDue
                              ? Colors.red.shade700
                              : Colors.green.shade700)),
                    ])),
            ] else if (_selectedMode == 'Card') ...[
              // Card Terminal Simulator
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    Icon(
                      Icons.contactless,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'Terminal Card Payment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      'Swipe or Tap Card on the connected POS machine and confirm payment completion.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13),
                      textAlign: TextAlign.center),
                  ])),
            ],
          ])),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          onPressed:
              (_selectedMode == 'Cash' &&
                  _isBalanceDue &&
                  _cashCtrl.text.isNotEmpty)
              ? null
              : () async {
                  // Update order
                  String updatedJson = widget.order.itemsJson;
                  try {
                    final decoded = jsonDecode(widget.order.itemsJson);
                    if (decoded is Map<String, dynamic>) {
                      decoded['paymentStatus'] = 'PAID';
                      decoded['paymentMode'] = _selectedMode;
                      updatedJson = jsonEncode(decoded);
                    } else if (decoded is List) {
                      final wrappedMap = {
                        'items': decoded,
                        'paymentMode': _selectedMode,
                        'paymentStatus': 'PAID',
                      };
                      updatedJson = jsonEncode(wrappedMap);
                    }
                  } catch (_) {}

                  final updatedOrder = OrderModel(
                    id: widget.order.id,
                    total: widget.order.total,
                    subtotal: widget.order.subtotal,
                    tax: widget.order.tax,
                    discount: widget.order.discount,
                    date: widget.order.date,
                    itemsJson: updatedJson);

                  await ref
                      .read(orderProvider.notifier)
                      .updateOrder(updatedOrder);

                  // Credit customer totalSpent upon settlement
                  final customerPhone = widget.order.customerPhone;
                  if (customerPhone.isNotEmpty) {
                    try {
                      final customersList = ref.read(customersProvider);
                      final customersNotifier = ref.read(customersProvider.notifier);
                      final targetPhoneClean = customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
                      final existingIndex = customersList.indexWhere((c) {
                        final cPhoneClean = c.phone.replaceAll(RegExp(r'[^0-9]'), '');
                        return cPhoneClean == targetPhoneClean;
                      });
                      if (existingIndex != -1) {
                        final existingCust = customersList[existingIndex];
                        customersNotifier.updateCustomer(
                          Customer(
                            id: existingCust.id,
                            name: existingCust.name,
                            phone: existingCust.phone,
                            email: existingCust.email,
                            totalOrders: existingCust.totalOrders,
                            totalSpent: existingCust.totalSpent + widget.order.total),
                        );
                      }
                    } catch (_) {}
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    NotificationHelper.showCenter(context, 'Bill settled successfully!', isError: false);
                  }
                },
          child: const Text(
            'CONFIRM PAYMENT',
            style: TextStyle(fontWeight: FontWeight.bold))),
      ]);
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../domain/models/order.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../core/hardware/printer_service.dart';
import '../../../../core/utils/ui_utils.dart';
import '../../../../providers/language_provider.dart';
import '../../../../providers/order_provider.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/inventory_provider.dart';
import '../../../../domain/models/cart_item.dart';
import '../../../../domain/models/product.dart';

class OrderDetailsDialog extends ConsumerWidget {
  final OrderModel order;

  const OrderDetailsDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = order.parsedItems;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Details',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop()),
              ]),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        '#${order.displayId.toUpperCase()}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        DateFormat('MMM dd, yyyy - hh:mm a').format(order.date),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Divider(height: 1, thickness: 1, color: Colors.transparent), 
                    ),
                    Expanded(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            visualDensity: const VisualDensity(vertical: -4),
                            title: Text(
                              (ref.watch(languageProvider) == 'ta' &&
                                      item.product.nameTamil != null &&
                                      item.product.nameTamil!.isNotEmpty)
                                  ? item.product.nameTamil!
                                  : item.product.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                              '${item.quantity}x @ ₹${item.effectivePrice(order.resolvedOrderType).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12)),
                            trailing: Text(
                              '₹${item.effectiveTotal(order.resolvedOrderType).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold)));
                        })),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Divider(height: 1, thickness: 1)),
                    _SummaryRow(title: 'Subtotal', value: order.subtotal),
                    const SizedBox(height: 4),
                    _SummaryRow(title: 'Tax', value: order.tax),
                    if (order.discount > 0) ...[
                      const SizedBox(height: 4),
                      _SummaryRow(
                        title: 'Discount',
                        value: -order.discount,
                        isDiscount: true),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                          Text(
                            '₹${order.total.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                        ]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (order.isVoided)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200)),
                child: Column(
                  children: [
                    const Text(
                      'VOIDED',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 18)),
                    if (order.voidReason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${order.voidReason}',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12)),
                    ],
                  ]))
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('REPRINT'),
                          onPressed: () async {
                            final settings = ref.read(settingsProvider);
                            final bytes =
                                await PrinterService.generateReceiptBytes(
                                  items: items,
                                  subtotal: order.subtotal,
                                  tax: order.tax,
                                  discount: order.discount,
                                  total: order.total,
                                  shopName: settings.shopName,
                                  receiptHeader: settings.receiptHeader,
                                  receiptFooter: settings.receiptFooter,
                                  showGstOnReceipt: settings.showGstOnReceipt,
                                  gstNumber: settings.gstNumber,
                                  orderId: order.displayId,
                                  tableNo: order.dineTableNo,
                                  orderType: order.resolvedOrderType,
                                  printAsImage: settings.printAsImage,
                                  is80mmPaper: settings.is80mmPaper,
                                  addressLine1: settings.addressLine1,
                                  addressLine2: settings.addressLine2,
                                  hotelType: settings.hotelType,
                                  mobileNumber: settings.mobileNumber,
                                  fssaiNumber: settings.fssaiNumber,
                                  enableAddressOnReceipt:
                                      settings.enableAddressOnReceipt,
                                  enableMobileOnReceipt:
                                      settings.enableMobileOnReceipt,
                                  enableFssaiOnReceipt:
                                      settings.enableFssaiOnReceipt,
                                  enableHotelTypeOnReceipt:
                                      settings.enableHotelTypeOnReceipt,
                                  showPoweredByDiyan:
                                      settings.showPoweredByDiyan);
                            try {
                              await ref
                                  .read(printerProvider.notifier)
                                  .printReceipt(bytes);
                              if (context.mounted) {
                                UiUtils.showSquarePopup(
                                  context,
                                  'Receipt sent to printer!',
                                  isError: false);
                              }
                            } catch (e) {
                              final errorMsg = e.toString().replaceAll('Exception:', '').trim();
                              if (context.mounted) {
                                UiUtils.showSquarePopup(
                                  context,
                                  'Printing failed: $errorMsg',
                                  isError: true);
                              }
                            }
                          })),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('SHARE PDF'),
                          onPressed: () async {
                            final settings = ref.read(settingsProvider);
                            final pdf = pw.Document();

                            pdf.addPage(
                              pw.Page(
                                pageFormat: PdfPageFormat.roll80,
                                margin: const pw.EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10),
                                build: (pw.Context context) {
                                  return pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Center(
                                        child: pw.Text(
                                          settings.shopName.toUpperCase(),
                                          style: pw.TextStyle(
                                            fontWeight: pw.FontWeight.bold,
                                            fontSize: 12))),
                                      if (settings.receiptHeader.isNotEmpty)
                                        pw.Center(
                                          child: pw.Text(
                                            settings.receiptHeader,
                                            style: const pw.TextStyle(
                                              fontSize: 7.5))),
                                      if (settings.showGstOnReceipt &&
                                          settings.gstNumber.isNotEmpty)
                                        pw.Center(
                                          child: pw.Text(
                                            'GSTIN: ${settings.gstNumber}',
                                            style: const pw.TextStyle(
                                              fontSize: 7.5))),
                                      pw.SizedBox(height: 4),
                                      pw.Divider(
                                        thickness: 0.5,
                                        borderStyle: pw.BorderStyle.dashed),
                                      pw.SizedBox(height: 2),
                                      pw.Row(
                                        mainAxisAlignment:
                                            pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text(
                                            'Date: ${order.date.toString().substring(0, 16)}',
                                            style: const pw.TextStyle(
                                              fontSize: 7.5)),
                                          pw.Text(
                                            'Mode: ${order.paymentMode}',
                                            style: const pw.TextStyle(
                                              fontSize: 7.5)),
                                        ]),
                                      pw.SizedBox(height: 2),
                                      pw.Divider(
                                        thickness: 0.5,
                                        borderStyle: pw.BorderStyle.dashed),
                                      pw.SizedBox(height: 2),
                                      // Items Table Header
                                      pw.Row(
                                        mainAxisAlignment:
                                            pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text(
                                            'Item Description',
                                            style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 7.5)),
                                          pw.Text(
                                            'Amount',
                                            style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 7.5)),
                                        ]),
                                      pw.SizedBox(height: 2),
                                      ...items.map((item) {
                                        return pw.Padding(
                                          padding:
                                              const pw.EdgeInsets.symmetric(
                                                vertical: 1.5),
                                          child: pw.Row(
                                            mainAxisAlignment: pw
                                                .MainAxisAlignment
                                                .spaceBetween,
                                            crossAxisAlignment:
                                                pw.CrossAxisAlignment.start,
                                            children: [
                                              pw.Expanded(
                                                child: pw.Text(
                                                  '${item.product.name} x${item.quantity.toInt()} (@Rs.${item.effectivePrice(order.resolvedOrderType).toStringAsFixed(2)})',
                                                  style: const pw.TextStyle(
                                                    fontSize: 7.5))),
                                              pw.Text(
                                                'Rs. ${item.effectiveTotal(order.resolvedOrderType).toStringAsFixed(2)}',
                                                style: const pw.TextStyle(
                                                  fontSize: 7.5)),
                                            ]));
                                      }).toList(),
                                      pw.SizedBox(height: 2),
                                      pw.Divider(
                                        thickness: 0.5,
                                        borderStyle: pw.BorderStyle.dashed),
                                      pw.SizedBox(height: 2),
                                      // Summary Rows
                                      pw.Row(
                                        mainAxisAlignment:
                                            pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text(
                                            'Subtotal:',
                                            style: const pw.TextStyle(
                                              fontSize: 7.5)),
                                          pw.Text(
                                            'Rs. ${order.subtotal.toStringAsFixed(2)}',
                                            style: const pw.TextStyle(
                                              fontSize: 7.5)),
                                        ]),
                                      pw.Row(
                                        mainAxisAlignment:
                                            pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text(
                                            'Tax:',
                                            style: const pw.TextStyle(
                                              fontSize: 7.5)),
                                          pw.Text(
                                            'Rs. ${order.tax.toStringAsFixed(2)}',
                                            style: const pw.TextStyle(
                                              fontSize: 7.5)),
                                        ]),
                                      if (order.discount > 0)
                                        pw.Row(
                                          mainAxisAlignment:
                                              pw.MainAxisAlignment.spaceBetween,
                                          children: [
                                            pw.Text(
                                              'Discount:',
                                              style: const pw.TextStyle(
                                                fontSize: 7.5)),
                                            pw.Text(
                                              '-Rs. ${order.discount.toStringAsFixed(2)}',
                                              style: const pw.TextStyle(
                                                fontSize: 7.5)),
                                          ]),
                                      pw.SizedBox(height: 2),
                                      pw.Divider(
                                        thickness: 0.5,
                                        borderStyle: pw.BorderStyle.dashed),
                                      pw.SizedBox(height: 2),
                                      pw.Row(
                                        mainAxisAlignment:
                                            pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text(
                                            'TOTAL AMOUNT:',
                                            style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 9)),
                                          pw.Text(
                                            'Rs. ${order.total.toStringAsFixed(2)}',
                                            style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 9)),
                                        ]),
                                      pw.SizedBox(height: 6),
                                      pw.Divider(
                                        thickness: 0.5,
                                        borderStyle: pw.BorderStyle.dashed),
                                      pw.SizedBox(height: 4),
                                      if (settings
                                          .receiptFooter
                                          .isNotEmpty) ...[
                                        pw.Center(
                                          child: pw.Text(
                                            settings.receiptFooter,
                                            style: const pw.TextStyle(
                                              fontSize: 7.5))),
                                        pw.SizedBox(height: 2),
                                      ],
                                      if (settings.isDemoVersion) ...[
                                        pw.Center(
                                          child: pw.Text(
                                            'This is a demo version. Custom features will be added.',
                                            style: const pw.TextStyle(
                                              fontSize: 7.0))),
                                        pw.SizedBox(height: 2),
                                      ],
                                      pw.Center(
                                        child: pw.Text(
                                          'Thank you! Please visit again.',
                                          style: pw.TextStyle(
                                            fontSize: 7.5,
                                            fontWeight: pw.FontWeight.bold))),
                                    ]);
                                }));

                            final bytes = await pdf.save();
                            await Printing.sharePdf(
                              bytes: bytes,
                              filename: 'receipt_${order.displayId}.pdf');
                          })),
                    ]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          label: const Text(
                            'EDIT',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blue)),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => _ManualEditBillDialog(order: order));
                          })),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text(
                            'VOID',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red)),
                          onPressed: () {
                            final textCtrl = TextEditingController();
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Void Bill'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Are you sure you want to void this bill? This will reverse the transaction and restock inventory.',
                                      style: TextStyle(fontSize: 13)),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: textCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Reason for voiding',
                                        border: OutlineInputBorder())),
                                  ]),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white),
                                    onPressed: () {
                                      if (textCtrl.text.trim().isEmpty) {
                                        UiUtils.showSquarePopup(
                                          ctx,
                                          'Reason is required to void.',
                                          isError: true);
                                        return;
                                      }
                                      ref
                                          .read(orderProvider.notifier)
                                          .voidOrder(
                                            order.id,
                                            textCtrl.text.trim());
                                      Navigator.pop(ctx); // close void dialog
                                      Navigator.pop(
                                        context); // close details dialog
                                      UiUtils.showSquarePopup(
                                        context,
                                        'Bill voided successfully.',
                                        isError: false);
                                    },
                                    child: const Text('Confirm Void')),
                                ]));
                          })),
                    ]),
                  const SizedBox(height: 12),
                ]),
          ])));
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final double value;
  final bool isDiscount;

  const _SummaryRow({
    required this.title,
    required this.value,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
        Text(
          '${isDiscount ? '-₹' : '₹'}${value.abs().toStringAsFixed(2)}',
          style: TextStyle(
            color: isDiscount ? Colors.green : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 14)),
      ]);
  }
}

class _ManualEditBillDialog extends ConsumerStatefulWidget {
  final OrderModel order;
  const _ManualEditBillDialog({required this.order});

  @override
  ConsumerState<_ManualEditBillDialog> createState() => _ManualEditBillDialogState();
}

class _ManualEditBillDialogState extends ConsumerState<_ManualEditBillDialog> {
  late TextEditingController subtotalCtrl;
  late TextEditingController taxCtrl;
  late TextEditingController discountCtrl;
  late TextEditingController totalCtrl;
  late TextEditingController splitCashCtrl;
  late TextEditingController splitUpiCtrl;
  String paymentMode = 'UPI';
  String paymentStatus = 'PAID';

  List<CartItem> editedItems = [];

  @override
  void initState() {
    super.initState();
    editedItems = List.from(widget.order.parsedItems);
    subtotalCtrl = TextEditingController(text: widget.order.subtotal.toStringAsFixed(2));
    taxCtrl = TextEditingController(text: widget.order.tax.toStringAsFixed(2));
    discountCtrl = TextEditingController(text: widget.order.discount.toStringAsFixed(2));
    totalCtrl = TextEditingController(text: widget.order.total.toStringAsFixed(2));
    splitCashCtrl = TextEditingController();
    splitUpiCtrl = TextEditingController();
    
    paymentMode = widget.order.paymentMode.isNotEmpty ? widget.order.paymentMode : 'UPI';
    if (paymentMode.startsWith('Split|')) {
      final parts = paymentMode.split('|');
      if (parts.length == 3) {
        splitCashCtrl.text = parts[1];
        splitUpiCtrl.text = parts[2];
      }
      paymentMode = 'Split';
    } else if (!['Cash', 'UPI', 'Card', 'Split'].contains(paymentMode)) {
      paymentMode = 'UPI';
    }
    
    paymentStatus = widget.order.paymentStatus.isNotEmpty ? widget.order.paymentStatus : 'PAID';
    if (!['PAID', 'UNPAID'].contains(paymentStatus)) paymentStatus = 'PAID';
  }

  @override
  void dispose() {
    subtotalCtrl.dispose();
    taxCtrl.dispose();
    discountCtrl.dispose();
    totalCtrl.dispose();
    splitCashCtrl.dispose();
    splitUpiCtrl.dispose();
    super.dispose();
  }

  void _recalculateTotals() {
    final settingsBox = ref.read(settingsProvider);
    double newSubtotal = 0;
    for (var item in editedItems) {
      newSubtotal += item.effectiveTotal(widget.order.orderType);
    }
    
    // Attempt to maintain the original discount logic if it was a flat amount,
    // or you can leave discount as manually overridden. For now, keep the old discount amount.
    double d = double.tryParse(discountCtrl.text) ?? widget.order.discount;
    
    // Tax recalculation: use the taxRate from settings
    final taxRate = settingsBox.taxRate;
    double newTax = ((newSubtotal - d) * taxRate / 100);
    if (newTax < 0) newTax = 0;

    double newTotal = newSubtotal + newTax - d;
    if (newTotal < 0) newTotal = 0;

    subtotalCtrl.text = newSubtotal.toStringAsFixed(2);
    taxCtrl.text = newTax.toStringAsFixed(2);
    totalCtrl.text = newTotal.toStringAsFixed(2);
  }

  void _incrementQty(int index) {
    setState(() {
      final current = editedItems[index];
      editedItems[index] = current.copyWith(quantity: current.quantity + 1);
      _recalculateTotals();
    });
  }

  void _decrementQty(int index) {
    setState(() {
      final current = editedItems[index];
      if (current.quantity > 1) {
        editedItems[index] = current.copyWith(quantity: current.quantity - 1);
        _recalculateTotals();
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      editedItems.removeAt(index);
      _recalculateTotals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);
    final settings = ref.watch(settingsProvider);

    return AlertDialog(
      title: Text('Manual Edit: #${widget.order.id}'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 250),
                child: editedItems.isEmpty 
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No items in this order.'),
                    )
                  : ListView.separated(
                  shrinkWrap: true,
                  itemCount: editedItems.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = editedItems[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('₹${item.effectivePrice(widget.order.orderType).toStringAsFixed(2)} x ${item.quantity.toInt()} = ₹${item.effectiveTotal(widget.order.orderType).toStringAsFixed(2)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                            onPressed: () => _decrementQty(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          Text('${item.quantity.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                            onPressed: () => _incrementQty(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeItem(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Autocomplete<Product>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Product>.empty();
                  }
                  return inventory.where((Product p) =>
                      p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (Product option) => option.name,
                onSelected: (Product selection) {
                  setState(() {
                    final existingIndex = editedItems.indexWhere((i) => i.product.id == selection.id);
                    if (existingIndex >= 0) {
                      final current = editedItems[existingIndex];
                      editedItems[existingIndex] = current.copyWith(quantity: current.quantity + 1);
                    } else {
                      editedItems.add(CartItem(product: selection, quantity: 1));
                    }
                    _recalculateTotals();
                  });
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Search & Add Item',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Cash'),
                    selected: paymentMode == 'Cash',
                    onSelected: (_) => setState(() => paymentMode = 'Cash'),
                  ),
                  ChoiceChip(
                    label: const Text('UPI'),
                    selected: paymentMode == 'UPI',
                    onSelected: (_) => setState(() => paymentMode = 'UPI'),
                  ),
                  if (settings.enableSplitPayment)
                    ChoiceChip(
                      label: const Text('Split'),
                      selected: paymentMode == 'Split',
                      onSelected: (_) => setState(() => paymentMode = 'Split'),
                    ),
                  ChoiceChip(
                    label: const Text('Card'),
                    selected: paymentMode == 'Card',
                    onSelected: (_) => setState(() => paymentMode = 'Card'),
                  ),
                ],
              ),
              if (paymentMode == 'Split') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: splitCashCtrl,
                        decoration: const InputDecoration(labelText: 'Cash Amount', border: OutlineInputBorder(), isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState((){}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: splitUpiCtrl,
                        decoration: const InputDecoration(labelText: 'UPI Amount', border: OutlineInputBorder(), isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState((){}),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: paymentStatus,
                decoration: const InputDecoration(labelText: 'Payment Status', border: OutlineInputBorder(), isDense: true),
                items: ['PAID', 'UNPAID'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => paymentStatus = v!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: subtotalCtrl, decoration: const InputDecoration(labelText: 'Subtotal', border: OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState((){}))),
                  if (settings.enableTaxCalculation) ...[
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: taxCtrl, decoration: const InputDecoration(labelText: 'Tax', border: OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState((){}))),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (settings.enableDiscountInCart) ...[
                    Expanded(child: TextField(
                      controller: discountCtrl, 
                      decoration: const InputDecoration(labelText: 'Discount', border: OutlineInputBorder(), isDense: true), 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _recalculateTotals(),
                    )),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: TextField(controller: totalCtrl, decoration: const InputDecoration(labelText: 'Total', border: OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState((){}))),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final st = double.tryParse(subtotalCtrl.text) ?? widget.order.subtotal;
            final t = double.tryParse(taxCtrl.text) ?? widget.order.tax;
            final d = double.tryParse(discountCtrl.text) ?? widget.order.discount;
            final tot = double.tryParse(totalCtrl.text) ?? widget.order.total;

            final List<String> changes = [];
            
            // Build item changes string
            Map<String, double> oldItems = {};
            for (var i in widget.order.parsedItems) { oldItems[i.product.name] = i.quantity; }
            Map<String, double> newItems = {};
            for (var i in editedItems) { newItems[i.product.name] = i.quantity; }
            
            List<String> itemDiffs = [];
            for (var key in newItems.keys) {
              if (!oldItems.containsKey(key)) {
                itemDiffs.add('Added: $key x${newItems[key]?.toInt()}');
              } else if (oldItems[key] != newItems[key]) {
                itemDiffs.add('Changed: $key ${oldItems[key]?.toInt()}->${newItems[key]?.toInt()}');
              }
            }
            for (var key in oldItems.keys) {
              if (!newItems.containsKey(key)) {
                itemDiffs.add('Removed: $key x${oldItems[key]?.toInt()}');
              }
            }
            if (itemDiffs.isNotEmpty) {
              changes.add(itemDiffs.join(', '));
            }

            String finalPaymentMode = paymentMode;
            if (paymentMode == 'Split') {
              final c = double.tryParse(splitCashCtrl.text) ?? 0.0;
              final u = double.tryParse(splitUpiCtrl.text) ?? 0.0;
              if ((c + u - tot).abs() > 0.01) {
                UiUtils.showSquarePopup(context, 'Split amounts must equal Total (₹${tot.toStringAsFixed(2)})', isError: true);
                return;
              }
              finalPaymentMode = 'Split|${splitCashCtrl.text}|${splitUpiCtrl.text}';
            }

            if (st != widget.order.subtotal) changes.add('Subtotal: ${widget.order.subtotal} -> $st');
            if (t != widget.order.tax) changes.add('Tax: ${widget.order.tax} -> $t');
            if (d != widget.order.discount) changes.add('Discount: ${widget.order.discount} -> $d');
            if (tot != widget.order.total) changes.add('Total: ${widget.order.total} -> $tot');
            if (finalPaymentMode != widget.order.paymentMode) changes.add('Mode: ${widget.order.paymentMode} -> $finalPaymentMode');
            if (paymentStatus != widget.order.paymentStatus) changes.add('Status: ${widget.order.paymentStatus} -> $paymentStatus');
            
            final reason = changes.isNotEmpty ? changes.join(' | ') : 'Manually edited';

            await ref.read(orderProvider.notifier).saveOrder(
              id: widget.order.id,
              items: editedItems,
              subtotal: st,
              tax: t,
              discount: d,
              total: tot,
              paymentMode: finalPaymentMode,
              paymentStatus: paymentStatus,
              customerName: widget.order.customerName,
              customerPhone: widget.order.customerPhone,
              staffName: widget.order.staffName,
              isEdited: true,
              editReason: reason,
              originalItemsForRestock: widget.order.parsedItems,
              originalDate: widget.order.date, // Preserve original date so order stays on its original day
            );
            
            if (context.mounted) {
              Navigator.pop(context); // close manual edit dialog
              Navigator.pop(context); // close order details dialog
              UiUtils.showSquarePopup(context, 'Order manually updated successfully.', isError: false);
            }
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}


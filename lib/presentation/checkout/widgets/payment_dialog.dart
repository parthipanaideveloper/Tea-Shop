import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../providers/order_provider.dart';
import '../../../../providers/inventory_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../providers/auth_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'dart:async';
import '../../../../core/hardware/printer_service.dart';
import '../../../../core/utils/ui_utils.dart';
import '../../customers/customers_screen.dart';

import '../../../core/utils/notification_helper.dart';
import '../../../../services/print_router_service.dart';
import '../../../../services/firebase_sync_service.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  final String initialPaymentMode;
  const PaymentDialog({super.key, required this.initialPaymentMode});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  bool _showPreview = false;
  String _selectedPaymentMode = 'UPI';
  final TextEditingController _cashCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  double _changeAmount = 0.0;
  bool _isBalanceDue = true;
  String _customerName = '';
  String _customerPhone = '';
  bool _isProcessing = false;

  Timer? _printerCheckTimer;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMode = widget.initialPaymentMode;

    _printerCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.read(printerProvider.notifier).checkConnection();
    });
    _cashCtrl.addListener(_onCashChanged);
  }

  @override
  void dispose() {
    _printerCheckTimer?.cancel();
    _cashCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onCashChanged() {
    final cart = ref.read(cartProvider);
    final val = double.tryParse(_cashCtrl.text.trim()) ?? 0.0;
    setState(() {
      if (val >= cart.total) {
        _changeAmount = val - cart.total;
        _isBalanceDue = false;
      } else {
        _changeAmount = cart.total - val;
        _isBalanceDue = true;
      }
    });
  }

  Future<Uint8List> _generatePdfBytes(
    CartState cart, {
    bool isUnpaid = false,
  }) async {
    final settings = ref.read(settingsProvider);
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                    style: const pw.TextStyle(fontSize: 7.5))),
              if (settings.showGstOnReceipt && settings.gstNumber.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'GSTIN: ${settings.gstNumber}',
                    style: const pw.TextStyle(fontSize: 7.5))),
              if (isUnpaid) ...[
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    '** NOT PAID - KOT **',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9))),
              ],
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date: ${DateTime.now().toString().substring(0, 16)}',
                    style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text(
                    'Mode: $_selectedPaymentMode',
                    style: const pw.TextStyle(fontSize: 7.5)),
                ]),
              if (_customerName.isNotEmpty)
                pw.Text(
                  'Customer: $_customerName',
                  style: const pw.TextStyle(fontSize: 7.5)),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2),
              // Items Table Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
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
              ...cart.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${item.product.name} x${item.quantity.toInt()} (@Rs.${item.effectivePrice(cart.orderType).toStringAsFixed(2)})',
                          style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Text(
                        'Rs. ${item.effectiveTotal(cart.orderType).toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 7.5)),
                    ]));
              }).toList(),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2),
              // Summary Rows
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Subtotal:',
                    style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text(
                    'Rs. ${cart.subtotal.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 7.5)),
                ]),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Tax (${(cart.taxRate * 100).toInt()}%):',
                    style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text(
                    'Rs. ${cart.taxAmount.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 7.5)),
                ]),
              if (cart.discountAmount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Discount:',
                      style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text(
                      '-Rs. ${cart.discountAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 7.5)),
                  ]),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL AMOUNT:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9)),
                  pw.Text(
                    'Rs. ${cart.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9)),
                ]),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              if (settings.receiptFooter.isNotEmpty) ...[
                pw.Center(
                  child: pw.Text(
                    settings.receiptFooter,
                    style: const pw.TextStyle(fontSize: 7.5))),
                pw.SizedBox(height: 4),
              ],
              if (settings.isDemoVersion) ...[
                pw.Center(
                  child: pw.Text(
                    'This is a demo version.',
                    style: pw.TextStyle(
                      fontSize: 7.0,
                      fontWeight: pw.FontWeight.bold))),
                pw.Center(
                  child: pw.Text(
                    'Custom features will be added.',
                    style: pw.TextStyle(
                      fontSize: 7.0,
                      fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 4),
              ],
              if (settings.showPoweredByDiyan)
                pw.Center(
                  child: pw.Text(
                    'Powered by DiyanTechSolutions, 8667442426',
                    style: const pw.TextStyle(fontSize: 6.0))),
            ]);
        }));

    return await pdf.save();
  }

  Future<void> _sharePdfReceipt() async {
    final cart = ref.read(cartProvider);
    final bytes = await _generatePdfBytes(cart);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final printerState = ref.watch(printerProvider);
    final settings = ref.watch(settingsProvider);
    final customers = ref.watch(customersProvider);
    final authState = ref.watch(authProvider);
    final isStaff = authState?.role == UserRole.staff;

    final String upiUrl =
        'upi://pay?pa=${settings.upiId}&pn=${Uri.encodeComponent(settings.shopName)}&am=${cart.total.toStringAsFixed(2)}&cu=INR';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Complete Payment',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Total Amount: ₹${cart.total.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
              const SizedBox(height: 20),

              const SizedBox(height: 16),

              // Customer Details & WhatsApp Form
              Card(
                color: Colors.blue.shade50.withOpacity(0.3),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.shade100, width: 1)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: Colors.blue.shade700,
                            size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue.shade700)),
                        ]),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: Size.zero),
                          onPressed: () =>
                              _showSelectCustomerDialog(context, customers),
                          icon: const Icon(Icons.people, size: 16),
                          label: const Text(
                            'Choose Existing',
                            style: TextStyle(fontSize: 12)))),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            onChanged: (val) {
                              _customerName = val;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Customer Name',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10))),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phoneCtrl,
                            onChanged: (val) {
                              _customerPhone = val;
                            },
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number',
                              hintText: '9876543210',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10))),
                        ]),
                    ]))),
              const SizedBox(height: 20),

              // Conditional widgets based on payment mode
              if (_selectedPaymentMode == 'UPI') ...[
                // UPI QR Code Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10),
                    ]),
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
              ] else if (_selectedPaymentMode == 'Cash') ...[
                // Cash Payment Simulator
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    children: [
                      Icon(
                        Icons.payments,
                        size: 48,
                        color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'Cash Payment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        'Collect ₹${cart.total.toStringAsFixed(2)} in cash from the customer.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13),
                        textAlign: TextAlign.center),
                    ])),
              ] else if (_selectedPaymentMode == 'Card') ...[
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
                        color: theme.colorScheme.primary),
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

              const SizedBox(height: 16),
              // Printer Status info
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    printerState.connectedDevice != null
                        ? Icons.print
                        : Icons.print_disabled,
                    color: printerState.connectedDevice != null
                        ? Colors.green
                        : Colors.grey,
                    size: 18),
                  const SizedBox(width: 8),
                  Text(
                    printerState.connectedDevice != null
                        ? 'Printer: ${printerState.connectedDevice!.name}'
                        : 'No printer paired (Mock printing)',
                    style: TextStyle(
                      color: printerState.connectedDevice != null
                          ? Colors.green
                          : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
                ]),

              const SizedBox(height: 20),

              // Action buttons row
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(fontWeight: FontWeight.bold)))),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _sharePdfReceipt,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.share),
                        label: const Text(
                          'SHARE',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                    ]),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                          onPressed: _isProcessing
                              ? null
                              : () async {
                                  if (context.mounted) {
                                    setState(() => _isProcessing = true);
                                    await _processCheckout(
                                      context,
                                      ref,
                                      cart,
                                      settings,
                                      printerState,
                                      'PAID');
                                    if (mounted) {
                                      setState(() => _isProcessing = false);
                                    }
                                  }
                                },
                          icon: _isProcessing
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                              : const Icon(Icons.check_circle, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'CONFIRM PAID',
                              style: TextStyle(fontWeight: FontWeight.bold))))),
                    ]),
                ]),
            ]))));
  }

  void _showSelectCustomerDialog(
    BuildContext context,
    List<Customer> customers) {
    showDialog(
      context: context,
      builder: (context) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final matches = customers.where((c) {
              final q = filter.trim().toLowerCase();
              return c.name.toLowerCase().contains(q) || c.phone.contains(q);
            }).toList();

            return AlertDialog(
              title: const Text(
                'Select Customer',
                style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search customer name or phone...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder()),
                      onChanged: (val) {
                        setDialogState(() {
                          filter = val;
                        });
                      }),
                    const SizedBox(height: 12),
                    Flexible(
                      child: matches.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No customers found'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: matches.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(),
                              itemBuilder: (context, index) {
                                final c = matches[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                                  subtitle: Text(c.phone),
                                  onTap: () {
                                    setState(() {
                                      _nameCtrl.text = c.name;
                                      _phoneCtrl.text = c.phone;
                                      _customerName = c.name;
                                      _customerPhone = c.phone;
                                    });
                                    Navigator.pop(context);
                                  });
                              })),
                  ])),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ]);
          });
      });
  }

  Future<void> _processCheckout(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
    SettingsState settings,
    PrinterState printerState,
    String paymentStatus) async {
    final navigatorContext = Navigator.of(context).context;
    
    // Resolve all providers upfront before unmounting
    final printer = ref.read(printerProvider.notifier);
    final orderNotifier = ref.read(orderProvider.notifier);
    final inventoryNotifier = ref.read(inventoryProvider.notifier);
    final cartNotifier = ref.read(cartProvider.notifier);
    final customersNotifier = ref.read(customersProvider.notifier);
    final customersList = ref.read(customersProvider);
    final session = ref.read(authProvider);

    // Capture properties before cart is cleared
    final finalCart = cart;
    final finalShopName = settings.shopName;
    final targetPhone = _customerPhone.trim();
    final targetName = _customerName.trim();
    final newOrderId = orderNotifier.generateNextOrderId();
    final staffName = session?.name ?? 'Admin';

    // 1. Save Order to History & Deduct Stock FIRST before clearing cart or popping UI!
    try {
      await orderNotifier.saveOrder(
        items: finalCart.items,
        total: finalCart.total,
        subtotal: finalCart.subtotal,
        tax: finalCart.taxAmount,
        discount: finalCart.discountAmount,
        paymentMode: _selectedPaymentMode,
        paymentStatus: paymentStatus,
        customerName: targetName,
        customerPhone: targetPhone,
        staffName: staffName,
        orderType: finalCart.orderType ?? '',
        dineTableNo: finalCart.dineTableNo,
        id: newOrderId);

      // Deduct Stock from Inventory
      final settingsBox = Hive.box<String>('settings');
      final showStock = (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
      if (showStock) {
        final currentProducts = ref.read(inventoryProvider);
        for (var item in finalCart.items) {
          try {
            final liveProduct = currentProducts.firstWhere((p) => p.id == item.product.id);
            if (liveProduct.trackInventory) {
              final deductedUnits = item.quantity.round();
              final unitsToDeduct = deductedUnits < 1 ? 1 : deductedUnits;
              final newStock = (liveProduct.stockCount - unitsToDeduct).clamp(0, 999999);
              final updatedProduct = liveProduct.copyWith(stockCount: newStock);
              inventoryNotifier.updateProduct(updatedProduct);
            }
          } catch (_) {}
        }
      }

      // Update or Create Customer (Only add to totalSpent if paymentStatus is PAID!)
      if (targetPhone.isNotEmpty) {
        final targetPhoneClean = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');
        final existingIndex = customersList.indexWhere((c) {
          final cPhoneClean = c.phone.replaceAll(RegExp(r'[^0-9]'), '');
          return cPhoneClean == targetPhoneClean;
        });

        final spendToAdd = paymentStatus == 'PAID' ? finalCart.total : 0.0;

        if (existingIndex != -1) {
          final existingCust = customersList[existingIndex];
          customersNotifier.updateCustomer(
            Customer(
              id: existingCust.id,
              name: targetName.isNotEmpty ? targetName : existingCust.name,
              phone: existingCust.phone,
              email: existingCust.email,
              totalOrders: existingCust.totalOrders + 1,
              totalSpent: existingCust.totalSpent + spendToAdd));
        } else if (targetName.isNotEmpty) {
          customersNotifier.addCustomer(
            Customer(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: targetName,
              phone: targetPhone,
              email: '',
              totalOrders: 1,
              totalSpent: spendToAdd));
        }
      }

      // 2. Show confirmation popup & Clear Cart ONLY after order is saved successfully!
      if (context.mounted) {
        final nav = Navigator.of(context);
        nav.pop();
        UiUtils.showSquarePopup(
          navigatorContext,
          'Order Confirmed! 🎉',
          isError: false);
      }

      cartNotifier.clearCart();
    } catch (saveErr) {
      debugPrint('Order save failed: $saveErr');
      if (context.mounted) {
        NotificationHelper.showCenter(
          context,
          'Order save failed: ${saveErr.toString().replaceAll('Exception:', '').trim()}',
          isError: true);
      }
      return;
    }

    // 3. Printing & Background tasks
    Future.microtask(() async {

        List<int>? kitchenBytes;
        List<int>? receiptBytes;

        int? parcelToken;
        if (settings.enableKotReceipt && finalCart.orderType?.toLowerCase() == 'parcel') {
          parcelToken = await FirebaseSyncService.instance.getNextParcelToken();

          if (!settings.enableMultiplePrinters) {
            kitchenBytes = await PrinterService.generateKitchenReceiptBytes(
              items: finalCart.items,
              orderId: newOrderId,
              orderType: finalCart.orderType ?? 'DINE',
              printAsImage: settings.printAsImage,
              is80mmPaper: settings.is80mmPaper,
              parcelToken: parcelToken,
              shopName: finalShopName,
              addressLine1: settings.addressLine1,
              addressLine2: settings.addressLine2,
              hotelType: settings.hotelType,
              mobileNumber: settings.mobileNumber,
              fssaiNumber: settings.fssaiNumber,
              gstNumber: settings.gstNumber,
              enableAddressOnReceipt: settings.enableAddressOnReceipt,
              enableMobileOnReceipt: settings.enableMobileOnReceipt,
              enableFssaiOnReceipt: settings.enableFssaiOnReceipt,
              enableHotelTypeOnReceipt: settings.enableHotelTypeOnReceipt,
              enableShopDetailsOnKot: settings.enableShopDetailsOnKot,
              showGstOnReceipt: settings.showGstOnReceipt);
          }
        }

        receiptBytes = await PrinterService.generateReceiptBytes(
          items: finalCart.items,
          subtotal: finalCart.subtotal,
          tax: finalCart.taxAmount,
          discount: finalCart.discountAmount,
          total: finalCart.total,
          shopName: finalShopName,
          receiptHeader: settings.receiptHeader,
          receiptFooter: settings.receiptFooter,
          showGstOnReceipt: settings.showGstOnReceipt,
          gstNumber: settings.gstNumber,
          isUnpaid: paymentStatus == 'UNPAID',
          orderId: newOrderId,
          tableNo: finalCart.dineTableNo,
          orderType: finalCart.orderType,
          customerName: finalCart.customerName,
          customerPhone: finalCart.customerPhone,
          printAsImage: settings.printAsImage,
          is80mmPaper: settings.is80mmPaper,
          parcelToken: parcelToken,
          addressLine1: settings.addressLine1,
          addressLine2: settings.addressLine2,
          hotelType: settings.hotelType,
          mobileNumber: settings.mobileNumber,
          fssaiNumber: settings.fssaiNumber,
          enableAddressOnReceipt: settings.enableAddressOnReceipt,
          enableMobileOnReceipt: settings.enableMobileOnReceipt,
          enableFssaiOnReceipt: settings.enableFssaiOnReceipt,
          enableHotelTypeOnReceipt: settings.enableHotelTypeOnReceipt,
          showPoweredByDiyan: settings.showPoweredByDiyan);

        // 1. Print to Main Printer First (No Delay for Cashier)
        try {
          if (kitchenBytes != null) {
            await printer.printReceipt(kitchenBytes);
            await Future.delayed(const Duration(milliseconds: 500));
          }
          if (receiptBytes != null) {
            await printer.printReceipt(receiptBytes);
          }
        } catch (printErr) {
          debugPrint('Main Receipt printing failed: $printErr');
          final errorMsg = printErr.toString().replaceAll('Exception:', '').trim();
          UiUtils.showToast('Main Printer failed: $errorMsg', isError: true);
        }

        // 2. Fire and Forget Secondary Printers (Background)
        // This runs even if the main printer fails!
        if (settings.enableKotReceipt && settings.enableMultiplePrinters) {
          PrintRouterService.routeKOTs(
            items: finalCart.items,
            orderId: newOrderId,
            orderType: finalCart.orderType ?? 'DINE',
            settings: settings,
            parcelToken: parcelToken,
            shopName: finalShopName).catchError((e) {
            debugPrint('Background KOT routing failed: $e');
            UiUtils.showToast('KOT Printer failed: ${e.toString().replaceAll('Exception:', '').trim()}', isError: true);
          });
        }
      } catch (e) {
        debugPrint('Receipt printing failed: $e');
        final errorMsg = e.toString().replaceAll('Exception:', '').trim();
        UiUtils.showToast('Printing failed: $errorMsg', isError: true);
        if (navigatorContext.mounted) {
          NotificationHelper.showCenter(
            navigatorContext,
            'Printing failed: $errorMsg',
            isError: true);
        }
      }
    });


  }
}

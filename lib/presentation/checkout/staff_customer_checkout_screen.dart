import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/order.dart';
import '../../providers/settings_provider.dart';
import '../../providers/printer_provider.dart';
import '../../core/hardware/printer_service.dart';
import '../../core/utils/ui_utils.dart';
import '../customers/customers_screen.dart';
import 'dart:async';
import '../settings/printer_settings_screen.dart';
import '../../providers/language_provider.dart';
import '../../core/extensions/string_extensions.dart';
import '../../services/firebase_sync_service.dart';

class StaffCustomerCheckoutScreen extends ConsumerStatefulWidget {
  const StaffCustomerCheckoutScreen({super.key});

  @override
  ConsumerState<StaffCustomerCheckoutScreen> createState() =>
      _StaffCustomerCheckoutScreenState();
}

class _StaffCustomerCheckoutScreenState
    extends ConsumerState<StaffCustomerCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedPaymentMode = 'Cash';
  final _splitCashCtrl = TextEditingController();
  final _splitUpiCtrl = TextEditingController();
  bool _splitValid = false;
  bool _isProcessing = false;
  Timer? _printerCheckTimer;

  @override
  void initState() {
    super.initState();
    _printerCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.read(printerProvider.notifier).checkConnection();
    });
  }

  @override
  void dispose() {
    _printerCheckTimer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _splitCashCtrl.dispose();
    _splitUpiCtrl.dispose();
    super.dispose();
  }

  void _validateSplit(double total) {
    final cash = double.tryParse(_splitCashCtrl.text) ?? 0.0;
    final upi = double.tryParse(_splitUpiCtrl.text) ?? 0.0;
    setState(() {
      _splitValid = (cash + upi).toStringAsFixed(2) == total.toStringAsFixed(2);
    });
  }

  Future<void> _confirmOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final navigatorContext = Navigator.of(context).context;

    // Pre-checkout Printer Check
    final printerState = ref.read(printerProvider);
    if (printerState.connectedDevice == null) {
      final shouldGoToSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.print_disabled, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Printer Not Connected'),
            ],
          ),
          content: const Text(
            'Do you want to connect a printer before confirming the order?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Continue Without Printer',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Go to Printer Setup'),
            ),
          ],
        ),
      );

      if (shouldGoToSettings == true) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
          );
        }
        return; // Stop checkout process so they can resume when they come back
      }
    }

    setState(() => _isProcessing = true);

    try {
      // Resolve all providers upfront before unmounting
      final session = ref.read(authProvider);
      final orderNotifier = ref.read(orderProvider.notifier);
      final settings = ref.read(settingsProvider);
      final cartNotifier = ref.read(cartProvider.notifier);
      final printer = ref.read(printerProvider.notifier);

      final newOrderId = orderNotifier.generateNextOrderId();
      final finalCart = cart;
      final targetName = _nameCtrl.text.trim();
      final targetPhone = _phoneCtrl.text.trim();

      // 1. Show popup and close UI first while context is mounted
      if (mounted) {
        Navigator.pop(context);
        UiUtils.showSquarePopup(
          navigatorContext,
          'Order placed successfully!',
          isError: false,
        );
      }

      // 2. Clear cart
      cartNotifier.clearCart();

      // 3. Do heavy tasks in background!
      Future.microtask(() async {
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          // Save to database
          await orderNotifier.saveOrder(
            items: finalCart.items,
            total: finalCart.total,
            subtotal: finalCart.subtotal,
            tax: finalCart.taxAmount,
            discount: finalCart.discountAmount,
            paymentMode: _selectedPaymentMode == 'Split'
                ? 'Split|${_splitCashCtrl.text}|${_splitUpiCtrl.text}'
                : _selectedPaymentMode,
            paymentStatus: 'PAID',
            customerName: targetName,
            customerPhone: targetPhone,
            staffName: session?.name ?? 'Staff',
            orderType: finalCart.orderType ?? '',
            dineTableNo: finalCart.dineTableNo,
            id: newOrderId,
          );

          // Deduct Stock from Inventory
          final settingsBox = Hive.box<String>('settings');
          final showStock =
              (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
          if (showStock) {
            final inventoryNotifier = ref.read(inventoryProvider.notifier);
            for (var item in finalCart.items) {
              if (item.product.trackInventory) {
                final newStock = item.product.stockCount - item.quantity.ceil();
                final updatedProduct = item.product.copyWith(
                  stockCount: newStock < 0 ? 0 : newStock,
                );
                inventoryNotifier.updateProduct(updatedProduct);
              }
            }
          }

          List<int>? kitchenBytes;
          List<int>? receiptBytes;
          final futures = <Future>[];

          int? parcelToken;
          if (finalCart.orderType?.toLowerCase() == 'parcel') {
            parcelToken = await FirebaseSyncService.instance
                .getNextParcelToken();

            futures.add(
              PrinterService.generateKitchenReceiptBytes(
                items: finalCart.items,
                orderId: newOrderId.replaceFirst(RegExp(r'^\d{6}-'), ''),
                orderType: finalCart.orderType ?? 'DINE',
                printAsImage: settings.printAsImage,
                is80mmPaper: settings.is80mmPaper,
                parcelToken: parcelToken,
                shopName: settings.shopName,
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
                showGstOnReceipt: settings.showGstOnReceipt,
              ).then((v) => kitchenBytes = v),
            );
          }

          futures.add(
            PrinterService.generateReceiptBytes(
              items: finalCart.items,
              subtotal: finalCart.subtotal,
              tax: finalCart.taxAmount,
              discount: finalCart.discountAmount,
              total: finalCart.total,
              shopName: settings.shopName,
              receiptHeader: settings.receiptHeader,
              receiptFooter: settings.receiptFooter,
              showGstOnReceipt: settings.showGstOnReceipt,
              gstNumber: settings.gstNumber,
              isUnpaid: false,
              orderId: newOrderId.replaceFirst(RegExp(r'^\d{6}-'), ''),
              tableNo: finalCart.dineTableNo,
              orderType: finalCart.orderType,
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
              showPoweredByDiyan: settings.showPoweredByDiyan,
            ).then((v) => receiptBytes = v),
          );

          await Future.wait(futures);

          if (kitchenBytes != null) {
            await printer.printReceipt(kitchenBytes!);
            await Future.delayed(const Duration(milliseconds: 500));
          }
          if (receiptBytes != null) {
            await printer.printReceipt(receiptBytes!);
          }
        } catch (e) {
          debugPrint('Receipt printing failed: $e');
          final errorMsg = e.toString().replaceAll('Exception:', '').trim();
          UiUtils.showToast('Printing failed: $errorMsg', isError: true);
          if (navigatorContext.mounted) {
            NotificationHelper.showCenter(
              navigatorContext,
              'Printing failed: $errorMsg',
              isError: true,
            );
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        UiUtils.showToast('Error processing order: $e', isError: true);
        if (navigatorContext.mounted) {
          NotificationHelper.showCenter(
            navigatorContext,
            'Error processing order: $e',
            isError: true,
          );
        }
      }
    }
  }

  void _showSelectCustomerDialog(
    BuildContext context,
    List<Customer> customers,
  ) {
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
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          filter = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: matches.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No customers found'),
                            )
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
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(c.phone),
                                  onTap: () {
                                    setState(() {
                                      _nameCtrl.text = c.name;
                                      _phoneCtrl.text = c.phone;
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final customers = ref.watch(customersProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Customer Directory'.tr(ref.watch(languageProvider)),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: theme.colorScheme.primary.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'Total'.tr(ref.watch(languageProvider)),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${cart.total.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (true)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              _showSelectCustomerDialog(context, customers),
                          icon: const Icon(Icons.people, size: 18),
                          label: Text(
                            'Customer Directory'.tr(
                              ref.watch(languageProvider),
                            ),
                          ),
                        ),
                      ),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Customer Name (Optional)'.tr(
                          ref.watch(languageProvider),
                        ),
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number (Optional)'.tr(
                          ref.watch(languageProvider),
                        ),
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (settings.enablePaymentModeSelection) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children:
                        (settings.enableSplitPayment
                                ? ['Cash', 'UPI', 'Split']
                                : ['Cash', 'UPI'])
                            .map((mode) {
                              final isSelected = _selectedPaymentMode == mode;
                              final isSplitMode =
                                  _selectedPaymentMode == 'Split';

                              if (isSplitMode &&
                                  (mode == 'Cash' || mode == 'UPI')) {
                                return Expanded(
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: mode == 'Cash'
                                          ? _splitCashCtrl
                                          : _splitUpiCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: mode,
                                        prefixText: '₹',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                      ),
                                      onChanged: (_) =>
                                          _validateSplit(cart.total),
                                    ),
                                  ),
                                );
                              }

                              return Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (mode == 'Split' &&
                                          _selectedPaymentMode == 'Split') {
                                        _selectedPaymentMode = 'Cash';
                                      } else {
                                        _selectedPaymentMode = mode;
                                        if (mode == 'Split') {
                                          _validateSplit(cart.total);
                                        }
                                      }
                                    });
                                  },
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.horizontal(
                                        left: mode == 'Cash'
                                            ? const Radius.circular(11)
                                            : Radius.zero,
                                        right: mode == 'Split'
                                            ? const Radius.circular(11)
                                            : Radius.zero,
                                      ),
                                      border: mode != 'Split'
                                          ? Border(
                                              right: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                            )
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      mode,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(),
                  ),
                ),
                if (_selectedPaymentMode == 'Split' && !_splitValid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Split amounts must total ₹${cart.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
              _buildPrinterStatus(ref),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(
                        'Clear'.tr(ref.watch(languageProvider)),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          (_isProcessing ||
                              (_selectedPaymentMode == 'Split' && !_splitValid))
                          ? null
                          : _confirmOrder,
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Confirm Order'.tr(ref.watch(languageProvider)),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrinterStatus(WidgetRef ref) {
    final printerState = ref.watch(printerProvider);
    final isConnected = printerState.connectedDevice != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.print : Icons.print_disabled,
            size: 16,
            color: isConnected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'Printer: Connected' : 'Printer: Disconnected / Mock',
            style: TextStyle(
              fontSize: 12,
              color: isConnected ? Colors.green : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

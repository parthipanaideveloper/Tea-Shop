import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../domain/models/order.dart';
import '../domain/models/cart_item.dart';
import '../domain/models/product.dart';
import 'hive_provider.dart';
import 'refund_provider.dart';
import 'inventory_provider.dart';
import '../services/firebase_sync_service.dart';

class OrderNotifier extends Notifier<List<OrderModel>> {
  @override
  List<OrderModel> build() {
    final box = ref.watch(orderBoxProvider);
    // Listen to Hive changes for two-way sync
    box.watch().listen((_) {
      final orders = box.values.toList();
      orders.sort((a, b) => b.date.compareTo(a.date));
      state = orders;
    });

    final orders = box.values.toList();
    orders.sort((a, b) => b.date.compareTo(a.date));
    return orders;
  }

  int _parseSequenceNumber(String id) {
    try {
      final String rawSequence = id.contains('-') ? id.split('-').last : id;
      final regex = RegExp(r'^([A-Z]{3})(\d{3})$');
      final match = regex.firstMatch(rawSequence);
      if (match != null) {
        final prefix = match.group(1)!;
        final numStr = match.group(2)!;

        final c1 = prefix.codeUnitAt(0) - 65;
        final c2 = prefix.codeUnitAt(1) - 65;
        final c3 = prefix.codeUnitAt(2) - 65;
        final prefixIndex = c1 * 26 * 26 + c2 * 26 + c3;

        final num = int.tryParse(numStr) ?? 0;
        return prefixIndex * 999 + num;
      }
    } catch (_) {}
    return 0;
  }

  String generateNextOrderId() {
    final settingsBox = Hive.box<String>('settings');
    final orderBox = ref.read(orderBoxProvider);

    try {
      String devicePrefix = settingsBox.get('devicePrefix') ?? '';
      if (devicePrefix.isEmpty || devicePrefix == 'XX') {
        final randNum = (DateTime.now().millisecondsSinceEpoch % 899 + 100).toString();
        devicePrefix = 'D$randNum';
        settingsBox.put('devicePrefix', devicePrefix);
      }
      bool dailyReset = settingsBox.get('dailyResetOrderId') == 'true';
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      // Start with settings-stored lastId only if NOT daily reset or if lastId is from TODAY
      int maxN = 0;
      if (!dailyReset) {
        final lastId = settingsBox.get('lastOrderId') ?? 'AAA000';
        maxN = _parseSequenceNumber(lastId);
      } else {
        final lastDateStr = settingsBox.get('lastOrderIdDate') ?? '';
        if (lastDateStr == todayStr) {
          final lastId = settingsBox.get('lastOrderId');
          if (lastId != null) {
            maxN = _parseSequenceNumber(lastId);
          }
        }
      }

      // Calculate the global prefix for today
      String prefixCheck = '';
      if (dailyReset) prefixCheck += DateFormat('yyMMdd').format(now) + '-';
      if (devicePrefix.isNotEmpty) prefixCheck += '$devicePrefix-';

      // Systemic check: Scan all orders to find absolute highest number.
      for (final order in orderBox.values) {
        if (dailyReset) {
          final localDate = order.date.toLocal();
          if (localDate.year != now.year ||
              localDate.month != now.month ||
              localDate.day != now.day) {
            continue; // Skip past orders if daily reset is enabled
          }
        }

        // Match device prefix if present
        if (prefixCheck.isNotEmpty && !order.id.startsWith(prefixCheck)) {
          continue;
        }

        final orderN = _parseSequenceNumber(order.id);
        if (orderN > maxN) {
          maxN = orderN;
        }
      }

      final nextN = maxN + 1;
      final num = ((nextN - 1) % 999) + 1;
      final prefixIndex = (nextN - 1) ~/ 999;

      final c3 = prefixIndex % 26;
      final c2 = (prefixIndex ~/ 26) % 26;
      final c1 = (prefixIndex ~/ (26 * 26)) % 26;

      final prefixStr =
          String.fromCharCode(65 + c1) +
          String.fromCharCode(65 + c2) +
          String.fromCharCode(65 + c3);
      final numStr = num.toString().padLeft(3, '0');

      return '$prefixCheck$prefixStr$numStr';
    } catch (e) {
      final devicePrefix = settingsBox.get('devicePrefix') ?? 'XX';
      final fallbackSuffix = DateTime.now().millisecondsSinceEpoch.toString();
      final safeSuffix = fallbackSuffix.substring(fallbackSuffix.length - 6);
      return '$devicePrefix-ERR$safeSuffix';
    }
  }

  Future<void> saveOrder({
    required List<CartItem> items,
    required double total,
    required double subtotal,
    required double tax,
    required double discount,
    String paymentMode = 'UPI',
    String paymentStatus = 'PAID',
    String customerName = '',
    String customerPhone = '',
    String staffName = '',
    String orderType = '',
    String dineTableNo = '',
    String? id,
    bool isEdited = false,
    String editReason = '',
    List<CartItem>? originalItemsForRestock,
    DateTime? originalDate, // Preserve original order date when editing
  }) async {
    final box = ref.read(orderBoxProvider);
    String orderId = id ?? generateNextOrderId();
    if (!isEdited && box.containsKey(orderId)) {
      final safeSuffix = DateTime.now().microsecondsSinceEpoch.toString();
      orderId = '$orderId-${safeSuffix.substring(safeSuffix.length - 4)}';
    }
    String itemsJson = OrderModel.serializeItems(
      items,
      paymentMode: paymentMode,
      paymentStatus: paymentStatus,
      customerName: customerName,
      customerPhone: customerPhone,
      staffName: staffName,
      orderType: orderType,
      dineTableNo: dineTableNo,
    );

    if (isEdited) {
      try {
        final decoded = jsonDecode(itemsJson) as Map<String, dynamic>;
        decoded['isEdited'] = true;
        decoded['editedAt'] = DateTime.now().toIso8601String();
        if (editReason.isNotEmpty) {
          decoded['editReason'] = editReason;
        }
        itemsJson = jsonEncode(decoded);
      } catch (_) {}
    }

    final newOrder = OrderModel(
      id: orderId,
      total: total,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      // Use original date when editing so the order stays on its original day.
      // For new orders, always use DateTime.now().
      date: (isEdited && originalDate != null) ? originalDate : DateTime.now(),
      itemsJson: itemsJson,
    );

    await box.put(orderId, newOrder);

    // Only update global counter and sync settings if this is a NEW order, not an edit.
    if (!isEdited) {
      final settingsBox = Hive.box<String>('settings');
      settingsBox.put('lastOrderId', orderId);
      settingsBox.put(
        'lastOrderIdDate',
        DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );
      FirebaseSyncService().pushSettingsSync();
    }

    FirebaseSyncService().pushOrder(newOrder);

    // Handle Inventory Restocking/Deduction for Edited Items
    if (originalItemsForRestock != null) {
      final settingsBox = Hive.box<String>('settings');
      final showStock =
          (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
      if (showStock) {
        final inventoryNotifier = ref.read(inventoryProvider.notifier);

        // Sum old quantities
        Map<String, double> oldQty = {};
        for (var i in originalItemsForRestock) {
          oldQty[i.product.id] = (oldQty[i.product.id] ?? 0) + i.quantity;
        }

        // Sum new quantities
        Map<String, double> newQty = {};
        for (var i in items) {
          newQty[i.product.id] = (newQty[i.product.id] ?? 0) + i.quantity;
        }

        // Apply diffs to stock
        final products = ref.read(inventoryProvider);
        for (var p in products) {
          final oldQ = oldQty[p.id] ?? 0;
          final newQ = newQty[p.id] ?? 0;
          final diff = newQ - oldQ;
          if (diff != 0) {
            final diffInt = diff > 0 ? diff.ceil() : diff.floor();
            inventoryNotifier.updateStock(p.id, p.stockCount - diffInt);
          }
        }
      }
    }
  }

  Future<void> voidOrder(String orderId, String reason) async {
    final box = ref.read(orderBoxProvider);
    final order = box.values.firstWhere((o) => o.id == orderId);

    // Create new itemsJson with voided flag
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(order.itemsJson) as Map<String, dynamic>;
    } catch (_) {
      decoded = {};
    }

    decoded['isVoided'] = true;
    decoded['voidReason'] = reason;
    final newItemsJson = jsonEncode(decoded);

    // Create new OrderModel
    final updatedOrder = OrderModel(
      id: order.id,
      total: order.total,
      subtotal: order.subtotal,
      tax: order.tax,
      discount: order.discount,
      date: order.date,
      itemsJson: newItemsJson,
    );

    // Overwrite in box
    await box.put(orderId, updatedOrder);

    // Update Firebase Sync
    FirebaseSyncService().pushOrder(updatedOrder);
    FirebaseSyncService().pushSettingsSync();

    // Restock inventory only if global tracking is enabled
    final settingsBox = Hive.box<String>('settings');
    final showStock =
        (settingsBox.get('showStockQuantity') ?? 'true') == 'true';

    if (showStock) {
      final inventoryNotifier = ref.read(inventoryProvider.notifier);
      for (var item in order.parsedItems) {
        // Find existing product first to get current stock count
        final products = ref.read(inventoryProvider);
        try {
          final p = products.firstWhere((p) => p.id == item.product.id);
          inventoryNotifier.updateStock(
            item.product.id,
            p.stockCount + item.quantity.round(),
          );
        } catch (_) {
          try {
            final pBox = Hive.box<Product>('products');
            final restoredProd = item.product.copyWith(
              stockCount: item.quantity.round(),
              isActive: true,
            );
            pBox.put(item.product.id, restoredProd);
            FirebaseSyncService().pushProduct(restoredProd);
          } catch (_) {}
        }
      }
    }
  }

  Future<void> deleteOrder(String id, {bool isRefund = false}) async {
    final box = ref.read(orderBoxProvider);
    // Soft-delete: keep record in Hive but mark as deleted so it can be
    // filtered from normal views while still appearing in Auditing Logs.
    try {
      final order = box.values.firstWhere((o) => o.id == id);

      // Restock inventory if this order was not already voided or deleted
      if (!order.isVoided && !order.isDeleted) {
        final settingsBox = Hive.box<String>('settings');
        final showStock =
            (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
        if (showStock) {
          final inventoryNotifier = ref.read(inventoryProvider.notifier);
          final products = ref.read(inventoryProvider);
          for (var item in order.parsedItems) {
            try {
              final p = products.firstWhere((prod) => prod.id == item.product.id);
              inventoryNotifier.updateStock(
                item.product.id,
                p.stockCount + item.quantity.round(),
              );
            } catch (_) {
              try {
                final pBox = Hive.box<Product>('products');
                final restoredProd = item.product.copyWith(
                  stockCount: item.quantity.round(),
                  isActive: true,
                );
                pBox.put(item.product.id, restoredProd);
                FirebaseSyncService().pushProduct(restoredProd);
              } catch (_) {}
            }
          }
        }
      }

      Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(order.itemsJson) as Map<String, dynamic>;
      } catch (_) {
        decoded = {};
      }
      decoded['isDeleted'] = true;
      if (isRefund) {
        decoded['isRefunded'] = true;
      }
      final newItemsJson = jsonEncode(decoded);
      final updatedOrder = OrderModel(
        id: order.id,
        total: order.total,
        subtotal: order.subtotal,
        tax: order.tax,
        discount: order.discount,
        date: order.date,
        itemsJson: newItemsJson,
      );
      await box.put(id, updatedOrder);
      FirebaseSyncService().pushOrder(updatedOrder);
      FirebaseSyncService().pushSettingsSync();
    } catch (_) {
      // Order not found — attempt a hard delete as fallback
      await box.delete(id);
    }
  }

  Future<void> updateOrder(OrderModel updatedOrder) async {
    final box = ref.read(orderBoxProvider);
    await box.put(updatedOrder.id, updatedOrder);
    FirebaseSyncService().pushOrder(updatedOrder);
  }

  Future<void> clearAllOrders() async {
    final box = ref.read(orderBoxProvider);
    await box.clear();

    // Reset global counter
    final settingsBox = Hive.box<String>('settings');
    settingsBox.put('lastOrderId', 'AAA000');
    // Firebase cleanup is handled by clearAllHistory() called separately from settings_screen

    state = [];
  }
}

final orderProvider = NotifierProvider<OrderNotifier, List<OrderModel>>(() {
  return OrderNotifier();
});

// Analytics Providers
class AnalyticsData {
  final double todayRevenue;
  final int todayOrders;
  final double averageOrderValue;
  final double upiRevenue;
  final double cashRevenue;
  final double cardRevenue;

  AnalyticsData({
    required this.todayRevenue,
    required this.todayOrders,
    required this.averageOrderValue,
    required this.upiRevenue,
    required this.cashRevenue,
    required this.cardRevenue,
  });
}

final dailyAnalyticsProvider = Provider<AnalyticsData>((ref) {
  final orders = ref.watch(orderProvider);

  final now = DateTime.now();
  final todayOrders = orders
      .where(
        (o) =>
            !o.isDeleted &&
            o.date.toLocal().year == now.year &&
            o.date.toLocal().month == now.month &&
            o.date.toLocal().day == now.day,
      )
      .toList();

  final paidOrders = todayOrders
      .where((o) => o.paymentStatus == 'PAID' && !o.isVoided)
      .toList();

  final todayRevenue = paidOrders.fold(0.0, (sum, o) => sum + o.total);
  double upiRevenue = 0.0;
  double cashRevenue = 0.0;
  double cardRevenue = 0.0;

  for (var o in paidOrders) {
    final modeUpper = o.paymentMode.trim().toUpperCase();
    if (modeUpper == 'UPI') {
      upiRevenue += o.total;
    } else if (modeUpper == 'CASH') {
      cashRevenue += o.total;
    } else if (modeUpper == 'CARD') {
      cardRevenue += o.total;
    } else if (modeUpper.startsWith('SPLIT|')) {
      final parts = o.paymentMode.split('|');
      if (parts.length >= 3) {
        cashRevenue += double.tryParse(parts[1]) ?? 0.0;
        upiRevenue += double.tryParse(parts[2]) ?? 0.0;
      }
    }
  }

  final count = todayOrders.length;

  // Subtract refunds from today's revenue tallies
  final refunds = ref.watch(refundProvider);
  final todayRefunds = refunds
      .where(
        (r) =>
            r.date.toLocal().year == now.year &&
            r.date.toLocal().month == now.month &&
            r.date.toLocal().day == now.day,
      )
      .toList();

  final totalRefundAmount = todayRefunds.fold(
    0.0,
    (sum, r) => sum + r.amountRefunded,
  );

  final adjustedRevenue =
      (todayRevenue - totalRefundAmount).clamp(0.0, double.infinity);

  // Average is based on net revenue and total paid orders
  final paidCount = paidOrders.length;
  final average = paidCount > 0 ? adjustedRevenue / paidCount : 0.0;

  double adjustedUpi = upiRevenue;
  double adjustedCash = cashRevenue;
  double adjustedCard = cardRevenue;

  for (var r in todayRefunds) {
    final origOrder = orders
        .where((o) => o.id == r.originalOrderId)
        .firstOrNull;
    if (origOrder != null) {
      final isOrigOrderToday =
          origOrder.date.toLocal().year == now.year &&
          origOrder.date.toLocal().month == now.month &&
          origOrder.date.toLocal().day == now.day;
      if (isOrigOrderToday) {
        final refundModeUpper = origOrder.paymentMode.trim().toUpperCase();
        if (refundModeUpper == 'UPI')
          adjustedUpi =
              (adjustedUpi - r.amountRefunded).clamp(0.0, double.infinity);
        else if (refundModeUpper == 'CASH')
          adjustedCash =
              (adjustedCash - r.amountRefunded).clamp(0.0, double.infinity);
        else if (refundModeUpper == 'CARD')
          adjustedCard =
              (adjustedCard - r.amountRefunded).clamp(0.0, double.infinity);
        else if (refundModeUpper.startsWith('SPLIT|')) {
          if (adjustedCash >= r.amountRefunded) {
            adjustedCash =
                (adjustedCash - r.amountRefunded).clamp(0.0, double.infinity);
          } else {
            final remainder = r.amountRefunded - adjustedCash;
            adjustedCash = 0;
            adjustedUpi =
                (adjustedUpi - remainder).clamp(0.0, double.infinity);
          }
        }
      }
    }
  }

  return AnalyticsData(
    todayRevenue: adjustedRevenue,
    todayOrders: count,
    averageOrderValue: average,
    upiRevenue: adjustedUpi,
    cashRevenue: adjustedCash,
    cardRevenue: adjustedCard,
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/refund_model.dart';
import '../services/firebase_sync_service.dart';
import 'package:uuid/uuid.dart';
import 'order_provider.dart';

class RefundNotifier extends Notifier<List<RefundModel>> {
  @override
  List<RefundModel> build() {
    final box = Hive.box<RefundModel>('refunds');
    box.watch().listen((_) {
      state = box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    });
    return box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<String?> addRefund({
    required String originalOrderId,
    required double amountRefunded,
    required String staffName,
    String reason = 'Returned Items',
  }) async {
    if (amountRefunded <= 0) {
      return 'Refund amount must be greater than 0';
    }

    final orders = ref.read(orderProvider);
    final origOrder = orders.where((o) => o.id == originalOrderId).firstOrNull;

    if (origOrder == null) {
      return 'Original order not found';
    }

    if (origOrder.isVoided) {
      return 'Cannot refund a voided order';
    }

    final existingRefundTotal = state
        .where((r) => r.originalOrderId == originalOrderId)
        .fold(0.0, (sum, r) => sum + r.amountRefunded);

    if (existingRefundTotal + amountRefunded > origOrder.total) {
      final maxAllowed = origOrder.total - existingRefundTotal;
      return 'Refund amount exceeds remaining order balance (Max allowed: ₹${maxAllowed.toStringAsFixed(2)})';
    }

    final box = Hive.box<RefundModel>('refunds');
    final newRefund = RefundModel(
      id: const Uuid().v4(),
      originalOrderId: originalOrderId,
      amountRefunded: amountRefunded,
      date: DateTime.now(),
      staffName: staffName,
      reason: reason,
    );
    await box.put(newRefund.id, newRefund);
    FirebaseSyncService.instance.pushRefund(newRefund);

    // Mark original order as refunded
    await ref.read(orderProvider.notifier).deleteOrder(originalOrderId, isRefund: true);
    return null;
  }

  Future<void> clearAllRefunds() async {
    final box = Hive.box<RefundModel>('refunds');
    final allRefunds = box.values.toList();
    await box.clear();
    for (var r in allRefunds) {
      FirebaseSyncService.instance.deleteRefund(r.id);
    }
    state = [];
  }
}

final refundProvider = NotifierProvider<RefundNotifier, List<RefundModel>>(() {
  return RefundNotifier();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/firebase_sync_service.dart';

/// Holds a version counter that increments every time product order is saved.
/// Any widget that watches this will rebuild instantly when order changes.
class ProductOrderNotifier extends Notifier<int> {
  @override
  int build() {
    final box = Hive.box<String>('product_order');
    final sub = box.watch().listen((_) {
      state = state + 1;
    });
    ref.onDispose(() => sub.cancel());
    return 0;
  }

  /// Call this after saving order to Hive to trigger instant UI refresh.
  void notifyOrderChanged() {
    state = state + 1;
  }

  /// Save a new product order to Hive and notify all listeners.
  /// Note: The order map should contain only the products for the specific
  /// category being viewed to prevent shifting unrelated products.
  void saveOrder(List<String> orderedProductIds) {
    final box = Hive.box<String>('product_order');
    for (var i = 0; i < orderedProductIds.length; i++) {
      box.put(orderedProductIds[i], '$i');
    }
    notifyOrderChanged();
    
    // We optionally push settings sync so cloud backups retain the configuration.
    // This is shop-specific since FirebaseSyncService uses the local shop code.
    FirebaseSyncService().pushSettingsSync();
  }

  /// Read current order map from Hive.
  Map<String, int> getOrderMap() {
    final box = Hive.box<String>('product_order');
    final map = <String, int>{};
    for (final key in box.keys) {
      final val = int.tryParse(box.get(key) ?? '');
      if (val != null) map[key as String] = val;
    }
    return map;
  }
}

final productOrderProvider = NotifierProvider<ProductOrderNotifier, int>(() {
  return ProductOrderNotifier();
});

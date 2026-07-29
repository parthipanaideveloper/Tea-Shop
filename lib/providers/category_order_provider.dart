import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/firebase_sync_service.dart';

/// Holds a version counter that increments every time category order is saved.
/// Any widget that watches this will rebuild instantly when order changes.
class CategoryOrderNotifier extends Notifier<int> {
  @override
  int build() {
    final box = Hive.box<String>('category_order');
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

  /// Save a new category order to Hive and notify all listeners.
  void saveOrder(List<String> orderedCategories) {
    final box = Hive.box<String>('category_order');
    for (var i = 0; i < orderedCategories.length; i++) {
      box.put(orderedCategories[i], '$i');
    }
    notifyOrderChanged();
    FirebaseSyncService().pushSettingsSync();
  }

  /// Read current order map from Hive.
  Map<String, int> getOrderMap() {
    final box = Hive.box<String>('category_order');
    final map = <String, int>{};
    for (final key in box.keys) {
      final val = int.tryParse(box.get(key) ?? '');
      if (val != null) map[key as String] = val;
    }
    return map;
  }
}

final categoryOrderProvider = NotifierProvider<CategoryOrderNotifier, int>(() {
  return CategoryOrderNotifier();
});

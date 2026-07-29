import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/product.dart';
import 'hive_provider.dart';
import '../services/firebase_sync_service.dart';

class InventoryNotifier extends Notifier<List<Product>> {
  @override
  List<Product> build() {
    final box = ref.watch(productBoxProvider);

    // MIGRATION: Fix bad translation cached in Hive
    Future.microtask(() {
      for (final p in box.values) {
        if (p.nameTamil != null && p.nameTamil!.contains('காய்கிரேவி')) {
          final fixedName = p.nameTamil!.replaceAll('காய்கிரேவி', 'காய்கறி');
          final updatedProduct = p.copyWith(nameTamil: fixedName);
          box.put(p.id, updatedProduct);
          FirebaseSyncService().pushProduct(updatedProduct);
        }
      }
    });

    // Listen to Hive changes for two-way sync
    final sub = box.watch().listen((_) {
      state = box.values.toList();
    });
    ref.onDispose(() => sub.cancel());
    return box.values.toList();
  }

  Product addProduct({
    required String name,
    String? nameTamil,
    required String category,
    String? categoryTamil,
    List<String>? additionalCategories,
    required double price,
    required int stockCount,
    String? barcode,
    bool allowHalfPortion = false,
    bool trackInventory = true,
    bool isActive = true,
    bool isDefault = false,
    bool? isVeg,
    String? productNumber,
    bool isParcelEnabled = false,
    double? parcelAmount,
  }) {
    final box = ref.read(productBoxProvider);
    final id = const Uuid().v4();

    final newProduct = Product(
      id: id,
      name: name,
      nameTamil: nameTamil,
      category: category,
      categoryTamil: categoryTamil,
      additionalCategories: additionalCategories,
      price: price,
      stockCount: stockCount,
      barcode: barcode,
      allowHalfPortion: allowHalfPortion,
      trackInventory: trackInventory,
      isActive: isActive,
      isDefault: isDefault,
      isVeg: isVeg,
      productNumber: productNumber,
      isParcelEnabled: isParcelEnabled,
      parcelAmount: parcelAmount,
    );

    box.put(id, newProduct);
    // state is updated automatically by box.watch()
    FirebaseSyncService().pushProduct(newProduct);
    return newProduct;
  }

  void updateProduct(Product product) {
    final box = ref.read(productBoxProvider);
    box.put(product.id, product);
    FirebaseSyncService().pushProduct(product);
  }

  void updateStock(String productId, int newStockCount) {
    final box = ref.read(productBoxProvider);
    final p = box.get(productId);
    if (p != null) {
      final updated = p.copyWith(stockCount: newStockCount);
      box.put(productId, updated);
      FirebaseSyncService().pushProduct(updated);
    }
  }

  void deleteProduct(String id) {
    final box = ref.read(productBoxProvider);
    box.delete(id);
    FirebaseSyncService().deleteProduct(id);
  }
}

final inventoryProvider = NotifierProvider<InventoryNotifier, List<Product>>(
  () {
    return InventoryNotifier();
  });

class InventorySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final inventorySearchQueryProvider =
    NotifierProvider<InventorySearchQueryNotifier, String>(() {
      return InventorySearchQueryNotifier();
    });

class InventoryCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setCategory(String? category) {
    state = category;
  }
}

final inventoryCategoryFilterProvider =
    NotifierProvider<InventoryCategoryFilterNotifier, String?>(() {
      return InventoryCategoryFilterNotifier();
    });

final filteredInventoryProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(inventoryProvider);
  final query = ref.watch(inventorySearchQueryProvider).toLowerCase();
  final categoryFilter = ref.watch(inventoryCategoryFilterProvider);

  var result = products;

  // 1. Strict category filter
  if (categoryFilter != null && categoryFilter.isNotEmpty) {
    result = result
        .where(
          (p) =>
              p.category == categoryFilter ||
              (p.additionalCategories != null &&
                  p.additionalCategories!.contains(categoryFilter)))
        .toList();
  }

  // 2. Text search query
  if (query.isNotEmpty) {
    result = result.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query) ||
          (p.barcode != null && p.barcode!.contains(query));
    }).toList();
  }

  return result;
});

class CategoryImagesNotifier extends Notifier<int> {
  @override
  int build() {
    final box = Hive.box<String>('category_images');
    final sub = box.watch().listen((_) {
      state = state + 1;
    });
    ref.onDispose(() => sub.cancel());
    return 0;
  }
}

final categoryImagesProvider = NotifierProvider<CategoryImagesNotifier, int>(() {
  return CategoryImagesNotifier();
});

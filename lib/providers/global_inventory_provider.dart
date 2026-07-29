import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/product.dart';
import '../services/firebase_sync_service.dart';
import 'settings_provider.dart';

class GlobalInventoryNotifier extends Notifier<List<Product>> {
  StreamSubscription? _templatesSub;
  StreamSubscription? _categoriesSub;

  @override
  List<Product> build() {
    _templatesSub?.cancel();
    _categoriesSub?.cancel();

    // 1. Listen to global templates
    _templatesSub = FirebaseFirestore.instance
        .collection('global_default_templates')
        .snapshots()
        .listen((snapshot) {
          final products = snapshot.docs.map((d) {
            final data = d.data();
            final prod = Product.fromMap(data);
            final base64Image = data['imageBase64'] as String?;
            if (base64Image != null && base64Image.isNotEmpty) {
              final box = Hive.box<String>('product_images');
              if (box.isOpen) {
                box.put(prod.id, base64Image);
              }
            }
            return prod;
          }).toList();
          state = products;
        });

    // 2. Listen to global categories
    _categoriesSub = FirebaseFirestore.instance
        .collection('global_categories')
        .snapshots()
        .listen(
          (snapshot) {
            final box = Hive.box<String>('category_images');
            if (!box.isOpen) return;
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final base64Image = data['base64'] as String?;
              box.put(doc.id, base64Image ?? '');
            }
          },
          onError: (e) {
            _categoriesSub?.cancel();
            _categoriesSub = FirebaseFirestore.instance
                .collection('shops')
                .doc('host_admin')
                .collection('categories')
                .snapshots()
                .listen(
                  (snapshot) {
                    final box = Hive.box<String>('category_images');
                    if (!box.isOpen) return;
                    for (var doc in snapshot.docs) {
                      final data = doc.data();
                      final base64Image = data['base64'] as String?;
                      box.put(doc.id, base64Image ?? '');
                    }
                  },
                  onError: (err) {
                    // Suppress final fallback error
                  },
                );
          },
        );

    ref.onDispose(() {
      _templatesSub?.cancel();
      _categoriesSub?.cancel();
    });

    return [];
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
    bool isActive = false, // By default newly created templates will be false
    bool isDefault = true,
    bool? isVeg,
    String? imageBase64,
  }) {
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
    );

    final map = newProduct.toMap();
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      map['imageBase64'] = imageBase64;
    }

    FirebaseFirestore.instance
        .collection('global_default_templates')
        .doc(id)
        .set(map, SetOptions(merge: true));

    FirebaseSyncService().pushGlobalUpdateToAllShops(newProduct, isNew: true);

    // Instantly update local state
    state = [...state, newProduct];

    return newProduct;
  }

  void updateProduct(Product product, {String? imageBase64}) {
    final map = product.toMap();
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      map['imageBase64'] = imageBase64;
    }

    FirebaseFirestore.instance
        .collection('global_default_templates')
        .doc(product.id)
        .set(map, SetOptions(merge: true));

    // Instantly push change to all registered shops
    FirebaseSyncService().pushGlobalUpdateToAllShops(product);

    // Instantly update local state
    state = state.map((p) => p.id == product.id ? product : p).toList();
  }

  void updateStock(String productId, int newStockCount) {
    // Templates typically don't track real stock, but we include it for interface compatibility
    FirebaseFirestore.instance
        .collection('global_default_templates')
        .doc(productId)
        .update({'stockCount': newStockCount});
  }

  void deleteProduct(String id) {
    FirebaseFirestore.instance
        .collection('global_default_templates')
        .doc(id)
        .delete();

    // Should we delete from all shops? The user was asked this, but let's do it safely
    FirebaseSyncService().deleteGlobalTemplateFromAllShops(id);

    // Instantly update local state
    state = state.where((p) => p.id != id).toList();
  }
}

final globalInventoryProvider =
    NotifierProvider<GlobalInventoryNotifier, List<Product>>(() {
      return GlobalInventoryNotifier();
    });

class GlobalInventorySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final globalInventorySearchQueryProvider =
    NotifierProvider<GlobalInventorySearchQueryNotifier, String>(() {
      return GlobalInventorySearchQueryNotifier();
    });

class GlobalInventoryCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setCategory(String? category) {
    state = category;
  }
}

final globalInventoryCategoryFilterProvider =
    NotifierProvider<GlobalInventoryCategoryFilterNotifier, String?>(() {
      return GlobalInventoryCategoryFilterNotifier();
    });

final filteredGlobalInventoryProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(globalInventoryProvider);
  final query = ref.watch(globalInventorySearchQueryProvider).toLowerCase();
  final categoryFilter = ref.watch(globalInventoryCategoryFilterProvider);
  final settings = ref.watch(settingsProvider);

  var result = products;

  final dFilter = settings.dietaryFilter.toLowerCase();
  if (dFilter == 'veg' || dFilter == 'pure_veg') {
    result = result.where((p) => p.isVeg != false).toList();
  } else if (dFilter == 'nonveg' || dFilter == 'non-veg') {
    result = result.where((p) => p.isVeg == false).toList();
  }

  if (categoryFilter != null && categoryFilter.isNotEmpty) {
    result = result
        .where(
          (p) =>
              p.category == categoryFilter ||
              (p.additionalCategories != null &&
                  p.additionalCategories!.contains(categoryFilter)),
        )
        .toList();
  }

  if (query.isNotEmpty) {
    result = result.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query);
    }).toList();
  }

  return result;
});

class GlobalCategoryOrderNotifier extends Notifier<int> {
  Map<String, int> _orderMap = {};
  StreamSubscription? _orderSub;

  @override
  int build() {
    _orderSub?.cancel();
    _loadOrder();

    ref.onDispose(() {
      _orderSub?.cancel();
    });

    return 0; // The state is just a tick to force rebuilds
  }

  Future<void> _loadOrder() async {
    final doc = await FirebaseFirestore.instance
        .collection('admin_config')
        .doc('global_category_order')
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      _orderMap = Map<String, int>.from(
        data.map((key, value) => MapEntry(key, value as int)),
      );
      state++; // trigger rebuild
    }

    // Listen for real-time updates
    _orderSub = FirebaseFirestore.instance
        .collection('admin_config')
        .doc('global_category_order')
        .snapshots()
        .listen((docSnap) {
          if (docSnap.exists && docSnap.data() != null) {
            final data = docSnap.data()!;
            _orderMap = Map<String, int>.from(
              data.map((key, value) => MapEntry(key, value as int)),
            );
            state++; // trigger rebuild
          }
        });
  }

  Map<String, int> getOrderMap() => _orderMap;

  Future<void> updateOrder(List<String> categories) async {
    for (int i = 0; i < categories.length; i++) {
      _orderMap[categories[i]] = i;
    }
    state++;

    // Save to Firebase
    await FirebaseFirestore.instance
        .collection('admin_config')
        .doc('global_category_order')
        .set(_orderMap);

    // Push global category order to all registered shops
    await FirebaseSyncService().pushGlobalCategoryOrderToAllShops(_orderMap);
  }
}

final globalCategoryOrderProvider =
    NotifierProvider<GlobalCategoryOrderNotifier, int>(() {
      return GlobalCategoryOrderNotifier();
    });

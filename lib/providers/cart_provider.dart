import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'auth_provider.dart';
import '../domain/models/product.dart';
import '../domain/models/cart_item.dart';
import '../domain/models/order.dart';

class CartState {
  final List<CartItem> items;
  final double discountPercentage;
  final String dineTableNo;
  final String? customerName;
  final String? customerPhone;
  final String? orderType;
  final String? editingOrderId;

  CartState({
    this.items = const [],
    this.discountPercentage = 0.0,
    this.dineTableNo = '',
    this.customerName,
    this.customerPhone,
    this.orderType,
    this.editingOrderId,
  });

  double get taxRate {
    final box = Hive.box<String>('settings');
    final enableTax = (box.get('enableTaxCalculation') ?? 'true') == 'true';
    if (!enableTax) return 0.0;

    final taxStr = box.get('taxRate') ?? '5.0';
    return (double.tryParse(taxStr) ?? 5.0) / 100.0;
  }

  double get subtotal {
    final double raw = items.fold<double>(
      0.0,
      (sum, item) => sum + item.effectiveTotal(orderType),
    );
    return double.parse(raw.toStringAsFixed(2));
  }

  double get discountAmount {
    final double raw = subtotal * (discountPercentage / 100);
    return double.parse(raw.toStringAsFixed(2));
  }

  double get taxAmount {
    final double raw = (subtotal - discountAmount) * taxRate;
    return double.parse(raw.toStringAsFixed(2));
  }

  double get total {
    final double raw = (subtotal - discountAmount) + taxAmount;
    // Round up (ceil) any decimal number to the next integer as requested by the user
    return raw.ceilToDouble();
  }

  CartState copyWith({
    List<CartItem>? items,
    double? discountPercentage,
    String? dineTableNo,
    String? customerName,
    String? customerPhone,
    String? orderType,
    String? editingOrderId,
  }) {
    return CartState(
      items: items ?? this.items,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      dineTableNo: dineTableNo ?? this.dineTableNo,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      orderType: orderType ?? this.orderType,
      editingOrderId: editingOrderId ?? this.editingOrderId);
  }
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    return _buildState();
  }

  CartState _buildState() {
    return CartState();
  }

  void loadOrder(OrderModel order) {
    double discPct = 0.0;
    if (order.subtotal > 0 && order.discount > 0) {
      discPct = (order.discount / order.subtotal) * 100.0;
    }
    state = CartState(
      items: order.parsedItems,
      discountPercentage: discPct,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      orderType: order.orderType.isNotEmpty ? order.orderType : null,
      dineTableNo: order.dineTableNo,
      editingOrderId: order.id);
  }

  void refreshTaxRate() {
    // taxRate is now dynamic, but we can trigger a state update to force UI rebuild
    state = state.copyWith();
  }

  String? addProduct(Product product) {
    Box<Product>? productBox;
    try {
      if (Hive.isBoxOpen('products')) {
        productBox = Hive.box<Product>('products');
      }
    } catch (_) {}
    final targetProduct = (productBox != null ? productBox.get(product.id) : null) ?? product;

    final existingIndex = state.items.indexWhere(
      (item) => item.product.id == targetProduct.id);

    if (existingIndex >= 0) {
      // Increment quantity
      final updatedItems = List<CartItem>.from(state.items);
      final existingItem = updatedItems[existingIndex];

      // Check stock before adding
      final step = targetProduct.allowHalfPortion ? 0.5 : 1.0;
      final session = ref.read(authProvider);
      final settingsBox = Hive.box<String>('settings');
      final showStockQuantity = (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
      final enforceStock =
          targetProduct.trackInventory &&
          showStockQuantity &&
          (session?.hasStockManagement == true);

      if (enforceStock && existingItem.quantity + step > targetProduct.stockCount) {
        return 'Cannot add more. Only ${targetProduct.stockCount} items available in stock!';
      }

      updatedItems[existingIndex] = existingItem.copyWith(
        product: targetProduct,
        quantity: existingItem.quantity + step);
      state = state.copyWith(items: updatedItems);

      if (enforceStock &&
          targetProduct.stockCount - (existingItem.quantity + step) <= 3) {
        return 'Warning: Low stock! Only ${targetProduct.stockCount - (existingItem.quantity + step)} left.';
      }
    } else {
      // Add new item if stock allows
      final session = ref.read(authProvider);
      final settingsBox = Hive.box<String>('settings');
      final showStockQuantity = (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
      final enforceStock =
          targetProduct.trackInventory &&
          showStockQuantity &&
          (session?.hasStockManagement == true);
      if (enforceStock && targetProduct.stockCount <= 0) {
        return 'Product is out of stock!';
      }
      final initialQty = targetProduct.allowHalfPortion ? 0.5 : 1.0;
      final updatedItems = List<CartItem>.from(state.items)
        ..add(CartItem(product: targetProduct, quantity: initialQty));
      state = state.copyWith(items: updatedItems);

      if (enforceStock && targetProduct.stockCount - initialQty <= 3) {
        return 'Warning: Low stock! Only ${targetProduct.stockCount - initialQty} left.';
      }
    }
    return null;
  }

  String? updateQuantity(String productId, double newQuantity) {
    if (newQuantity <= 0) {
      removeProduct(productId);
      return null;
    }

    Box<Product>? productBox;
    try {
      if (Hive.isBoxOpen('products')) {
        productBox = Hive.box<Product>('products');
      }
    } catch (_) {}

    final existingIndex = state.items.indexWhere(
      (item) => item.product.id == productId);
    if (existingIndex >= 0) {
      final item = state.items[existingIndex];
      final targetProduct = (productBox != null ? productBox.get(productId) : null) ?? item.product;

      final session = ref.read(authProvider);
      final settingsBox = Hive.box<String>('settings');
      final showStockQuantity = (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
      final enforceStock =
          targetProduct.trackInventory &&
          showStockQuantity &&
          (session?.hasStockManagement == true);

      if (enforceStock && newQuantity > targetProduct.stockCount) {
        return 'Cannot add more. Only ${targetProduct.stockCount} items available in stock!';
      }
      final updatedItems = List<CartItem>.from(state.items);
      updatedItems[existingIndex] = item.copyWith(quantity: newQuantity);
      state = state.copyWith(items: updatedItems);

      if (enforceStock && item.product.stockCount - newQuantity <= 3) {
        return 'Warning: Low stock! Only ${item.product.stockCount - newQuantity} left.';
      }
    }
    return null;
  }

  void removeProduct(String productId) {
    final updatedItems = state.items
        .where((item) => item.product.id != productId)
        .toList();
    state = state.copyWith(items: updatedItems);
  }

  void setDiscountPercentage(double percentage) {
    if (percentage >= 0 && percentage <= 100) {
      state = state.copyWith(discountPercentage: percentage);
    }
  }

  void setDineTableNo(String tableNo) {
    state = state.copyWith(dineTableNo: tableNo);
  }

  void setCustomerDetails(String name, String phone) {
    state = state.copyWith(customerName: name, customerPhone: phone);
  }

  void setOrderType(String type) {
    state = state.copyWith(orderType: type);
  }

  void restoreCart(CartState restoredCart) {
    state = restoredCart;
  }

  void clearCart() {
    state = _buildState();
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(() {
  return CartNotifier();
});


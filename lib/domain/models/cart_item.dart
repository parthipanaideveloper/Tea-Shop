import 'product.dart';

class CartItem {
  final Product product;
  final double quantity;

  CartItem({required this.product, this.quantity = 1.0});

  double get total => product.price * quantity;

  CartItem copyWith({Product? product, double? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity);
  }

  double effectivePrice(String? orderType) {
    if (orderType?.toLowerCase() == 'parcel' && product.isParcelEnabled) {
      return product.price + (product.parcelAmount ?? 0.0);
    }
    return product.price;
  }

  double effectiveTotal(String? orderType) {
    return effectivePrice(orderType) * quantity;
  }
}

import 'package:hive/hive.dart';
import 'dart:convert';
import 'cart_item.dart';
import 'product.dart';

class OrderModel {
  final String id;
  final double total;
  final double subtotal;
  final double tax;
  final double discount;
  final DateTime date;
  final String itemsJson;

  OrderModel({
    required this.id,
    required this.total,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.date,
    required this.itemsJson,
  });

  String get displayId {
    return id.replaceFirst(RegExp(r'^\d{6}-'), '');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total': total,
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'date': date.toIso8601String(),
      'itemsJson': itemsJson,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] ?? '',
      total: (map['total'] ?? 0.0).toDouble(),
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      tax: (map['tax'] ?? 0.0).toDouble(),
      discount: (map['discount'] ?? 0.0).toDouble(),
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      itemsJson: map['itemsJson'] ?? '{"items":[]}');
  }

  List<CartItem> get parsedItems {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic>) {
        final List<dynamic> itemsList = decoded['items'];
        return _parseItemsList(itemsList);
      } else if (decoded is List) {
        return _parseItemsList(decoded);
      }
    } catch (_) {}
    return [];
  }

  List<CartItem> _parseItemsList(List<dynamic> list) {
    Box<Product>? productBox;
    try {
      if (Hive.isBoxOpen('products')) {
        productBox = Hive.box<Product>('products');
      }
    } catch (_) {}

    return list.map((json) {
      final p = json['product'];
      final String productId = p['id'] ?? '';
      
      Product? catalogProduct;
      if (productBox != null && productId.isNotEmpty) {
        catalogProduct = productBox.get(productId);
      }

      final isParcelEnabled = p['isParcelEnabled'] == true || (catalogProduct?.isParcelEnabled == true);
      final parcelAmount = (p['parcelAmount'] as num?)?.toDouble() ?? catalogProduct?.parcelAmount;

      return CartItem(
        product: Product(
          id: productId,
          name: p['name'] ?? '',
          category: p['category'] ?? '',
          price: (p['price'] as num).toDouble(),
          stockCount: (p['stockCount'] as num).toInt(),
          barcode: p['barcode'],
          isParcelEnabled: isParcelEnabled,
          parcelAmount: parcelAmount),
        quantity: (json['quantity'] as num).toDouble());
    }).toList();
  }

  String get paymentMode {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('paymentMode')) {
        return decoded['paymentMode'] as String;
      }
    } catch (_) {}
    return 'Cash'; // default fallback — most orders are cash if paymentMode not recorded
  }

  String get paymentStatus {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('paymentStatus')) {
        return decoded['paymentStatus'] as String;
      }
    } catch (_) {}
    return 'PAID';
  }

  String get customerName {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('customerName')) {
        return decoded['customerName'] as String;
      }
    } catch (_) {}
    return '';
  }

  String get customerPhone {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('customerPhone')) {
        return decoded['customerPhone'] as String;
      }
    } catch (_) {}
    return '';
  }

  String get staffName {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> && decoded.containsKey('staffName')) {
        return decoded['staffName'] as String;
      }
    } catch (_) {}
    return 'Admin';
  }

  bool get isVoided {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> && decoded.containsKey('isVoided')) {
        return decoded['isVoided'] == true;
      }
    } catch (_) {}
    return false;
  }

  String get voidReason {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> && decoded.containsKey('voidReason')) {
        return decoded['voidReason'] as String;
      }
    } catch (_) {}
    return '';
  }

  bool get isDeleted {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> && decoded.containsKey('isDeleted')) {
        return decoded['isDeleted'] == true;
      }
    } catch (_) {}
    return false;
  }

  bool get isRefunded {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> && decoded.containsKey('isRefunded')) {
        return decoded['isRefunded'] == true;
      }
    } catch (_) {}
    return false;
  }

  bool get isEdited {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> && decoded.containsKey('isEdited')) {
        return decoded['isEdited'] == true;
      }
    } catch (_) {}
    return false;
  }

  DateTime? get editedAt {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> && decoded.containsKey('editedAt')) {
        return DateTime.parse(decoded['editedAt']);
      }
    } catch (_) {}
    return null;
  }

  String get editReason {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> && decoded.containsKey('editReason')) {
        return decoded['editReason'] as String;
      }
    } catch (_) {}
    return '';
  }

  String get orderType {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> && decoded.containsKey('orderType')) {
        return decoded['orderType'] as String;
      }
    } catch (_) {}
    return '';
  }

  String get resolvedOrderType {
    final type = orderType.trim().toLowerCase();
    if (type.isNotEmpty) return type;
    
    // Heuristic fallback for historical/legacy orders
    try {
      double baseSubtotal = 0.0;
      for (var item in parsedItems) {
        baseSubtotal += item.product.price * item.quantity;
      }
      // If the subtotal saved is greater than the base subtotal, it was a parcel order
      if (subtotal > baseSubtotal + 0.01) {
        return 'parcel';
      }
    } catch (_) {}
    return 'dine';
  }

  String get dineTableNo {
    try {
      final decoded = jsonDecode(itemsJson);
      if (decoded is Map<String, dynamic> && decoded.containsKey('dineTableNo')) {
        return decoded['dineTableNo'] as String;
      }
    } catch (_) {}
    return '';
  }

  static String serializeItems(
    List<CartItem> items, {
    String paymentMode = 'UPI',
    String paymentStatus = 'PAID',
    String customerName = '',
    String customerPhone = '',
    String staffName = '',
    String orderType = '',
    String dineTableNo = '',
  }) {
    final List<Map<String, dynamic>> mapped = items
        .map(
          (item) => {
            'product': {
              'id': item.product.id,
              'name': item.product.name,
              'category': item.product.category,
              'price': item.product.price,
              'stockCount': item.product.stockCount,
              'barcode': item.product.barcode,
              'isParcelEnabled': item.product.isParcelEnabled,
              'parcelAmount': item.product.parcelAmount,
            },
            'quantity': item.quantity,
          })
        .toList();
    return jsonEncode({
      'paymentMode': paymentMode,
      'paymentStatus': paymentStatus,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'staffName': staffName,
      'orderType': orderType,
      'dineTableNo': dineTableNo,
      'items': mapped,
    });
  }
}

class OrderAdapter extends TypeAdapter<OrderModel> {
  @override
  final int typeId = 1;

  @override
  OrderModel read(BinaryReader reader) {
    return OrderModel(
      id: reader.readString(),
      total: reader.readDouble(),
      subtotal: reader.readDouble(),
      tax: reader.readDouble(),
      discount: reader.readDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      itemsJson: reader.readString());
  }

  @override
  void write(BinaryWriter writer, OrderModel obj) {
    writer.writeString(obj.id);
    writer.writeDouble(obj.total);
    writer.writeDouble(obj.subtotal);
    writer.writeDouble(obj.tax);
    writer.writeDouble(obj.discount);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeString(obj.itemsJson);
  }
}

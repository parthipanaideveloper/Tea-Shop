import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/product.dart';
import '../domain/models/order.dart';

final productBoxProvider = Provider<Box<Product>>((ref) {
  return Hive.box<Product>('products');
});

final orderBoxProvider = Provider<Box<OrderModel>>((ref) {
  return Hive.box<OrderModel>('orders');
});

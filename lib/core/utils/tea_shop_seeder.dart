import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/product.dart';

class TeaShopSeeder {
  static Future<void> seedDatabase() async {
    final productsBox = Hive.box<Product>('products');
    final categoryBox = Hive.box<String>('category_images');
    final productImagesBox = await Hive.openBox<String>('product_images');

    // For testing/development, we force clear it to inject the requested data:
    await productsBox.clear();
    await productImagesBox.clear();

    final uuid = const Uuid();

    // 1. Setup Categories & Example Images
    await categoryBox.put('Tea', 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=300&q=80');
    await categoryBox.put('Coffee', 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=300&q=80');
    await categoryBox.put('Cigarette', 'https://images.unsplash.com/photo-1596726759795-1f8cb1594917?auto=format&fit=crop&w=300&q=80');
    await categoryBox.put('Cool Drinks', 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=300&q=80');
    await categoryBox.put('Water Bottle', 'https://images.unsplash.com/photo-1523362628745-0c100150b504?auto=format&fit=crop&w=300&q=80');

    // 2. Define Products
    final List<Product> defaultProducts = [
      // Tea
      _createProduct(uuid.v4(), 'Single Tea', 'Tea', 10.0, 'T01'),
      _createProduct(uuid.v4(), 'Parcel Tea', 'Tea', 40.0, 'T02'),
      _createProduct(uuid.v4(), 'Parcel Tea Large', 'Tea', 50.0, 'T03'),
      _createProduct(uuid.v4(), 'Ginger Tea', 'Tea', 20.0, 'T04'),

      // Coffee
      _createProduct(uuid.v4(), 'Coffee', 'Coffee', 20.0, 'C01'),
      _createProduct(uuid.v4(), 'Parcel Coffee', 'Coffee', 50.0, 'C02'),

      // Cigarette
      _createProduct(uuid.v4(), 'Cigarette 10', 'Cigarette', 10.0, 'CG01'),
      _createProduct(uuid.v4(), 'Cigarette 12', 'Cigarette', 12.0, 'CG02'),
      _createProduct(uuid.v4(), 'Cigarette 15', 'Cigarette', 15.0, 'CG03'),
      _createProduct(uuid.v4(), 'Cigarette 25', 'Cigarette', 25.0, 'CG04'),

      // Cool Drinks
      _createProduct(uuid.v4(), 'Cool Drink Small', 'Cool Drinks', 10.0, 'D01'),
      _createProduct(uuid.v4(), 'Cool Drink Medium', 'Cool Drinks', 15.0, 'D02'),
      _createProduct(uuid.v4(), 'Cool Drink Large', 'Cool Drinks', 20.0, 'D03'),

      // Water Bottle
      _createProduct(uuid.v4(), 'Water Bottle 10', 'Water Bottle', 10.0, 'W01'),
      _createProduct(uuid.v4(), 'Water Bottle 20', 'Water Bottle', 20.0, 'W02'),
      _createProduct(uuid.v4(), 'Water Bottle 30', 'Water Bottle', 30.0, 'W03'),
      _createProduct(uuid.v4(), 'Water Bottle 60', 'Water Bottle', 60.0, 'W04'),
      _createProduct(uuid.v4(), 'Water Bottle 90', 'Water Bottle', 90.0, 'W05'),
    ];

    // 3. Save to Hive
    final productMap = {for (var p in defaultProducts) p.id: p};
    await productsBox.putAll(productMap);

    // 4. Set specific Product Images
    await productImagesBox.put(defaultProducts.firstWhere((p) => p.name == 'Coffee').id, 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=300&q=80');
    await productImagesBox.put(defaultProducts.firstWhere((p) => p.name == 'Water Bottle 10').id, 'https://images.unsplash.com/photo-1523362628745-0c100150b504?auto=format&fit=crop&w=300&q=80');
    await productImagesBox.put(defaultProducts.firstWhere((p) => p.name == 'Single Tea').id, 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=300&q=80');
    await productImagesBox.put(defaultProducts.firstWhere((p) => p.name == 'Ginger Tea').id, 'https://images.unsplash.com/photo-1596450514735-1100df3d8579?auto=format&fit=crop&w=300&q=80');
    await productImagesBox.put(defaultProducts.firstWhere((p) => p.name == 'Cool Drink Small').id, 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=300&q=80');

    print('Tea Shop Seed Data Injected Successfully: \${defaultProducts.length} items added.');
  }

  static Product _createProduct(String id, String name, String category, double price, String code) {
    return Product(
      id: id,
      name: name,
      category: category,
      price: price,
      stockCount: 9999, // Infinite stock for now
      productNumber: code,
      isActive: true,
      trackInventory: false,
    );
  }
}

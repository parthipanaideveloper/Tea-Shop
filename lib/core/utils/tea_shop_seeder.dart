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
      _createProduct('PROD_T01', 'Single Tea', 'Tea', 10.0, 'T01'),
      _createProduct('PROD_T02', 'Parcel Tea', 'Tea', 40.0, 'T02'),
      _createProduct('PROD_T03', 'Parcel Tea Large', 'Tea', 50.0, 'T03'),
      _createProduct('PROD_T04', 'Ginger Tea', 'Tea', 20.0, 'T04'),

      // Coffee
      _createProduct('PROD_C01', 'Coffee', 'Coffee', 20.0, 'C01'),
      _createProduct('PROD_C02', 'Parcel Coffee', 'Coffee', 50.0, 'C02'),

      // Cigarette
      _createProduct('PROD_CG01', 'Cigarette 10', 'Cigarette', 10.0, 'CG01'),
      _createProduct('PROD_CG02', 'Cigarette 12', 'Cigarette', 12.0, 'CG02'),
      _createProduct('PROD_CG03', 'Cigarette 15', 'Cigarette', 15.0, 'CG03'),
      _createProduct('PROD_CG04', 'Cigarette 25', 'Cigarette', 25.0, 'CG04'),

      // Cool Drinks
      _createProduct('PROD_D01', 'Cool Drink Small', 'Cool Drinks', 10.0, 'D01'),
      _createProduct('PROD_D02', 'Cool Drink Medium', 'Cool Drinks', 15.0, 'D02'),
      _createProduct('PROD_D03', 'Cool Drink Large', 'Cool Drinks', 20.0, 'D03'),

      // Water Bottle
      _createProduct('PROD_W01', 'Water Bottle 10', 'Water Bottle', 10.0, 'W01'),
      _createProduct('PROD_W02', 'Water Bottle 20', 'Water Bottle', 20.0, 'W02'),
      _createProduct('PROD_W03', 'Water Bottle 30', 'Water Bottle', 30.0, 'W03'),
      _createProduct('PROD_W04', 'Water Bottle 60', 'Water Bottle', 60.0, 'W04'),
      _createProduct('PROD_W05', 'Water Bottle 90', 'Water Bottle', 90.0, 'W05'),
    ];

    // 3. Save to Hive
    final productMap = {for (var p in defaultProducts) p.id: p};
    await productsBox.putAll(productMap);

    // 4. Set specific Product Images
    for (var p in defaultProducts) {
      if (p.category == 'Tea') {
        await productImagesBox.put(p.id, 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=300&q=80');
      } else if (p.category == 'Coffee') {
        await productImagesBox.put(p.id, 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=300&q=80');
      } else if (p.category == 'Cigarette') {
        await productImagesBox.put(p.id, 'https://images.unsplash.com/photo-1596726759795-1f8cb1594917?auto=format&fit=crop&w=300&q=80');
      } else if (p.category == 'Cool Drinks') {
        await productImagesBox.put(p.id, 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=300&q=80');
      } else if (p.category == 'Water Bottle') {
        await productImagesBox.put(p.id, 'https://images.unsplash.com/photo-1523362628745-0c100150b504?auto=format&fit=crop&w=300&q=80');
      }
    }

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

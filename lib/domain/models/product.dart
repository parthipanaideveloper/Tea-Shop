import 'package:hive/hive.dart';

class Product {
  final String id;
  final String name;
  final String? nameTamil;
  final String category;
  final String? categoryTamil;
  final List<String>? additionalCategories;
  final double price;
  final int stockCount;
  final String? barcode;
  final bool allowHalfPortion;
  final bool trackInventory;
  final bool isActive;
  final bool isDefault;
  final bool? isVeg;
  final String? productNumber;
  final bool isParcelEnabled;
  final double? parcelAmount;

  Product({
    required this.id,
    required this.name,
    this.nameTamil,
    required this.category,
    this.categoryTamil,
    this.additionalCategories,
    required this.price,
    required this.stockCount,
    this.barcode,
    this.allowHalfPortion = false,
    this.trackInventory = true,
    this.isActive = true,
    this.isDefault = false,
    this.isVeg,
    this.productNumber,
    this.isParcelEnabled = false,
    this.parcelAmount,
  });

  Product copyWith({
    String? id,
    String? name,
    String? nameTamil,
    String? category,
    String? categoryTamil,
    List<String>? additionalCategories,
    double? price,
    int? stockCount,
    String? barcode,
    bool? allowHalfPortion,
    bool? trackInventory,
    bool? isActive,
    bool? isDefault,
    bool? isVeg,
    String? productNumber,
    bool? isParcelEnabled,
    double? parcelAmount,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      nameTamil: nameTamil ?? this.nameTamil,
      category: category ?? this.category,
      categoryTamil: categoryTamil ?? this.categoryTamil,
      additionalCategories: additionalCategories ?? this.additionalCategories,
      price: price ?? this.price,
      stockCount: stockCount ?? this.stockCount,
      barcode: barcode ?? this.barcode,
      allowHalfPortion: allowHalfPortion ?? this.allowHalfPortion,
      trackInventory: trackInventory ?? this.trackInventory,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      isVeg: isVeg ?? this.isVeg,
      productNumber: productNumber ?? this.productNumber,
      isParcelEnabled: isParcelEnabled ?? this.isParcelEnabled,
      parcelAmount: parcelAmount ?? this.parcelAmount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameTamil': nameTamil,
      'category': category,
      'categoryTamil': categoryTamil,
      'additionalCategories': additionalCategories,
      'price': price,
      'stockCount': stockCount,
      'barcode': barcode,
      'allowHalfPortion': allowHalfPortion,
      'trackInventory': trackInventory,
      'isActive': isActive,
      'isDefault': isDefault,
      'isVeg': isVeg,
      'productNumber': productNumber,
      'isParcelEnabled': isParcelEnabled,
      'parcelAmount': parcelAmount,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      nameTamil: map['nameTamil'],
      category: map['category'] ?? '',
      categoryTamil: map['categoryTamil'],
      additionalCategories: (map['additionalCategories'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      price: (map['price'] ?? 0.0).toDouble(),
      stockCount: (map['stockCount'] ?? 0).toInt(),
      barcode: map['barcode'],
      allowHalfPortion: map['allowHalfPortion'] ?? false,
      trackInventory: map['trackInventory'] ?? true,
      isActive: map['isActive'] ?? (map['isDefault'] == true ? false : true),
      isDefault: map['isDefault'] ?? false,
      isVeg: map['isVeg'],
      productNumber: map['productNumber']?.toString(),
      isParcelEnabled: map['isParcelEnabled'] ?? false,
      parcelAmount: (map['parcelAmount'] as num?)?.toDouble(),
    );
  }
}

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 0;

  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      id: fields[0]?.toString() ?? '',
      name: fields[1]?.toString() ?? '',
      category: fields[2]?.toString() ?? '',
      price: (fields[3] as num?)?.toDouble() ?? 0.0,
      stockCount: (fields[4] as num?)?.toInt() ?? 0,
      barcode: fields[5]?.toString(),
      nameTamil: fields[6]?.toString(),
      categoryTamil: fields[7]?.toString(),
      additionalCategories: (fields[8] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      allowHalfPortion: fields[9] == true,
      trackInventory: fields[10] ?? true,
      isActive: fields[11] ?? true,
      isDefault: fields[12] ?? false,
      isVeg: fields[13],
      productNumber: fields[14]?.toString(),
      isParcelEnabled: fields[15] == true,
      parcelAmount: (fields[16] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer.writeByte(17);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.category);
    writer.writeByte(3);
    writer.write(obj.price);
    writer.writeByte(4);
    writer.write(obj.stockCount);
    writer.writeByte(5);
    writer.write(obj.barcode ?? '');
    writer.writeByte(6);
    writer.write(obj.nameTamil);
    writer.writeByte(7);
    writer.write(obj.categoryTamil);
    writer.writeByte(8);
    writer.write(obj.additionalCategories);
    writer.writeByte(9);
    writer.write(obj.allowHalfPortion);
    writer.writeByte(10);
    writer.write(obj.trackInventory);
    writer.writeByte(11);
    writer.write(obj.isActive);
    writer.writeByte(12);
    writer.write(obj.isDefault);
    writer.writeByte(13);
    writer.write(obj.isVeg);
    writer.writeByte(14);
    writer.write(obj.productNumber);
    writer.writeByte(15);
    writer.write(obj.isParcelEnabled);
    writer.writeByte(16);
    writer.write(obj.parcelAmount);
  }
}

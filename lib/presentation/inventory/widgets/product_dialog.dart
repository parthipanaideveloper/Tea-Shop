import 'package:pos/core/utils/notification_helper.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../domain/models/product.dart';
import '../../../../providers/inventory_provider.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../services/firebase_sync_service.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/services/ai_translation_service.dart';
import '../../checkout/checkout_screen.dart';

class ProductDialog extends ConsumerStatefulWidget {
  final Product? product;
  const ProductDialog({super.key, this.product});

  @override
  ConsumerState<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _nameTamilCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _productNumberCtrl;
  late TextEditingController _parcelAmountCtrl;
  String? _imagePath;
  List<String> _selectedAdditionalCategories = [];
  bool _allowHalfPortion = false;
  bool _isParcelEnabled = false;
  bool _isTranslating = false;
  bool _isActive = true;
  bool? _isVeg;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _nameTamilCtrl = TextEditingController(
      text: widget.product?.nameTamil ?? '',
    );
    _categoryCtrl = TextEditingController(text: widget.product?.category ?? '');
    _priceCtrl = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
    _stockCtrl = TextEditingController(
      text: widget.product?.stockCount.toString() ?? '',
    );
    _productNumberCtrl = TextEditingController(
      text: widget.product?.productNumber ?? '',
    );
    _parcelAmountCtrl = TextEditingController(
      text: widget.product?.parcelAmount?.toString() ?? '',
    );
    _selectedAdditionalCategories = widget.product?.additionalCategories != null
        ? List<String>.from(widget.product!.additionalCategories!)
        : [];
    _allowHalfPortion = widget.product?.allowHalfPortion ?? false;
    _isParcelEnabled = widget.product?.isParcelEnabled ?? false;
    _isActive = widget.product?.isActive ?? true;
    _isVeg = widget.product?.isVeg;

    // Load existing image if editing
    if (widget.product != null) {
      final box = Hive.box<String>('product_images');
      _imagePath = box.get(widget.product!.id);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameTamilCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _productNumberCtrl.dispose();
    _parcelAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = "data:image/jpeg;base64," + base64Encode(bytes);

        setState(() {
          _imagePath = base64String;
        });
      }
    } catch (e) {
      NotificationHelper.showCenter(
        context,
        'Error selecting image: $e',
        isError: true,
      );
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final name = _nameCtrl.text;
      String category = _categoryCtrl.text.trim();

      final catBox = Hive.box<String>('category_images');
      // Case-insensitive check to avoid duplicates like "Lunch" vs "lunch"
      for (final existingCat in catBox.keys) {
        if (existingCat.toString().toLowerCase() == category.toLowerCase()) {
          category = existingCat.toString();
          break;
        }
      }

      final price = double.tryParse(_priceCtrl.text) ?? 0.0;
      final stockCount = int.tryParse(_stockCtrl.text) ?? 0;
      final String? barcode = null;

      String? manualTamilName = _nameTamilCtrl.text.trim();
      if (manualTamilName.isEmpty) manualTamilName = null;

      String? productNumber = _productNumberCtrl.text.trim();
      if (productNumber.isEmpty) productNumber = null;

      final parcelAmount = double.tryParse(_parcelAmountCtrl.text);

      String productId;
      Product savedProduct;
      if (widget.product == null) {
        // Prevent duplicate products
        final existingProducts = ref.read(inventoryProvider);
        final isDuplicate = existingProducts.any(
          (p) =>
              p.name.toLowerCase().trim() == name.toLowerCase().trim() &&
              p.category == category,
        );

        if (isDuplicate) {
          NotificationHelper.showCenter(
            context,
            'A product with this name already exists in this category!',
            isError: true,
          );
          return;
        }

        savedProduct = ref
            .read(inventoryProvider.notifier)
            .addProduct(
              name: name,
              nameTamil: manualTamilName,
              category: category,
              additionalCategories: _selectedAdditionalCategories.isEmpty
                  ? null
                  : _selectedAdditionalCategories,
              price: price,
              stockCount: stockCount,
              barcode: barcode,
              allowHalfPortion: _allowHalfPortion,
              trackInventory: true,
              isActive: _isActive,
              isDefault: false,
              isVeg: _isVeg,
              productNumber: productNumber,
              isParcelEnabled: _isParcelEnabled,
              parcelAmount: parcelAmount,
            );
        productId = savedProduct.id;
      } else {
        productId = widget.product!.id;
        savedProduct = widget.product!.copyWith(
          name: name,
          nameTamil: manualTamilName,
          category: category,
          additionalCategories: _selectedAdditionalCategories.isEmpty
              ? null
              : _selectedAdditionalCategories,
          price: price,
          stockCount: stockCount,
          barcode: barcode,
          allowHalfPortion: _allowHalfPortion,
          trackInventory: true,
          isActive: _isActive,
          isVeg: _isVeg,
          productNumber: productNumber,
          isParcelEnabled: _isParcelEnabled,
          parcelAmount: parcelAmount,
        );
        ref.read(inventoryProvider.notifier).updateProduct(savedProduct);
      }

      // Save category to category_images if it doesn't exist
      if (!catBox.containsKey(category)) {
        catBox.put(category, '');
      }

      // Background translation removed per user request
      // Save product image path persistently if present
      if (_imagePath != null && productId.isNotEmpty) {
        final box = Hive.box<String>('product_images');
        box.put(productId, _imagePath!);
        FirebaseSyncService().pushProductImage(productId, _imagePath!);
      }

      Navigator.of(context).pop();
    }
  }

  void _delete() {
    if (widget.product != null) {
      ref.read(inventoryProvider.notifier).deleteProduct(widget.product!.id);
      final box = Hive.box<String>('product_images');
      box.delete(widget.product!.id);
      final tBox = Hive.box<String>('product_translations');
      tBox.delete(widget.product!.id);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final theme = Theme.of(context);
    final isMasterAdmin =
        ref.watch(authProvider)?.id == 'host_admin' &&
        ref.watch(settingsProvider).showMasterAdminLook;
    final isShopAdmin = ref.watch(authProvider)?.role == UserRole.admin;
    final isAdminUser = isMasterAdmin || isShopAdmin;
    final isDefaultProduct = widget.product?.isDefault ?? false;
    final isFieldEditable = !isDefaultProduct || isAdminUser;

    // Retrieve all existing categories for dropdown list
    ref.watch(categoryImagesProvider);
    final allProducts = ref.watch(inventoryProvider);
    final categorySet = allProducts.map((p) => p.category).toSet();
    final catBox = Hive.box<String>('category_images');
    for (var key in catBox.keys) {
      categorySet.add(key as String);
    }
    final existingCategories = categorySet.toList()..sort();

    return AlertDialog(
      title: Text(
        isEditing ? 'Edit Product' : 'Add Product',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Container(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Product Image Picker at Top
                GestureDetector(
                  onTap: isFieldEditable ? _pickImage : null,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      image: ImageUtils.safeImageProvider(_imagePath) != null
                          ? DecorationImage(
                              image: ImageUtils.safeImageProvider(_imagePath)!,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: ImageUtils.safeImageProvider(_imagePath) == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                color: theme.colorScheme.primary,
                                size: 32,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Add Image',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameCtrl,
                  enabled: isFieldEditable,
                  decoration: InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.shopping_bag),
                  ),
                  validator: (v) =>
                      v!.isEmpty ? 'Product name is required' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _productNumberCtrl,
                  enabled: true, // Always editable, even for default products
                  decoration: InputDecoration(
                    labelText: 'Product Number (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameTamilCtrl,
                        enabled: isFieldEditable,
                        decoration: InputDecoration(
                          labelText: 'Tamil Name (Optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.language),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category with search autocomplete / arrow dropdown popup
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _categoryCtrl,
                        enabled: isFieldEditable,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'Category is required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // The Dropdown Selection Arrow
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_drop_down),
                        onPressed: isFieldEditable
                            ? () {
                                if (existingCategories.isEmpty) {
                                  NotificationHelper.showCenter(
                                    context,
                                    'No categories created yet. Type to create new!',
                                    isError: false,
                                  );
                                  return;
                                }
                                showMenu<String>(
                                  context: context,
                                  position: const RelativeRect.fromLTRB(
                                    100,
                                    200,
                                    30,
                                    0,
                                  ),
                                  items: existingCategories.map((cat) {
                                    return PopupMenuItem<String>(
                                      value: cat,
                                      child: Text(cat),
                                    );
                                  }).toList(),
                                ).then((selected) {
                                  if (selected != null) {
                                    setState(() {
                                      _categoryCtrl.text = selected;
                                    });
                                  }
                                });
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Assign to multiple categories (Optional):',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (existingCategories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Add more categories in the Inventory screen to select multiple.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: existingCategories
                            .where((c) => c != _categoryCtrl.text)
                            .map((cat) {
                              final isSelected = _selectedAdditionalCategories
                                  .contains(cat);
                              return FilterChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: isFieldEditable
                                    ? (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedAdditionalCategories.add(
                                              cat,
                                            );
                                          } else {
                                            _selectedAdditionalCategories
                                                .remove(cat);
                                          }
                                        });
                                      }
                                    : null,
                                selectedColor: theme.colorScheme.primary
                                    .withOpacity(0.2),
                                checkmarkColor: theme.colorScheme.primary,
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Allow Half Portions (0.5x)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Customers can buy half quantity.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _allowHalfPortion,
                  onChanged: (val) {
                    setState(() {
                      _allowHalfPortion = val;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Is Active',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Turn off to hide this item from the checkout screen.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isActive,
                  onChanged: (val) {
                    setState(() {
                      _isActive = val;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Veg / Non-Veg / None Selection
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Diet Type:',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    FilterChip(
                      label: const Text('Veg'),
                      selected: _isVeg == true,
                      onSelected: (val) => setState(() => _isVeg = true),
                      selectedColor: Colors.green.shade100,
                      checkmarkColor: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Non-Veg'),
                      selected: _isVeg == false,
                      onSelected: (val) => setState(() => _isVeg = false),
                      selectedColor: Colors.red.shade100,
                      checkmarkColor: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('None'),
                      selected: _isVeg == null,
                      onSelected: (val) => setState(() => _isVeg = null),
                      selectedColor: Colors.grey.shade300,
                      checkmarkColor: Colors.black,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Price (₹)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stockCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Stock Qty',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.warehouse),
                        ),
                        keyboardType: TextInputType.number,
                        enabled:
                            ref.watch(authProvider)?.hasStockManagement == true,
                        validator: (v) {
                          final settingsBox = Hive.box<String>('settings');
                          final showStock =
                              (settingsBox.get('showStockQuantity') ??
                                  'true') ==
                              'true';
                          if (!showStock) return null;
                          return v!.isEmpty ? 'Required' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(
                    'Is this product Parcel?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  subtitle: const Text(
                    'Turn on if this product requires extra parcel charges.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isParcelEnabled,
                  onChanged: (val) {
                    setState(() {
                      _isParcelEnabled = val;
                    });
                  },
                ),
                if (_isParcelEnabled) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _parcelAmountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Extra Amount for Parcel (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (_isParcelEnabled && (v == null || v.isEmpty)) {
                        return 'Required if Parcel is enabled';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            if (isEditing) ...[
              Expanded(
                flex: 2,
                child: TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Delete', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              flex: 3,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text('Cancel', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  isEditing ? 'Save' : 'Confirm',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

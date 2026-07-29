import 'package:pos/core/utils/notification_helper.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../domain/models/product.dart';
import '../../../../providers/global_inventory_provider.dart';
import '../../../../providers/inventory_provider.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../services/firebase_sync_service.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/services/ai_translation_service.dart';
import '../../checkout/checkout_screen.dart';
import '../master_admin_shell.dart';

class GlobalProductDialog extends ConsumerStatefulWidget {
  final Product? product;
  const GlobalProductDialog({super.key, this.product});

  @override
  ConsumerState<GlobalProductDialog> createState() =>
      _GlobalProductDialogState();
}

class _GlobalProductDialogState extends ConsumerState<GlobalProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _nameTamilCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _stockCtrl;
  String? _imagePath;
  List<String> _selectedAdditionalCategories = [];
  bool _allowHalfPortion = false;
  bool _isTranslating = false;
  bool _isActive = false;
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
    _selectedAdditionalCategories = widget.product?.additionalCategories != null
        ? List<String>.from(widget.product!.additionalCategories!)
        : [];
    _allowHalfPortion = widget.product?.allowHalfPortion ?? false;
    _isActive = widget.product?.isActive ?? false;
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
      final category = _categoryCtrl.text;
      final price = double.tryParse(_priceCtrl.text) ?? 0.0;
      final stockCount = int.tryParse(_stockCtrl.text) ?? 0;
      final String? barcode = null;

      String? manualTamilName = _nameTamilCtrl.text.trim();
      if (manualTamilName.isEmpty) manualTamilName = null;

      String productId;
      Product savedProduct;
      if (widget.product == null) {
        // Prevent duplicate products
        final existingProducts = ref.read(globalInventoryProvider);
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
      }

      String? base64Image;
      if (_imagePath != null && _imagePath!.isNotEmpty) {
        base64Image = _imagePath!;
        if (!_imagePath!.startsWith('data:')) {
          try {
            if (File(_imagePath!).existsSync()) {
              final bytes = File(_imagePath!).readAsBytesSync();
              base64Image = base64Encode(bytes);
            }
          } catch (e) {
            debugPrint("Error reading image file: $e");
          }
        }
      }

      if (widget.product == null) {
        savedProduct = ref
            .read(globalInventoryProvider.notifier)
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
              imageBase64: base64Image,
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
        );
        ref.read(globalInventoryProvider.notifier).updateProduct(savedProduct, imageBase64: base64Image);
      }

      // Save category to category_images if it doesn't exist
      final catBox = Hive.box<String>('category_images');
      if (!catBox.containsKey(category)) {
        catBox.put(category, '');
        FirebaseSyncService().pushGlobalCategoryToAllShops(category, '');
      }

      // Save product image path persistently if present
      if (base64Image != null && base64Image.isNotEmpty && productId.isNotEmpty) {
        // Put in local box for instant UI update
        Hive.box<String>('product_images').put(productId, base64Image);

        FirebaseFirestore.instance
            .collection('global_default_templates')
            .doc(productId)
            .set({'imageBase64': base64Image}, SetOptions(merge: true));
        FirebaseSyncService().pushGlobalProductImageToAllShops(
          productId,
          base64Image,
        );
      }

      Navigator.of(context).pop();
    }
  }

  void _delete() {
    if (widget.product != null) {
      ref
          .read(globalInventoryProvider.notifier)
          .deleteProduct(widget.product!.id);
      final box = Hive.box<String>('product_images');
      box.delete(widget.product!.id);
      final tBox = Hive.box<String>('product_translations');
      tBox.delete(widget.product!.id);
      Navigator.of(context).pop();
    }
  }

  Widget _buildNeumorphicField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kMasterWorkspaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
          BoxShadow(
            color: Color(0xFFD1D9E6),
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF4F46E5)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final theme = Theme.of(context);
    final isMasterAdmin =
        ref.watch(authProvider)?.id == 'host_admin' &&
        ref.watch(settingsProvider).showMasterAdminLook;
    final isDefaultProduct = widget.product?.isDefault ?? false;
    final isFieldEditable = !isDefaultProduct || isMasterAdmin;

    // Retrieve all existing categories for dropdown list
    ref.watch(categoryImagesProvider);
    final allProducts = ref.watch(globalInventoryProvider);
    final categorySet = allProducts.map((p) => p.category).toSet();
    final catBox = Hive.box<String>('category_images');
    for (var key in catBox.keys) {
      categorySet.add(key as String);
    }
    final existingCategories = categorySet.toList()..sort();

    return AlertDialog(
      backgroundColor: kMasterWorkspaceColor,
      title: Text(
        isEditing ? 'Edit Product' : 'Add Product',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                      color: kMasterWorkspaceColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.white,
                          blurRadius: 4,
                          offset: Offset(-2, -2),
                        ),
                        BoxShadow(
                          color: Color(0xFFD1D9E6),
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],
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
                                color: const Color(0xFF4F46E5),
                                size: 32,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Add Image',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 20),

                _buildNeumorphicField(
                  controller: _nameCtrl,
                  labelText: 'Product Name',
                  prefixIcon: Icons.shopping_bag,
                  enabled: isFieldEditable,
                  validator: (v) =>
                      v!.isEmpty ? 'Product name is required' : null,
                ),
                const SizedBox(height: 16),

                _buildNeumorphicField(
                  controller: _nameTamilCtrl,
                  labelText: 'Tamil Name (Optional)',
                  prefixIcon: Icons.language,
                  enabled: isFieldEditable,
                ),
                const SizedBox(height: 16),

                // Category with search autocomplete / arrow dropdown popup
                Row(
                  children: [
                    Expanded(
                      child: _buildNeumorphicField(
                        controller: _categoryCtrl,
                        labelText: 'Category',
                        prefixIcon: Icons.category,
                        enabled: isFieldEditable,
                        validator: (v) =>
                            v!.isEmpty ? 'Category is required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // The Dropdown Selection Arrow
                    Container(
                      decoration: BoxDecoration(
                        color: kMasterWorkspaceColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.white,
                            blurRadius: 4,
                            offset: Offset(-2, -2),
                          ),
                          BoxShadow(
                            color: Color(0xFFD1D9E6),
                            blurRadius: 4,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF4F46E5),
                        ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: const Text(
                    'Customers can buy half quantity.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  value: _allowHalfPortion,
                  activeColor: const Color(0xFF4F46E5),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: const Text(
                    'Turn off to hide this item from the checkout screen.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  value: _isActive,
                  activeColor: const Color(0xFF4F46E5),
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
                      onSelected: isFieldEditable
                          ? (val) => setState(() => _isVeg = true)
                          : null,
                      selectedColor: Colors.green.shade100,
                      checkmarkColor: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Non-Veg'),
                      selected: _isVeg == false,
                      onSelected: isFieldEditable
                          ? (val) => setState(() => _isVeg = false)
                          : null,
                      selectedColor: Colors.red.shade100,
                      checkmarkColor: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('None'),
                      selected: _isVeg == null,
                      onSelected: isFieldEditable
                          ? (val) => setState(() => _isVeg = null)
                          : null,
                      selectedColor: Colors.grey.shade300,
                      checkmarkColor: Colors.black,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildNeumorphicField(
                  controller: _priceCtrl,
                  labelText: 'Price (₹)',
                  prefixIcon: Icons.currency_rupee,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (isEditing && isFieldEditable)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.white,
                blurRadius: 4,
                offset: Offset(-2, -2),
              ),
              BoxShadow(
                color: Color(0xFFD1D9E6),
                blurRadius: 4,
                offset: Offset(2, 2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(isEditing ? 'Save Changes' : 'Confirm & Save'),
          ),
        ),
      ],
    );
  }
}

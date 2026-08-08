import '../../core/services/ai_service.dart';
import 'package:pos/core/utils/notification_helper.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/models/product.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/services/ai_translation_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/category_order_provider.dart';
import '../../../providers/product_order_provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../../../services/firebase_sync_service.dart';
import 'widgets/product_dialog.dart';
import '../../../core/utils/export_utils.dart';
import '../../../services/print_router_service.dart';
import '../../../providers/printer_provider.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToHome;

  const InventoryScreen({super.key, this.onBackToHome});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  void _showAiMenuGenerator(BuildContext context) {
    final controller = TextEditingController();
    bool isGenerating = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('AI Menu Generator'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter a prompt like "Suggest 3 summer drinks"'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  if (isGenerating) const Padding(padding: EdgeInsets.only(top: 16), child: CircularProgressIndicator()),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isGenerating ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isGenerating ? null : () async {
                    if (controller.text.trim().isEmpty) return;
                    setState(() => isGenerating = true);
                    final suggestions = await AiService().generateMenuItems(controller.text);
                    setState(() => isGenerating = false);
                    
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      if (suggestions.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not generate items.')));
                        return;
                      }
                      
                      for (var p in suggestions) {
                        ref.read(inventoryProvider.notifier).addProduct(
                          name: p.name,
                          nameTamil: p.nameTamil,
                          category: p.category,
                          price: p.price,
                          stockCount: p.stockCount,
                          allowHalfPortion: p.allowHalfPortion,
                        );
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${suggestions.length} items from AI!')));
                    }
                  },
                  child: const Text('Generate & Add'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  late TabController _tabController;
  late TextEditingController _searchController;
  int _activeTabIndex = 0;
  String _categorySearchQuery = '';
  bool _showLowStockOnly = false; // Filter state for low stock items

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _activeTabIndex = _tabController.index;
      });
    });
    _searchController = TextEditingController(
      text: ref.read(inventorySearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _showCategoryReorderDialog(
    BuildContext context,
    List<String> currentCategories,
  ) {
    final orderBox = Hive.box<String>('category_order');
    final orderedCategories = List<String>.from(currentCategories);
    orderedCategories.sort((a, b) {
      final oA = int.tryParse(orderBox.get(a) ?? '') ?? 9999;
      final oB = int.tryParse(orderBox.get(b) ?? '') ?? 9999;
      return oA.compareTo(oB);
    });

    showDialog(
      context: context,
      builder: (ctx) {
        final cats = List<String>.from(orderedCategories);
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.sort, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  'Reorder Categories',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: ReorderableListView.builder(
                itemCount: cats.length,
                onReorder: (oldIndex, newIndex) {
                  setS(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = cats.removeAt(oldIndex);
                    cats.insert(newIndex, item);
                  });
                },
                itemBuilder: (ctx, index) {
                  final cat = cats[index];
                  return Card(
                    key: ValueKey(cat),
                    color: Colors.white,
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple.withOpacity(0.1),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        cat,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_upward,
                              color: Colors.blueGrey,
                            ),
                            onPressed: index > 0
                                ? () {
                                    setS(() {
                                      final item = cats.removeAt(index);
                                      cats.insert(index - 1, item);
                                    });
                                  }
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_downward,
                              color: Colors.blueGrey,
                            ),
                            onPressed: index < cats.length - 1
                                ? () {
                                    setS(() {
                                      final item = cats.removeAt(index);
                                      cats.insert(index + 1, item);
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Order'),
                onPressed: () {
                  try {
                    ref.read(categoryOrderProvider.notifier).saveOrder(cats);
                  } catch (e) {
                    debugPrint('Save order error: $e');
                  }

                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }

                  setState(() {});

                  if (context.mounted) {
                    NotificationHelper.showCenter(
                      context,
                      'Category order saved! ✅',
                      isError: false,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProductReorderDialog(
    BuildContext context,
    List<Product> currentProducts,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final prods = List<Product>.from(currentProducts);
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.sort, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Reorder Products',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 500,
              child: ReorderableListView.builder(
                itemCount: prods.length,
                onReorder: (oldIndex, newIndex) {
                  setS(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = prods.removeAt(oldIndex);
                    prods.insert(newIndex, item);
                  });
                },
                itemBuilder: (ctx, index) {
                  final prod = prods[index];
                  return Card(
                    key: ValueKey(prod.id),
                    color: Colors.white,
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        prod.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_upward,
                              color: Colors.blueGrey,
                            ),
                            onPressed: index > 0
                                ? () {
                                    setS(() {
                                      final item = prods.removeAt(index);
                                      prods.insert(index - 1, item);
                                    });
                                  }
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_downward,
                              color: Colors.blueGrey,
                            ),
                            onPressed: index < prods.length - 1
                                ? () {
                                    setS(() {
                                      final item = prods.removeAt(index);
                                      prods.insert(index + 1, item);
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Order'),
                onPressed: () {
                  try {
                    final orderedIds = prods.map((p) => p.id).toList();
                    ref
                        .read(productOrderProvider.notifier)
                        .saveOrder(orderedIds);
                  } catch (e) {
                    debugPrint('Save order error: $e');
                  }

                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }

                  setState(() {});

                  if (context.mounted) {
                    NotificationHelper.showCenter(
                      context,
                      'Product order saved! ✅',
                      isError: false,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(filteredInventoryProvider);
    final allProducts = ref.watch(inventoryProvider);
    final categoryFilter = ref.watch(inventoryCategoryFilterProvider);
    ref.watch(
      categoryImagesProvider,
    ); // Rebuild when a category is added manually
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(authProvider);
    final role = session?.role;
    final settingsBox = Hive.box<String>('settings');
    final showStockQuantity =
        (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
    final showStock =
        showStockQuantity && (session?.hasStockManagement == true);

    final isStaff = role != UserRole.admin;

    // Apply filters to products list
    final displayedProductsRaw = products.where((p) {
      final dFilter = settings.dietaryFilter.toLowerCase();
      if ((dFilter == 'veg' || dFilter == 'pure_veg') && p.isVeg == false) return false;
      if ((dFilter == 'nonveg' || dFilter == 'non-veg') && p.isVeg == true) return false;
      if (_showLowStockOnly && p.stockCount > 5) return false;
      return true;
    }).toList();
    ref.watch(productOrderProvider);
    final productOrderMap = ref
        .read(productOrderProvider.notifier)
        .getOrderMap();

    final displayedProducts = isStaff
        ? displayedProductsRaw.where((p) => p.isActive).toList()
        : displayedProductsRaw;

    // Apply product ordering
    displayedProducts.sort((a, b) {
      final orderA = productOrderMap[a.id] ?? 9999;
      final orderB = productOrderMap[b.id] ?? 9999;
      if (orderA != orderB) return orderA.compareTo(orderB);
      return a.name.compareTo(b.name);
    });

    // Build unique categories and their product counts (using dietary filtered products)
    final Map<String, int> categoryCounts = {};
    for (var p in displayedProductsRaw) {
      if (isStaff && !p.isActive) continue;
      categoryCounts[p.category] = (categoryCounts[p.category] ?? 0) + 1;
    }

    // Include categories that might have been added manually without products yet
    final catImagesBox = Hive.box<String>('category_images');
    for (var key in catImagesBox.keys) {
      final catName = key as String;
      if (!categoryCounts.containsKey(catName)) {
        categoryCounts[catName] = 0;
      }
    }

    ref.watch(categoryOrderProvider);
    final orderMap = ref.read(categoryOrderProvider.notifier).getOrderMap();

    final dBox = Hive.box<String>('category_dietary');
    final shopDiet = settings.dietaryFilter.toLowerCase();
    final isVegShop = shopDiet == 'veg' || shopDiet == 'pure_veg';
    final isNonVegShop = shopDiet == 'nonveg' || shopDiet == 'non-veg';

    final filteredCategories =
        categoryCounts.keys
            .where((c) {
              if (!c.toLowerCase().contains(_categorySearchQuery.toLowerCase())) {
                return false;
              }
              if (dBox.isOpen) {
                final cType = dBox.get(c) ?? 'both';
                if (isVegShop && (cType == 'nonveg' || cType == 'non-veg')) return false;
                if (isNonVegShop && cType == 'veg') return false;
              }
              // Hide category if shop is Veg and all products in this category are non-veg
              if (isVegShop) {
                final prodsInCat = allProducts.where((p) => p.category == c);
                if (prodsInCat.isNotEmpty && prodsInCat.every((p) => p.isVeg == false)) {
                  return false;
                }
              }
              // Hide category if shop is Non-Veg and all products in this category are veg
              if (isNonVegShop) {
                final prodsInCat = allProducts.where((p) => p.category == c);
                if (prodsInCat.isNotEmpty && prodsInCat.every((p) => p.isVeg == true)) {
                  return false;
                }
              }
              return true;
            })
            .toList()
          ..sort((a, b) {
            final orderA = orderMap[a] ?? 9999;
            final orderB = orderMap[b] ?? 9999;
            if (orderA != orderB) return orderA.compareTo(orderB);
            return a.compareTo(b);
          });

    final canPop = Navigator.canPop(context);
    return Scaffold(
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: theme.colorScheme.primary),
              title: Text(
                'Inventory'.tr(ref.watch(languageProvider)),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                  fontSize: 20,
                ),
              ),
              actions: [
                if (isStaff == false)
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                    onPressed: () => _showAiMenuGenerator(context),
                  ),
                GestureDetector(
                  onTap: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: UiUtils.getLogoProvider(
                        ref.watch(settingsProvider).shopLogoPath,
                      ),
                      child:
                          ref.watch(settingsProvider).shopLogoPath == null ||
                              ref.watch(settingsProvider).shopLogoPath!.isEmpty
                          ? const Icon(
                              Icons.store,
                              color: Color(0xFF64748B),
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _tabController.animateTo(0),
                  child: AnimatedScale(
                    scale: _activeTabIndex == 0 ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 140,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _activeTabIndex == 0
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _activeTabIndex == 0
                              ? Colors.green.shade400
                              : Colors.red.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inventory,
                            color: _activeTabIndex == 0
                                ? Colors.green.shade700
                                : Colors.red.shade400,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PRODUCTS'.tr(ref.watch(languageProvider)),
                            style: TextStyle(
                              color: _activeTabIndex == 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () => _tabController.animateTo(1),
                  child: AnimatedScale(
                    scale: _activeTabIndex == 1 ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 140,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _activeTabIndex == 1
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _activeTabIndex == 1
                              ? Colors.green.shade400
                              : Colors.red.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.category,
                            color: _activeTabIndex == 1
                                ? Colors.green.shade700
                                : Colors.red.shade400,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CATEGORIES'.tr(ref.watch(languageProvider)),
                            style: TextStyle(
                              color: _activeTabIndex == 1
                                  ? Colors.green.shade700
                                  : Colors.red.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // PRODUCTS TAB
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    ref
                                        .read(
                                          inventorySearchQueryProvider.notifier,
                                        )
                                        .setQuery(value);
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search products...'.tr(
                                      ref.watch(languageProvider),
                                    ),
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.sort),
                                tooltip: 'Reorder Products',
                                onPressed: () {
                                  _showProductReorderDialog(
                                    context,
                                    displayedProducts,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.print),
                                tooltip: 'Print / Export Inventory',
                                onSelected: (value) async {
                                  try {
                                    if (value == 'print') {
                                      final printTamil = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Print Language'),
                                          content: const Text(
                                            'Select the language for the inventory list print.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('English'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text(
                                                'Tamil (Image Print)',
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (printTamil != null) {
                                        await PrintRouterService.printInventoryList(
                                          products: displayedProducts,
                                          settings: settings,
                                          shopName: settings.shopName,
                                          printerNotifier: ref.read(
                                            printerProvider.notifier,
                                          ),
                                          printTamil: printTamil,
                                        );
                                      }
                                    } else if (value == 'pdf') {
                                      final bytes =
                                          await ExportUtils.exportInventoryToPdf(
                                            displayedProducts,
                                            settings.shopName,
                                            showStock: showStock,
                                          );
                                      final tempDir =
                                          await getTemporaryDirectory();
                                      final file = File(
                                        '${tempDir.path}/inventory_${DateTime.now().millisecondsSinceEpoch}.pdf',
                                      );
                                      await file.writeAsBytes(bytes);
                                      await Share.shareXFiles([
                                        XFile(file.path),
                                      ], text: 'Inventory PDF');
                                    } else if (value == 'excel') {
                                      final bytes =
                                          await ExportUtils.exportInventoryToExcel(
                                            displayedProducts,
                                            settings.shopName,
                                            showStock: showStock,
                                          );
                                      final tempDir =
                                          await getTemporaryDirectory();
                                      final file = File(
                                        '${tempDir.path}/inventory_${DateTime.now().millisecondsSinceEpoch}.xlsx',
                                      );
                                      await file.writeAsBytes(bytes);
                                      await Share.shareXFiles([
                                        XFile(file.path),
                                      ], text: 'Inventory Excel');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      NotificationHelper.showCenter(
                                        context,
                                        'Failed to process: $e',
                                        isError: true,
                                      );
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'print',
                                    child: Text('Print via POS'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'pdf',
                                    child: Text('Export as PDF'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'excel',
                                    child: Text('Export as Excel'),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              // Low Stock Toggle Button with indicator badge
                              if (showStock)
                                FilterChip(
                                  selected: _showLowStockOnly,
                                  onSelected: (selected) {
                                    setState(() {
                                      _showLowStockOnly = selected;
                                    });
                                  },
                                  label: Row(
                                    children: [
                                      const Icon(
                                        Icons.warning,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Low Stock Only',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (allProducts
                                          .where((p) => p.stockCount <= 5)
                                          .isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${allProducts.where((p) => p.stockCount <= 5).length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  backgroundColor: Colors.white,
                                  selectedColor: Colors.orange.withOpacity(
                                    0.15,
                                  ),
                                  checkmarkColor: Colors.orange,
                                ),
                            ],
                          ),
                          if (categoryFilter != null &&
                              categoryFilter.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Chip(
                                label: Text(
                                  'Category: $categoryFilter',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () {
                                  ref
                                      .read(
                                        inventoryCategoryFilterProvider
                                            .notifier,
                                      )
                                      .setCategory(null);
                                },
                                backgroundColor: theme.colorScheme.primary
                                    .withOpacity(0.1),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: displayedProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _showLowStockOnly
                                        ? 'No low stock products found.'
                                        : 'No products found.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : (() {
                              final isDesktopWidth = MediaQuery.of(context).size.width >= 600;
                              final canReorder = !isDesktopWidth && categoryFilter != null;
                              final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktopWidth
                                    ? (MediaQuery.of(context).size.width / 180).floor()
                                    : 3,
                                childAspectRatio: 0.72,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              );
                              
                              if (canReorder) {
                                return ReorderableGridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  gridDelegate: gridDelegate,
                                  itemCount: displayedProducts.length,
                                  onReorder: (oldIndex, newIndex) {
                                    setState(() {
                                      final element = displayedProducts.removeAt(oldIndex);
                                      displayedProducts.insert(newIndex, element);
                                      final orderedIds = displayedProducts.map((p) => p.id).toList();
                                      ref.read(productOrderProvider.notifier).saveOrder(orderedIds);
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    final product = displayedProducts[index];
                                    return ProductCard(
                                      key: ValueKey(product.id),
                                      product: product,
                                    );
                                  },
                                );
                              } else {
                                return GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  gridDelegate: gridDelegate,
                                  itemCount: displayedProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = displayedProducts[index];
                                    return ProductCard(
                                      key: ValueKey(product.id),
                                      product: product,
                                    );
                                  },
                                );
                              }
                            })(),
                    ),
                  ],
                ),
                // CATEGORIES TAB
                ValueListenableBuilder(
                  valueListenable: Hive.box<String>(
                    'category_images',
                  ).listenable(),
                  builder: (context, box, _) {
                    // Recompute categories here to guarantee freshness
                    final Map<String, int> freshCounts = {};
                    for (var p in allProducts) {
                      freshCounts[p.category] =
                          (freshCounts[p.category] ?? 0) + 1;
                    }
                    for (var key in box.keys) {
                      final catName = key as String;
                      if (!freshCounts.containsKey(catName))
                        freshCounts[catName] = 0;
                    }
                    final orderMap = ref
                        .read(categoryOrderProvider.notifier)
                        .getOrderMap();
                    final freshFiltered =
                        freshCounts.keys
                            .where(
                              (c) => c.toLowerCase().contains(
                                _categorySearchQuery.toLowerCase(),
                              ),
                            )
                            .toList()
                          ..sort((a, b) {
                            final orderA = orderMap[a] ?? 9999;
                            final orderB = orderMap[b] ?? 9999;
                            if (orderA != orderB)
                              return orderA.compareTo(orderB);
                            return a.compareTo(b);
                          });

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      _categorySearchQuery = value;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    hintText: 'Search categories...',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Reorder Categories',
                                icon: const Icon(
                                  Icons.sort,
                                  color: Colors.deepPurple,
                                ),
                                onPressed: () => _showCategoryReorderDialog(
                                  context,
                                  freshFiltered,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: freshFiltered.isEmpty
                              ? const Center(
                                  child: Text('No categories found.'),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isDesktop =
                                        constraints.maxWidth >= 800;

                                    Widget buildCategoryItem(
                                      String category,
                                      int? count,
                                      ThemeData theme,
                                      bool isGrid,
                                    ) {
                                      final box = Hive.box<String>(
                                        'category_images',
                                      );
                                      final imgPath = box.get(category);
                                      final isTamil =
                                          ref.watch(languageProvider) == 'ta';
                                      final displayName = isTamil
                                          ? category.tr('ta')
                                          : category;

                                      void handleEdit() {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => CategoryDialog(
                                            initialCategory: category,
                                          ),
                                        ).then((_) => setState(() {}));
                                      }

                                      void handleDelete() {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Category'),
                                            content: Text(
                                              'Are you sure you want to delete the category "$category"? This will also delete all products in this category.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  final productsNotifier = ref.read(inventoryProvider.notifier);
                                                  final allProds = ref.read(inventoryProvider);
                                                  for (var p in allProds) {
                                                    if (p.category == category) {
                                                      productsNotifier.deleteProduct(p.id);
                                                    }
                                                  }

                                                  Hive.box<String>('category_images').delete(category);
                                                  Hive.box<String>('category_dietary').delete(category);
                                                  Hive.box<String>('category_translations').delete(category);
                                                  Hive.box<bool>('category_status').delete(category);
                                                  FirebaseSyncService().deleteCategory(category);
                                                  FirebaseSyncService().pushSettingsSync();
                                                  setState(() {});
                                                  Navigator.pop(ctx);
                                                },
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      void handleTap() {
                                        _tabController.animateTo(0);
                                        _searchController.clear();
                                        ref
                                            .read(
                                              inventorySearchQueryProvider
                                                  .notifier,
                                            )
                                            .setQuery('');
                                        ref
                                            .read(
                                              inventoryCategoryFilterProvider
                                                  .notifier,
                                            )
                                            .setCategory(category);
                                      }

                                      if (isGrid) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.04),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(16),
                                              onTap: handleTap,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  Expanded(
                                                    child: Stack(
                                                      children: [
                                                        Positioned.fill(
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: theme.colorScheme.secondary.withOpacity(0.1),
                                                              borderRadius: const BorderRadius.vertical(
                                                                top: Radius.circular(14),
                                                              ),
                                                              image: ImageUtils.safeImageProvider(imgPath) != null
                                                                  ? DecorationImage(
                                                                      image: ImageUtils.safeImageProvider(imgPath)!,
                                                                      fit: BoxFit.cover,
                                                                    )
                                                                  : null,
                                                            ),
                                                            child: ImageUtils.safeImageProvider(imgPath) == null
                                                                ? Icon(
                                                                    Icons.category,
                                                                    size: 48,
                                                                    color: theme.colorScheme.secondary,
                                                                  )
                                                                : null,
                                                          ),
                                                        ),
                                                        // Active/Inactive toggle switch badge at top-right
                                                        Positioned(
                                                          top: 8,
                                                          right: 8,
                                                          child: ValueListenableBuilder(
                                                            valueListenable: Hive.box<bool>('category_status').listenable(keys: [category]),
                                                            builder: (context, box, _) {
                                                              final isActive = box.get(category, defaultValue: true) ?? true;
                                                              return Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.white.withOpacity(0.92),
                                                                  borderRadius: BorderRadius.circular(20),
                                                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Text(
                                                                      isActive ? 'Active' : 'Hidden',
                                                                      style: TextStyle(
                                                                        fontSize: 11,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 2),
                                                                    Transform.scale(
                                                                      scale: 0.65,
                                                                      child: Switch(
                                                                        value: isActive,
                                                                        onChanged: (val) {
                                                                          box.put(category, val);
                                                                          FirebaseSyncService().pushSettingsSync();
                                                                        },
                                                                        activeColor: theme.colorScheme.primary,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                displayName,
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 15,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              const SizedBox(height: 2),
                                                              Text(
                                                                '${count ?? 0} Products',
                                                                style: TextStyle(
                                                                  color: Colors.grey.shade600,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              icon: Icon(
                                                                Icons.edit,
                                                                size: 18,
                                                                color: theme.colorScheme.primary,
                                                              ),
                                                              onPressed: handleEdit,
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(),
                                                            ),
                                                            const SizedBox(width: 12),
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons.delete_outline,
                                                                size: 18,
                                                                color: Colors.red,
                                                              ),
                                                              onPressed: handleDelete,
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      } else {
                                        return Card(
                                          elevation: 0,
                                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: BorderSide(color: Colors.grey.shade200),
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: handleTap,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme.secondary.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(10),
                                                      image: ImageUtils.safeImageProvider(imgPath) != null
                                                          ? DecorationImage(
                                                              image: ImageUtils.safeImageProvider(imgPath)!,
                                                              fit: BoxFit.cover,
                                                            )
                                                          : null,
                                                    ),
                                                    child: ImageUtils.safeImageProvider(imgPath) == null
                                                        ? Icon(
                                                            Icons.category,
                                                            color: theme.colorScheme.secondary,
                                                            size: 24,
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          displayName,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          '${count ?? 0} Products',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey.shade600,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  ValueListenableBuilder(
                                                    valueListenable: Hive.box<bool>('category_status').listenable(keys: [category]),
                                                    builder: (context, box, _) {
                                                      final isActive = box.get(category, defaultValue: true) ?? true;
                                                      return Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            isActive ? 'Active' : 'Hidden',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: isActive ? Colors.green.shade700 : Colors.grey.shade500,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 2),
                                                          Transform.scale(
                                                            scale: 0.75,
                                                            child: Switch(
                                                              value: isActive,
                                                              onChanged: (val) {
                                                                box.put(category, val);
                                                                FirebaseSyncService().pushSettingsSync();
                                                              },
                                                              activeColor: theme.colorScheme.primary,
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.edit,
                                                      size: 20,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                    onPressed: handleEdit,
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      size: 20,
                                                      color: Colors.red,
                                                    ),
                                                    onPressed: handleDelete,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    }

                                    if (isDesktop) {
                                      return GridView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        gridDelegate:
                                            const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 260,
                                              childAspectRatio: 1.0,
                                              crossAxisSpacing: 16,
                                              mainAxisSpacing: 16,
                                            ),
                                        itemCount: freshFiltered.length,
                                        itemBuilder: (context, index) {
                                          final category = freshFiltered[index];
                                          final count = freshCounts[category];
                                          return buildCategoryItem(
                                            category,
                                            count,
                                            theme,
                                            true,
                                          );
                                        },
                                      );
                                    } else {
                                      return ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        itemCount: freshFiltered.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final category = freshFiltered[index];
                                          final count = freshCounts[category];
                                          return buildCategoryItem(
                                            category,
                                            count,
                                            theme,
                                            false,
                                          );
                                        },
                                      );
                                    }
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _activeTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ProductDialog(),
                );
              },
              icon: const Icon(Icons.add),
              label: Text('Add Product'.tr(ref.watch(languageProvider))),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                showDialog<String>(
                  context: context,
                  builder: (context) => const CategoryDialog(),
                ).then((newCategory) {
                  if (newCategory != null) {
                    NotificationHelper.showCenter(
                      context,
                      'Category "$newCategory" created! You can now assign it to products.',
                      isError: false,
                    );
                    setState(() {}); // Refresh categories view
                  }
                });
              },
              icon: const Icon(Icons.create_new_folder),
              label: Text('Add Category'.tr(ref.watch(languageProvider))),
            ),
    );
  }
}

class ProductCard extends ConsumerWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stockColor = product.stockCount > 5
        ? Colors.green
        : (product.stockCount > 0 ? Colors.orange : Colors.red);
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(authProvider);
    final settingsBox = Hive.box<String>('settings');
    final showStockQuantity =
        (settingsBox.get('showStockQuantity') ?? 'true') == 'true';
    final showStock =
        showStockQuantity && (session?.hasStockManagement == true);

    return Opacity(
      opacity: product.isActive ? 1.0 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: product.isActive
                ? Colors.green.shade400
                : Colors.red.shade400,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: product.isActive
                  ? Colors.black.withValues(alpha: 0.04)
                  : Colors.red.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => ProductDialog(product: product),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Product Image at Top
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: Hive.box<String>(
                      'product_images',
                    ).listenable(keys: [product.id]),
                    builder: (context, imgBox, _) {
                      final currentImgPath = imgBox.get(product.id);
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          image:
                              ImageUtils.safeImageProvider(currentImgPath) !=
                                  null
                              ? DecorationImage(
                                  image: ImageUtils.safeImageProvider(
                                    currentImgPath,
                                  )!,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: Stack(
                          children: [
                            if (ImageUtils.safeImageProvider(currentImgPath) ==
                                null)
                              Center(
                                child: Icon(
                                  Icons.image,
                                  color: Colors.grey.shade400,
                                  size: 40,
                                ),
                              ),
                            if (product.productNumber != null &&
                                product.productNumber!.trim().isNotEmpty)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(1, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    product.productNumber!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            if (showStock &&
                                product.trackInventory &&
                                product.stockCount <= 5)
                              Positioned(
                                top: 8,
                                left:
                                    (product.productNumber != null &&
                                        product.productNumber!
                                            .trim()
                                            .isNotEmpty)
                                    ? 44
                                    : 8,
                                child: product.stockCount <= 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'OUT OF STOCK',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.warning,
                                          color: Colors.orange,
                                          size: 20,
                                        ),
                                      ),
                              ),
                            if (!product.isActive)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade600,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'INACTIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  if (product.isVeg != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 6.0,
                                      ),
                                      child: Icon(
                                        product.isVeg == true
                                            ? Icons.eco
                                            : Icons.restaurant,
                                        color: product.isVeg == true
                                            ? Colors.green
                                            : Colors.red,
                                        size: 14,
                                      ),
                                    ),
                                  Text(
                                    ref.watch(languageProvider) == 'ta'
                                        ? (product.nameTamil != null &&
                                                  product.nameTamil!.isNotEmpty
                                              ? product.nameTamil!
                                              : product.name)
                                        : product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (showStock &&
                              product.trackInventory &&
                              product.stockCount <= 5)
                            const Icon(
                              Icons.warning,
                              color: Colors.orange,
                              size: 18,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (ref.watch(languageProvider) == 'ta' &&
                                product.categoryTamil != null &&
                                product.categoryTamil!.isNotEmpty)
                            ? product.categoryTamil!
                            : product.category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '₹${product.price.toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showStock && product.trackInventory)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: stockColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Qty: ${product.stockCount}',
                                style: TextStyle(
                                  color: stockColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dialog to Add or Edit Category with Image
class CategoryDialog extends ConsumerStatefulWidget {
  final String? initialCategory;
  const CategoryDialog({super.key, this.initialCategory});

  @override
  ConsumerState<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _tamilNameCtrl = TextEditingController();
  String? _imagePath;
  String _dietaryType = 'both';

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _nameCtrl.text = widget.initialCategory!;
      _imagePath = Hive.box<String>(
        'category_images',
      ).get(widget.initialCategory);
      final dBox = Hive.box<String>('category_dietary');
      if (dBox.isOpen) {
        final fetchedDiet = dBox.get(widget.initialCategory) ?? 'both';
        _dietaryType = (fetchedDiet == 'non-veg') ? 'nonveg' : fetchedDiet;
      }
      final tBox = Hive.box<String>('category_translations');
      if (tBox.isOpen) {
        _tamilNameCtrl.text = tBox.get(widget.initialCategory) ?? '';
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 300,
        maxHeight: 300,
      );
      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'category_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = File('${appDir.path}/$fileName');
        final bytes = await image.readAsBytes();
        await savedImage.writeAsBytes(bytes);

        setState(() => _imagePath = savedImage.path);
      }
    } catch (e) {
      NotificationHelper.showCenter(
        context,
        'Error selecting image: $e',
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tamilNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.initialCategory == null ? 'Add Category' : 'Edit Category',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
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
                              size: 28,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add Image',
                              style: TextStyle(
                                fontSize: 10,
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
                decoration: InputDecoration(
                  labelText: 'Category'.tr(ref.watch(languageProvider)),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category),
                ),
                validator: (v) =>
                    v!.isEmpty ? 'Category name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tamilNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tamil Name (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _dietaryType,
                decoration: const InputDecoration(
                  labelText: 'Dietary Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.restaurant_menu),
                ),
                items: const [
                  DropdownMenuItem(value: 'both', child: Text('Both (Default)')),
                  DropdownMenuItem(value: 'veg', child: Text('Veg')),
                  DropdownMenuItem(value: 'nonveg', child: Text('Non-Veg')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _dietaryType = val);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              String name = _nameCtrl.text.trim();
              final tamilName = _tamilNameCtrl.text.trim();
              final box = Hive.box<String>('category_images');

              // Check for case-insensitive duplicates
              for (final existingCat in box.keys) {
                if (existingCat.toString().toLowerCase() ==
                        name.toLowerCase() &&
                    (widget.initialCategory == null ||
                        existingCat.toString().toLowerCase() !=
                            widget.initialCategory!.toLowerCase())) {
                  name = existingCat.toString();
                  break;
                }
              }

              // If renaming an existing category
              if (widget.initialCategory != null &&
                  widget.initialCategory != name) {
                final oldName = widget.initialCategory!;
                box.delete(oldName);
                Hive.box<String>('category_dietary').delete(oldName);
                Hive.box<String>('category_translations').delete(oldName);
                Hive.box<bool>('category_status').delete(oldName);
                FirebaseSyncService().deleteCategory(oldName);

                // Update all products
                final products = ref.read(inventoryProvider);
                for (final p in products) {
                  final matchPrimary = (p.category == oldName);
                  final matchAdditional = (p.additionalCategories != null && p.additionalCategories!.contains(oldName));

                  if (matchPrimary || matchAdditional) {
                    final newPrimary = matchPrimary ? name : p.category;
                    List<String>? newAdditional;
                    if (p.additionalCategories != null) {
                      newAdditional = p.additionalCategories!.map((c) => c == oldName ? name : c).toList();
                    }
                    final updatedP = p.copyWith(
                      category: newPrimary,
                      additionalCategories: newAdditional,
                    );
                    ref
                        .read(inventoryProvider.notifier)
                        .updateProduct(updatedP);
                  }
                }
              }

              final path = _imagePath ?? '';
              box.put(name, path);

              String base64Image = '';
              if (path.isNotEmpty) {
                if (path.startsWith('data:')) {
                  base64Image = path;
                } else {
                  try {
                    if (File(path).existsSync()) {
                      base64Image = base64Encode(File(path).readAsBytesSync());
                    }
                  } catch (e) {
                    debugPrint("File read error: $e");
                  }
                }
              }
              FirebaseSyncService().pushCategory(
                name,
                base64Image,
                tamilName: tamilName.isNotEmpty ? tamilName : null,
                dietaryType: _dietaryType,
              );
              
              final dBox = Hive.box<String>('category_dietary');
              dBox.put(name, _dietaryType);

              final tBox = Hive.box<String>('category_translations');
              if (tBox.isOpen) {
                if (tamilName.isNotEmpty) {
                  tBox.put(name, tamilName);
                } else {
                  tBox.delete(name);
                }
              }

              Navigator.pop(context, name);
              NotificationHelper.showCenter(
                context,
                widget.initialCategory == null
                    ? 'Category "$name" created successfully!'
                    : 'Category "$name" updated successfully!',
                isError: false,
              );
            }
          },
          child: const Text('Confirm & Save'),
        ),
      ],
    );
  }
}

import 'package:pos/core/utils/notification_helper.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../../domain/models/product.dart';
import '../../../providers/global_inventory_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/category_order_provider.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/services/ai_translation_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firebase_sync_service.dart';
import 'widgets/global_product_dialog.dart';
import 'master_admin_shell.dart';

class GlobalInventoryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToHome;
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;

  const GlobalInventoryScreen({
    super.key,
    this.onBackToHome,
    this.onOpenDrawer,
    this.hideAppBar = false,
  });

  @override
  ConsumerState<GlobalInventoryScreen> createState() =>
      _GlobalInventoryScreenState();
}

class _GlobalInventoryScreenState extends ConsumerState<GlobalInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;
  int _activeTabIndex = 0;
  String _categorySearchQuery = '';

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
      text: ref.read(globalInventorySearchQueryProvider),
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
    final orderMap = ref
        .read(globalCategoryOrderProvider.notifier)
        .getOrderMap();
    final orderedCategories = List<String>.from(currentCategories);
    orderedCategories.sort((a, b) {
      final oA = orderMap[a] ?? 9999;
      final oB = orderMap[b] ?? 9999;
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
              width: double.maxFinite,
              height: 400,
              child: ReorderableListView.builder(
                itemCount: cats.length,
                onReorder: (oldIndex, newIndex) {
                  setS(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = cats.removeAt(oldIndex);
                    cats.insert(newIndex, item);
                  });
                },
                itemBuilder: (ctx, index) {
                  final cat = cats[index];
                  return ListTile(
                    key: ValueKey(cat),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      cat,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                    tileColor: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade200),
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
                onPressed: () async {
                  await ref
                      .read(globalCategoryOrderProvider.notifier)
                      .updateOrder(cats);
                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() {});
                    NotificationHelper.showCenter(
                      context,
                      'Global Category order saved! ✅',
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
    final products = ref.watch(filteredGlobalInventoryProvider);
    final allProducts = ref.watch(globalInventoryProvider);
    final categoryFilter = ref.watch(globalInventoryCategoryFilterProvider);
    ref.watch(categoryImagesProvider); // Rebuild when category added
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(authProvider);
    final showStock =
        settings.showStockQuantity && (session?.hasStockManagement == true);

    // Build unique categories and their product counts
    final Map<String, int> categoryCounts = {};
    for (var p in allProducts) {
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

    final dBox = Hive.box<String>('category_dietary');
    final filteredCategories =
        categoryCounts.keys
            .where((c) {
              if (!c.toLowerCase().contains(_categorySearchQuery.toLowerCase())) {
                return false;
              }
              if (dBox.isOpen) {
                final cType = dBox.get(c) ?? 'both';
                if ((settings.dietaryFilter == 'veg' || settings.dietaryFilter == 'pure_veg') && (cType == 'nonveg' || cType == 'non-veg')) return false;
                if ((settings.dietaryFilter == 'nonveg' || settings.dietaryFilter == 'non-veg') && cType == 'veg') return false;
              }
              return true;
            })
            .toList()
          ..sort();

    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: kMasterWorkspaceColor,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: const Text(
                'Global Inventory',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              backgroundColor: kMasterWorkspaceColor,
              elevation: 0,
              foregroundColor: const Color(0xFF1E293B),
              automaticallyImplyLeading: !isDesktop,
              leading: isDesktop
                  ? null
                  : (widget.onOpenDrawer != null
                        ? IconButton(
                            icon: const Icon(
                              Icons.menu,
                              color: Color(0xFF1E293B),
                            ),
                            onPressed: widget.onOpenDrawer,
                          )
                        : BackButton(
                            color: const Color(0xFF1E293B),
                            onPressed:
                                widget.onBackToHome ??
                                () => Navigator.pop(context),
                          )),
            ),
      body: Column(
        children: [
          Container(
            color: kMasterWorkspaceColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Container(
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
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF4F46E5),
                  unselectedLabelColor: Colors.grey,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFE0E7FF),
                  ),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.inventory, size: 20),
                      text: 'PRODUCTS'.tr(ref.watch(languageProvider)),
                    ),
                    Tab(
                      icon: const Icon(Icons.category, size: 20),
                      text: 'CATEGORIES'.tr(ref.watch(languageProvider)),
                    ),
                  ],
                ),
              ),
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
                                child: Container(
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
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (value) {
                                      ref
                                          .read(
                                            globalInventorySearchQueryProvider
                                                .notifier,
                                          )
                                          .setQuery(value);
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Search products...'.tr(
                                        ref.watch(languageProvider),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        color: Color(0xFF64748B),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                ),
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
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                deleteIcon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Color(0xFF4F46E5),
                                ),
                                onDeleted: () {
                                  ref
                                      .read(
                                        globalInventoryCategoryFilterProvider
                                            .notifier,
                                      )
                                      .setCategory(null);
                                },
                                backgroundColor: const Color(0xFFE0E7FF),
                                side: BorderSide.none,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: products.isEmpty
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
                                    'No products found.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        MediaQuery.of(context).size.width < 600
                                        ? 2
                                        : (MediaQuery.of(context).size.width /
                                                  180)
                                              .floor(),
                                    childAspectRatio: 0.72,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index];
                                return ProductCard(product: product);
                              },
                            ),
                    ),
                  ],
                ),
                // CATEGORIES TAB
                ValueListenableBuilder(
                  valueListenable: Hive.box<String>(
                    'category_images',
                  ).listenable(),
                  builder: (context, box, _) {
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
                    final orderNotifier = ref.watch(
                      globalCategoryOrderProvider.notifier,
                    );
                    final orderMap = orderNotifier.getOrderMap();

                    final freshFiltered =
                        freshCounts.keys
                            .where(
                              (c) => c.toLowerCase().contains(
                                _categorySearchQuery.toLowerCase(),
                              ),
                            )
                            .toList()
                          ..sort((a, b) {
                            final oA = orderMap[a] ?? 9999;
                            final oB = orderMap[b] ?? 9999;
                            if (oA != oB) return oA.compareTo(oB);
                            return a.compareTo(b);
                          });

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
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
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        _categorySearchQuery = value;
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Search categories...',
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Color(0xFF64748B),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: 'Reorder Categories',
                                icon: const Icon(
                                  Icons.sort,
                                  color: Color(0xFF4F46E5),
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
                                    final isDesktop = constraints.maxWidth > 600;
                                    
                                    Widget buildItem(BuildContext context, int index) {
                                    final category = freshFiltered[index];
                                    final count = freshCounts[category];

                                    final box = Hive.box<String>(
                                      'category_images',
                                    );
                                    final imgPath = box.get(category);

                                    final isTamil =
                                        ref.watch(languageProvider) == 'ta';
                                    final displayName = isTamil
                                        ? category.tr('ta')
                                        : category;

                                      return Container(
                                        margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
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
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () {
                                            _tabController.animateTo(0);
                                            _searchController.clear();
                                            ref.read(globalInventorySearchQueryProvider.notifier).setQuery('');
                                            ref.read(globalInventoryCategoryFilterProvider.notifier).setCategory(category);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: theme.colorScheme.secondary.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
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
                                                              size: 20,
                                                            )
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        displayName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                          color: Color(0xFF1E293B),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Spacer(),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Chip(
                                                      label: Text(
                                                        '$count Products',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                          color: Color(0xFF4F46E5),
                                                        ),
                                                      ),
                                                      backgroundColor: const Color(0xFFE0E7FF),
                                                      side: BorderSide.none,
                                                      padding: EdgeInsets.zero,
                                                    ),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.edit_outlined,
                                                            color: Colors.blue,
                                                            size: 20,
                                                          ),
                                                          onPressed: () {
                                                            showDialog<String>(
                                                              context: context,
                                                              builder: (context) => CategoryDialog(initialCategory: category),
                                                            ).then((updatedName) {
                                                              if (updatedName != null) {
                                                                setState(() {});
                                                              }
                                                            });
                                                          },
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.delete_outline,
                                                            color: Colors.red,
                                                            size: 20,
                                                          ),
                                                          onPressed: () {
                                                            showDialog(
                                                              context: context,
                                                              builder: (ctx) => AlertDialog(
                                                                title: const Text('Delete Category'),
                                                                content: Text('Are you sure you want to delete the category "$category"? This will also delete all products in this category.'),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () => Navigator.pop(ctx),
                                                                    child: const Text('Cancel'),
                                                                  ),
                                                                  TextButton(
                                                                    onPressed: () {
                                                                      final globalNotifier = ref.read(globalInventoryProvider.notifier);
                                                                      final allProds = ref.read(globalInventoryProvider);
                                                                      for (var p in allProds) {
                                                                        if (p.category == category) {
                                                                          globalNotifier.deleteProduct(p.id);
                                                                        }
                                                                      }

                                                                      Hive.box<String>('category_images').delete(category);
                                                                      Hive.box<String>('category_dietary').delete(category);
                                                                      Hive.box<String>('category_translations').delete(category);
                                                                      FirebaseSyncService().deleteGlobalCategoryFromAllShops(category);
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
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                    }

                                    if (isDesktop) {
                                      return GridView.builder(
                                        padding: const EdgeInsets.all(16),
                                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 350,
                                          mainAxisExtent: 110,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                        ),
                                        itemCount: freshFiltered.length,
                                        itemBuilder: buildItem,
                                      );
                                    } else {
                                      return ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        itemCount: freshFiltered.length,
                                        itemBuilder: buildItem,
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
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const GlobalProductDialog(),
                );
              },
              icon: const Icon(Icons.add),
              label: Text('Add Product'.tr(ref.watch(languageProvider))),
            )
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
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
                    setState(() {});
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
    final showStock =
        settings.showStockQuantity && (session?.hasStockManagement == true);

    return Opacity(
      opacity: product.isActive ? 1.0 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: kMasterWorkspaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.white,
              blurRadius: 6,
              offset: Offset(-3, -3),
            ),
            BoxShadow(
              color: Color(0xFFD1D9E6),
              blurRadius: 6,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => GlobalProductDialog(product: product),
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
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
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
                            if (showStock && product.stockCount <= 5)
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
                          if (product.stockCount <= 5)
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
                          if (showStock)
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

// Dialog to Add/Edit Category with Image
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
      _imagePath = Hive.box<String>('category_images').get(widget.initialCategory);
      final dBox = Hive.box<String>('category_dietary');
      final fetchedDiet = dBox.get(widget.initialCategory, defaultValue: 'both') ?? 'both';
      _dietaryType = (fetchedDiet == 'non-veg') ? 'nonveg' : fetchedDiet;
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

  Widget _buildNeumorphicField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool readOnly = false,
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
        validator: validator,
        readOnly: readOnly,
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
    return AlertDialog(
      backgroundColor: kMasterWorkspaceColor,
      title: Text(
        widget.initialCategory != null ? 'Edit Category' : 'Add Category',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: kMasterWorkspaceColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
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
                          children: const [
                            Icon(
                              Icons.add_a_photo,
                              size: 26,
                              color: Color(0xFF4F46E5),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Add Image',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              _buildNeumorphicField(
                controller: _nameCtrl,
                labelText: 'Category Name',
                prefixIcon: Icons.category,
                readOnly: false,
                validator: (v) => v!.isEmpty ? 'Category name is required' : null,
              ),
              const SizedBox(height: 16),
              _buildNeumorphicField(
                controller: _tamilNameCtrl,
                labelText: 'Tamil Name (Optional)',
                prefixIcon: Icons.language,
              ),
              const SizedBox(height: 16),
              Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dietaryType,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4F46E5)),
                    items: const [
                      DropdownMenuItem(value: 'both', child: Text('Both (Default)', style: TextStyle(fontSize: 14))),
                      DropdownMenuItem(value: 'veg', child: Text('Veg', style: TextStyle(fontSize: 14))),
                      DropdownMenuItem(value: 'nonveg', child: Text('Non-Veg', style: TextStyle(fontSize: 14))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _dietaryType = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
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
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                String name = _nameCtrl.text.trim();
                final tamilName = _tamilNameCtrl.text.trim();
                final dietaryType = _dietaryType;
                final box = Hive.box<String>('category_images');

                // If renaming an existing category
                if (widget.initialCategory != null && widget.initialCategory != name) {
                  final oldName = widget.initialCategory!;
                  box.delete(oldName);
                  Hive.box<String>('category_dietary').delete(oldName);
                  Hive.box<String>('category_translations').delete(oldName);
                  FirebaseSyncService().deleteGlobalCategoryFromAllShops(oldName);

                  // Update products in global inventory that belong to this category
                  final globalNotifier = ref.read(globalInventoryProvider.notifier);
                  final products = ref.read(globalInventoryProvider);
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
                      globalNotifier.updateProduct(updatedP);
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

                final dBox = Hive.box<String>('category_dietary');
                dBox.put(name, dietaryType);
                final tBox = Hive.box<String>('category_translations');
                if (tBox.isOpen) {
                  if (tamilName.isNotEmpty) {
                    tBox.put(name, tamilName);
                  } else {
                    tBox.delete(name);
                  }
                }

                FirebaseSyncService().pushGlobalCategoryToAllShops(
                  name,
                  base64Image,
                  tamilName: tamilName.isNotEmpty ? tamilName : null,
                  dietaryType: dietaryType,
                );

                Navigator.pop(context, name);
                NotificationHelper.showCenter(
                  context,
                  widget.initialCategory != null
                      ? 'Category "$name" updated successfully!'
                      : 'Category "$name" created successfully!',
                  isError: false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Confirm & Save'),
          ),
        ),
      ],
    );
  }
}

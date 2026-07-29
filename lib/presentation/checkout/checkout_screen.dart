import 'package:pos/core/utils/notification_helper.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../providers/inventory_provider.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/order.dart';
import '../../providers/auth_provider.dart';
import '../../../providers/product_order_provider.dart';
import 'widgets/payment_dialog.dart';
import '../analytics/analytics_screen.dart';
import '../../providers/printer_provider.dart';
import '../settings/printer_settings_screen.dart';
import 'staff_customer_checkout_screen.dart';
import '../../../../core/utils/ui_utils.dart';

import 'package:intl/intl.dart';
import '../../../providers/order_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../providers/category_order_provider.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/hardware/printer_service.dart';
import '../../../../services/print_router_service.dart';
import '../../services/firebase_sync_service.dart';

final GlobalKey<_CartPreviewState> globalCartPreviewKey =
    GlobalKey<_CartPreviewState>();
final GlobalKey<_ProductPickerState> globalProductPickerKey =
    GlobalKey<_ProductPickerState>();

class CheckoutScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToHome;

  const CheckoutScreen({super.key, this.onBackToHome});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          globalProductPickerKey.currentState?.focusSearch();
        },
        child: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _ProductPicker(key: globalProductPickerKey)),
                  Container(
                    width: 360,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(-2, 0),
                        ),
                      ],
                    ),
                    child: _CartPreview(
                      key: globalCartPreviewKey,
                      isMobileSheet: false,
                    ),
                  ),
                ],
              )
            : _ProductPicker(key: globalProductPickerKey),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: (!isDesktop && isLandscape && cart.items.isNotEmpty)
          ? Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: FloatingActionButton.extended(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (context) {
                      final bottomInset = MediaQuery.of(
                        context,
                      ).viewInsets.bottom;
                      return Padding(
                        padding: EdgeInsets.only(bottom: bottomInset),
                        child: SafeArea(
                          child: FractionallySizedBox(
                            heightFactor: 0.85,
                            child: Column(
                              children: [
                                const SizedBox(height: 12),
                                Container(
                                  width: 40,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: _CartPreview(isMobileSheet: true),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(Icons.shopping_bag),
                label: Text(
                  'PAY ${cart.total.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
          : null,

      // Premium bottom sticky cart drawer for all users to maximize screen width
      bottomNavigationBar: (isDesktop || isLandscape)
          ? null
          : (cart.items.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shopping_bag,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${cart.items.fold<double>(0.0, (sum, item) => sum + item.quantity) % 1 == 0 ? cart.items.fold<double>(0.0, (sum, item) => sum + item.quantity).toInt() : cart.items.fold<double>(0.0, (sum, item) => sum + item.quantity)} ${'Items'.tr(ref.watch(languageProvider))}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${'Subtotal'.tr(ref.watch(languageProvider))}: ₹${cart.subtotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Slide open beautiful cart sheet
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.white,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                  ),
                                  builder: (context) {
                                    final bottomInset = MediaQuery.of(
                                      context,
                                    ).viewInsets.bottom;
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        bottom: bottomInset,
                                      ),
                                      child: SafeArea(
                                        child: FractionallySizedBox(
                                          heightFactor: 0.85,
                                          child: Column(
                                            children: [
                                              const SizedBox(height: 12),
                                              Container(
                                                width: 40,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade300,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Expanded(
                                                child: _CartPreview(
                                                  isMobileSheet: true,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: theme.colorScheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_upward, size: 18),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'PAY'.tr(ref.watch(languageProvider)) +
                                      ' ₹${cart.total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : null),
    );
  }
}

// Removed full screen OrderTypeSelector as we use dialog now

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.8),
                theme.colorScheme.primary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker({super.key});

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker>
    with TickerProviderStateMixin {
  TabController? _tabController;
  List<String> _lastCategories = [];
  bool _lastShowPopular = true;
  String _lastCategoryKey = '';
  final _searchQuery = ValueNotifier<String>('');
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusSearch();
    });
  }

  void focusSearch() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _searchFocusNode.requestFocus();
    }
  }

  List<Product> _filterProducts(List<Product> source, String query) {
    if (query.isEmpty) return source;
    final q = query.toLowerCase();

    // 1. Exact Match on Product Number
    final exactMatches = source
        .where((p) => p.productNumber?.toLowerCase() == q)
        .toList();
    if (exactMatches.isNotEmpty) return exactMatches;

    // 2. Exact Match on Barcode
    final exactBarcodeMatches = source
        .where((p) => p.barcode?.toLowerCase() == q)
        .toList();
    if (exactBarcodeMatches.isNotEmpty) return exactBarcodeMatches;

    // 3. Fallback fuzzy search
    return source.where((p) {
      final tName = (p.nameTamil != null && p.nameTamil!.isNotEmpty)
          ? p.nameTamil!
          : p.name.tr('ta');
      final tCat = p.category.tr('ta');
      return p.name.toLowerCase().contains(q) ||
          tName.toLowerCase().contains(q) ||
          (p.nameTamil?.toLowerCase().contains(q) ?? false) ||
          p.category.toLowerCase().contains(q) ||
          tCat.toLowerCase().contains(q) ||
          (p.categoryTamil?.toLowerCase().contains(q) ?? false) ||
          (p.productNumber?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _handleFastEntry(String rawValue, List<Product> allProducts) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      // Empty enter -> Move to Order Type
      globalCartPreviewKey.currentState?.focusOrderType();
      return;
    }

    String query = value;
    double qty = 1.0;

    if (value.contains('*') || value.toLowerCase().contains('x')) {
      final parts = value.toLowerCase().split(RegExp(r'[\*x]'));
      if (parts.length == 2) {
        query = parts[0].trim();
        qty = double.tryParse(parts[1].trim()) ?? 1.0;
        if (qty <= 0) qty = 1.0;
      }
    }

    Product? matchedProduct;
    // 1. Match Product Number Exact
    for (final p in allProducts) {
      if (p.productNumber != null &&
          p.productNumber!.toLowerCase() == query.toLowerCase()) {
        matchedProduct = p;
        break;
      }
    }

    // 2. Match Barcode Exact
    if (matchedProduct == null) {
      for (final p in allProducts) {
        if (p.barcode != null &&
            p.barcode!.toLowerCase() == query.toLowerCase()) {
          matchedProduct = p;
          break;
        }
      }
    }

    if (matchedProduct != null) {
      final cartNotifier = ref.read(cartProvider.notifier);
      final cartItem = ref
          .read(cartProvider)
          .items
          .where((i) => i.product.id == matchedProduct!.id)
          .firstOrNull;

      if (cartItem != null) {
        cartNotifier.updateQuantity(matchedProduct.id, cartItem.quantity + qty);
      } else {
        cartNotifier.addProduct(matchedProduct);
        if (qty > 1) {
          cartNotifier.updateQuantity(matchedProduct.id, qty);
        }
      }

      _searchCtrl.clear();
      _searchQuery.value = '';
      ref.read(inventorySearchQueryProvider.notifier).setQuery('');
      focusSearch();
    } else {
      NotificationHelper.showCenter(
        context,
        'Product not found!',
        isError: true,
      );
      _searchCtrl.clear();
      _searchQuery.value = '';
      ref.read(inventorySearchQueryProvider.notifier).setQuery('');
      focusSearch();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchQuery.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _syncTabController(List<String> categories) {
    if (_tabController == null || _lastCategories != categories) {
      final oldIndex = _tabController?.index ?? 0;
      _tabController?.dispose();
      _tabController = TabController(
        length: categories.length + 1, // +1 for "Popular" (which contains all)
        vsync: this,
        initialIndex: oldIndex < categories.length + 1 ? oldIndex : 0,
      );
      _lastCategories = categories;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    ref.watch(productOrderProvider);
    final productOrderMap = ref
        .read(productOrderProvider.notifier)
        .getOrderMap();

    final allProducts =
        ref.watch(inventoryProvider).where((p) {
          if (!p.isActive) return false;
          final dFilter = settings.dietaryFilter.toLowerCase();
          if ((dFilter == 'veg' || dFilter == 'pure_veg') && p.isVeg == false) return false;
          if ((dFilter == 'nonveg' || dFilter == 'non-veg') && p.isVeg == true) return false;
          return true;
        }).toList()..sort((a, b) {
          final orderA = productOrderMap[a.id] ?? 9999;
          final orderB = productOrderMap[b.id] ?? 9999;
          if (orderA != orderB) return orderA.compareTo(orderB);
          return a.name.compareTo(b.name);
        });
    final allOrders = ref.watch(orderProvider);
    final theme = Theme.of(context);
    final showPopular = settings.enablePopularCategory;

    final now = DateTime.now();
    final isMorning = now.hour >= 6 && now.hour < 12;
    final isAfternoon = now.hour >= 12 && now.hour < 18;

    // Calculate popular products for current time slot
    final Map<String, int> productSales = {};
    for (var order in allOrders) {
      if (order.paymentStatus == 'PAID') {
        try {
          final orderTime = order.date.toLocal();
          bool matchesSlot = false;
          if (isMorning && orderTime.hour >= 6 && orderTime.hour < 12)
            matchesSlot = true;
          else if (isAfternoon && orderTime.hour >= 12 && orderTime.hour < 18)
            matchesSlot = true;
          else if (!isMorning &&
              !isAfternoon &&
              (orderTime.hour >= 18 || orderTime.hour < 6))
            matchesSlot = true;

          if (matchesSlot) {
            final itemsJson =
                jsonDecode(order.itemsJson) as Map<String, dynamic>;
            final itemsList = itemsJson['items'] as List<dynamic>? ?? [];
            for (var item in itemsList) {
              final productId = item['product']['id'] as String;
              final quantity = (item['quantity'] as num).toInt();
              productSales[productId] =
                  (productSales[productId] ?? 0) + quantity;
            }
          }
        } catch (_) {}
      }
    }

    // Sort all products: Popular first, then alphabetical
    final sortedAllProducts = List<Product>.from(allProducts)
      ..sort((a, b) {
        final salesA = productSales[a.id] ?? 0;
        final salesB = productSales[b.id] ?? 0;
        if (salesA != salesB) return salesB.compareTo(salesA);
        return a.name.compareTo(b.name);
      });

    // Extract unique categories from products, sorted by user-defined order then alphabetically
    final categorySet = allProducts.expand((p) {
      final list = [p.category];
      if (p.additionalCategories != null) {
        list.addAll(p.additionalCategories!);
      }
      return list;
    }).toSet();

    // Also include empty categories that were created but have no products yet
    final catImagesBox = Hive.box<String>('category_images');
    for (var key in catImagesBox.keys) {
      categorySet.add(key as String);
    }

    final rawCategories = categorySet.toList();

    // Watch category order provider — rebuilds instantly when order is saved from inventory
    ref.watch(categoryOrderProvider); // reactivity: rebuilds when order changes

    // Watch category images provider — rebuilds instantly when a new empty category is synced
    ref.watch(categoryImagesProvider);

    // Read user-defined category order from Hive
    final categoryOrderNotifier = ref.read(categoryOrderProvider.notifier);
    final orderMap = categoryOrderNotifier.getOrderMap();
    rawCategories.sort((a, b) {
      final orderA = orderMap[a] ?? 9999;
      final orderB = orderMap[b] ?? 9999;
      if (orderA != orderB) return orderA.compareTo(orderB);
      return a.compareTo(b);
    });
    final categoryStatusBox = Hive.box<bool>('category_status');
    final dBox = Hive.box<String>('category_dietary');
    final shopDiet = settings.dietaryFilter.toLowerCase();
    final isVegShop = shopDiet == 'veg' || shopDiet == 'pure_veg';
    final isNonVegShop = shopDiet == 'nonveg' || shopDiet == 'non-veg';

    rawCategories.removeWhere((c) {
      if (categoryStatusBox.get(c, defaultValue: true) == false) return true;
      if (dBox.isOpen) {
        final cType = dBox.get(c) ?? 'both';
        if (isVegShop && (cType == 'nonveg' || cType == 'non-veg')) return true;
        if (isNonVegShop && cType == 'veg') return true;
      }
      if (isVegShop) {
        final prodsInCat = allProducts.where((p) => p.category == c || (p.additionalCategories != null && p.additionalCategories!.contains(c)));
        if (prodsInCat.isNotEmpty && prodsInCat.every((p) => p.isVeg == false)) {
          return true;
        }
      }
      if (isNonVegShop) {
        final prodsInCat = allProducts.where((p) => p.category == c || (p.additionalCategories != null && p.additionalCategories!.contains(c)));
        if (prodsInCat.isNotEmpty && prodsInCat.every((p) => p.isVeg == true)) {
          return true;
        }
      }
      return false;
    });

    final categories = rawCategories;

    // Build a key from category names+order so any order change triggers rebuild
    final categoryKey = categories.join('|');

    final tabCount = showPopular ? categories.length + 1 : categories.length;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isMobileLandscape =
        isLandscape && MediaQuery.of(context).size.shortestSide < 600;

    return ValueListenableBuilder(
      valueListenable: categoryStatusBox.listenable(),
      builder: (context, box, _) {
        // Re-filter categories if status changed
        final activeCategories = rawCategories
            .where((c) => box.get(c, defaultValue: true) == true)
            .toList();
        final activeCategoryKey = activeCategories.join('|');
        final currentTabCount = showPopular
            ? activeCategories.length + 1
            : activeCategories.length;
        return DefaultTabController(
          key: ValueKey('${currentTabCount}_$activeCategoryKey'),
          length: currentTabCount,
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: isMobileLandscape ? 0.0 : 4.0,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocusNode,
                  onChanged: (value) {
                    String query = value;
                    if (value.contains('*') ||
                        value.toLowerCase().contains('x')) {
                      final parts = value.toLowerCase().split(RegExp(r'[\*x]'));
                      if (parts.isNotEmpty) {
                        query = parts[0].trim();
                      }
                    }
                    _searchQuery.value = query;
                    ref
                        .read(inventorySearchQueryProvider.notifier)
                        .setQuery(query);
                  },
                  onSubmitted: (value) =>
                      _handleFastEntry(value, sortedAllProducts),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    hintText: 'Search products...'.tr(
                      ref.watch(languageProvider),
                    ),
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),

              // WhatsApp-style scrollable TabBar
              if (categories.isNotEmpty) ...[
                SizedBox(
                  height: isMobileLandscape ? 40 : 48,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.green,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    indicator: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    dividerColor:
                        Colors.transparent, // remove the bottom border line
                    tabs: [
                      if (showPopular)
                        Tab(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            child: Text(
                              '${'Popular'.tr(ref.watch(languageProvider))} 🔥',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, height: 1.1),
                            ),
                          ),
                        ),
                      ...categories.map((c) {
                        final isTamil = ref.watch(languageProvider) == 'ta';
                        final displayName = isTamil ? c.tr('ta') : c;
                        final len = displayName.length;
                        final fontSize = len > 16 ? 11.0 : (len > 10 ? 12.0 : 13.0);
                        return Tab(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            child: Text(
                              displayName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: fontSize,
                                height: 1.1,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Swipeable product grid per tab
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _searchQuery,
                    builder: (context, query, _) {
                      return TabBarView(
                        children: [
                          // "Popular" tab (only if enabled)
                          if (showPopular)
                            _ProductGrid(
                              products: query.isEmpty
                                  ? sortedAllProducts
                                  : _filterProducts(sortedAllProducts, query),
                            ),
                          // Category tabs
                          ...categories.map(
                            (cat) => _ProductGrid(
                              products: (() {
                                final catProducts = allProducts
                                    .where(
                                      (p) =>
                                          p.category == cat ||
                                          (p.additionalCategories != null &&
                                              p.additionalCategories!.contains(
                                                cat,
                                              )),
                                    )
                                    .toList();
                                return query.isEmpty
                                    ? catProducts
                                    : _filterProducts(catProducts, query);
                              })(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ] else
                // No categories yet
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory,
                          size: 64,
                          color: Color(0xFFD1D5DB),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No products available for checkout.'.tr(
                            ref.watch(languageProvider),
                          ),
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Simple product grid used inside each tab
class _ProductGrid extends ConsumerWidget {
  final List<Product> products;
  const _ProductGrid({required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory, size: 64, color: Color(0xFFD1D5DB)),
            SizedBox(height: 16),
            Text(
              'No products in this category.'.tr(ref.watch(languageProvider)),
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final settings = ref.watch(settingsProvider);
    final hideImages = settings.hideImagesInCheckout;

    final double aspectRatio = hideImages
        ? (isDesktop ? 1.0 : (isLandscape ? 1.1 : 0.85)) // Much more height for text
        : (isDesktop ? 0.70 : (isLandscape ? 0.85 : 0.65));

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: hideImages ? (isDesktop ? 180 : 160) : (isDesktop ? 140 : 130),
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _QuickAddProductCard(product: products[index]);
      },
    );
  }
}

class _QuickAddProductCard extends ConsumerWidget {
  final Product product;
  const _QuickAddProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(authProvider);
    final showStock =
        settings.showStockQuantity && (session?.hasStockManagement == true);
    final outOfStock = (showStock && product.trackInventory)
        ? product.stockCount <= 0
        : false;

    final cart = ref.watch(cartProvider);
    final cartItem = cart.items
        .where((item) => item.product.id == product.id)
        .firstOrNull;
    final isInCart = cartItem != null;
    final qty = cartItem?.quantity ?? 0.0;
    final step = product.allowHalfPortion ? 0.5 : 1.0;
    final hasProductNumber =
        product.productNumber != null &&
        product.productNumber!.trim().isNotEmpty;

    final isTamil = ref.watch(languageProvider) == 'ta';
    final pName = isTamil
        ? (product.nameTamil != null && product.nameTamil!.isNotEmpty
            ? product.nameTamil!
            : product.name)
        : product.name;

    double baseTitleFontSize = settings.hideImagesInCheckout
        ? (isTamil ? 14.5 : 14.0)
        : (isTamil ? 13.0 : 17.5);

    if (pName.length > 22) {
      baseTitleFontSize = (baseTitleFontSize - 2.0).clamp(10.5, 16.0);
    } else if (pName.length > 14) {
      baseTitleFontSize = (baseTitleFontSize - 1.0).clamp(11.5, 16.5);
    }
    final double titleFontSize = baseTitleFontSize;

    final double priceFontSize = settings.hideImagesInCheckout
        ? (isTamil ? 14.5 : 14.0)
        : (isTamil ? 13.5 : 17.5);

    Widget cardContent = AnimatedScale(
      scale: isInCart ? 1.015 : 1.0, // Extremely subtle 1.5% pop effect
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: isInCart
              ? theme.colorScheme.primary.withOpacity(0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isInCart ? Colors.green.shade400 : Colors.red.shade200,
            width: 1.5,
          ),
          boxShadow: isInCart
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            splashColor: theme.colorScheme.primary.withOpacity(0.1),
            highlightColor: Colors.transparent,
            onTap: outOfStock
                ? null
                : () {
                    if (isInCart) {
                      // Toggle off
                      ref.read(cartProvider.notifier).removeProduct(product.id);
                    } else {
                      // Toggle on
                      ref.read(cartProvider.notifier).addProduct(product);
                    }
                  },
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!settings.hideImagesInCheckout) ...[
                  // Product image area
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: Hive.box<String>(
                        'product_images',
                      ).listenable(keys: [product.id]),
                      builder: (context, imgBox, _) {
                        final currentImgPath = imgBox.get(product.id);
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
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
                                    fit: BoxFit.fill,
                                  ) // Stretches to completely fill the space
                                : null,
                          ),
                          child: Stack(
                            children: [
                              if (ImageUtils.safeImageProvider(
                                    currentImgPath,
                                  ) ==
                                  null)
                                Center(
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey.shade300,
                                    size: 36,
                                  ),
                                ),
                              if (outOfStock)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'OUT OF STOCK'
                                          .tr(ref.watch(languageProvider))
                                          .replaceAll(' ', '\n'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              // Checkmark for selected items
                              if (isInCart)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              // Stock quantity indicator
                              if (showStock && product.trackInventory)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${product.stockCount}',
                                      style: TextStyle(
                                        color: outOfStock
                                            ? Colors.red
                                            : (product.stockCount <= 3
                                                  ? Colors.orange.shade700
                                                  : Colors.green),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
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
                ],

                // Product info or Action buttons
                Flexible(
                  fit: settings.hideImagesInCheckout ? FlexFit.tight : FlexFit.loose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    height: settings.hideImagesInCheckout ? null : 88,
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(
                                      0.0,
                                      0.1,
                                    ), // Slight slide up effect
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                              child: child,
                            ),
                          );
                        },
                    child: isInCart
                        ? Container(
                            key: const ValueKey('cart_controls'),
                            height: 54, // Taller button to match huge text
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Decrease / Remove button
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (qty <= step) {
                                      ref
                                          .read(cartProvider.notifier)
                                          .removeProduct(product.id);
                                    } else {
                                      ref
                                          .read(cartProvider.notifier)
                                          .updateQuantity(
                                            product.id,
                                            qty - step,
                                          );
                                    }
                                  },
                                  child: Container(
                                    width: 36,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      qty <= step
                                          ? Icons.delete_outline
                                          : Icons.remove,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                // Quantity display
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        qty % 1 == 0
                                            ? qty.toInt().toString()
                                            : qty.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Increase button
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    final msg = ref
                                        .read(cartProvider.notifier)
                                        .updateQuantity(product.id, qty + step);
                                    if (msg != null && context.mounted) {
                                      NotificationHelper.showCenter(
                                        context,
                                        msg,
                                        isError: true,
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: 36,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            key: const ValueKey('product_info'),
                            children: [

                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        ref.watch(languageProvider) == 'ta'
                                            ? (product.nameTamil != null &&
                                                      product
                                                          .nameTamil!
                                                          .isNotEmpty
                                                  ? product.nameTamil!
                                                  : product.name)
                                            : product.name,
                                        maxLines: settings.hideImagesInCheckout ? 4 : 3,
                                        textAlign: TextAlign.center,
                                        softWrap: true,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: titleFontSize,
                                              height: 1.12,
                                              color: outOfStock
                                                  ? Colors.grey
                                                  : Colors.black87,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Align(
                                        alignment:
                                            Alignment.center, // Center the price!
                                        child: Text(
                                          '₹${(product.price + (ref.read(cartProvider).orderType?.toLowerCase() == 'parcel' && product.isParcelEnabled ? (product.parcelAmount ?? 0.0) : 0.0)).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: outOfStock
                                                ? Colors.grey
                                                : theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: priceFontSize,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
      ),
    ),
  );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        cardContent,
        if (hasProductNumber)
          Positioned(
            top: -4,
            left: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        if (product.isVeg != null)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                product.isVeg == true ? Icons.eco : Icons.restaurant,
                color: product.isVeg == true ? Colors.green : Colors.red,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }
}

class _CartPreview extends ConsumerStatefulWidget {
  final bool isMobileSheet;
  const _CartPreview({super.key, required this.isMobileSheet});

  @override
  ConsumerState<_CartPreview> createState() => _CartPreviewState();
}

class _CartPreviewState extends ConsumerState<_CartPreview> {
  String _selectedPaymentMode = 'Cash';
  final _splitCashCtrl = TextEditingController();
  final _splitUpiCtrl = TextEditingController();
  bool _splitValid = false;
  bool _isProcessing = false;

  final _orderTypeFocus = FocusNode();
  final _paymentModeFocus = FocusNode();

  void focusOrderType() {
    _orderTypeFocus.requestFocus();
  }

  void focusPaymentMode() {
    _paymentModeFocus.requestFocus();
  }

  @override
  void dispose() {
    _splitCashCtrl.dispose();
    _splitUpiCtrl.dispose();
    _orderTypeFocus.dispose();
    _paymentModeFocus.dispose();
    super.dispose();
  }

  void _validateSplit(double total) {
    final cash = double.tryParse(_splitCashCtrl.text) ?? 0.0;
    final upi = double.tryParse(_splitUpiCtrl.text) ?? 0.0;
    setState(() {
      _splitValid = (cash + upi).toStringAsFixed(2) == total.toStringAsFixed(2);
    });
  }

  Future<void> triggerPayment(WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    final bool canConfirm =
        cart.items.isNotEmpty &&
        (_selectedPaymentMode != 'Split' || _splitValid);
    if (!canConfirm || _isProcessing) return;

    if (mounted) {
      setState(() => _isProcessing = true);
      await _processDirectCheckout(
        context,
        ref,
        cart,
        ref.read(settingsProvider),
      );
      if (mounted) {
        setState(() => _isProcessing = false);
        globalProductPickerKey.currentState?.focusSearch();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);

    final cartList = ListView.separated(
      shrinkWrap: false,
      physics: const ClampingScrollPhysics(),
      itemCount: cart.items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = cart.items[index];
        final minQty = item.product.allowHalfPortion ? 0.5 : 1.0;
        return ListTile(
          leading: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Remove item',
            onPressed: () {
              ref.read(cartProvider.notifier).removeProduct(item.product.id);
            },
          ),
          title: Text(
            ref.watch(languageProvider) == 'ta'
                ? (item.product.nameTamil != null &&
                          item.product.nameTamil!.isNotEmpty
                      ? item.product.nameTamil!
                      : item.product.name)
                : item.product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('₹${item.effectivePrice(cart.orderType).toStringAsFixed(2)} each'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                iconSize: 32,
                padding: const EdgeInsets.all(4),
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: item.quantity <= minQty ? Colors.grey : Colors.orange,
                ),
                onPressed: item.quantity <= minQty
                    ? null
                    : () {
                        final step = item.product.allowHalfPortion ? 0.5 : 1.0;
                        final newQty = item.quantity - step;
                        if (newQty < minQty) return; // safety clamp
                        final msg = ref
                            .read(cartProvider.notifier)
                            .updateQuantity(item.product.id, newQty);
                        if (msg != null && context.mounted) {
                          // ScaffoldMessenger cleared
                          NotificationHelper.showCenter(
                            context,
                            msg,
                            isError: true,
                          );
                        }
                      },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  item.quantity % 1 == 0
                      ? item.quantity.toInt().toString()
                      : item.quantity.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                iconSize: 32,
                padding: const EdgeInsets.all(4),
                icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                onPressed: () {
                  final step = item.product.allowHalfPortion ? 0.5 : 1.0;
                  final msg = ref
                      .read(cartProvider.notifier)
                      .updateQuantity(item.product.id, item.quantity + step);
                  if (msg != null && context.mounted) {
                    // ScaffoldMessenger cleared
                    NotificationHelper.showCenter(context, msg, isError: true);
                  }
                },
              ),
            ],
          ),
        );
      },
    );

    final settings = ref.watch(settingsProvider);
    final cartSummary = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Order Type Selection (Dine/Parcel)
          Focus(
            focusNode: _orderTypeFocus,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  final cartNotifier = ref.read(cartProvider.notifier);
                  final current = ref.read(cartProvider).orderType;
                  if (current == 'DINE' || current == null) {
                    cartNotifier.setOrderType('PARCEL');
                  } else {
                    cartNotifier.setOrderType('DINE');
                  }
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                  if (ref.read(settingsProvider).enablePaymentModeSelection) {
                    focusPaymentMode();
                  } else {
                    triggerPayment(ref);
                  }
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Builder(
              builder: (context) {
                final settings = ref.watch(settingsProvider);
                final showDineIn = settings.enableDineIn;
                final showParcel = settings.enableParcel;

                if (!showDineIn && !showParcel) {
                  return const SizedBox.shrink();
                }

                // Auto-adjust default orderType if one of the modes is disabled
                if (!showDineIn && (cart.orderType == 'DINE' || cart.orderType == null)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(cartProvider.notifier).setOrderType('PARCEL');
                  });
                } else if (!showParcel && cart.orderType == 'PARCEL') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(cartProvider.notifier).setOrderType('DINE');
                  });
                }

                final hasFocus = Focus.of(context).hasFocus;
                return Container(
                  padding: const EdgeInsets.all(2),
                  decoration: hasFocus
                      ? BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (showDineIn)
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('DINE')),
                            selected:
                                cart.orderType == 'DINE' ||
                                cart.orderType == null,
                            selectedColor: Colors.green,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  (cart.orderType == 'DINE' ||
                                      cart.orderType == null)
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            onSelected: (selected) {
                              if (selected)
                                ref
                                    .read(cartProvider.notifier)
                                    .setOrderType('DINE');
                            },
                          ),
                        ),
                      if (showDineIn && showParcel) const SizedBox(width: 8),
                      if (showParcel)
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('PARCEL')),
                            selected: cart.orderType == 'PARCEL',
                            selectedColor: Colors.green,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cart.orderType == 'PARCEL'
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            onSelected: (selected) {
                              if (selected)
                                ref
                                    .read(cartProvider.notifier)
                                    .setOrderType('PARCEL');
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Conditional Customer Row
          if (settings.enableCustomerDetails) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: Text(
                      cart.customerName != null
                          ? '${cart.customerName} (${cart.customerPhone})'
                          : 'Add Customer',
                    ),
                    onPressed: () {
                      // Navigate to Customers screen, expect result back
                      // This implies navigating to CustomersScreen as a selector.
                      // For now, since CustomersScreen might not return data directly,
                      // let's show a dialog to enter name and phone directly here,
                      // or if user wants to pick from directory, they can. Let's do a simple dialog for now to guarantee functionality.
                      showDialog(
                        context: context,
                        builder: (ctx) {
                          final nameCtrl = TextEditingController(
                            text: cart.customerName,
                          );
                          final phoneCtrl = TextEditingController(
                            text: cart.customerPhone,
                          );
                          return AlertDialog(
                            title: const Text('Add Customer Details'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('CANCEL'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  ref
                                      .read(cartProvider.notifier)
                                      .setCustomerDetails(
                                        nameCtrl.text.trim(),
                                        phoneCtrl.text.trim(),
                                      );
                                  Navigator.pop(ctx);
                                },
                                child: const Text('SAVE'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                if (cart.customerName != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () {
                      ref
                          .read(cartProvider.notifier)
                          .setCustomerDetails('', '');
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          Row(
            children: [
              if (settings.enableTableNumber &&
                  (cart.orderType == 'DINE' || cart.orderType == null))
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Dine Table No',
                      hintText: 'e.g. 1',
                      prefixText: 'DT',
                      prefixIcon: Icon(Icons.table_restaurant),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      if (val.trim().isEmpty) {
                        ref.read(cartProvider.notifier).setDineTableNo('');
                      } else {
                        final num = int.tryParse(val.trim()) ?? 0;
                        final formatted = 'DT${num.toString().padLeft(2, '0')}';
                        ref
                            .read(cartProvider.notifier)
                            .setDineTableNo(formatted);
                      }
                    },
                  ),
                ),
              if (settings.enableTableNumber &&
                  settings.enableDiscountInCart &&
                  (cart.orderType == 'DINE' || cart.orderType == null))
                const SizedBox(width: 8),
              if (settings.enableDiscountInCart)
                Expanded(
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Discount (%)',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.percent),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      final discount = double.tryParse(val) ?? 0.0;
                      ref
                          .read(cartProvider.notifier)
                          .setDiscountPercentage(discount);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            title: 'Subtotal'.tr(ref.watch(languageProvider)),
            value: cart.subtotal,
          ),
          if (settings.enableTaxCalculation) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              title:
                  '${'Tax'.tr(ref.watch(languageProvider))} (${(cart.taxRate * 100).toInt()}%)',
              value: cart.taxAmount,
            ),
          ],
          if (cart.discountAmount > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              title: 'Discount'.tr(ref.watch(languageProvider)),
              value: -cart.discountAmount,
              isDiscount: true,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total'.tr(ref.watch(languageProvider)),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${cart.total.toStringAsFixed(2)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (settings.enablePaymentModeSelection) ...[
            Focus(
              focusNode: _paymentModeFocus,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                      event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    setState(() {
                      if (_selectedPaymentMode == 'Cash') {
                        _selectedPaymentMode = 'UPI';
                      } else if (_selectedPaymentMode == 'UPI') {
                        _selectedPaymentMode = 'Split';
                        _validateSplit(cart.total);
                      } else {
                        _selectedPaymentMode = 'Cash';
                      }
                    });
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                    triggerPayment(ref);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Builder(
                builder: (context) {
                  final hasFocus = Focus.of(context).hasFocus;
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasFocus ? Colors.blue : Colors.grey.shade300,
                        width: hasFocus ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children:
                          (settings.enableSplitPayment
                                  ? ['Cash', 'UPI', 'Split']
                                  : ['Cash', 'UPI'])
                              .map((mode) {
                                final isSelected = _selectedPaymentMode == mode;
                                final isSplitMode =
                                    _selectedPaymentMode == 'Split';

                                if (isSplitMode &&
                                    (mode == 'Cash' || mode == 'UPI')) {
                                  // Render input fields for Cash/UPI when Split is selected
                                  return Expanded(
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                      ),
                                      child: TextField(
                                        controller: mode == 'Cash'
                                            ? _splitCashCtrl
                                            : _splitUpiCtrl,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: mode,
                                          prefixText: '₹',
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                        ),
                                        onChanged: (_) =>
                                            _validateSplit(cart.total),
                                      ),
                                    ),
                                  );
                                }

                                // Render normal toggle buttons
                                return Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (mode == 'Split' &&
                                            _selectedPaymentMode == 'Split') {
                                          _selectedPaymentMode = 'Cash';
                                        } else {
                                          _selectedPaymentMode = mode;
                                          if (mode == 'Split') {
                                            _validateSplit(cart.total);
                                          }
                                        }
                                      });
                                    },
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.green
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.horizontal(
                                          left: mode == 'Cash'
                                              ? const Radius.circular(11)
                                              : Radius.zero,
                                          right: mode == 'Split'
                                              ? const Radius.circular(11)
                                              : Radius.zero,
                                        ),
                                        border: mode != 'Split'
                                            ? Border(
                                                right: BorderSide(
                                                  color: Colors.grey.shade300,
                                                ),
                                              )
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        mode,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                    ),
                  );
                },
              ),
            ),
            if (_selectedPaymentMode == 'Split' && !_splitValid)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Split amounts must total ₹${cart.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 8),
          ],

          Consumer(
            builder: (context, ref, child) {
              final bool canConfirm =
                  cart.items.isNotEmpty &&
                  (_selectedPaymentMode != 'Split' || _splitValid);
              return SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (!canConfirm || _isProcessing)
                      ? null
                      : () => triggerPayment(ref),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'CONFIRM',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );

    return SafeArea(
      bottom: true,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header of current order
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.primary.withOpacity(0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Current Cart Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Row(
                    children: [
                      IconButton(
                        iconSize: 28,
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Clear Cart',
                        onPressed: () {
                          ref.read(cartProvider.notifier).clearCart();
                          if (widget.isMobileSheet) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable cart items only
            Expanded(
              child: cart.items.isEmpty
                  ? const Center(
                      child: Text(
                        'Your checkout cart is empty',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : cartList,
            ),
            const Divider(height: 1),
            // Fixed bottom controls (dine/parcel, discount, table, totals, confirm)
            SingleChildScrollView(child: cartSummary),
          ],
        ),
      ),
    );
  }

  Future<void> _processDirectCheckout(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
    SettingsState settings,
  ) async {
    final navigatorContext = Navigator.of(context).context;

    // Resolve all providers upfront before unmounting
    final printer = ref.read(printerProvider.notifier);
    final orderNotifier = ref.read(orderProvider.notifier);
    final inventoryNotifier = ref.read(inventoryProvider.notifier);
    final cartNotifier = ref.read(cartProvider.notifier);
    final authState = ref.read(authProvider);
    final printerState = ref.read(printerProvider);

    // Pre-checkout Printer Check
    if (printerState.connectedDevice == null) {
      final shouldGoToSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.print_disabled, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Printer Not Connected'),
            ],
          ),
          content: const Text(
            'Do you want to connect a printer before confirming the order?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Continue Without Printer',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Go to Printer Setup'),
            ),
          ],
        ),
      );

      if (shouldGoToSettings == true) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
          );
        }
        return; // Stop checkout process so they can resume when they come back
      }
    }

    final newOrderId =
        cart.editingOrderId ?? orderNotifier.generateNextOrderId();
    final paymentStatus = 'PAID';
    // If split mode, encode the amounts into the paymentMode string for analytics parsing
    final paymentMode = _selectedPaymentMode == 'Split'
        ? 'Split|${_splitCashCtrl.text}|${_splitUpiCtrl.text}'
        : _selectedPaymentMode;
    final staffName = authState?.name ?? 'Admin';
    final finalCart = cart;

    // 1. Show popup and close UI first while context is mounted
    if (context.mounted) {
      final nav = Navigator.of(context);
      if (widget.isMobileSheet) {
        nav.pop();
      }
      UiUtils.showSquarePopup(
        navigatorContext,
        'Order Confirmed! 🎉',
        isError: false,
      );
    }

    // 2. Clear Cart
    cartNotifier.clearCart();

    // Reset payment selector
    if (mounted) {
      setState(() {
        _selectedPaymentMode = 'Cash';
        _splitCashCtrl.clear();
        _splitUpiCtrl.clear();
        _splitValid = false;
      });
    }

    // 2. Do heavy tasks in background!
    Future.microtask(() async {
      try {
        // Save Order to History
        await orderNotifier.saveOrder(
          items: finalCart.items,
          total: finalCart.total,
          subtotal: finalCart.subtotal,
          tax: finalCart.taxAmount,
          discount: finalCart.discountAmount,
          paymentMode: paymentMode,
          paymentStatus: paymentStatus,
          customerName: finalCart.customerName ?? '',
          customerPhone: finalCart.customerPhone ?? '',
          staffName: staffName,
          orderType: finalCart.orderType ?? '',
          dineTableNo: finalCart.dineTableNo,
          id: newOrderId,
          isEdited: finalCart.editingOrderId != null,
          originalDate: finalCart.editingOrderId != null 
              ? (orderNotifier.state.firstWhere(
                  (o) => o.id == finalCart.editingOrderId,
                  orElse: () => OrderModel(id: '', total: 0, subtotal: 0, tax: 0, discount: 0, date: DateTime.now(), itemsJson: ''),
                ).date)
              : null,
        );

        // Deduct Stock from Inventory
        if (settings.showStockQuantity) {
          for (var item in finalCart.items) {
            if (item.product.trackInventory) {
              final newStock = item.product.stockCount - item.quantity.ceil();
              final updatedProduct = item.product.copyWith(
                stockCount: newStock < 0 ? 0 : newStock,
              );
              inventoryNotifier.updateProduct(updatedProduct);
            }
          }
        }

        List<int>? kitchenBytes;
        List<int>? receiptBytes;

        int? parcelToken;
        if (finalCart.orderType?.toLowerCase() == 'parcel') {
          try {
            parcelToken = await FirebaseSyncService.instance
                .getNextParcelToken();
          } catch (e) {
            debugPrint('Failed to get parcel token: $e');
          }

          if (!settings.enableMultiplePrinters) {
            kitchenBytes = await PrinterService.generateKitchenReceiptBytes(
              items: finalCart.items,
              orderId: newOrderId.replaceFirst(RegExp(r'^\d{6}-'), ''),
              orderType: finalCart.orderType ?? 'DINE',
              printAsImage: settings.printAsImage,
              is80mmPaper: settings.is80mmPaper,
              parcelToken: parcelToken,
              shopName: settings.shopName,
              addressLine1: settings.addressLine1,
              addressLine2: settings.addressLine2,
              hotelType: settings.hotelType,
              mobileNumber: settings.mobileNumber,
              fssaiNumber: settings.fssaiNumber,
              gstNumber: settings.gstNumber,
              enableAddressOnReceipt: settings.enableAddressOnReceipt,
              enableMobileOnReceipt: settings.enableMobileOnReceipt,
              enableFssaiOnReceipt: settings.enableFssaiOnReceipt,
              enableHotelTypeOnReceipt: settings.enableHotelTypeOnReceipt,
              enableShopDetailsOnKot: settings.enableShopDetailsOnKot,
              showGstOnReceipt: settings.showGstOnReceipt,
            );
          }
        }

        receiptBytes = await PrinterService.generateReceiptBytes(
          items: finalCart.items,
          subtotal: finalCart.subtotal,
          tax: finalCart.taxAmount,
          discount: finalCart.discountAmount,
          total: finalCart.total,
          shopName: settings.shopName,
          receiptHeader: settings.receiptHeader,
          receiptFooter: settings.receiptFooter,
          showGstOnReceipt: settings.showGstOnReceipt,
          gstNumber: settings.gstNumber,
          isUnpaid: false,
          orderId: newOrderId.replaceFirst(RegExp(r'^\d{6}-'), ''),
          tableNo: finalCart.dineTableNo,
          orderType: finalCart.orderType,
          customerName: finalCart.customerName,
          customerPhone: finalCart.customerPhone,
          printAsImage: settings.printAsImage,
          is80mmPaper: settings.is80mmPaper,
          parcelToken: parcelToken,
          addressLine1: settings.addressLine1,
          addressLine2: settings.addressLine2,
          hotelType: settings.hotelType,
          mobileNumber: settings.mobileNumber,
          fssaiNumber: settings.fssaiNumber,
          enableAddressOnReceipt: settings.enableAddressOnReceipt,
          enableMobileOnReceipt: settings.enableMobileOnReceipt,
          enableFssaiOnReceipt: settings.enableFssaiOnReceipt,
          enableHotelTypeOnReceipt: settings.enableHotelTypeOnReceipt,
          showPoweredByDiyan: settings.showPoweredByDiyan,
        );

        // 1. Print to Main Printer First (No Delay for Cashier)
        if (kitchenBytes != null) {
          await printer.printReceipt(kitchenBytes);
          await Future.delayed(const Duration(milliseconds: 500));
        }

        if (receiptBytes != null) {
          await printer.printReceipt(receiptBytes);
        }

        // 2. Fire and Forget Secondary Printers (Background)
        if (settings.enableMultiplePrinters) {
          PrintRouterService.routeKOTs(
            items: finalCart.items,
            orderId: newOrderId,
            orderType: finalCart.orderType ?? 'DINE',
            settings: settings,
            parcelToken: parcelToken,
            shopName: settings.shopName,
            printerNotifier: printer,
          ).catchError((e) {
            debugPrint('Background KOT routing failed: $e');
          });
        }
      } catch (e) {
        debugPrint('Background print failed: $e');
        final errorMsg = e.toString().replaceAll('Exception:', '').trim();
        UiUtils.showToast('Printing failed: $errorMsg', isError: true);
        if (navigatorContext.mounted) {
          NotificationHelper.showCenter(
            navigatorContext,
            'Printing failed: $errorMsg',
            isError: true,
          );
        }
      }
    });
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final double value;
  final bool isDiscount;

  const _SummaryRow({
    required this.title,
    required this.value,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 15)),
        Text(
          '${isDiscount ? '-₹' : '₹'}${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: isDiscount ? Colors.green : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

import 'package:pos/core/utils/notification_helper.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../providers/inventory_provider.dart';
import '../../domain/models/product.dart';
import '../../core/utils/image_utils.dart';

class QuickStockEditScreen extends ConsumerStatefulWidget {
  const QuickStockEditScreen({super.key});

  @override
  ConsumerState<QuickStockEditScreen> createState() =>
      _QuickStockEditScreenState();
}

class _QuickStockEditScreenState extends ConsumerState<QuickStockEditScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final _exactStockCtrl = TextEditingController();

  @override
  void dispose() {
    _exactStockCtrl.dispose();
    super.dispose();
  }

  void _showSetExactStockDialog(Product product) {
    _exactStockCtrl.text = product.stockCount.toString();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Adjust Stock: ${product.name}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _exactStockCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Stock Count',
              border: OutlineInputBorder())),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final newCount = int.tryParse(_exactStockCtrl.text.trim());
                if (newCount != null && newCount >= 0) {
                  final updated = product.copyWith(stockCount: newCount);
                  ref.read(inventoryProvider.notifier).updateProduct(updated);
                  Navigator.pop(context);
                  NotificationHelper.showCenter(context, 'Stock updated for ${product.name} to $newCount', isError: false);
                }
              },
              child: const Text('Save')),
          ]);
      });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final products = ref.watch(inventoryProvider);

    final categories = [
      'All',
      ...products.map((p) => p.category).toSet().toList()..sort(),
    ];

    final filteredProducts = products.where((product) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesQuery =
          product.name.toLowerCase().contains(q) ||
          product.category.toLowerCase().contains(q);
      final matchesCategory =
          _selectedCategory == 'All' || product.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Quick Stock Adjustment',
          style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search product by name or category...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
                fillColor: Colors.white,
                filled: true),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              })),

          // Category Filter
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      }
                    }));
              })),

          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No products found matching query',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.bold)),
                      ]))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8),
                    itemCount: filteredProducts.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10),
                          child: Row(
                            children: [
                              // Product image or icon placeholder
                              Builder(
                                builder: (context) {
                                  final imgPath = Hive.box<String>(
                                    'product_images').get(product.id);
                                  final imgProvider =
                                      ImageUtils.safeImageProvider(imgPath);
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey.shade100,
                                      child: imgProvider != null
                                          ? Image(
                                              image: imgProvider,
                                              fit: BoxFit.cover)
                                          : Icon(
                                              Icons.shopping_bag_outlined,
                                              color: theme.colorScheme.primary)));
                                }),
                              const SizedBox(width: 14),

                              // Name & details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rs. ${product.price.toStringAsFixed(2)} • ${product.category}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600)),
                                  ])),

                              // Stock Editor Row
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.red.shade50,
                                      foregroundColor: Colors.red.shade700,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(36, 36)),
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: product.stockCount > 0
                                        ? () {
                                            final updated = product.copyWith(
                                              stockCount:
                                                  product.stockCount - 1);
                                            ref
                                                .read(
                                                  inventoryProvider.notifier)
                                                .updateProduct(updated);
                                          }
                                        : null),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () =>
                                        _showSetExactStockDialog(product),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 44),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.grey.shade200)),
                                      child: Text(
                                        '${product.stockCount}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)))),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.green.shade50,
                                      foregroundColor: Colors.green.shade700,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(36, 36)),
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: () {
                                      final updated = product.copyWith(
                                        stockCount: product.stockCount + 1);
                                      ref
                                          .read(inventoryProvider.notifier)
                                          .updateProduct(updated);
                                    }),
                                ]),
                            ])));
                    })),
        ]));
  }
}

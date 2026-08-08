import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import 'package:flutter/services.dart';
import '../../core/hardware/printer_service.dart';
import '../../providers/printer_provider.dart';
import '../../providers/order_provider.dart';
import '../../domain/models/order.dart';
import '../../domain/models/cart_item.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../providers/settings_provider.dart';
import '../checkout/checkout_screen.dart'; // For CartPreview if needed

class TeaShopHomeScreen extends ConsumerStatefulWidget {
  const TeaShopHomeScreen({super.key});

  @override
  ConsumerState<TeaShopHomeScreen> createState() => _TeaShopHomeScreenState();
}

class _TeaShopHomeScreenState extends ConsumerState<TeaShopHomeScreen> {
  int _currentIndex = 0;
  String _searchQuery = '';
  String _selectedCategory = 'All Items';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Disabled in favor of checkout_screen.dart advanced logic
    return false;
  }

  void _processInstantKey(String key) {
    final allProducts = ref.read(inventoryProvider);
    Product? targetProduct = allProducts.where((p) => p.productNumber == key).firstOrNull;

    if (targetProduct != null) {
      ref.read(cartProvider.notifier).addProduct(targetProduct);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${targetProduct.name} to cart'),
            backgroundColor: Colors.blue,
            duration: const Duration(milliseconds: 500),
          )
        );
      }
    }
  }

  void _processInstantCheckout() async {
    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty) return;

    final orderNotifier = ref.read(orderProvider.notifier);
    final newOrderId = orderNotifier.generateNextOrderId();
    final session = ref.read(authProvider);
    final staffName = session?.name ?? 'Admin';
    
    final cartNotifier = ref.read(cartProvider.notifier);
    final total = cartState.total;

    await orderNotifier.saveOrder(
      items: cartState.items,
      total: total,
      subtotal: total,
      tax: 0,
      discount: 0,
      paymentMode: 'CASH',
      paymentStatus: 'PAID',
      customerName: '',
      customerPhone: '',
      staffName: staffName,
      orderType: 'DINE',
      dineTableNo: '',
      id: newOrderId,
    );

    // 2. Generate Receipt
    final settings = ref.read(settingsProvider);
    final receiptBytes = await PrinterService.generateReceiptBytes(
      items: cartState.items,
      subtotal: total,
      tax: 0,
      discount: 0,
      total: total,
      shopName: settings.shopName,
      receiptHeader: settings.receiptHeader,
      receiptFooter: settings.receiptFooter,
      showGstOnReceipt: settings.showGstOnReceipt,
      gstNumber: settings.gstNumber,
      isUnpaid: false,
      orderId: newOrderId,
      tableNo: '',
      orderType: 'DINE',
      customerName: '',
      customerPhone: '',
      printAsImage: settings.printAsImage,
      is80mmPaper: settings.is80mmPaper,
      parcelToken: null,
      addressLine1: settings.addressLine1,
      addressLine2: settings.addressLine2,
      hotelType: settings.hotelType,
      mobileNumber: settings.mobileNumber,
      fssaiNumber: settings.fssaiNumber,
      enableAddressOnReceipt: settings.enableAddressOnReceipt,
      enableMobileOnReceipt: settings.enableMobileOnReceipt,
      enableFssaiOnReceipt: settings.enableFssaiOnReceipt,
      enableHotelTypeOnReceipt: settings.enableHotelTypeOnReceipt,
    );

    // 3. Print
    if (receiptBytes != null) {
      await ref.read(printerProvider.notifier).printReceipt(receiptBytes);
    }

    // 4. Clear cart and show feedback
    cartNotifier.clearCart();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order printed successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 1000),
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _currentIndex == 0 ? _buildHeader() : null,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildCartFab(),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.black87),
        onPressed: () {},
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_cafe, color: Colors.blue.shade700, size: 28),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tea Point',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Cursive', // Try to get a stylized font
                ),
              ),
              const Text(
                'Fresh Tea, Fresh Day!',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black87),
              onPressed: () {},
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 8)),
              ),
            ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBox(Icons.calendar_today, DateFormat('dd MMM yyyy\nhh:mm a').format(DateTime.now()), null),
              _buildStatusBox(Icons.receipt_long, 'Bill No.\n10245', null),
              _buildStatusBox(Icons.confirmation_num, 'Token No.\n37', Colors.green),
              _buildStatusBox(Icons.person, 'Cashier\nAdmin', null, hasStatusDot: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBox(IconData icon, String text, Color? highlightColor, {bool hasStatusDot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: highlightColor ?? Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: highlightColor ?? Colors.black87,
            ),
          ),
          if (hasStatusDot) ...[
            const SizedBox(width: 4),
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
          ]
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_currentIndex != 0) {
      return const Center(child: Text("Under Construction"));
    }

    final allProducts = ref.watch(inventoryProvider);
    var filtered = allProducts.where((p) => p.isActive).toList();
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    final categories = ['All Items', 'Tea', 'Coffee', 'Cool Drinks', 'Water Bottle', 'Cigarette'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Items', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Browse and select items to add to order', style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(height: 12),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search item (Press name or code)',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.filter_alt_outlined),
                  onPressed: () {},
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Categories
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() => _selectedCategory = val ? cat : 'All Items');
                  },
                  selectedColor: Colors.blue.shade700,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Item List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _buildCategoryGroups(filtered),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCategoryGroups(List<Product> products) {
    final Map<String, List<Product>> grouped = {};
    for (var p in products) {
      if (_selectedCategory == 'All Items' || p.category == _selectedCategory) {
        grouped.putIfAbsent(p.category, () => []).add(p);
      }
    }

    List<Widget> widgets = [];
    grouped.forEach((category, items) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 4, height: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Text('View All >', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
            ],
          ),
        )
      );

      widgets.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 items per row
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildProductCard(items[index]);
          },
        )
      );
      widgets.add(const SizedBox(height: 24));
    });

    return widgets;
  }

  Widget _buildProductCard(Product product) {
    return InkWell(
      onTap: () {
        ref.read(cartProvider.notifier).addProduct(product);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${product.name} added to cart'), duration: const Duration(seconds: 1)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                // Dummy logic for placeholder images matching the tea shop theme based on category
                child: _getImageForCategory(product.category),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.productNumber ?? '00',
                          style: TextStyle(color: Colors.blue.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '₹ \${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getImageForCategory(String category) {
    String url = '';
    if (category == 'Tea') url = 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=200&q=80';
    else if (category == 'Coffee') url = 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=200&q=80';
    else if (category == 'Water Bottle') url = 'https://images.unsplash.com/photo-1523362628745-0c100150b504?auto=format&fit=crop&w=200&q=80';
    else if (category == 'Cool Drinks') url = 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=200&q=80';
    else url = 'https://images.unsplash.com/photo-1596726759795-1f8cb1594917?auto=format&fit=crop&w=200&q=80';

    return Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200, child: const Icon(Icons.image, color: Colors.grey)));
  }

  Widget? _buildCartFab() {
    final cart = ref.watch(cartProvider);
    if (cart.items.isEmpty) return null;

    return FloatingActionButton.extended(
      backgroundColor: Colors.blue.shade700,
      onPressed: () {
        // Just show checkout logic (bottom sheet for now)
      },
      icon: const Icon(Icons.shopping_cart, color: Colors.white),
      label: Text('₹ \${cart.total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      selectedItemColor: Colors.blue.shade700,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.local_cafe), label: 'Items'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), label: 'Orders'),
        BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Customers'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    );
  }
}

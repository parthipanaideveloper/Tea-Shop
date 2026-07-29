import 'package:flutter/material.dart';
import '../../services/firebase_sync_service.dart';
import '../master_admin/master_admin_screen.dart';

class GlobalSearchOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<ShopRegistryEntry> onSelectShop;

  const GlobalSearchOverlay({
    super.key,
    required this.onClose,
    required this.onSelectShop,
  });

  @override
  State<GlobalSearchOverlay> createState() => _GlobalSearchOverlayState();
}

class _GlobalSearchOverlayState extends State<GlobalSearchOverlay> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final shops = await FirebaseSyncService.instance
          .getAllShopsFromRegistry();
      final q = query.toLowerCase();

      final matches = shops.where((shop) {
        final code = (shop['shopCode'] ?? shop['id'] ?? '')
            .toString()
            .toLowerCase();
        final name = (shop['shopName'] ?? '').toString().toLowerCase();
        return code.contains(q) || name.contains(q);
      }).toList();

      if (mounted) {
        setState(() {
          _results = matches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.6), // darkened backdrop
      child: Center(
        child: Container(
          width: 550,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header tag for registry search only
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                color: const Color(0xFFF1F5F9),
                child: Row(
                  children: const [
                    Icon(
                      Icons.storefront_rounded,
                      size: 16,
                      color: Color(0xFF4F46E5),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'REGISTRY SHOP SEARCH ONLY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F46E5),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              // Search Input Section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      color: Color(0xFF94A3B8),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search shop code or name...',
                          hintStyle: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: _onSearch,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                )
              else if (_results.isNotEmpty)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final shop = _results[index];
                      final name = (shop['shopName'] ?? 'Unknown Shop')
                          .toString();
                      final code = (shop['shopCode'] ?? shop['id'] ?? '')
                          .toString();

                      // Status Badge Calculation
                      final isBlocked = shop['isBlocked'] ?? false;
                      final validUntilStr = shop['validUntil'];
                      final validUntil = validUntilStr != null
                          ? DateTime.tryParse(validUntilStr.toString())
                          : null;
                      final isExpired =
                          validUntil != null &&
                          DateTime.now().isAfter(validUntil);

                      String statusText = 'ACTIVE';
                      Color statusColor = const Color(0xFF10B981);
                      Color statusBg = const Color(0xFFD1FAE5);
                      if (isBlocked) {
                        statusText = 'BLOCKED';
                        statusColor = const Color(0xFFEF4444);
                        statusBg = const Color(0xFFFEE2E2);
                      } else if (isExpired) {
                        statusText = 'EXPIRED';
                        statusColor = const Color(0xFFF59E0B);
                        statusBg = const Color(0xFFFEF3C7);
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          final shopEntry = ShopRegistryEntry(
                            shopCode: code,
                            shopName: name,
                            registeredAt: shop['registeredAt'] != null
                                ? DateTime.tryParse(
                                        shop['registeredAt'].toString(),
                                      ) ??
                                      DateTime.now()
                                : DateTime.now(),
                            validUntil: validUntil,
                            isBlocked: isBlocked,
                            isGlobalInventoryEnabled:
                                shop['isGlobalInventoryEnabled'] ?? false,
                            isDemoVersion:
                                shop['isDemoVersion'] == true ||
                                shop['isDemoVersion'] == 'true',
                            showStoreInfo:
                                shop['showStoreInfo'] != 'false' &&
                                shop['showStoreInfo'] != false,
                            showAppSettings:
                                shop['showAppSettings'] != 'false' &&
                                shop['showAppSettings'] != false,
                            showReceiptOptions:
                                shop['showReceiptOptions'] != 'false' &&
                                shop['showReceiptOptions'] != false,
                            showCheckoutFeatures:
                                shop['showCheckoutFeatures'] != 'false' &&
                                shop['showCheckoutFeatures'] != false,
                            dietaryFilter: (shop['dietaryFilter'] ?? 'both')
                                .toString(),
                          );
                          widget.onSelectShop(shopEntry);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFEEF2FF),
                                child: const Icon(
                                  Icons.storefront,
                                  color: Color(0xFF4F46E5),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Code: $code',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF94A3B8),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                )
              else if (_searchController.text.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: Text(
                    'No matching shops found.',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

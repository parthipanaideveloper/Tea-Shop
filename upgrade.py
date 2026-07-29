import re

with open('lib/presentation/master_admin/master_admin_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

start_class = text.find('class _ShopActionScreenState extends ConsumerState<ShopActionScreen> {')
start = text.find('  @override\n  Widget build(BuildContext context) {', start_class)
end = text.rfind('}\n}')

if start != -1 and end != -1:
    new_build = '''  Widget _buildExtendBtn(String label, int days) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
          BoxShadow(color: Color(0xFFD1D9E6), blurRadius: 4, offset: Offset(2, 2)),
        ],
        borderRadius: BorderRadius.circular(8),
      ),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: kMasterWorkspaceColor,
          foregroundColor: const Color(0xFF4F46E5),
          side: const BorderSide(color: Color(0xFF4F46E5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => _extendValidity(days),
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final fmt = DateFormat('dd MMM yyyy');

    final headerSection = [
      Row(
        children: [
          const Icon(Icons.store, color: Color(0xFF4F46E5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))),
                Text(shop.shopCode, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: shop.statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: shop.statusColor.withOpacity(0.3))),
            child: Text(shop.statusLabel, style: TextStyle(color: shop.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (shop.validUntil != null) Text('Valid Until: \', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      const Divider(height: 24, color: Color(0xFFE2E8F0)),
    ];

    final coreSettings = [
      _buildNeumorphicTile(
        title: 'Block Access',
        subtitle: shop.isBlocked ? 'Shop is currently BLOCKED — login denied' : 'Shop has normal access',
        value: shop.isBlocked,
        icon: shop.isBlocked ? Icons.lock : Icons.lock_open,
        iconColor: shop.isBlocked ? Colors.red : Colors.green,
        onChanged: (val) => _setBlocked(val),
      ),
      _buildNeumorphicTile(
        title: 'Demo Version Mode',
        subtitle: shop.isDemoVersion ? 'App will show "This is a demo version" banner' : 'Normal production mode',
        value: shop.isDemoVersion,
        icon: shop.isDemoVersion ? Icons.info_outline : Icons.verified,
        iconColor: shop.isDemoVersion ? Colors.orange : Colors.blue,
        onChanged: (val) => _setDemoVersion(val),
      ),
      _buildNeumorphicTile(
        title: 'Global Inventory Database',
        subtitle: shop.isGlobalInventoryEnabled ? 'Shop syncs from Master Global Inventory' : 'Shop uses isolated Local Inventory',
        value: shop.isGlobalInventoryEnabled,
        icon: shop.isGlobalInventoryEnabled ? Icons.cloud_sync : Icons.cloud_off,
        iconColor: shop.isGlobalInventoryEnabled ? Colors.deepPurple : Colors.grey,
        onChanged: (val) => _setGlobalInventory(val),
      ),
    ];

    final featureSettings = [
      const Text('App Features Visibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      _buildNeumorphicFeatureTile(title: 'Store Information', value: shop.showStoreInfo, onChanged: (val) => _setFeatureToggle('showStoreInfo', val, (v) => shop.showStoreInfo = v)),
      _buildNeumorphicFeatureTile(title: 'App Settings', value: shop.showAppSettings, onChanged: (val) => _setFeatureToggle('showAppSettings', val, (v) => shop.showAppSettings = v)),
      _buildNeumorphicFeatureTile(title: 'Receipt Options', value: shop.showReceiptOptions, onChanged: (val) => _setFeatureToggle('showReceiptOptions', val, (v) => shop.showReceiptOptions = v)),
      _buildNeumorphicFeatureTile(title: 'Checkout & Cart Features', value: shop.showCheckoutFeatures, onChanged: (val) => _setFeatureToggle('showCheckoutFeatures', val, (v) => shop.showCheckoutFeatures = v)),
    ];

    final dietarySettings = [
      const Text('Dietary Filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: const Color(0xFFE0E7FF),
            selectedForegroundColor: const Color(0xFF4F46E5),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          segments: const [
            ButtonSegment(value: 'both', label: Text('Both'), icon: Icon(Icons.restaurant, size: 18)),
            ButtonSegment(value: 'veg', label: Text('Veg'), icon: Icon(Icons.eco, size: 18)),
            ButtonSegment(value: 'nonveg', label: Text('Non-Veg'), icon: Icon(Icons.set_meal, size: 18)),
          ],
          selected: {shop.dietaryFilter},
          onSelectionChanged: (Set<String> newSelection) => _setDietaryFilter(newSelection.first),
        ),
      ),
    ];

    final actionSettings = [
      Container(
        decoration: BoxDecoration(
          boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)), BoxShadow(color: Color(0xFFD1D9E6), blurRadius: 4, offset: Offset(2, 2))],
          borderRadius: BorderRadius.circular(10),
        ),
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            setState(() => _loading = true);
            try {
              await FirebaseSyncService().injectGlobalDefaults(widget.shop.shopCode);
              if (mounted) NotificationHelper.showCenter(context, 'Global Inventory injected into "\" successfully!', isError: false);
            } catch (e) {
              if (mounted) NotificationHelper.showCenter(context, 'Failed to inject global inventory: \', isError: true);
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          icon: const Icon(Icons.sync),
          label: const Text('Force Sync Global Inventory Defaults', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      const Divider(height: 36, color: Color(0xFFE2E8F0)),
      const Text('Extend Validity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _buildExtendBtn('+30 Days', 30)),
          const SizedBox(width: 12),
          Expanded(child: _buildExtendBtn('+90 Days', 90)),
          const SizedBox(width: 12),
          Expanded(child: _buildExtendBtn('+365 Days', 365)),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(
          boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)), BoxShadow(color: Color(0xFFD1D9E6), blurRadius: 4, offset: Offset(2, 2))],
          borderRadius: BorderRadius.circular(10),
        ),
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: kMasterWorkspaceColor,
            foregroundColor: const Color(0xFF4F46E5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: const BorderSide(color: Color(0xFF4F46E5)),
          ),
          onPressed: _setCustomDate,
          icon: const Icon(Icons.edit_calendar),
          label: const Text('Set Custom Date', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      const Divider(height: 36, color: Color(0xFFE2E8F0)),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _deleteShop,
          icon: const Icon(Icons.delete_forever),
          label: const Text('Delete Shop Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: kMasterWorkspaceColor,
      appBar: AppBar(
        title: const Text('Manage Shop', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: kMasterWorkspaceColor,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        leading: BackButton(onPressed: widget.onBack ?? () => Navigator.pop(context)),
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: isDesktop
                            ? Column(
                                children: [
                                  ...headerSection,
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ...coreSettings,
                                            const SizedBox(height: 24),
                                            ...dietarySettings,
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 48),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ...featureSettings,
                                            const SizedBox(height: 24),
                                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                            const SizedBox(height: 24),
                                            ...actionSettings,
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...headerSection,
                                  ...coreSettings,
                                  const SizedBox(height: 16),
                                  ...featureSettings,
                                  const SizedBox(height: 16),
                                  ...dietarySettings,
                                  const Divider(height: 36, color: Color(0xFFE2E8F0)),
                                  ...actionSettings,
                                ],
                              ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
'''
    text = text[:start] + new_build + '\n}\n'
    with open('lib/presentation/master_admin/master_admin_screen.dart', 'w', encoding='utf-8') as f:
        f.write(text)
    print("Done")
else:
    print("Could not find boundaries", start, end)

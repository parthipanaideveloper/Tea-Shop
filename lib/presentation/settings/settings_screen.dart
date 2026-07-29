import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import '../../core/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../../providers/settings_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/refund_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../core/extensions/string_extensions.dart';
import '../../services/backup_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/master_password_service.dart';
import '../../providers/order_provider.dart';
import '../widgets/neumorphic_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  int _activeTab = 0;
  late TextEditingController _shopNameCtrl;
  late TextEditingController _shopNameTamilCtrl;
  late TextEditingController _upiIdCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _receiptHeaderCtrl;
  late TextEditingController _receiptFooterCtrl;
  late TextEditingController _aiApiKeyCtrl;
  late TextEditingController _addressLine1Ctrl;
  late TextEditingController _addressLine2Ctrl;
  late TextEditingController _hotelTypeCtrl;
  late TextEditingController _mobileNumberCtrl;
  late TextEditingController _fssaiNumberCtrl;
  bool _showGstOnReceipt = true;
  bool _showStockQuantity = true;
  bool _enableTaxCalculation = true;
  bool _enableTableNumber = false;
  bool _enableDiscountInCart = false;
  bool _enableCustomerDetails = false;
  bool _enableAddressOnReceipt = false;
  bool _enableMobileOnReceipt = false;
  bool _enableFssaiOnReceipt = false;
  bool _enableHotelTypeOnReceipt = false;
  bool _enableShopDetailsOnKot = false;
  bool _enableKotReceipt = true;
  bool _enablePopularCategory = true;
  bool _enablePaymentModeSelection = false;
  bool _enableTokenLimit = true;
  bool _dailyResetOrderId = false;
  bool _showMasterAdminLook = true;
  bool _enableSplitPayment = true;
  bool _hideImagesInCheckout = false;
  bool _enableDineIn = true;
  bool _enableParcel = true;
  bool _showPoweredByDiyan = true;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _shopNameCtrl = TextEditingController(text: settings.shopName);
    _shopNameTamilCtrl = TextEditingController(
      text: settings.shopNameTamil ?? '',
    );
    _upiIdCtrl = TextEditingController(text: settings.upiId);
    _gstCtrl = TextEditingController(text: settings.gstNumber);
    _taxCtrl = TextEditingController(text: settings.taxRate.toString());
    _receiptHeaderCtrl = TextEditingController(text: settings.receiptHeader);
    _receiptFooterCtrl = TextEditingController(text: settings.receiptFooter);
    _addressLine1Ctrl = TextEditingController(
      text: settings.addressLine1 ?? '',
    );
    _addressLine2Ctrl = TextEditingController(
      text: settings.addressLine2 ?? '',
    );
    _hotelTypeCtrl = TextEditingController(text: settings.hotelType ?? '');
    _mobileNumberCtrl = TextEditingController(
      text: settings.mobileNumber ?? '',
    );
    _fssaiNumberCtrl = TextEditingController(text: settings.fssaiNumber ?? '');
    _receiptHeaderCtrl.text = settings.receiptHeader;
    _receiptFooterCtrl.text = settings.receiptFooter;
    _showGstOnReceipt = settings.showGstOnReceipt;
    _showStockQuantity = settings.showStockQuantity;
    _enableTaxCalculation = settings.enableTaxCalculation;
    _enableTableNumber = settings.enableTableNumber;
    _enableDiscountInCart = settings.enableDiscountInCart;
    _enableCustomerDetails = settings.enableCustomerDetails;
    _enableAddressOnReceipt = settings.enableAddressOnReceipt;
    _enableMobileOnReceipt = settings.enableMobileOnReceipt;
    _enableFssaiOnReceipt = settings.enableFssaiOnReceipt;
    _enableHotelTypeOnReceipt = settings.enableHotelTypeOnReceipt;
    _enableShopDetailsOnKot = settings.enableShopDetailsOnKot;
    _enableKotReceipt = settings.enableKotReceipt;
    _enablePopularCategory = settings.enablePopularCategory;
    _enablePaymentModeSelection = settings.enablePaymentModeSelection;
    _enableTokenLimit = settings.enableTokenLimit;
    _dailyResetOrderId = settings.dailyResetOrderId;
    _showMasterAdminLook = settings.showMasterAdminLook;
    _enableSplitPayment = settings.enableSplitPayment;
    _hideImagesInCheckout = settings.hideImagesInCheckout;
    _enableDineIn = settings.enableDineIn;
    _enableParcel = settings.enableParcel;
    _showPoweredByDiyan = settings.showPoweredByDiyan;
    _logoPath = settings.shopLogoPath;
    // Check for security alerts
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSecurityAlerts());
  }

  Future<void> _checkSecurityAlerts() async {
    final alerts = await ref.read(authProvider.notifier).checkLoginAlerts();
    if (alerts.isNotEmpty && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text(
                'Security Alert!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Someone tried to log into your Admin account from an unknown device on ${alerts.first['timestamp']?.toString().substring(0, 10) ?? 'recently'}.\n\nIf this was not you, please change your Admin password immediately!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('DISMISS'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _showChangeAdminPasswordDialog();
              },
              child: const Text('CHANGE PASSWORD NOW'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopNameTamilCtrl.dispose();
    _upiIdCtrl.dispose();
    _gstCtrl.dispose();
    _taxCtrl.dispose();
    _receiptHeaderCtrl.dispose();
    _receiptFooterCtrl.dispose();
    _addressLine1Ctrl.dispose();
    _addressLine2Ctrl.dispose();
    _hotelTypeCtrl.dispose();
    _mobileNumberCtrl.dispose();
    _fssaiNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 300,
        maxHeight: 300,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        setState(() => _logoPath = base64String);
        ref
            .read(settingsProvider.notifier)
            .updateSettings(shopLogoPath: base64String);
        NotificationHelper.showCenter(
          context,
          'Shop Logo Updated Instantly! 🎉',
          isError: false,
        );
      }
    } catch (e) {
      if (context.mounted)
        NotificationHelper.showCenter(context, 'Error: $e', isError: true);
    }
  }

  void _showChangeAdminPasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Change Admin Password',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (err != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    err!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                  isDense: true,
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
                if (newCtrl.text != confirmCtrl.text) {
                  setDialogState(() => err = 'Passwords do not match');
                  return;
                }
                if (newCtrl.text.length < 6) {
                  setDialogState(
                    () => err = 'Password must be at least 6 characters',
                  );
                  return;
                }
                // Verify current password
                final success = ref
                    .read(authProvider.notifier)
                    .login('admin', currentCtrl.text);
                if (!success) {
                  setDialogState(() => err = 'Current password is incorrect');
                  return;
                }
                ref
                    .read(authProvider.notifier)
                    .setupAdminCredentials('admin', newCtrl.text);
                Navigator.pop(ctx);
                NotificationHelper.showCenter(
                  context,
                  'Admin password changed successfully! ✅',
                  isError: false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('CHANGE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeMasterPasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.vpn_key, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text(
                'Change Master Password',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (err != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    err!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Master Password',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Master Password',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Master Password',
                  border: OutlineInputBorder(),
                  isDense: true,
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
              onPressed: () async {
                if (!MasterPasswordService().verifyMasterPassword(
                  currentCtrl.text,
                )) {
                  setDialogState(
                    () => err = 'Current master password is incorrect',
                  );
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  setDialogState(() => err = 'Passwords do not match');
                  return;
                }
                if (newCtrl.text.length < 8) {
                  setDialogState(
                    () => err = 'Master password must be at least 8 characters',
                  );
                  return;
                }
                await MasterPasswordService().setMasterPassword(newCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  NotificationHelper.showCenter(
                    context,
                    'Master password changed successfully! 🔐',
                    isError: false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('CHANGE'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAll() {
    if (_formKey.currentState!.validate()) {
      ref
          .read(settingsProvider.notifier)
          .updateSettings(
            shopName: _shopNameCtrl.text.trim(),
            shopNameTamil: _shopNameTamilCtrl.text.isEmpty
                ? null
                : _shopNameTamilCtrl.text.trim(),
            upiId: _upiIdCtrl.text.trim(),
            gstNumber: _gstCtrl.text.trim(),
            taxRate: double.tryParse(_taxCtrl.text) ?? 5.0,
            shopLogoPath: _logoPath,
            receiptHeader: _receiptHeaderCtrl.text.trim(),
            receiptFooter: _receiptFooterCtrl.text.trim(),
            showGstOnReceipt: _showGstOnReceipt,
            showStockQuantity: _showStockQuantity,
            enableTaxCalculation: _enableTaxCalculation,
            addressLine1: _addressLine1Ctrl.text.trim(),
            addressLine2: _addressLine2Ctrl.text.trim(),
            hotelType: _hotelTypeCtrl.text.trim(),
            mobileNumber: _mobileNumberCtrl.text.trim(),
            fssaiNumber: _fssaiNumberCtrl.text.trim(),
            enableAddressOnReceipt: _enableAddressOnReceipt,
            enableMobileOnReceipt: _enableMobileOnReceipt,
            enableFssaiOnReceipt: _enableFssaiOnReceipt,
            enableHotelTypeOnReceipt: _enableHotelTypeOnReceipt,
            enableShopDetailsOnKot: _enableShopDetailsOnKot,
            showMasterAdminLook: _showMasterAdminLook,
          );

      // Auto-sync settings to cloud so staff devices get the update immediately
      FirebaseSyncService().pushSync();

      NotificationHelper.showCenter(
        context,
        'Settings Saved Successfully!',
        isError: false,
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  ImageProvider? _getLogoProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.length < 255 && File(path).existsSync()) {
      return FileImage(File(path));
    }
    try {
      String cleanBase64 = path;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
      while (cleanBase64.length % 4 != 0) {
        cleanBase64 += '=';
      }
      return MemoryImage(base64Decode(cleanBase64));
    } catch (e) {
      return null;
    }
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final Map<String, Color> colorMap = {
      'Store Information': const Color(0xFF3B82F6), // Blue
      'App Settings': const Color(0xFF10B981), // Emerald
      'Receipt Options': const Color(0xFF8B5CF6), // Purple
      'Checkout & Cart Features': const Color(0xFFF59E0B), // Amber
      'Database Backup & Restore': const Color(0xFF06B6D4), // Cyan
      'Security': const Color(0xFF6366F1), // Indigo
      'Danger Zone (Advanced)': const Color(0xFFEF4444), // Red
    };

    final color = colorMap[title] ?? Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 24),
      shadowColor: color.withOpacity(0.3),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: title == 'Store Information',
          collapsedBackgroundColor: color.withOpacity(0.05),
          backgroundColor: Colors.white,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 8.0,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color.withOpacity(0.9),
            ),
          ),
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getSidebarItems(
    bool isMasterAdmin,
    SettingsState settings,
  ) {
    return [
      if (settings.showStoreInfo)
        {
          'index': 0,
          'title': 'Store Information',
          'icon': Icons.storefront_outlined,
          'color': const Color(0xFF0284C7),
          'bgColor': const Color(0xFFE0F2FE),
        },
      if (settings.showAppSettings)
        {
          'index': 1,
          'title': 'App Settings',
          'icon': Icons.settings_applications_outlined,
          'color': const Color(0xFF059669),
          'bgColor': const Color(0xFFD1FAE5),
        },
      if (settings.showReceiptOptions)
        {
          'index': 2,
          'title': 'Receipt Options',
          'icon': Icons.receipt_long_outlined,
          'color': const Color(0xFF7C3AED),
          'bgColor': const Color(0xFFF3E8FF),
        },
      if (settings.showCheckoutFeatures)
        {
          'index': 3,
          'title': 'Checkout & Cart Features',
          'icon': Icons.shopping_cart_checkout_outlined,
          'color': const Color(0xFFD97706),
          'bgColor': const Color(0xFFFEF3C7),
        },
      {
        'index': 4,
        'title': 'Database Backup & Restore',
        'icon': Icons.backup_outlined,
        'color': const Color(0xFF0891B2),
        'bgColor': const Color(0xFFECFEFF),
      },
      {
        'index': 5,
        'title': 'Security',
        'icon': Icons.security_outlined,
        'color': const Color(0xFF4F46E5),
        'bgColor': const Color(0xFFE0E7FF),
      },
      if (MasterPasswordService().isHostDevice())
        {
          'index': 6,
          'title': 'Danger Zone (Advanced)',
          'icon': Icons.warning_amber_rounded,
          'color': const Color(0xFFDC2626),
          'bgColor': const Color(0xFFFEE2E2),
        },
    ];
  }

  Widget _buildDetailView(
    bool isMasterAdmin,
    SettingsState settings,
    ThemeData theme,
  ) {
    switch (_activeTab) {
      case 0:
        return _buildStoreInfoTab(theme);
      case 1:
        return _buildAppSettingsTab(theme);
      case 2:
        return _buildReceiptOptionsTab(theme);
      case 3:
        return _buildCheckoutFeaturesTab(isMasterAdmin, settings, theme);
      case 4:
        return _buildBackupRestoreTab(theme);
      case 5:
        return _buildSecurityTab(theme);
      case 6:
        if (MasterPasswordService().isHostDevice()) {
          return _buildDangerZoneTab(theme);
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStoreInfoTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickLogo,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: Colors.grey.shade100,
                      backgroundImage: _getLogoProvider(_logoPath),
                      child: _logoPath == null
                          ? Icon(
                              Icons.storefront_outlined,
                              size: 54,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload Shop Logo',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Tap profile icon to upload logo',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _shopNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shop Name',
                  prefixIcon: Icon(Icons.storefront),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _shopNameTamilCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shop Name (Tamil)',
                  prefixIcon: Icon(Icons.language),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _upiIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business UPI ID',
                  prefixIcon: Icon(Icons.qr_code),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _gstCtrl,
                decoration: const InputDecoration(
                  labelText: 'GST Number',
                  prefixIcon: Icon(Icons.receipt_long),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _taxCtrl,
          decoration: const InputDecoration(
            labelText: 'Default Tax Rate (%)',
            prefixIcon: Icon(Icons.percent),
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildAppSettingsTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: ref.watch(languageProvider),
          decoration: InputDecoration(
            labelText: 'Language'.tr(ref.watch(languageProvider)),
            prefixIcon: const Icon(Icons.language),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'en',
              child: Text('English'.tr(ref.watch(languageProvider))),
            ),
            DropdownMenuItem(
              value: 'ta',
              child: Text('Tamil'.tr(ref.watch(languageProvider))),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              ref.read(languageProvider.notifier).setLanguage(val);
            }
          },
        ),
      ],
    );
  }

  Widget _buildReceiptOptionsTab(ThemeData theme) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopPlatform =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final isWide = width >= 768 && isDesktopPlatform;

    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _receiptHeaderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Receipt Header Tagline',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text(
                        'Print KOT Receipt',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: const Text(
                        'Print Kitchen Order Ticket (KOT) during checkout',
                        style: TextStyle(fontSize: 11),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableKotReceipt,
                      onChanged: (val) {
                        setState(() => _enableKotReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableKotReceipt: val);
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text(
                        'Print Shop Details on KOT Receipt',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: const Text(
                        'Show address, phone, FSSAI, GST, hotel type on KOT',
                        style: TextStyle(fontSize: 11),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableShopDetailsOnKot,
                      onChanged: (val) {
                        setState(() => _enableShopDetailsOnKot = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableShopDetailsOnKot: val);
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text(
                        'Print Address on Receipt',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableAddressOnReceipt,
                      onChanged: (val) {
                        setState(() => _enableAddressOnReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableAddressOnReceipt: val);
                      },
                    ),
                    if (_enableAddressOnReceipt) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _addressLine1Ctrl,
                              decoration: const InputDecoration(
                                labelText: 'Address Line 1',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _addressLine2Ctrl,
                              decoration: const InputDecoration(
                                labelText: 'Address Line 2',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text(
                        'Print Hotel Type',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableHotelTypeOnReceipt,
                      onChanged: (val) {
                        setState(() => _enableHotelTypeOnReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableHotelTypeOnReceipt: val);
                      },
                    ),
                    if (_enableHotelTypeOnReceipt) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _hotelTypeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hotel Type',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _receiptFooterCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Receipt Footer Tagline',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text(
                        'Print Mobile No.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableMobileOnReceipt,
                      onChanged: (val) {
                        setState(() => _enableMobileOnReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableMobileOnReceipt: val);
                      },
                    ),
                    if (_enableMobileOnReceipt) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _mobileNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text(
                        'Print FSSAI No.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableFssaiOnReceipt,
                      onChanged: (val) {
                        setState(() => _enableFssaiOnReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableFssaiOnReceipt: val);
                      },
                    ),
                    if (_enableFssaiOnReceipt) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _fssaiNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'FSSAI Number',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text(
                        'Print GSTIN on Receipt',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _showGstOnReceipt,
                      onChanged: (val) {
                        setState(() => _showGstOnReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(showGstOnReceipt: val);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text(
                        "Print 'Powered by Diyan Tech Solutions' on Receipt",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _showPoweredByDiyan,
                      onChanged: (val) {
                        setState(() => _showPoweredByDiyan = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(showPoweredByDiyan: val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _receiptHeaderCtrl,
                decoration: const InputDecoration(
                  labelText: 'Receipt Header Tagline',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _receiptFooterCtrl,
                decoration: const InputDecoration(
                  labelText: 'Receipt Footer Tagline',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text(
            'Print KOT Receipt',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Print Kitchen Order Ticket (KOT) during checkout',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableKotReceipt,
          onChanged: (val) {
            setState(() => _enableKotReceipt = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableKotReceipt: val);
          },
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text(
            'Print Shop Details on KOT Receipt',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Show address, phone, FSSAI, GST, hotel type on KOT',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableShopDetailsOnKot,
          onChanged: (val) {
            setState(() => _enableShopDetailsOnKot = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableShopDetailsOnKot: val);
          },
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text(
            'Print Address on Receipt',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Show 2 lines of address below shop name',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableAddressOnReceipt,
          onChanged: (val) {
            setState(() => _enableAddressOnReceipt = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableAddressOnReceipt: val);
          },
        ),
        if (_enableAddressOnReceipt) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _addressLine1Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 1',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _addressLine2Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 2',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        SwitchListTile(
          title: const Text(
            'Print Hotel Type',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Show hotel type (e.g., A/C Veg & Non-Veg)',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableHotelTypeOnReceipt,
          onChanged: (val) {
            setState(() => _enableHotelTypeOnReceipt = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableHotelTypeOnReceipt: val);
          },
        ),
        if (_enableHotelTypeOnReceipt) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _hotelTypeCtrl,
            decoration: const InputDecoration(
              labelText: 'Hotel Type',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SwitchListTile(
          title: const Text(
            'Print Mobile No.',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Show mobile number on receipt',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableMobileOnReceipt,
          onChanged: (val) {
            setState(() => _enableMobileOnReceipt = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableMobileOnReceipt: val);
          },
        ),
        if (_enableMobileOnReceipt) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _mobileNumberCtrl,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SwitchListTile(
          title: const Text(
            'Print FSSAI No.',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Show FSSAI number on receipt',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableFssaiOnReceipt,
          onChanged: (val) {
            setState(() => _enableFssaiOnReceipt = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableFssaiOnReceipt: val);
          },
        ),
        if (_enableFssaiOnReceipt) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _fssaiNumberCtrl,
            decoration: const InputDecoration(
              labelText: 'FSSAI Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SwitchListTile(
          title: const Text(
            'Print GSTIN on Receipt',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Show the GST Identification Number on customer invoices',
            style: TextStyle(fontSize: 12),
          ),
          value: _showGstOnReceipt,
          onChanged: (val) {
            setState(() => _showGstOnReceipt = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(showGstOnReceipt: val);
          },
        ),
      ],
    );
  }

  Widget _buildCheckoutFeaturesTab(
    bool isMasterAdmin,
    SettingsState settings,
    ThemeData theme,
  ) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopPlatform =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final isWide = width >= 768 && isDesktopPlatform;

    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Enable Inventory Tracking',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _showStockQuantity,
                      onChanged: (val) {
                        setState(() => _showStockQuantity = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(showStockQuantity: val);
                      },
                    ),
                    SwitchListTile(
                      title: Text(
                        'Enable Tax Calculation'.tr(
                          ref.watch(languageProvider),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableTaxCalculation,
                      onChanged: (val) {
                        setState(() => _enableTaxCalculation = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableTaxCalculation: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Enable Table Number Field',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableTableNumber,
                      onChanged: (val) {
                        setState(() => _enableTableNumber = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableTableNumber: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Enable Discount in Cart',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableDiscountInCart,
                      onChanged: (val) {
                        setState(() => _enableDiscountInCart = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableDiscountInCart: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Show "Dine-In" Option in Checkout',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableDineIn,
                      onChanged: (val) {
                        setState(() => _enableDineIn = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableDineIn: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Show "Parcel" Option in Checkout',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableParcel,
                      onChanged: (val) {
                        setState(() => _enableParcel = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableParcel: val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Enable Add Customer in Cart',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableCustomerDetails,
                      onChanged: (val) {
                        setState(() => _enableCustomerDetails = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableCustomerDetails: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Show "Popular" Tab in Checkout',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enablePopularCategory,
                      onChanged: (val) {
                        setState(() => _enablePopularCategory = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enablePopularCategory: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Show Payment Mode Selector at Checkout',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enablePaymentModeSelection,
                      onChanged: (val) {
                        setState(() => _enablePaymentModeSelection = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enablePaymentModeSelection: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Enable Split Payment Option',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableSplitPayment,
                      onChanged: (val) {
                        setState(() => _enableSplitPayment = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableSplitPayment: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Hide Product Images in Checkout',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _hideImagesInCheckout,
                      onChanged: (val) {
                        setState(() => _hideImagesInCheckout = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(hideImagesInCheckout: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Enable 1-499 Token Limit',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _enableTokenLimit,
                      onChanged: (val) {
                        setState(() => _enableTokenLimit = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableTokenLimit: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Daily Reset Order ID Sequence',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _dailyResetOrderId,
                      onChanged: (val) {
                        setState(() => _dailyResetOrderId = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(dailyResetOrderId: val);
                      },
                    ),
                    if (isMasterAdmin)
                      SwitchListTile(
                        title: const Text(
                          'Customer Support Look',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        value: _showMasterAdminLook,
                        onChanged: (val) {
                          setState(() => _showMasterAdminLook = val);
                          ref
                              .read(settingsProvider.notifier)
                              .updateSettings(showMasterAdminLook: val);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text(
            'Enable Inventory Tracking',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'When off, products have unlimited stock and inventory limits are ignored.',
            style: TextStyle(fontSize: 12),
          ),
          value: _showStockQuantity,
          onChanged: (val) {
            setState(() => _showStockQuantity = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(showStockQuantity: val);
          },
        ),
        SwitchListTile(
          title: Text(
            'Enable Tax Calculation'.tr(ref.watch(languageProvider)),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Calculate tax automatically in checkout',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableTaxCalculation,
          onChanged: (val) {
            setState(() => _enableTaxCalculation = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableTaxCalculation: val);
          },
        ),
        SwitchListTile(
          title: const Text(
            'Enable Table Number Field',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Show a text field to enter Table Number when placing Dine-in orders',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableTableNumber,
          onChanged: (val) {
            setState(() => _enableTableNumber = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableTableNumber: val);
          },
        ),
        SwitchListTile(
          title: const Text(
            'Enable Discount in Cart',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Allow entering discount percentages during checkout',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableDiscountInCart,
          onChanged: (val) {
            setState(() => _enableDiscountInCart = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableDiscountInCart: val);
          },
        ),
        SwitchListTile(
          title: const Text(
            'Enable Add Customer in Cart',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Show a button to link a customer to the order in the cart',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableCustomerDetails,
          onChanged: (val) {
            setState(() => _enableCustomerDetails = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableCustomerDetails: val);
          },
        ),
        SwitchListTile(
          title: const Text(
            'Show "Popular" Tab in Checkout',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Shows a Popular 🔥 tab that lists best-selling items first',
            style: TextStyle(fontSize: 12),
          ),
          value: _enablePopularCategory,
          onChanged: (val) {
            setState(() => _enablePopularCategory = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enablePopularCategory: val);
          },
        ),
        SwitchListTile(
          title: const Text(
            'Show Payment Mode Selector at Checkout',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Allows Cash, UPI, and Split (partial Cash + UPI) payment entry',
            style: TextStyle(fontSize: 12),
          ),
          value: _enablePaymentModeSelection,
          onChanged: (val) {
            setState(() => _enablePaymentModeSelection = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enablePaymentModeSelection: val);
          },
        ),
        SwitchListTile(
          title: const Text(
            'Enable Split Payment Option',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Allows combining Cash and UPI modes for a single checkout',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableSplitPayment,
          onChanged: (val) {
            setState(() => _enableSplitPayment = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableSplitPayment: val);
          },
        ),
        SwitchListTile(
          title: const Text(
            'Hide Product Images in Checkout',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Hides images in checkout product grid for a more compact view',
            style: TextStyle(fontSize: 12),
          ),
          value: _hideImagesInCheckout,
          onChanged: (val) {
            setState(() => _hideImagesInCheckout = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(hideImagesInCheckout: val);
          },
        ),
        SwitchListTile(
          title: const Text(
            'Enable 1-499 Token Limit',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'If enabled, parcel tokens cycle 1-499 continuously. If disabled, tokens increment infinitely but reset to 1 daily at midnight.',
            style: TextStyle(fontSize: 12),
          ),
          value: _enableTokenLimit,
          onChanged: (val) {
            setState(() => _enableTokenLimit = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(enableTokenLimit: val);
          },
        ),
        SwitchListTile(
          title: const Text(
            'Daily Reset Order ID Sequence',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'If enabled, receipt order ID sequence resets to 1 daily.',
            style: TextStyle(fontSize: 12),
          ),
          value: _dailyResetOrderId,
          onChanged: (val) {
            setState(() => _dailyResetOrderId = val);
            ref
                .read(settingsProvider.notifier)
                .updateSettings(dailyResetOrderId: val);
          },
        ),
        if (isMasterAdmin)
          SwitchListTile(
            title: const Text(
              'Customer Support Look',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Toggle between full Customer Support layout and standard Admin layout view.',
              style: TextStyle(fontSize: 12),
            ),
            value: _showMasterAdminLook,
            onChanged: (val) {
              setState(() => _showMasterAdminLook = val);
              ref
                  .read(settingsProvider.notifier)
                  .updateSettings(showMasterAdminLook: val);
            },
          ),
      ],
    );
  }

  Widget _buildBackupRestoreTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Export or restore your transaction records, settings, and product list offline. Backups are saved to your device Downloads folder.',
          style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Backup Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final password = await UiUtils.showPasswordPrompt(
                    context,
                    title: 'Encrypt Backup',
                    message: 'Enter a strong password to encrypt your database backup. You will need this password to restore it later.',
                  );
                  if (password == null) return;

                  final backupService = BackupService();
                  final path = await backupService.exportBackup(
                    _shopNameCtrl.text,
                    password,
                  );
                  if (path != null) {
                    NotificationHelper.showCenter(
                      context,
                      'Backup exported successfully to:\n$path',
                      isError: false,
                    );
                  } else {
                    NotificationHelper.showCenter(
                      context,
                      'Failed to export backup. Check permissions.',
                      isError: true,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text('Restore Data'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final result = await fp.FilePicker.pickFiles(
                    type: fp.FileType.any,
                  );
                  if (result != null && result.files.single.path != null) {
                    final password = await UiUtils.showPasswordPrompt(
                      context,
                      title: 'Decrypt Backup',
                      message: 'Enter the password you used to encrypt this backup file.',
                    );
                    if (password == null) return;

                    final file = File(result.files.single.path!);
                    final backupService = BackupService();
                    final success = await backupService.importBackup(file, password);
                    if (success) {
                      NotificationHelper.showCenter(
                        context,
                        'Database restored successfully! 🎉 Please restart the app.',
                        isError: false,
                      );
                    } else {
                      NotificationHelper.showCenter(
                        context,
                        'Failed to restore backup. Invalid or tampered file, or incorrect password.',
                        isError: true,
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.lock_reset),
          label: const Text('Change Admin Password'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _showChangeAdminPasswordDialog,
        ),
      ],
    );
  }

  Widget _buildDangerZoneTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.vpn_key, color: Colors.deepPurple),
          label: const Text(
            'Change Master Password',
            style: TextStyle(color: Colors.deepPurple),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            side: const BorderSide(color: Colors.deepPurple),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _showChangeMasterPasswordDialog,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_forever, color: Colors.red),
          label: const Text(
            'Clear All Order History (Reset to 1)',
            style: TextStyle(color: Colors.red),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text(
                  '⚠️ Clear All Orders?',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: const Text(
                  'Are you absolutely sure you want to delete all order history? This will reset your Order ID back to AAA001.\n\nThis action cannot be undone!',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('CANCEL'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final orders = ref.read(orderProvider);
                      final inventoryNotifier = ref.read(
                        inventoryProvider.notifier,
                      );
                      final allProducts = ref.read(inventoryProvider);

                      for (var order in orders) {
                        for (var item in order.parsedItems) {
                          try {
                            final existingProduct = allProducts.firstWhere(
                              (p) => p.id == item.product.id,
                            );
                            final updatedProduct = existingProduct.copyWith(
                              stockCount:
                                  existingProduct.stockCount +
                                  item.quantity.ceil(),
                            );
                            inventoryNotifier.updateProduct(updatedProduct);
                          } catch (e) {}
                        }
                      }

                      await ref.read(orderProvider.notifier).clearAllOrders();
                      await ref
                          .read(expenseProvider.notifier)
                          .clearAllExpenses();
                      await ref.read(refundProvider.notifier).clearAllRefunds();
                      await FirebaseSyncService.instance.clearAllHistory();
                      await Hive.box<String>(
                        'settings',
                      ).put('parcelToken', '0');

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        NotificationHelper.showCenter(
                          context,
                          'All data cleared & stock restored!',
                          isError: true,
                        );
                      }
                    },
                    child: const Text('DELETE ALL'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final settings = ref.watch(settingsProvider);
    final isMasterAdmin =
        ref.watch(authProvider)?.id == 'host_admin' ||
        Hive.box<String>('settings').get('is_impersonating') == 'true';
    final canPop = Navigator.canPop(context);
    final width = MediaQuery.of(context).size.width;
    final isWide =
        width >= 768 &&
        !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isWide) {
      final sidebarItems = _getSidebarItems(isMasterAdmin, settings);

      if (_activeTab >= sidebarItems.length) {
        _activeTab = 0;
      }
      final activeItem = sidebarItems.isNotEmpty
          ? sidebarItems[_activeTab]
          : null;
      final activeColor = activeItem != null
          ? activeItem['color'] as Color
          : theme.colorScheme.primary;

      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF1F5F9),
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(top: 12.0, right: 32.0),
              child: ElevatedButton.icon(
                onPressed: _saveAll,
                icon: const Icon(Icons.check, size: 16, color: Colors.white),
                label: const Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 280,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                  ),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  itemCount: sidebarItems.length,
                  itemBuilder: (context, index) {
                    final item = sidebarItems[index];
                    final isSelected = _activeTab == index;
                    final itemColor = item['color'] as Color;
                    final itemBg = item['bgColor'] as Color;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? itemBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            _activeTab = index;
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Icon(
                          item['icon'] as IconData,
                          color: isSelected ? itemColor : Colors.grey.shade600,
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? itemColor
                                : const Color(0xFF0F172A),
                            fontSize: 14,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.chevron_right,
                                color: itemColor,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(32),
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: activeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  activeItem?['icon'] as IconData,
                                  color: activeColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeItem?['title'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: activeColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Configure and manage your ${activeItem?['title'].toString().toLowerCase()}',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Divider(color: Color(0xFFE2E8F0)),
                          ),
                          _buildDetailView(isMasterAdmin, settings, theme),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Store Configuration'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        automaticallyImplyLeading: canPop,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          TextButton(
            onPressed: _saveAll,
            child: Text(
              'Save',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickLogo,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 54,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _getLogoProvider(_logoPath),
                            child: _logoPath == null
                                ? Icon(
                                    Icons.store,
                                    size: 54,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upload Shop Logo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tap profile icon to upload logo',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (settings.showStoreInfo)
                _buildSectionCard(
                  title: 'Store Information',
                  icon: Icons.store_mall_directory_outlined,
                  children: [
                    TextFormField(
                      controller: _shopNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Shop Name',
                        prefixIcon: Icon(Icons.storefront),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _shopNameTamilCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Shop Name (Tamil)',
                        prefixIcon: Icon(Icons.language),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _upiIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Business UPI ID',
                        prefixIcon: Icon(Icons.qr_code),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gstCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GST Number',
                        prefixIcon: Icon(Icons.receipt_long),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _taxCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Default Tax Rate (%)',
                        prefixIcon: Icon(Icons.percent),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),

              if (settings.showAppSettings)
                _buildSectionCard(
                  title: 'App Settings'.tr(ref.watch(languageProvider)),
                  icon: Icons.settings_applications_outlined,
                  children: [
                    DropdownButtonFormField<String>(
                      value: ref.watch(languageProvider),
                      decoration: InputDecoration(
                        labelText: 'Language'.tr(ref.watch(languageProvider)),
                        prefixIcon: const Icon(Icons.language),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(
                            'English'.tr(ref.watch(languageProvider)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ta',
                          child: Text('Tamil'.tr(ref.watch(languageProvider))),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(languageProvider.notifier).setLanguage(val);
                        }
                      },
                    ),
                  ],
                ),

              if (settings.showReceiptOptions)
                _buildSectionCard(
                  title: 'Receipt Options',
                  icon: Icons.receipt_long_outlined,
                  children: [
                    TextFormField(
                      controller: _receiptHeaderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Receipt Header Tagline',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _receiptFooterCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Receipt Footer Tagline',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text(
                        'Print KOT Receipt',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Print Kitchen Order Ticket (KOT) during checkout',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableKotReceipt,
                      onChanged: (val) {
                        setState(() => _enableKotReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableKotReceipt: val);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text(
                        'Print Shop Details on KOT Receipt',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Show address, phone, FSSAI, GST, hotel type on KOT',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableShopDetailsOnKot,
                      onChanged: (val) {
                        setState(() => _enableShopDetailsOnKot = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableShopDetailsOnKot: val);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text(
                        'Print Address on Receipt',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Show 2 lines of address below shop name',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableAddressOnReceipt,
                      onChanged: (val) {
                        setState(() => _enableAddressOnReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableAddressOnReceipt: val);
                      },
                    ),
                    if (_enableAddressOnReceipt) ...[
                      TextFormField(
                        controller: _addressLine1Ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Address Line 1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressLine2Ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Address Line 2',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SwitchListTile(
                      title: const Text(
                        'Print Hotel Type',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Show hotel type (e.g., A/C Veg & Non-Veg)',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableHotelTypeOnReceipt,
                      onChanged: (val) {
                        setState(() => _enableHotelTypeOnReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableHotelTypeOnReceipt: val);
                      },
                    ),
                    if (_enableHotelTypeOnReceipt) ...[
                      TextFormField(
                        controller: _hotelTypeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hotel Type',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SwitchListTile(
                      title: const Text(
                        'Print Mobile No.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Show mobile number on receipt',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableMobileOnReceipt,
                      onChanged: (val) {
                        setState(() => _enableMobileOnReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableMobileOnReceipt: val);
                      },
                    ),
                    if (_enableMobileOnReceipt) ...[
                      TextFormField(
                        controller: _mobileNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SwitchListTile(
                      title: const Text(
                        'Print FSSAI No.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Show FSSAI number on receipt',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableFssaiOnReceipt,
                      onChanged: (val) {
                        setState(() => _enableFssaiOnReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableFssaiOnReceipt: val);
                      },
                    ),
                    if (_enableFssaiOnReceipt) ...[
                      TextFormField(
                        controller: _fssaiNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'FSSAI Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SwitchListTile(
                      title: const Text(
                        'Print GSTIN on Receipt',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Show the GST Identification Number on customer invoices',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _showGstOnReceipt,
                      onChanged: (val) {
                        setState(() => _showGstOnReceipt = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(showGstOnReceipt: val);
                      },
                    ),
                  ],
                ),

              if (settings.showCheckoutFeatures)
                _buildSectionCard(
                  title: 'Checkout & Cart Features',
                  icon: Icons.shopping_cart_checkout_outlined,
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Enable Inventory Tracking',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'When off, products have unlimited stock and inventory limits are ignored.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _showStockQuantity,
                      onChanged: (val) {
                        setState(() => _showStockQuantity = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(showStockQuantity: val);
                      },
                    ),
                    SwitchListTile(
                      title: Text(
                        'Enable Tax Calculation'.tr(
                          ref.watch(languageProvider),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Calculate tax automatically in checkout',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableTaxCalculation,
                      onChanged: (val) {
                        setState(() {
                          _enableTaxCalculation = val;
                        });
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableTaxCalculation: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Enable Table Number Field',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Show a text field to enter Table Number when placing Dine-in orders',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableTableNumber,
                      onChanged: (val) {
                        setState(() => _enableTableNumber = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableTableNumber: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Enable Discount in Cart',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Allow entering discount percentages during checkout',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableDiscountInCart,
                      onChanged: (val) {
                        setState(() => _enableDiscountInCart = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableDiscountInCart: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Enable Add Customer in Cart',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Show a button to link a customer to the order in the cart',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableCustomerDetails,
                      onChanged: (val) {
                        setState(() => _enableCustomerDetails = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableCustomerDetails: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Show "Popular" Tab in Checkout',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Shows a Popular 🔥 tab that lists best-selling items first',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enablePopularCategory,
                      onChanged: (val) {
                        setState(() => _enablePopularCategory = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enablePopularCategory: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Show Payment Mode Selector at Checkout',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Allows Cash, UPI, and Split (partial Cash + UPI) payment entry',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enablePaymentModeSelection,
                      onChanged: (val) {
                        setState(() => _enablePaymentModeSelection = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enablePaymentModeSelection: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Enable Split Payment Option',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Allows combining Cash and UPI modes for a single checkout',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableSplitPayment,
                      onChanged: (val) {
                        setState(() => _enableSplitPayment = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableSplitPayment: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Hide Product Images in Checkout',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Hides images in checkout product grid for a more compact view',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _hideImagesInCheckout,
                      onChanged: (val) {
                        setState(() => _hideImagesInCheckout = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(hideImagesInCheckout: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Enable 1-499 Token Limit',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'If enabled, parcel tokens cycle 1-499 continuously. If disabled, tokens increment infinitely but reset to 1 daily at midnight.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _enableTokenLimit,
                      onChanged: (val) {
                        setState(() => _enableTokenLimit = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(enableTokenLimit: val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Daily Reset Order ID Sequence',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      value: _dailyResetOrderId,
                      onChanged: (val) {
                        setState(() => _dailyResetOrderId = val);
                        ref
                            .read(settingsProvider.notifier)
                            .updateSettings(dailyResetOrderId: val);
                      },
                    ),
                    if (isMasterAdmin)
                      SwitchListTile(
                        title: const Text(
                          'Customer Support Look',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          'Toggle between full Customer Support layout and standard Admin layout view.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _showMasterAdminLook,
                        onChanged: (val) {
                          setState(() => _showMasterAdminLook = val);
                          ref
                              .read(settingsProvider.notifier)
                              .updateSettings(showMasterAdminLook: val);
                        },
                      ),
                  ],
                ),

              _buildSectionCard(
                title: 'Database Backup & Restore',
                icon: Icons.backup_outlined,
                children: [
                  const Text(
                    'Export or restore your transaction records, settings, and product list offline. Backups are saved to your device Downloads folder.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Backup Data'),
                          onPressed: () async {
                            final password = await UiUtils.showPasswordPrompt(
                              context,
                              title: 'Encrypt Backup',
                              message: 'Enter a strong password to encrypt your database backup. You will need this password to restore it later.',
                            );
                            if (password == null) return;

                            final backupService = BackupService();
                            final path = await backupService.exportBackup(
                              _shopNameCtrl.text,
                              password,
                            );
                            if (path != null) {
                              NotificationHelper.showCenter(
                                context,
                                'Backup exported successfully to:\n$path',
                                isError: false,
                              );
                            } else {
                              NotificationHelper.showCenter(
                                context,
                                'Failed to export backup. Check permissions.',
                                isError: true,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.upload),
                          label: const Text('Restore Data'),
                          onPressed: () async {
                            final result = await fp.FilePicker.pickFiles(
                              type: fp.FileType.any,
                            );
                            if (result != null &&
                                result.files.single.path != null) {
                              final password = await UiUtils.showPasswordPrompt(
                                context,
                                title: 'Decrypt Backup',
                                message: 'Enter the password you used to encrypt this backup file.',
                              );
                              if (password == null) return;

                              final file = File(result.files.single.path!);
                              final backupService = BackupService();
                              final success = await backupService.importBackup(
                                file,
                                password,
                              );
                              if (success) {
                                NotificationHelper.showCenter(
                                  context,
                                  'Database restored successfully! 🎉 Please restart the app.',
                                  isError: false,
                                );
                              } else {
                                NotificationHelper.showCenter(
                                  context,
                                  'Failed to restore backup. Invalid or tampered file, or incorrect password.',
                                  isError: true,
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              _buildSectionCard(
                title: 'Security',
                icon: Icons.security_outlined,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Change Admin Password'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _showChangeAdminPasswordDialog,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restore, color: Colors.orange),
                    label: const Text(
                      'Reset All Settings to Default',
                      style: TextStyle(color: Colors.orange),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.orange),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            'Reset All Settings?',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: const Text(
                            'Are you sure you want to reset all shop settings (header, footer, toggles, printer configurations) back to default values?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('CANCEL'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                await ref.read(settingsProvider.notifier).resetSettings();
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  NotificationHelper.showCenter(
                                    context,
                                    'All settings reset to default values!',
                                    isError: false,
                                  );
                                }
                              },
                              child: const Text('RESET DEFAULT'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),

              if (MasterPasswordService().isHostDevice())
                _buildSectionCard(
                  title: 'Danger Zone (Advanced)',
                  icon: Icons.warning_amber_rounded,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.vpn_key, color: Colors.deepPurple),
                      label: const Text(
                        'Change Master Password',
                        style: TextStyle(color: Colors.deepPurple),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.deepPurple),
                      ),
                      onPressed: _showChangeMasterPasswordDialog,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text(
                        'Clear All Order History (Reset to 1)',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text(
                              '⚠️ Clear All Orders?',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: const Text(
                              'Are you absolutely sure you want to delete all order history? This will reset your Order ID back to AAA001.\n\nThis action cannot be undone!',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('CANCEL'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final orders = ref.read(orderProvider);
                                  final inventoryNotifier = ref.read(
                                    inventoryProvider.notifier,
                                  );
                                  final allProducts = ref.read(
                                    inventoryProvider,
                                  );

                                  for (var order in orders) {
                                    for (var item in order.parsedItems) {
                                      try {
                                        final existingProduct = allProducts
                                            .firstWhere(
                                              (p) => p.id == item.product.id,
                                            );
                                        final updatedProduct = existingProduct
                                            .copyWith(
                                              stockCount:
                                                  existingProduct.stockCount +
                                                  item.quantity.ceil(),
                                            );
                                        inventoryNotifier.updateProduct(
                                          updatedProduct,
                                        );
                                      } catch (e) {}
                                    }
                                  }

                                  await ref
                                      .read(orderProvider.notifier)
                                      .clearAllOrders();
                                  await ref
                                      .read(expenseProvider.notifier)
                                      .clearAllExpenses();
                                  await ref
                                      .read(refundProvider.notifier)
                                      .clearAllRefunds();
                                  await FirebaseSyncService.instance
                                      .clearAllHistory();

                                  await Hive.box<String>(
                                    'settings',
                                  ).put('parcelToken', '0');

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    NotificationHelper.showCenter(
                                      context,
                                      'All data cleared & stock restored!',
                                      isError: true,
                                    );
                                  }
                                },
                                child: const Text('DELETE ALL'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isLandscape
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saveAll,
                    child: const Text(
                      'Confirm & Save Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

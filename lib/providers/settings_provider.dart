import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/firebase_sync_service.dart';
import 'cart_provider.dart';
import '../domain/models/printer_profile.dart';
import 'dart:convert';

class SettingsState {
  final String shopName;
  final String? shopNameTamil;
  final String upiId;
  final String gstNumber;
  final double taxRate;
  final String? shopLogoPath;
  final String receiptHeader;
  final String receiptFooter;
  final bool showGstOnReceipt;
  final bool enableStaffCustomerDirectory;
  final bool enableStaffInventory;
  final bool showStockQuantity;
  final bool enableStaffStockManagement;
  final bool enableTaxCalculation;
  final String? savedPrinterMacAddress;
  final bool enableStaffRefund;
  final bool enableStaffOrderHistory;
  final bool enableStaffEditBill; // New Receptionist Edit Bill
  final bool captainCustomerDirectory; // Captain Permissions
  final bool captainInventory;
  final bool captainStockManagement;
  final bool captainRefund;
  final bool captainOrderHistory;
  final bool captainEditBill;
  final bool enableStaffExpenses; // Receptionist expenses
  final bool captainExpenses; // Captain expenses
  final bool enableTableNumber;
  final bool enableDiscountInCart;
  final bool enableCustomerDetails;
  final bool printAsImage;
  final bool is80mmPaper;
  final String? addressLine1;
  final String? addressLine2;
  final String? hotelType;
  final String? mobileNumber;
  final String? fssaiNumber;
  final bool enableAddressOnReceipt;
  final bool enableMobileOnReceipt;
  final bool enableFssaiOnReceipt;
  final bool enableHotelTypeOnReceipt;
  final bool enableShopDetailsOnKot;
  final bool enableKotReceipt;
  bool enablePopularCategory;
  final bool enablePaymentModeSelection;
  final bool enableTokenLimit;
  final bool showMasterAdminLook;
  final String dietaryFilter;
  final bool enableMultiplePrinters;
  final List<PrinterProfile> customPrinters;
  final String printerConnectionType; // 'Bluetooth', 'Network', 'USB'
  final String? savedPrinterIpAddress;
  final bool enableSplitPayment;
  final bool hideImagesInCheckout;
  final bool dailyResetOrderId;
  final bool enableDineIn;
  final bool enableParcel;

  // App Features Visibility (Master Admin controls)
  final bool showStoreInfo;
  final bool showAppSettings;
  final bool showReceiptOptions;
  final bool showCheckoutFeatures;
  final bool showPoweredByDiyan;

  // Global Demo Mode
  final bool isDemoVersion;

  SettingsState({
    required this.shopName,
    this.shopNameTamil,
    this.enableDineIn = true,
    this.enableParcel = true,
    required this.upiId,
    required this.gstNumber,
    required this.taxRate,
    this.shopLogoPath,
    this.receiptHeader = 'WELCOME TO OUR SHOP',
    this.receiptFooter = 'THANK YOU, VISIT AGAIN!',
    this.showGstOnReceipt = true,
    this.enableStaffCustomerDirectory = true,
    this.enableStaffInventory = false,
    this.showStockQuantity = true,
    this.enableStaffStockManagement = false,
    this.enableTaxCalculation = true,
    this.enableStaffRefund = false,
    this.enableStaffOrderHistory = true,
    this.enableStaffEditBill = false,
    this.captainCustomerDirectory = true,
    this.captainInventory = true,
    this.captainStockManagement = true,
    this.captainRefund = true,
    this.captainOrderHistory = true,
    this.captainEditBill = true,
    this.enableStaffExpenses = false,
    this.captainExpenses = false,
    this.enableTableNumber = false,
    this.enableDiscountInCart = false,
    this.enableCustomerDetails = false,
    this.printAsImage = true,
    this.is80mmPaper = true,
    this.savedPrinterMacAddress,
    this.addressLine1,
    this.addressLine2,
    this.hotelType,
    this.mobileNumber,
    this.fssaiNumber,
    this.enableAddressOnReceipt = false,
    this.enableMobileOnReceipt = false,
    this.enableFssaiOnReceipt = false,
    this.enableHotelTypeOnReceipt = false,
    this.enableShopDetailsOnKot = false,
    this.enableKotReceipt = true,
    this.enablePopularCategory = true,
    this.enablePaymentModeSelection = false,
    this.enableTokenLimit = true,
    this.showMasterAdminLook = true,
    this.dietaryFilter = 'both',
    this.enableMultiplePrinters = false,
    this.customPrinters = const [],
    this.printerConnectionType = 'Bluetooth',
    this.savedPrinterIpAddress,
    this.showStoreInfo = true,
    this.showAppSettings = true,
    this.showReceiptOptions = true,
    this.showCheckoutFeatures = true,
    this.showPoweredByDiyan = true,
    this.isDemoVersion = false,
    this.enableSplitPayment = true,
    this.hideImagesInCheckout = false,
    this.dailyResetOrderId = false,
  });

  SettingsState copyWith({
    String? shopName,
    String? shopNameTamil,
    String? upiId,
    String? gstNumber,
    double? taxRate,
    String? shopLogoPath,
    String? receiptHeader,
    String? receiptFooter,
    bool? showGstOnReceipt,
    bool? enableStaffCustomerDirectory,
    bool? enableStaffInventory,
    bool? showStockQuantity,
    bool? enableStaffStockManagement,
    bool? enableTaxCalculation,
    bool? enableStaffRefund,
    bool? enableStaffOrderHistory,
    bool? enableStaffEditBill,
    bool? captainCustomerDirectory,
    bool? captainInventory,
    bool? captainStockManagement,
    bool? captainRefund,
    bool? captainOrderHistory,
    bool? captainEditBill,
    bool? enableStaffExpenses,
    bool? captainExpenses,
    bool? enableTableNumber,
    bool? enableDiscountInCart,
    bool? enableCustomerDetails,
    bool? printAsImage,
    bool? is80mmPaper,
    String? savedPrinterMacAddress,
    String? addressLine1,
    String? addressLine2,
    String? hotelType,
    String? mobileNumber,
    String? fssaiNumber,
    bool? enableAddressOnReceipt,
    bool? enableMobileOnReceipt,
    bool? enableFssaiOnReceipt,
    bool? enableHotelTypeOnReceipt,
    bool? enableShopDetailsOnKot,
    bool? enableKotReceipt,
    bool? enablePopularCategory,
    bool? enablePaymentModeSelection,
    bool? enableTokenLimit,
    bool? showMasterAdminLook,
    String? dietaryFilter,
    bool? enableMultiplePrinters,
    List<PrinterProfile>? customPrinters,
    String? printerConnectionType,
    String? savedPrinterIpAddress,
    bool? showStoreInfo,
    bool? showAppSettings,
    bool? showReceiptOptions,
    bool? showCheckoutFeatures,
    bool? showPoweredByDiyan,
    bool? enableSplitPayment,
    bool? hideImagesInCheckout,
    bool? dailyResetOrderId,
    bool? enableDineIn,
    bool? enableParcel,
  }) {
    return SettingsState(
      enableDineIn: enableDineIn ?? this.enableDineIn,
      enableParcel: enableParcel ?? this.enableParcel,
      shopName: shopName ?? this.shopName,
      shopNameTamil: shopNameTamil ?? this.shopNameTamil,
      upiId: upiId ?? this.upiId,
      gstNumber: gstNumber ?? this.gstNumber,
      taxRate: taxRate ?? this.taxRate,
      shopLogoPath: shopLogoPath ?? this.shopLogoPath,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      showGstOnReceipt: showGstOnReceipt ?? this.showGstOnReceipt,
      enableStaffCustomerDirectory:
          enableStaffCustomerDirectory ?? this.enableStaffCustomerDirectory,
      enableStaffInventory: enableStaffInventory ?? this.enableStaffInventory,
      showStockQuantity: showStockQuantity ?? this.showStockQuantity,
      enableStaffStockManagement:
          enableStaffStockManagement ?? this.enableStaffStockManagement,
      enableTaxCalculation: enableTaxCalculation ?? this.enableTaxCalculation,
      enableStaffRefund: enableStaffRefund ?? this.enableStaffRefund,
      enableStaffOrderHistory:
          enableStaffOrderHistory ?? this.enableStaffOrderHistory,
      enableStaffEditBill: enableStaffEditBill ?? this.enableStaffEditBill,
      captainCustomerDirectory:
          captainCustomerDirectory ?? this.captainCustomerDirectory,
      captainInventory: captainInventory ?? this.captainInventory,
      captainStockManagement:
          captainStockManagement ?? this.captainStockManagement,
      captainRefund: captainRefund ?? this.captainRefund,
      captainOrderHistory: captainOrderHistory ?? this.captainOrderHistory,
      captainEditBill: captainEditBill ?? this.captainEditBill,
      enableStaffExpenses: enableStaffExpenses ?? this.enableStaffExpenses,
      captainExpenses: captainExpenses ?? this.captainExpenses,
      enableTableNumber: enableTableNumber ?? this.enableTableNumber,
      enableDiscountInCart: enableDiscountInCart ?? this.enableDiscountInCart,
      enableCustomerDetails:
          enableCustomerDetails ?? this.enableCustomerDetails,
      printAsImage: printAsImage ?? this.printAsImage,
      is80mmPaper: is80mmPaper ?? this.is80mmPaper,
      savedPrinterMacAddress:
          savedPrinterMacAddress ?? this.savedPrinterMacAddress,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      hotelType: hotelType ?? this.hotelType,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      fssaiNumber: fssaiNumber ?? this.fssaiNumber,
      enableAddressOnReceipt:
          enableAddressOnReceipt ?? this.enableAddressOnReceipt,
      enableMobileOnReceipt:
          enableMobileOnReceipt ?? this.enableMobileOnReceipt,
      enableFssaiOnReceipt: enableFssaiOnReceipt ?? this.enableFssaiOnReceipt,
      enableHotelTypeOnReceipt:
          enableHotelTypeOnReceipt ?? this.enableHotelTypeOnReceipt,
      enableShopDetailsOnKot:
          enableShopDetailsOnKot ?? this.enableShopDetailsOnKot,
      enableKotReceipt: enableKotReceipt ?? this.enableKotReceipt,
      enablePopularCategory:
          enablePopularCategory ?? this.enablePopularCategory,
      enablePaymentModeSelection:
          enablePaymentModeSelection ?? this.enablePaymentModeSelection,
      enableTokenLimit: enableTokenLimit ?? this.enableTokenLimit,
      showMasterAdminLook: showMasterAdminLook ?? this.showMasterAdminLook,
      dietaryFilter: dietaryFilter ?? this.dietaryFilter,
      enableMultiplePrinters:
          enableMultiplePrinters ?? this.enableMultiplePrinters,
      customPrinters: customPrinters ?? this.customPrinters,
      printerConnectionType:
          printerConnectionType ?? this.printerConnectionType,
      savedPrinterIpAddress:
          savedPrinterIpAddress ?? this.savedPrinterIpAddress,
      showStoreInfo: showStoreInfo ?? this.showStoreInfo,
      showAppSettings: showAppSettings ?? this.showAppSettings,
      showReceiptOptions: showReceiptOptions ?? this.showReceiptOptions,
      showCheckoutFeatures: showCheckoutFeatures ?? this.showCheckoutFeatures,
      showPoweredByDiyan: showPoweredByDiyan ?? this.showPoweredByDiyan,
      isDemoVersion: isDemoVersion ?? this.isDemoVersion,
      enableSplitPayment: enableSplitPayment ?? this.enableSplitPayment,
      hideImagesInCheckout: hideImagesInCheckout ?? this.hideImagesInCheckout,
      dailyResetOrderId: dailyResetOrderId ?? this.dailyResetOrderId,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final box = Hive.box<String>('settings');

    // Listen to Firebase sync changes
    final sub = box.watch().listen((_) {
      state = _loadState(box);
    });
    ref.onDispose(() => sub.cancel());

    return _loadState(box);
  }

  SettingsState _loadState(Box<String> box) {
    List<PrinterProfile> loadedPrinters = [];
    try {
      final printersJson = box.get('customPrinters');
      if (printersJson != null) {
        final List<dynamic> list = jsonDecode(printersJson);
        loadedPrinters = list.map((e) => PrinterProfile.fromMap(e)).toList();
      }
    } catch (_) {}

    return SettingsState(
      shopName: box.get('shopName') ?? 'Enterprise POS',
      shopNameTamil: box.get('shopNameTamil'),
      upiId: box.get('upiId') ?? 'demo@upi',
      gstNumber: box.get('gstNumber') ?? 'GSTIN22334455',
      taxRate: double.tryParse(box.get('taxRate') ?? '5.0') ?? 5.0,
      shopLogoPath: box.get('shopLogoPath'),
      receiptHeader: box.get('receiptHeader') ?? 'WELCOME TO OUR SHOP',
      receiptFooter: box.get('receiptFooter') ?? 'THANK YOU, VISIT AGAIN!',
      showGstOnReceipt: (box.get('showGstOnReceipt') ?? 'true') == 'true',
      enableStaffCustomerDirectory:
          (box.get('enableStaffCustomerDirectory') ?? 'true') == 'true',
      enableStaffInventory:
          (box.get('enableStaffInventory') ?? 'false') == 'true',
      showStockQuantity: (box.get('showStockQuantity') ?? 'true') == 'true',
      enableStaffStockManagement:
          (box.get('enableStaffStockManagement') ?? 'false') == 'true',
      enableTaxCalculation:
          (box.get('enableTaxCalculation') ?? 'true') == 'true',
      enableStaffRefund: (box.get('enableStaffRefund') ?? 'false') == 'true',
      enableStaffOrderHistory:
          (box.get('enableStaffOrderHistory') ?? 'true') == 'true',
      enableStaffEditBill:
          (box.get('enableStaffEditBill') ?? 'false') == 'true',
      captainCustomerDirectory:
          (box.get('captainCustomerDirectory') ?? 'true') == 'true',
      captainInventory: (box.get('captainInventory') ?? 'true') == 'true',
      captainStockManagement:
          (box.get('captainStockManagement') ?? 'true') == 'true',
      captainRefund: (box.get('captainRefund') ?? 'true') == 'true',
      captainOrderHistory:
          bool.tryParse(box.get('captainOrderHistory')?.toString() ?? 'true') ??
          true,
      captainEditBill:
          bool.tryParse(box.get('captainEditBill')?.toString() ?? 'true') ??
          true,
      enableStaffExpenses:
          bool.tryParse(
            box.get('enableStaffExpenses')?.toString() ?? 'false') ??
          false,
      captainExpenses:
          bool.tryParse(box.get('captainExpenses')?.toString() ?? 'false') ??
          false,
      enableTableNumber: (box.get('enableTableNumber') ?? 'false') == 'true',
      enableDiscountInCart:
          (box.get('enableDiscountInCart') ?? 'false') == 'true',
      enableCustomerDetails:
          (box.get('enableCustomerDetails') ?? 'false') == 'true',
      printAsImage: (box.get('printAsImage') ?? 'true') == 'true',
      is80mmPaper: (box.get('is80mmPaper') ?? 'true') == 'true',
      savedPrinterMacAddress: box.get('savedPrinterMacAddress'),
      addressLine1: box.get('addressLine1'),
      addressLine2: box.get('addressLine2'),
      hotelType: box.get('hotelType'),
      mobileNumber: box.get('mobileNumber'),
      fssaiNumber: box.get('fssaiNumber'),
      enableAddressOnReceipt:
          (box.get('enableAddressOnReceipt') ?? 'false') == 'true',
      enableMobileOnReceipt:
          (box.get('enableMobileOnReceipt') ?? 'false') == 'true',
      enableFssaiOnReceipt:
          (box.get('enableFssaiOnReceipt') ?? 'false') == 'true',
      enableHotelTypeOnReceipt:
          (box.get('enableHotelTypeOnReceipt') ?? 'false') == 'true',
      enableShopDetailsOnKot:
          (box.get('enableShopDetailsOnKot') ?? 'false') == 'true',
      enableKotReceipt: (box.get('enableKotReceipt') ?? 'true') == 'true',
      enablePopularCategory:
          (box.get('enablePopularCategory') ?? 'true') == 'true',
      enablePaymentModeSelection:
          (box.get('enablePaymentModeSelection') ?? 'false') == 'true',
      enableTokenLimit: (box.get('enableTokenLimit') ?? 'true') == 'true',
      showMasterAdminLook: (box.get('showMasterAdminLook') ?? 'true') == 'true',
      dietaryFilter: box.get('dietaryFilter') ?? 'both',
      enableMultiplePrinters:
          (box.get('enableMultiplePrinters') ?? 'false') == 'true',
      customPrinters: loadedPrinters,
      printerConnectionType: box.get('printerConnectionType') ?? 'Bluetooth',
      savedPrinterIpAddress: box.get('savedPrinterIpAddress'),
      showStoreInfo: (box.get('showStoreInfo') ?? 'true') == 'true',
      showAppSettings: (box.get('showAppSettings') ?? 'true') == 'true',
      showReceiptOptions: (box.get('showReceiptOptions') ?? 'true') == 'true',
      showCheckoutFeatures: (box.get('showCheckoutFeatures') ?? 'true') == 'true',
      showPoweredByDiyan: (box.get('showPoweredByDiyan') ?? 'true') == 'true',
      isDemoVersion: (box.get('isDemoVersion') ?? 'false') == 'true',
      enableSplitPayment: (box.get('enableSplitPayment') ?? 'true') == 'true',
      hideImagesInCheckout: (box.get('hideImagesInCheckout') ?? 'false') == 'true',
      dailyResetOrderId: (box.get('dailyResetOrderId') ?? 'false') == 'true',
      enableDineIn: (box.get('enableDineIn') ?? 'true') == 'true',
      enableParcel: (box.get('enableParcel') ?? 'true') == 'true',
    );
  }

  void updateSettings({
    String? shopName,
    String? shopNameTamil,
    String? upiId,
    String? gstNumber,
    double? taxRate,
    String? shopLogoPath,
    String? receiptHeader,
    String? receiptFooter,
    bool? showGstOnReceipt,
    bool? enableStaffCustomerDirectory,
    bool? enableStaffInventory,
    bool? showStockQuantity,
    bool? enableStaffStockManagement,
    bool? enableTaxCalculation,
    bool? enableStaffRefund,
    bool? enableStaffOrderHistory,
    bool? enableStaffEditBill,
    bool? captainCustomerDirectory,
    bool? captainInventory,
    bool? captainStockManagement,
    bool? captainRefund,
    bool? captainOrderHistory,
    bool? captainEditBill,
    bool? enableStaffExpenses,
    bool? captainExpenses,
    bool? enableTableNumber,
    bool? enableDiscountInCart,
    bool? enableCustomerDetails,
    bool? printAsImage,
    bool? is80mmPaper,
    String? savedPrinterMacAddress,
    String? addressLine1,
    String? addressLine2,
    String? hotelType,
    String? mobileNumber,
    String? fssaiNumber,
    bool? enableAddressOnReceipt,
    bool? enableMobileOnReceipt,
    bool? enableFssaiOnReceipt,
    bool? enableHotelTypeOnReceipt,
    bool? enableShopDetailsOnKot,
    bool? enableKotReceipt,
    bool? enablePopularCategory,
    bool? enablePaymentModeSelection,
    bool? enableTokenLimit,
    bool? showMasterAdminLook,
    String? dietaryFilter,
    bool? enableMultiplePrinters,
    List<PrinterProfile>? customPrinters,
    String? printerConnectionType,
    String? savedPrinterIpAddress,
    bool? showStoreInfo,
    bool? showAppSettings,
    bool? showReceiptOptions,
    bool? showCheckoutFeatures,
    bool? showPoweredByDiyan,
    bool? enableSplitPayment,
    bool? hideImagesInCheckout,
    bool? dailyResetOrderId,
    bool? enableDineIn,
    bool? enableParcel,
  }) {
    final box = Hive.box<String>('settings');
    if (shopName != null) box.put('shopName', shopName);
    if (shopNameTamil != null) box.put('shopNameTamil', shopNameTamil);
    if (upiId != null) box.put('upiId', upiId);
    if (gstNumber != null) box.put('gstNumber', gstNumber);
    if (taxRate != null) box.put('taxRate', taxRate.toString());
    if (shopLogoPath != null) box.put('shopLogoPath', shopLogoPath);
    if (receiptHeader != null) box.put('receiptHeader', receiptHeader);
    if (receiptFooter != null) box.put('receiptFooter', receiptFooter);
    if (showGstOnReceipt != null)
      box.put('showGstOnReceipt', showGstOnReceipt.toString());
    if (enableStaffCustomerDirectory != null)
      box.put(
        'enableStaffCustomerDirectory',
        enableStaffCustomerDirectory.toString());
    if (enableStaffInventory != null) {
      box.put('enableStaffInventory', enableStaffInventory.toString());
    }
    if (showStockQuantity != null)
      box.put('showStockQuantity', showStockQuantity.toString());
    if (enableStaffStockManagement != null)
      box.put(
        'enableStaffStockManagement',
        enableStaffStockManagement.toString());
    if (enableTaxCalculation != null)
      box.put('enableTaxCalculation', enableTaxCalculation.toString());
    if (enableStaffRefund != null) {
      box.put('enableStaffRefund', enableStaffRefund.toString());
    }
    if (enableStaffOrderHistory != null) {
      box.put('enableStaffOrderHistory', enableStaffOrderHistory.toString());
    }
    if (enableStaffEditBill != null) {
      box.put('enableStaffEditBill', enableStaffEditBill.toString());
    }
    if (captainCustomerDirectory != null) {
      box.put('captainCustomerDirectory', captainCustomerDirectory.toString());
    }
    if (captainInventory != null) {
      box.put('captainInventory', captainInventory.toString());
    }
    if (captainStockManagement != null) {
      box.put('captainStockManagement', captainStockManagement.toString());
    }
    if (captainRefund != null) {
      box.put('captainRefund', captainRefund.toString());
    }
    if (captainOrderHistory != null) {
      box.put('captainOrderHistory', captainOrderHistory.toString());
    }
    if (captainEditBill != null) {
      box.put('captainEditBill', captainEditBill.toString());
    }
    if (enableStaffExpenses != null) {
      box.put('enableStaffExpenses', enableStaffExpenses.toString());
    }
    if (captainExpenses != null) {
      box.put('captainExpenses', captainExpenses.toString());
    }
    if (enableTableNumber != null) {
      box.put('enableTableNumber', enableTableNumber.toString());
    }
    if (enableDiscountInCart != null) {
      box.put('enableDiscountInCart', enableDiscountInCart.toString());
    }
    if (enableCustomerDetails != null) {
      box.put('enableCustomerDetails', enableCustomerDetails.toString());
    }
    if (printAsImage != null) {
      box.put('printAsImage', printAsImage.toString());
    }
    if (is80mmPaper != null) {
      box.put('is80mmPaper', is80mmPaper.toString());
    }
    if (savedPrinterMacAddress != null)
      box.put('savedPrinterMacAddress', savedPrinterMacAddress);
    if (addressLine1 != null) box.put('addressLine1', addressLine1);
    if (addressLine2 != null) box.put('addressLine2', addressLine2);
    if (hotelType != null) box.put('hotelType', hotelType);
    if (mobileNumber != null) box.put('mobileNumber', mobileNumber);
    if (fssaiNumber != null) box.put('fssaiNumber', fssaiNumber);
    if (enableAddressOnReceipt != null)
      box.put('enableAddressOnReceipt', enableAddressOnReceipt.toString());
    if (enableMobileOnReceipt != null)
      box.put('enableMobileOnReceipt', enableMobileOnReceipt.toString());
    if (enableFssaiOnReceipt != null)
      box.put('enableFssaiOnReceipt', enableFssaiOnReceipt.toString());
    if (enableHotelTypeOnReceipt != null)
      box.put('enableHotelTypeOnReceipt', enableHotelTypeOnReceipt.toString());
    if (enableShopDetailsOnKot != null)
      box.put('enableShopDetailsOnKot', enableShopDetailsOnKot.toString());
    if (enableKotReceipt != null)
      box.put('enableKotReceipt', enableKotReceipt.toString());
    if (enablePopularCategory != null)
      box.put('enablePopularCategory', enablePopularCategory.toString());
    if (enablePaymentModeSelection != null) {
      box.put(
        'enablePaymentModeSelection',
        enablePaymentModeSelection.toString());
    }
    if (enableTokenLimit != null) {
      box.put('enableTokenLimit', enableTokenLimit.toString());
    }
    if (showMasterAdminLook != null) {
      box.put('showMasterAdminLook', showMasterAdminLook.toString());
    }
    if (dietaryFilter != null) {
      box.put('dietaryFilter', dietaryFilter);
    }
    if (enableMultiplePrinters != null) {
      box.put('enableMultiplePrinters', enableMultiplePrinters.toString());
    }
    if (customPrinters != null) {
      final jsonStr = jsonEncode(customPrinters.map((e) => e.toMap()).toList());
      box.put('customPrinters', jsonStr);
    }
    if (printerConnectionType != null) {
      box.put('printerConnectionType', printerConnectionType);
    }
    if (savedPrinterIpAddress != null) {
      box.put('savedPrinterIpAddress', savedPrinterIpAddress);
    }
    if (showStoreInfo != null) {
      box.put('showStoreInfo', showStoreInfo.toString());
    }
    if (showAppSettings != null) {
      box.put('showAppSettings', showAppSettings.toString());
    }
    if (showReceiptOptions != null) {
      box.put('showReceiptOptions', showReceiptOptions.toString());
    }
    if (showCheckoutFeatures != null) {
      box.put('showCheckoutFeatures', showCheckoutFeatures.toString());
    }
    if (showPoweredByDiyan != null) {
      box.put('showPoweredByDiyan', showPoweredByDiyan.toString());
    }
    if (enableSplitPayment != null) {
      box.put('enableSplitPayment', enableSplitPayment.toString());
    }
    if (hideImagesInCheckout != null) {
      box.put('hideImagesInCheckout', hideImagesInCheckout.toString());
    }
    if (dailyResetOrderId != null) {
      box.put('dailyResetOrderId', dailyResetOrderId.toString());
    }
    if (enableDineIn != null) {
      box.put('enableDineIn', enableDineIn.toString());
    }
    if (enableParcel != null) {
      box.put('enableParcel', enableParcel.toString());
    }

    state = state.copyWith(
      enableDineIn: enableDineIn ?? state.enableDineIn,
      enableParcel: enableParcel ?? state.enableParcel,
      shopName: shopName ?? state.shopName,
      shopNameTamil: shopNameTamil ?? state.shopNameTamil,
      upiId: upiId ?? state.upiId,
      gstNumber: gstNumber ?? state.gstNumber,
      taxRate: taxRate ?? state.taxRate,
      shopLogoPath: shopLogoPath ?? state.shopLogoPath,
      receiptHeader: receiptHeader ?? state.receiptHeader,
      receiptFooter: receiptFooter ?? state.receiptFooter,
      showGstOnReceipt: showGstOnReceipt ?? state.showGstOnReceipt,
      enableStaffCustomerDirectory:
          enableStaffCustomerDirectory ?? state.enableStaffCustomerDirectory,
      enableStaffInventory: enableStaffInventory ?? state.enableStaffInventory,
      showStockQuantity: showStockQuantity ?? state.showStockQuantity,
      enableStaffStockManagement:
          enableStaffStockManagement ?? state.enableStaffStockManagement,
      enableTaxCalculation: enableTaxCalculation ?? state.enableTaxCalculation,
      enableStaffRefund: enableStaffRefund ?? state.enableStaffRefund,
      enableStaffOrderHistory:
          enableStaffOrderHistory ?? state.enableStaffOrderHistory,
      enableStaffEditBill: enableStaffEditBill ?? state.enableStaffEditBill,
      captainCustomerDirectory: captainCustomerDirectory ?? state.captainCustomerDirectory,
      captainInventory: captainInventory ?? state.captainInventory,
      captainStockManagement: captainStockManagement ?? state.captainStockManagement,
      captainRefund: captainRefund ?? state.captainRefund,
      captainOrderHistory: captainOrderHistory ?? state.captainOrderHistory,
      captainEditBill: captainEditBill ?? state.captainEditBill,
      enableStaffExpenses: enableStaffExpenses ?? state.enableStaffExpenses,
      captainExpenses: captainExpenses ?? state.captainExpenses,
      enableTableNumber: enableTableNumber ?? state.enableTableNumber,
      enableDiscountInCart: enableDiscountInCart ?? state.enableDiscountInCart,
      enableCustomerDetails:
          enableCustomerDetails ?? state.enableCustomerDetails,
      printAsImage: printAsImage ?? state.printAsImage,
      is80mmPaper: is80mmPaper ?? state.is80mmPaper,
      savedPrinterMacAddress:
          savedPrinterMacAddress ?? state.savedPrinterMacAddress,
      addressLine1: addressLine1 ?? state.addressLine1,
      addressLine2: addressLine2 ?? state.addressLine2,
      hotelType: hotelType ?? state.hotelType,
      mobileNumber: mobileNumber ?? state.mobileNumber,
      fssaiNumber: fssaiNumber ?? state.fssaiNumber,
      enableAddressOnReceipt:
          enableAddressOnReceipt ?? state.enableAddressOnReceipt,
      enableMobileOnReceipt:
          enableMobileOnReceipt ?? state.enableMobileOnReceipt,
      enableFssaiOnReceipt: enableFssaiOnReceipt ?? state.enableFssaiOnReceipt,
      enableHotelTypeOnReceipt:
          enableHotelTypeOnReceipt ?? state.enableHotelTypeOnReceipt,
      enableShopDetailsOnKot:
          enableShopDetailsOnKot ?? state.enableShopDetailsOnKot,
      enableKotReceipt: enableKotReceipt ?? state.enableKotReceipt,
      enablePopularCategory:
          enablePopularCategory ?? state.enablePopularCategory,
      enablePaymentModeSelection:
          enablePaymentModeSelection ?? state.enablePaymentModeSelection,
      enableTokenLimit: enableTokenLimit ?? state.enableTokenLimit,
      showMasterAdminLook: showMasterAdminLook ?? state.showMasterAdminLook,
      dietaryFilter: dietaryFilter ?? state.dietaryFilter,
      enableMultiplePrinters:
          enableMultiplePrinters ?? state.enableMultiplePrinters,
      customPrinters: customPrinters ?? state.customPrinters,
      enableSplitPayment: enableSplitPayment ?? state.enableSplitPayment,
      hideImagesInCheckout: hideImagesInCheckout ?? state.hideImagesInCheckout,
      dailyResetOrderId: dailyResetOrderId ?? state.dailyResetOrderId,
    );
    FirebaseSyncService().pushSettingsSync();

    // Notify cart to update its tax rate
    if (taxRate != null) {
      ref.read(cartProvider.notifier).refreshTaxRate();
    }
  }

  Future<void> resetSettings() async {
    final box = Hive.box<String>('settings');
    await box.clear();
    state = SettingsState(
      shopName: 'My Restaurant',
      upiId: '',
      gstNumber: '',
      taxRate: 5.0,
    );
    FirebaseSyncService().pushSettingsSync();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

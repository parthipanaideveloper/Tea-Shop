import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:google_fonts/google_fonts.dart';

import '../../domain/models/cart_item.dart';
import '../../domain/models/product.dart';

class PrinterService {
  /// Generates the raw bytes for printing the inventory list (fast text).
  static Future<List<int>> generateInventoryBytes({
    required List<Product> products,
    required String shopName,
    bool is80mmPaper = true,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = is80mmPaper ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    bytes += generator.text(
      shopName.toUpperCase(),
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
        height: is80mmPaper ? PosTextSize.size2 : PosTextSize.size1,
        width: is80mmPaper ? PosTextSize.size2 : PosTextSize.size1,
      ),
    );
    bytes += generator.feed(1);

    bytes += generator.text(
      'INVENTORY LIST',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.text(
      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(1);
    bytes += generator.hr();

    // Table Header
    if (is80mmPaper) {
      bytes += generator.row([
        PosColumn(
          text: 'ITEM NAME',
          width: 8,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'PRICE',
          width: 4,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
    } else {
      bytes += generator.row([
        PosColumn(
          text: 'ITEM NAME',
          width: 8,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'PRICE',
          width: 4,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();

    // Print each item
    for (var p in products) {
      String name = p.name;
      if (p.productNumber != null && p.productNumber!.isNotEmpty) {
        name = "[${p.productNumber}] $name";
      }
      // Truncate name if it's too long to prevent weird wrapping on 58mm
      int maxLen = is80mmPaper ? 30 : 18;
      if (name.length > maxLen) {
        name = name.substring(0, maxLen);
      }
      bytes += generator.row([
        PosColumn(text: name, width: 8),
        PosColumn(
          text: p.price.toStringAsFixed(2),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.text(
      'Total Items: ${products.length}',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  static Future<List<int>> generateInventoryImageBytes({
    required List<Product> products,
    required String shopName,
    bool is80mmPaper = true,
  }) async {
    final controller = ScreenshotController();
    final double printerWidth = is80mmPaper ? 576.0 : 384.0;
    final double scale = is80mmPaper ? 1.3 : 1.0;

    final widget = Container(
      width: printerWidth,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            shopName.toUpperCase(),
            style: TextStyle(
              fontSize: 28 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8 * scale),
          Text(
            'INVENTORY LIST',
            style: TextStyle(
              fontSize: 22 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4 * scale),
          Text(
            'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: TextStyle(fontSize: 16 * scale, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12 * scale),
          Container(height: 2 * scale, color: Colors.black),
          SizedBox(height: 8 * scale),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'ITEM NAME',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18 * scale,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'PRICE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18 * scale,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Container(height: 2 * scale, color: Colors.black),
          SizedBox(height: 8 * scale),
          ...products.map(
            (p) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4 * scale),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      (p.productNumber != null && p.productNumber!.isNotEmpty)
                          ? "[${p.productNumber}] ${p.name}"
                          : p.name,
                      style: TextStyle(
                        fontSize: 18 * scale,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      p.price.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 18 * scale,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8 * scale),
          Container(height: 2 * scale, color: Colors.black),
          SizedBox(height: 8 * scale),
          Text(
            'Total Items: ${products.length}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18 * scale,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16 * scale),
        ],
      ),
    );

    final Uint8List imageBytes = await controller.captureFromWidget(
      widget,
      delay: const Duration(milliseconds: 50),
    );
    final image = img.decodeImage(imageBytes);
    if (image == null) return [];

    if (defaultTargetPlatform == TargetPlatform.windows) {
      final pdfBytes = await WinPdfHelper.generatePdfFromImageBytes(
        Uint8List.fromList(img.encodePng(image)),
        is80mmPaper,
      );
      return pdfBytes;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(
      is80mmPaper ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );
    List<int> bytes = [];
    bytes += generator.imageRaster(image, align: PosAlign.center);
    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }

  static Future<List<int>> generateProductPerformanceBytes({
    required List<MapEntry<String, Map<String, dynamic>>> sortedItems,
    required String shopName,
    required String periodName,
    double? netRevenue,
    bool is80mmPaper = true,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final pdf = pw.Document();
      final format = is80mmPaper
          ? PdfPageFormat(
              72.0 * PdfPageFormat.mm,
              double.infinity,
              marginAll: 10,
            )
          : PdfPageFormat(
              48.0 * PdfPageFormat.mm,
              double.infinity,
              marginAll: 5,
            );

      double totalRev = netRevenue ?? 0.0;
      int totalUnits = 0;
      for (final e in sortedItems) {
        if (netRevenue == null) {
          totalRev += (e.value['revenue'] as num).toDouble();
        }
        totalUnits += (e.value['count'] as num).toInt();
      }

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  shopName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: is80mmPaper ? 14 : 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'PRODUCT PERFORMANCE',
                  style: pw.TextStyle(
                    fontSize: is80mmPaper ? 12 : 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Period: $periodName',
                  style: pw.TextStyle(fontSize: is80mmPaper ? 9 : 8),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: is80mmPaper ? 8 : 7),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'ITEM',
                        style: pw.TextStyle(
                          fontSize: is80mmPaper ? 9 : 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        'QTY',
                        style: pw.TextStyle(
                          fontSize: is80mmPaper ? 9 : 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'AMOUNT',
                        style: pw.TextStyle(
                          fontSize: is80mmPaper ? 9 : 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5),
                ...sortedItems.map((e) {
                  final name = e.key;
                  final count = (e.value['count'] as num).toInt();
                  final rev = (e.value['revenue'] as num).toDouble();
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            name,
                            style: pw.TextStyle(fontSize: is80mmPaper ? 8 : 7),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            '$count',
                            style: pw.TextStyle(fontSize: is80mmPaper ? 8 : 7),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            rev.toStringAsFixed(2),
                            style: pw.TextStyle(fontSize: is80mmPaper ? 8 : 7),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Units:',
                      style: pw.TextStyle(
                        fontSize: is80mmPaper ? 9 : 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '$totalUnits',
                      style: pw.TextStyle(
                        fontSize: is80mmPaper ? 9 : 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Sales:',
                      style: pw.TextStyle(
                        fontSize: is80mmPaper ? 10 : 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Rs. ${totalRev.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: is80mmPaper ? 10 : 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
              ],
            );
          },
        ),
      );
      return await pdf.save();
    }

    final profile = await CapabilityProfile.load();
    final paperSize = is80mmPaper ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    bytes += generator.text(
      shopName.toUpperCase(),
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
        height: is80mmPaper ? PosTextSize.size2 : PosTextSize.size1,
        width: is80mmPaper ? PosTextSize.size2 : PosTextSize.size1,
      ),
    );
    bytes += generator.feed(1);

    bytes += generator.text(
      'PRODUCT PERFORMANCE',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.text(
      'Period: $periodName',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(1);
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(
        text: 'ITEM NAME',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'QTY',
        width: 2,
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
      PosColumn(
        text: 'AMOUNT',
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);

    bytes += generator.hr();

    double totalRev = 0;
    int totalUnits = 0;

    for (final e in sortedItems) {
      final name = e.key;
      final count = (e.value['count'] as num).toInt();
      final rev = (e.value['revenue'] as num).toDouble();
      totalRev += rev;
      totalUnits += count;

      int maxLen = is80mmPaper ? 20 : 12;
      String truncatedName = name.length > maxLen
          ? name.substring(0, maxLen)
          : name;

      bytes += generator.row([
        PosColumn(text: truncatedName, width: 6),
        PosColumn(
          text: '$count',
          width: 2,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: rev.toStringAsFixed(2),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(
        text: 'Total Units:',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: '$totalUnits',
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);

    bytes += generator.row([
      PosColumn(
        text: 'Total Sales:',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'Rs. ${totalRev.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);

    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }

  static Future<List<int>> generateProductPerformanceImageBytes({
    required List<MapEntry<String, Map<String, dynamic>>> sortedItems,
    required String shopName,
    required String periodName,
    bool is80mmPaper = true,
  }) async {
    final controller = ScreenshotController();
    final double printerWidth = is80mmPaper ? 576.0 : 384.0;
    final double scale = is80mmPaper ? 1.3 : 1.0;

    double totalRev = 0;
    int totalUnits = 0;
    for (final e in sortedItems) {
      totalRev += (e.value['revenue'] as num).toDouble();
      totalUnits += (e.value['count'] as num).toInt();
    }

    final widget = Container(
      width: printerWidth,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            shopName.toUpperCase(),
            style: TextStyle(
              fontSize: 28 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8 * scale),
          Text(
            'PRODUCT PERFORMANCE',
            style: TextStyle(
              fontSize: 22 * scale,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4 * scale),
          Text(
            'Period: $periodName',
            style: TextStyle(fontSize: 16 * scale, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4 * scale),
          Text(
            'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: TextStyle(fontSize: 16 * scale, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12 * scale),
          Container(height: 2 * scale, color: Colors.black),
          SizedBox(height: 8 * scale),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'ITEM NAME',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18 * scale,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'QTY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18 * scale,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'AMOUNT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18 * scale,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Container(height: 2 * scale, color: Colors.black),
          SizedBox(height: 8 * scale),
          ...sortedItems.map(
            (e) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4 * scale),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      e.key,
                      style: TextStyle(
                        fontSize: 18 * scale,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${(e.value['count'] as num).toInt()}',
                      style: TextStyle(
                        fontSize: 18 * scale,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      (e.value['revenue'] as num).toDouble().toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 18 * scale,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8 * scale),
          Container(height: 2 * scale, color: Colors.black),
          SizedBox(height: 8 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Units:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18 * scale,
                  color: Colors.black,
                ),
              ),
              Text(
                '$totalUnits',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18 * scale,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Sales:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22 * scale,
                  color: Colors.black,
                ),
              ),
              Text(
                'Rs. ${totalRev.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22 * scale,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 16 * scale),
        ],
      ),
    );

    final Uint8List imageBytes = await controller.captureFromWidget(
      widget,
      delay: const Duration(milliseconds: 50),
    );
    final image = img.decodeImage(imageBytes);
    if (image == null) return [];

    if (defaultTargetPlatform == TargetPlatform.windows) {
      final pdfBytes = await WinPdfHelper.generatePdfFromImageBytes(
        Uint8List.fromList(img.encodePng(image)),
        is80mmPaper,
      );
      return pdfBytes;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(
      is80mmPaper ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );
    List<int> bytes = [];
    bytes += generator.imageRaster(image);
    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }

  /// Generates the raw bytes for the receipt by rendering a Widget to an image.
  static Future<List<int>> generateReceiptBytes({
    required List<CartItem> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    String shopName = 'ENTERPRISE POS',
    String receiptHeader = 'WELCOME TO OUR SHOP',
    String receiptFooter = 'THANK YOU, VISIT AGAIN!',
    bool showGstOnReceipt = true,
    String gstNumber = 'GSTIN22334455',
    bool isUnpaid = false,
    String orderId = '',
    String? tableNo = '',
    String? orderType,
    String? customerName,
    String? customerPhone,
    bool printAsImage = true,
    bool is80mmPaper = true,
    int? parcelToken,
    String? addressLine1,
    String? addressLine2,
    String? hotelType,
    String? mobileNumber,
    String? fssaiNumber,
    bool enableAddressOnReceipt = false,
    bool enableMobileOnReceipt = false,
    bool enableFssaiOnReceipt = false,
    bool enableHotelTypeOnReceipt = false,
    bool showPoweredByDiyan = true,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = is80mmPaper ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    if (!printAsImage) {
      // FAST TEXT PRINTING MODE (English Only / No Complex Fonts)
      if (parcelToken != null) {
        if (is80mmPaper) {
          bytes += generator.rawBytes([
            27,
            33,
            56,
          ]); // Bold + Double-Height + Double-Width
          bytes += generator.text(
            '**  KOT NO - $parcelToken  **',
            styles: const PosStyles(align: PosAlign.center),
          );
          bytes += generator.rawBytes([27, 33, 0]); // Reset
        } else {
          bytes += generator.rawBytes([27, 33, 16]); // Double-Height
          bytes += generator.text(
            '**  KOT NO - $parcelToken  **',
            styles: const PosStyles(align: PosAlign.center, bold: true),
          );
          bytes += generator.rawBytes([27, 33, 0]); // Reset
        }
        // No feed here — shop name follows immediately below
      }
      if (is80mmPaper) {
        bytes += generator.rawBytes([
          27,
          33,
          56,
        ]); // Bold + Double-Height + Double-Width
        bytes += generator.text(
          shopName.toUpperCase(),
          styles: const PosStyles(align: PosAlign.center),
        );
        bytes += generator.rawBytes([27, 33, 0]); // Reset
      } else {
        bytes += generator.text(
          shopName.toUpperCase(),
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }
      // One blank line after shop name before contact info
      bytes += generator.feed(1);

      if (enableHotelTypeOnReceipt &&
          hotelType != null &&
          hotelType.isNotEmpty) {
        bytes += generator.text(
          hotelType,
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }
      if (enableAddressOnReceipt) {
        if (addressLine1 != null && addressLine1.isNotEmpty) {
          bytes += generator.text(
            addressLine1,
            styles: const PosStyles(align: PosAlign.center),
          );
        }
        if (addressLine2 != null && addressLine2.isNotEmpty) {
          bytes += generator.text(
            addressLine2,
            styles: const PosStyles(align: PosAlign.center),
          );
        }
      }

      if (enableMobileOnReceipt &&
          mobileNumber != null &&
          mobileNumber.isNotEmpty) {
        bytes += generator.text(
          'Ph: $mobileNumber',
          styles: const PosStyles(align: PosAlign.center),
        );
      }
      if (enableFssaiOnReceipt &&
          fssaiNumber != null &&
          fssaiNumber.isNotEmpty) {
        bytes += generator.text(
          'FSSAI: $fssaiNumber',
          styles: const PosStyles(align: PosAlign.center),
        );
      }
      if (showGstOnReceipt && gstNumber.isNotEmpty) {
        bytes += generator.text(
          'GSTIN: $gstNumber',
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      bytes += generator.feed(1);
      bytes += generator.text(
        'Date: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.hr();
      if (orderId.isNotEmpty) {
        bytes += generator.text('Order ID: $orderId');
      }
      if (tableNo != null && tableNo.isNotEmpty) {
        bytes += generator.text(
          'Table: $tableNo',
          styles: const PosStyles(bold: true),
        );
      }
      if ((customerName != null && customerName.isNotEmpty) ||
          (customerPhone != null && customerPhone.isNotEmpty)) {
        bytes += generator.text(
          'Customer: ${customerName ?? ''} ${customerPhone ?? ''}'.trim(),
        );
      }
      bytes += generator.hr();

      // Items header
      if (is80mmPaper) {
        bytes += generator.text(
          'Item'.padRight(28) + 'Qty*Pr'.padLeft(11) + 'Total'.padLeft(9),
          styles: const PosStyles(bold: true),
        );
      } else {
        bytes += generator.text(
          'Item'.padRight(16) + 'Qty*Pr'.padLeft(9) + 'Total'.padLeft(7),
          styles: const PosStyles(bold: true),
        );
      }
      bytes += generator.hr();

      // Items — formatted manually to align directly with the margins without absolute position padding
      for (var item in items) {
        final name = item.product.name;
        final String qtyStr = item.quantity % 1 == 0
            ? item.quantity.toInt().toString()
            : item.quantity.toString();
        final qtyPrice =
            '${qtyStr}x${item.effectivePrice(orderType).toStringAsFixed(2)}';
        final totalStr = item.effectiveTotal(orderType).toStringAsFixed(2);

        if (is80mmPaper) {
          final nameLines = _wrapText(name, 26);
          for (int i = 0; i < nameLines.length; i++) {
            if (i == 0) {
              bytes += generator.text(
                nameLines[i].padRight(28) +
                    qtyPrice.padLeft(11) +
                    totalStr.padLeft(9),
                styles: const PosStyles(bold: true),
              );
            } else {
              bytes += generator.text(
                nameLines[i].padRight(28),
                styles: const PosStyles(bold: true),
              );
            }
          }
        } else {
          final nameLines = _wrapText(name, 14);
          for (int i = 0; i < nameLines.length; i++) {
            if (i == 0) {
              bytes += generator.text(
                nameLines[i].padRight(16) +
                    qtyPrice.padLeft(9) +
                    totalStr.padLeft(7),
                styles: const PosStyles(bold: true),
              );
            } else {
              bytes += generator.text(
                nameLines[i].padRight(16),
                styles: const PosStyles(bold: true),
              );
            }
          }
        }
      }
      bytes += generator.hr();

      // Totals
      if (is80mmPaper) {
        bytes += generator.text(
          'Subtotal'.padRight(30) + subtotal.toStringAsFixed(2).padLeft(18),
        );
        if (tax > 0) {
          bytes += generator.text(
            'Tax'.padRight(30) + tax.toStringAsFixed(2).padLeft(18),
          );
        }
        if (discount > 0) {
          bytes += generator.text(
            'Discount'.padRight(30) +
                '-${discount.toStringAsFixed(2)}'.padLeft(18),
          );
        }
      } else {
        bytes += generator.text(
          'Subtotal'.padRight(20) + subtotal.toStringAsFixed(2).padLeft(12),
        );
        if (tax > 0) {
          bytes += generator.text(
            'Tax'.padRight(20) + tax.toStringAsFixed(2).padLeft(12),
          );
        }
        if (discount > 0) {
          bytes += generator.text(
            'Discount'.padRight(20) +
                '-${discount.toStringAsFixed(2)}'.padLeft(12),
          );
        }
      }
      bytes += generator.hr();

      if (is80mmPaper) {
        // On 80mm (48 characters printable width), double-width font gives 24 character slots
        final String typeLabel = orderType != null
            ? orderType.toUpperCase()
            : 'TOTAL';
        final String totalLabel = 'Rs. ${total.toStringAsFixed(2)}';
        const int totalSlots = 24;
        final int textLength = typeLabel.length + totalLabel.length;
        final int spacesNeeded = (totalSlots - textLength).clamp(1, totalSlots);
        final String spaceStr = ' ' * spacesNeeded;

        bytes += generator.rawBytes([
          27,
          33,
          56,
        ]); // Bold + Double-Height + Double-Width
        bytes += generator.text('$typeLabel$spaceStr$totalLabel');
        bytes += generator.rawBytes([27, 33, 0]); // Reset
      } else {
        // On 58mm (32 characters printable width), we use Bold + Double-Height (Single Width)
        // to avoid wrapping issues when the total has 3 or more digits.
        final String typeLabel = orderType != null
            ? orderType.toUpperCase()
            : 'TOTAL';
        final String totalLabel = 'Rs. ${total.toStringAsFixed(2)}';
        const int totalSlots = 32;
        final int textLength = typeLabel.length + totalLabel.length;
        final int spacesNeeded = (totalSlots - textLength).clamp(1, totalSlots);
        final String spaceStr = ' ' * spacesNeeded;

        bytes += generator.rawBytes([
          27,
          33,
          8,
        ]); // Bold (Single Height, Single Width)
        bytes += generator.text('$typeLabel$spaceStr$totalLabel');
        bytes += generator.rawBytes([27, 33, 0]); // Reset
      }
      bytes += generator.hr();

      if (receiptFooter.isNotEmpty) {
        bytes += generator.text(
          receiptFooter,
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }
      // Demo & powered-by lines: kept ≤32 chars to fit on 58mm (32 chars/line)
      if (Hive.box<String>('settings').get('isDemoVersion') == 'true') {
        bytes += generator.text(
          'Demo ver: features coming soon',
          styles: const PosStyles(align: PosAlign.center),
        );
      }
      if (showPoweredByDiyan) {
        bytes += generator.text(
          is80mmPaper
              ? 'Powered by DiyanTech Solutions, 8667442624'
              : 'DiyanTech Solutions 8667442624',
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        );
      }
      bytes += generator.feed(1);
      bytes += generator.cut();
      return bytes;
    }

    final controller = ScreenshotController();

    final double printerWidth = is80mmPaper ? 576.0 : 384.0;
    final double scale = is80mmPaper ? 1.3 : 1.0;

    final widget = Container(
      width: printerWidth,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (parcelToken != null)
                Container(
                  width: 80 * scale,
                  height: 80 * scale,
                  margin: EdgeInsets.only(right: 8 * scale, bottom: 8 * scale),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2.5 * scale),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$parcelToken',
                    style: TextStyle(
                      fontSize: 36 * scale,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      shopName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 26 * scale,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (enableHotelTypeOnReceipt &&
                        hotelType != null &&
                        hotelType.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 2 * scale),
                        child: Text(
                          hotelType,
                          style: TextStyle(
                            fontSize: 20 * scale,
                            color: Colors.black,
                            fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                          ),
                        ),
                      ),
                    if (enableAddressOnReceipt)
                      Column(
                        children: [
                          if (addressLine1 != null && addressLine1.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 2 * scale),
                              child: Text(
                                addressLine1,
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  color: Colors.black,
                                  fontFamily:
                                      GoogleFonts.notoSansTamil().fontFamily,
                                ),
                              ),
                            ),
                          if (addressLine2 != null && addressLine2.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 2 * scale),
                              child: Text(
                                addressLine2,
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  color: Colors.black,
                                  fontFamily:
                                      GoogleFonts.notoSansTamil().fontFamily,
                                ),
                              ),
                            ),
                        ],
                      ),
                    if (enableMobileOnReceipt &&
                        mobileNumber != null &&
                        mobileNumber.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 2 * scale),
                        child: Text(
                          'Ph: $mobileNumber',
                          style: TextStyle(
                            fontSize: 18 * scale,
                            color: Colors.black,
                            fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                          ),
                        ),
                      ),
                    if (enableFssaiOnReceipt &&
                        fssaiNumber != null &&
                        fssaiNumber.isNotEmpty &&
                        showGstOnReceipt &&
                        gstNumber.isNotEmpty &&
                        is80mmPaper &&
                        parcelToken == null)
                      Text(
                        'FSSAI: $fssaiNumber | GSTIN: $gstNumber',
                        style: TextStyle(
                          fontSize: 18 * scale,
                          color: Colors.black,
                          fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                        ),
                        textAlign: TextAlign.center,
                      )
                    else ...[
                      if (enableFssaiOnReceipt &&
                          fssaiNumber != null &&
                          fssaiNumber.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 2 * scale),
                          child: Text(
                            'FSSAI: $fssaiNumber',
                            style: TextStyle(
                              fontSize: 18 * scale,
                              color: Colors.black,
                              fontFamily:
                                  GoogleFonts.notoSansTamil().fontFamily,
                            ),
                          ),
                        ),
                      if (showGstOnReceipt && gstNumber.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 2 * scale),
                          child: Text(
                            'GSTIN: $gstNumber',
                            style: TextStyle(
                              fontSize: 18 * scale,
                              color: Colors.black,
                              fontFamily:
                                  GoogleFonts.notoSansTamil().fontFamily,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                    Text(
                      'Date: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}',
                      style: TextStyle(
                        fontSize: 18 * scale,
                        color: Colors.black,
                        fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.black, thickness: 1.5),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (orderId.isNotEmpty)
                Text(
                  'Order ID: ${orderId.length > 15 ? orderId.substring(0, 15) : orderId}',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    color: Colors.black,
                    fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                  ),
                ),
              if (tableNo != null && tableNo.isNotEmpty)
                Text(
                  'Table: $tableNo',
                  style: TextStyle(
                    fontSize: 20 * scale,
                    color: Colors.black,
                    fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                  ),
                ),
            ],
          ),
          if ((customerName != null && customerName.isNotEmpty) ||
              (customerPhone != null && customerPhone.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Customer: ${customerName ?? ''} ${customerPhone ?? ''}'.trim(),
                style: TextStyle(
                  fontSize: 18 * scale,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
              ),
            ),
          const Divider(color: Colors.black, thickness: 1.5),

          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Item',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    color: Colors.black,
                    fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    'QtyxPrice',
                    style: TextStyle(
                      fontSize: 18 * scale,
                      color: Colors.black,
                      fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 18 * scale,
                      color: Colors.black,
                      fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.black, thickness: 1.5),

          ...items.map((item) {
            final name = item.product.name;
            String tamilName =
                (item.product.nameTamil != null &&
                    item.product.nameTamil!.isNotEmpty)
                ? item.product.nameTamil!
                : name;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18 * scale,
                            color: Colors.black,
                            fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                          ),
                        ),
                        if (tamilName != name && tamilName.isNotEmpty)
                          Text(
                            tamilName,
                            style: TextStyle(
                              fontSize: 18 * scale,
                              color: Colors.black,
                              fontFamily:
                                  GoogleFonts.notoSansTamil().fontFamily,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        '${item.quantity} x ${item.effectivePrice(orderType).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18 * scale,
                          color: Colors.black,
                          fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        item.effectiveTotal(orderType).toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 18 * scale,
                          color: Colors.black,
                          fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          const Divider(color: Colors.black, thickness: 1.5),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: TextStyle(
                  fontSize: 18 * scale,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
              ),
              Text(
                subtotal.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 18 * scale,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
              ),
            ],
          ),
          if (tax > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tax',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    color: Colors.black,
                    fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                  ),
                ),
                Text(
                  tax.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 18 * scale,
                    color: Colors.black,
                    fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                  ),
                ),
              ],
            ),
          if (discount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    color: Colors.black,
                    fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                  ),
                ),
                Text(
                  '-${discount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    color: Colors.black,
                    fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                  ),
                ),
              ],
            ),

          const Divider(color: Colors.black, thickness: 1.5),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (orderType != null)
                Text(
                  orderType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 22 * scale,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                  ),
                ),
              Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 22 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
              ),
              Text(
                'Rs. ${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
              ),
            ],
          ),

          const Divider(color: Colors.black, thickness: 1.5),
          if (receiptFooter.isNotEmpty)
            Center(
              child: Text(
                receiptFooter,
                style: TextStyle(
                  fontSize: 18 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 4),
          if (Hive.box<String>('settings').get('isDemoVersion') == 'true')
            Center(
              child: Text(
                'This is a Demo Version. Custom features will be added.',
                style: TextStyle(
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 2),
          if (showPoweredByDiyan)
            Center(
              child: Text(
                'Powered by DiyanTech Solutions, 8667442624',
                style: TextStyle(
                  fontSize: 10 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
              ),
            ),
        ],
      ),
    );

    final Uint8List pngBytes = await controller.captureFromWidget(
      Theme(
        data: ThemeData(fontFamily: GoogleFonts.notoSansTamil().fontFamily),
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(printerWidth, 5000),
            textScaler: TextScaler.noScaling,
            devicePixelRatio: 1.0,
          ),
          child: Material(
            color: Colors.white,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: DefaultTextStyle(
                style: TextStyle(
                  fontWeight: defaultTargetPlatform == TargetPlatform.windows
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: Colors.black,
                ),
                child: SizedBox(width: printerWidth, child: widget),
              ),
            ),
          ),
        ),
      ),
      delay: const Duration(milliseconds: 100),
      pixelRatio: 1.0,
      targetSize: Size(printerWidth, 5000),
    );

    // Use compute for image decoding and resizing to avoid UI jank and fix Android cutoff
    final img.Image? decoded = await compute(_decodeAndResizeImage, {
      'bytes': pngBytes,
      'width': printerWidth.toInt(),
    });

    if (defaultTargetPlatform == TargetPlatform.windows) {
      // On Windows, return a PDF wrapping the image
      if (decoded != null) {
        final pdfBytes = await WinPdfHelper.generatePdfFromImageBytes(
          Uint8List.fromList(img.encodePng(decoded)),
          is80mmPaper,
        );
        return pdfBytes;
      }
      return [];
    }

    if (decoded != null) {
      bytes += generator.imageRaster(decoded);
    }

    bytes += generator.feed(1);
    bytes += generator.cut();

    return bytes;
  }

  static Future<List<int>> generateKitchenReceiptBytes({
    required List<CartItem> items,
    required String orderId,
    required String orderType,
    bool printAsImage = true,
    bool is80mmPaper = true,
    int? parcelToken,
    String shopName = '',
    String? addressLine1,
    String? addressLine2,
    String? hotelType,
    String? mobileNumber,
    String? fssaiNumber,
    String gstNumber = '',
    bool enableAddressOnReceipt = false,
    bool enableMobileOnReceipt = false,
    bool enableFssaiOnReceipt = false,
    bool enableHotelTypeOnReceipt = false,
    bool enableShopDetailsOnKot = false,
    bool showGstOnReceipt = false,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = is80mmPaper ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    if (!printAsImage) {
      // FAST TEXT PRINTING MODE
      // --- Header: KOT number ---
      if (parcelToken != null) {
        if (is80mmPaper) {
          bytes += generator.rawBytes([
            27,
            33,
            56,
          ]); // Bold + Double-Height + Double-Width
          bytes += generator.text(
            '**  KOT NO - $parcelToken  **',
            styles: const PosStyles(align: PosAlign.center),
          );
          bytes += generator.rawBytes([27, 33, 0]); // Reset
        } else {
          bytes += generator.rawBytes([27, 33, 16]); // Double-Height
          bytes += generator.text(
            '**  KOT NO - $parcelToken  **',
            styles: const PosStyles(align: PosAlign.center, bold: true),
          );
          bytes += generator.rawBytes([27, 33, 0]); // Reset
        }
        // No feed — shop name immediately follows
      }
      // --- Shop name ---
      if (shopName.isNotEmpty) {
        if (is80mmPaper) {
          bytes += generator.rawBytes([
            27,
            33,
            56,
          ]); // Bold + Double-Height + Double-Width
          bytes += generator.text(
            shopName.toUpperCase(),
            styles: const PosStyles(align: PosAlign.center),
          );
          bytes += generator.rawBytes([27, 33, 0]); // Reset
        } else {
          bytes += generator.text(
            shopName.toUpperCase(),
            styles: const PosStyles(align: PosAlign.center, bold: true),
          );
        }
        bytes += generator.feed(1); // blank line after shop name
      }
      // --- Hotel type ---
      if (enableShopDetailsOnKot && hotelType != null && hotelType.isNotEmpty) {
        bytes += generator.text(
          hotelType,
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }
      // --- Address ---
      if (enableShopDetailsOnKot) {
        if (addressLine1 != null && addressLine1.isNotEmpty) {
          bytes += generator.text(
            addressLine1,
            styles: const PosStyles(align: PosAlign.center),
          );
        }
        if (addressLine2 != null && addressLine2.isNotEmpty) {
          bytes += generator.text(
            addressLine2,
            styles: const PosStyles(align: PosAlign.center),
          );
        }
      }
      // --- Ph / FSSAI / GSTIN ---
      if (enableShopDetailsOnKot &&
          mobileNumber != null &&
          mobileNumber.isNotEmpty) {
        bytes += generator.text(
          'Ph: $mobileNumber',
          styles: const PosStyles(align: PosAlign.center),
        );
      }
      if (enableShopDetailsOnKot &&
          fssaiNumber != null &&
          fssaiNumber.isNotEmpty) {
        bytes += generator.text(
          'FSSAI: $fssaiNumber',
          styles: const PosStyles(align: PosAlign.center),
        );
      }
      if (enableShopDetailsOnKot && gstNumber.isNotEmpty) {
        bytes += generator.text(
          'GSTIN: $gstNumber',
          styles: const PosStyles(align: PosAlign.center),
        );
      }
      // --- Date ---
      bytes += generator.feed(1);
      bytes += generator.text(
        'Date: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.hr();
      bytes += generator.text('Order ID: $orderId');
      bytes += generator.hr();
      // --- Items table ---
      if (is80mmPaper) {
        bytes += generator.text(
          'Item'.padRight(36) + '  Qty'.padRight(10),
          styles: const PosStyles(bold: true),
        );
      } else {
        bytes += generator.text(
          'Item'.padRight(22) + '  Qty'.padRight(10),
          styles: const PosStyles(bold: true),
        );
      }
      bytes += generator.hr();
      for (var item in items) {
        final name = item.product.name;
        final qtyStr = '${item.quantity}';

        if (parcelToken != null) {
          // KOT MODE: Slightly enlarged/bold but not double size (per user request)
          if (is80mmPaper) {
            final nameLines = _wrapText(name, 36);
            for (int i = 0; i < nameLines.length; i++) {
              if (i == 0) {
                bytes += generator.text(
                  nameLines[i].padRight(36) + '   ' + qtyStr.padRight(7),
                  styles: const PosStyles(bold: true),
                );
              } else {
                bytes += generator.text(
                  nameLines[i].padRight(36),
                  styles: const PosStyles(bold: true),
                );
              }
            }
          } else {
            final nameLines = _wrapText(name, 22);
            for (int i = 0; i < nameLines.length; i++) {
              if (i == 0) {
                bytes += generator.text(
                  nameLines[i].padRight(22) + '   ' + qtyStr.padRight(7),
                  styles: const PosStyles(bold: true),
                );
              } else {
                bytes += generator.text(
                  nameLines[i].padRight(22),
                  styles: const PosStyles(bold: true),
                );
              }
            }
          }
        } else {
          // NORMAL RECEIPT MODE: Regular size font
          if (is80mmPaper) {
            final nameLines = _wrapText(name, 36);
            for (int i = 0; i < nameLines.length; i++) {
              if (i == 0) {
                bytes += generator.text(
                  nameLines[i].padRight(36) + qtyStr.padLeft(10) + '  ',
                  styles: const PosStyles(bold: true),
                );
              } else {
                bytes += generator.text(
                  nameLines[i].padRight(36),
                  styles: const PosStyles(bold: true),
                );
              }
            }
          } else {
            final nameLines = _wrapText(name, 22);
            for (int i = 0; i < nameLines.length; i++) {
              if (i == 0) {
                bytes += generator.text(
                  nameLines[i].padRight(22) + qtyStr.padLeft(8) + '  ',
                  styles: const PosStyles(bold: true),
                );
              } else {
                bytes += generator.text(
                  nameLines[i].padRight(22),
                  styles: const PosStyles(bold: true),
                );
              }
            }
          }
        }
      }
      bytes += generator.hr();
      bytes += generator.feed(1);
      bytes += generator.cut();
      return bytes;
    }

    final controller = ScreenshotController();
    final double printerWidth = is80mmPaper ? 576.0 : 384.0;
    final double scale = is80mmPaper ? 1.3 : 1.0;

    final widget = Container(
      width: printerWidth,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (parcelToken != null)
                Container(
                  width: 80 * scale,
                  height: 80 * scale,
                  margin: EdgeInsets.only(right: 8 * scale, bottom: 8 * scale),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2.5 * scale),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$parcelToken',
                    style: TextStyle(
                      fontSize: 36 * scale,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '*** KITCHEN ***',
                      style: TextStyle(
                        fontSize: 28 * scale,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                      ),
                    ),
                    Text(
                      'Order Type: $orderType',
                      style: TextStyle(
                        fontSize: 22 * scale,
                        color: Colors.black,
                        fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                      ),
                    ),
                    Text(
                      'Order ID: ${orderId.length > 15 ? orderId.substring(0, 15) : orderId}',
                      style: TextStyle(
                        fontSize: 20 * scale,
                        color: Colors.black,
                        fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.black, thickness: 1.5),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item',
                style: TextStyle(
                  fontSize: 20 * scale,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 32 * scale),
                child: Text(
                  'Qty',
                  style: TextStyle(
                    fontSize: 20 * scale,
                    color: Colors.black,
                    fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.black, thickness: 1.5),

          ...items.map((item) {
            final name = item.product.name;
            String tamilName =
                (item.product.nameTamil != null &&
                    item.product.nameTamil!.isNotEmpty)
                ? item.product.nameTamil!
                : name;

            if (name.toLowerCase() == 'vegetable' ||
                name.toLowerCase() == 'veg') {
              tamilName = 'காய்கறி';
            }
            if (tamilName.toLowerCase().contains('kaaigravy')) {
              tamilName = tamilName.toLowerCase().replaceAll(
                'kaaigravy',
                'காய்கறி',
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 22 * scale,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                          ),
                        ),
                        if (tamilName != name && tamilName.isNotEmpty)
                          Text(
                            tamilName,
                            style: TextStyle(
                              fontSize: 22 * scale,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontFamily:
                                  GoogleFonts.notoSansTamil().fontFamily,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 32 * scale),
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontSize: 28 * scale,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          const Divider(color: Colors.black, thickness: 1.5),
        ],
      ),
    );

    final Uint8List pngBytes = await controller.captureFromWidget(
      Theme(
        data: ThemeData(fontFamily: GoogleFonts.notoSansTamil().fontFamily),
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(printerWidth, 8000),
            textScaler: TextScaler.noScaling,
            devicePixelRatio: 1.0,
          ),
          child: Material(
            color: Colors.white,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: DefaultTextStyle(
                style: TextStyle(
                  fontWeight: defaultTargetPlatform == TargetPlatform.windows
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: Colors.black,
                ),
                child: SizedBox(width: printerWidth, child: widget),
              ),
            ),
          ),
        ),
      ),
      delay: const Duration(milliseconds: 100),
      pixelRatio: 1.0,
      targetSize: Size(printerWidth, 5000),
    );

    // Use compute for image decoding and resizing to avoid UI jank and fix Android cutoff
    final img.Image? decoded = await compute(_decodeAndResizeImage, {
      'bytes': pngBytes,
      'width': printerWidth.toInt(),
    });

    if (defaultTargetPlatform == TargetPlatform.windows) {
      // On Windows, return a PDF wrapping the image
      if (decoded != null) {
        final pdfBytes = await WinPdfHelper.generatePdfFromImageBytes(
          Uint8List.fromList(img.encodePng(decoded)),
          is80mmPaper,
        );
        return pdfBytes;
      }
      return [];
    }

    if (decoded != null) {
      bytes += generator.imageRaster(decoded);
    }

    // Add feed and cut command
    bytes += generator.feed(1);
    bytes += generator.cut();

    return bytes;
  }

  static Future<List<int>> generateRefundReceiptBytes({
    required String orderId,
    required double refundAmount,
    required String staffName,
    String shopName = 'ENTERPRISE POS',
    String receiptFooter = 'THANK YOU, VISIT AGAIN!',
    bool printAsImage = true,
    bool is80mmPaper = true,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = is80mmPaper ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    if (defaultTargetPlatform == TargetPlatform.windows) {
      printAsImage = true;
    }

    if (!printAsImage) {
      bytes += generator.text(
        shopName.toUpperCase(),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        'REFUND RECEIPT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.hr();
      bytes += generator.text(
        'Date: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}',
      );
      bytes += generator.text('Staff: $staffName');
      bytes += generator.text('Orig. Order ID: $orderId');
      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(
          text: 'REFUND AMOUNT',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'Rs. ${refundAmount.toStringAsFixed(2)}',
          width: 6,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
      ]);
      bytes += generator.hr();
      if (receiptFooter.isNotEmpty) {
        bytes += generator.text(
          receiptFooter,
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }
      bytes += generator.feed(1);
      bytes += generator.cut();
      return bytes;
    }

    final controller = ScreenshotController();
    final double printerWidth = is80mmPaper ? 576 : 384;

    final widget = Container(
      width: printerWidth,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              shopName.toUpperCase(),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: GoogleFonts.notoSansTamil().fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: Text(
              'REFUND RECEIPT',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: GoogleFonts.notoSansTamil().fontFamily,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.black, thickness: 1.5),

          Text(
            'Date: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black,
              fontFamily: GoogleFonts.notoSansTamil().fontFamily,
            ),
          ),
          Text(
            'Staff: $staffName',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black,
              fontFamily: GoogleFonts.notoSansTamil().fontFamily,
            ),
          ),
          Text(
            'Orig. Order ID: $orderId',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black,
              fontFamily: GoogleFonts.notoSansTamil().fontFamily,
            ),
          ),

          const Divider(color: Colors.black, thickness: 1.5),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REFUND AMOUNT',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
              ),
              Text(
                'Rs. ${refundAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
              ),
            ],
          ),

          const Divider(color: Colors.black, thickness: 1.5),
          if (receiptFooter.isNotEmpty)
            Center(
              child: Text(
                receiptFooter,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: GoogleFonts.notoSansTamil().fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );

    final Uint8List pngBytes = await controller.captureFromWidget(
      Theme(
        data: ThemeData(fontFamily: GoogleFonts.notoSansTamil().fontFamily),
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(printerWidth, 8000),
            textScaler: TextScaler.noScaling,
            devicePixelRatio: 1.0,
          ),
          child: Material(
            color: Colors.white,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: DefaultTextStyle(
                style: TextStyle(
                  fontWeight: defaultTargetPlatform == TargetPlatform.windows
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: Colors.black,
                ),
                child: SizedBox(width: printerWidth, child: widget),
              ),
            ),
          ),
        ),
      ),
      delay: const Duration(milliseconds: 100),
      pixelRatio: 1.0,
      targetSize: Size(printerWidth, 5000),
    );

    // Use compute for image decoding and resizing to avoid UI jank and fix Android cutoff
    final img.Image? decoded = await compute(_decodeAndResizeImage, {
      'bytes': pngBytes,
      'width': printerWidth.toInt(),
    });

    if (defaultTargetPlatform == TargetPlatform.windows) {
      // On Windows, return a PDF wrapping the image
      if (decoded != null) {
        final pdfBytes = await WinPdfHelper.generatePdfFromImageBytes(
          Uint8List.fromList(img.encodePng(decoded)),
          is80mmPaper,
        );
        return pdfBytes;
      }
      return [];
    }

    if (decoded != null) {
      bytes += generator.imageRaster(decoded);
    }

    bytes += generator.feed(1);
    bytes += generator.cut();

    return bytes;
  }

  static List<String> _wrapText(String text, int maxLength) {
    if (text.isEmpty) return [''];
    final words = text.split(' ');
    final lines = <String>[];
    String currentLine = '';

    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if (currentLine.length + 1 + word.length <= maxLength) {
        currentLine += ' $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    return lines;
  }
}

img.Image? _decodeAndResizeImage(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'] as Uint8List;
  final int width = params['width'] as int;

  final img.Image? decodedImage = img.decodeImage(bytes);
  if (decodedImage != null) {
    // 1. Crop bottom whitespace
    int bottomY = decodedImage.height - 1;
    bool foundContent = false;
    // Scan upwards to find the first row with non-white/non-transparent pixels
    while (bottomY > 0 && !foundContent) {
      for (int x = 0; x < decodedImage.width; x += 4) {
        // Check every 4th pixel for speed
        final p = decodedImage.getPixel(x, bottomY);
        // If not transparent and not white
        if (p.a > 10 && (p.r < 250 || p.g < 250 || p.b < 250)) {
          foundContent = true;
          break;
        }
      }
      if (!foundContent) {
        bottomY--;
      }
    }

    // Add a small bottom padding (e.g. 40 pixels)
    bottomY = (bottomY + 40).clamp(0, decodedImage.height - 1);

    img.Image cropped = decodedImage;
    if (bottomY < decodedImage.height - 1) {
      cropped = img.copyCrop(
        decodedImage,
        x: 0,
        y: 0,
        width: decodedImage.width,
        height: bottomY + 1,
      );
    }

    // 2. Resize if necessary
    if (cropped.width == width) {
      return cropped;
    }
    return img.copyResize(
      cropped,
      width: width,
      interpolation: img.Interpolation.nearest,
    );
  }
  return null;
}

class WinPdfHelper {
  static Future<Uint8List> generatePdfFromImageBytes(
    Uint8List imageBytes,
    bool is80mm,
  ) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    final format = is80mm
        ? PdfPageFormat(
            72.0 * PdfPageFormat.mm,
            double.infinity,
            marginAll: 0,
          ) // 72mm printable area for 80mm roll
        : PdfPageFormat(
            48.0 * PdfPageFormat.mm,
            double.infinity,
            marginAll: 0,
          ); // 48mm printable area for 58mm roll

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Center(child: pw.Image(image));
        },
      ),
    );

    return await pdf.save();
  }
}

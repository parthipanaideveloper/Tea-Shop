import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../../domain/models/product.dart';

class ExportUtils {
  // Brand colors
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF4F46E5); // Indigo
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFF1E293B); // Slate
  static const PdfColor accentColor = PdfColor.fromInt(0xFF0EA5E9); // Sky blue
  static const PdfColor bgLight = PdfColor.fromInt(0xFFF8FAFC);
  
  static String get dateNow => DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

  /// Builds a premium PDF Header
  static pw.Widget buildPremiumPdfHeader(String shopName, String reportTitle, String subtitle) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: secondaryColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                shopName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
              pw.SizedBox(height: 4),
              pw.Text(
                reportTitle,
                style: pw.TextStyle(
                  fontSize: 16,
                  color: accentColor)),
            ]),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                subtitle,
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.white)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: $dateNow',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey300)),
            ]),
        ]));
  }

  /// Builds a premium PDF Footer
  static pw.Widget buildPremiumPdfFooter(pw.Context context, {bool showPoweredByDiyan = true}) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          showPoweredByDiyan 
            ? pw.Text(
                'Powered by DiyanTechSolutions',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
            : pw.SizedBox(),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ]));
  }

  /// Returns a style for PDF Table Headers
  static pw.TextStyle getPdfHeaderStyle() {
    return pw.TextStyle(
      color: PdfColors.white,
      fontWeight: pw.FontWeight.bold,
      fontSize: 11);
  }

  /// Returns a decoration for PDF Table Headers
  static pw.BoxDecoration getPdfHeaderDecoration() {
    return const pw.BoxDecoration(
      color: primaryColor);
  }

  /// Setup premium Excel sheet styles
  static void setupPremiumExcelHeader(Sheet sheet, String shopName, String reportTitle, String subtitle) {
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 18,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center);
    
    final subtitleStyle = CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString('#0EA5E9'),
      backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center);

    // Header 1: Shop Name
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('H1'));
    var cell1 = sheet.cell(CellIndex.indexByString('A1'));
    cell1.value = TextCellValue(shopName.toUpperCase());
    cell1.cellStyle = titleStyle;

    // Header 2: Report Title
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('H2'));
    var cell2 = sheet.cell(CellIndex.indexByString('A2'));
    cell2.value = TextCellValue('$reportTitle - $subtitle');
    cell2.cellStyle = subtitleStyle;

    // Header 3: Date
    sheet.merge(CellIndex.indexByString('A3'), CellIndex.indexByString('H3'));
    var cell3 = sheet.cell(CellIndex.indexByString('A3'));
    cell3.value = TextCellValue('Generated: $dateNow');
    cell3.cellStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
      horizontalAlign: HorizontalAlign.Center);
  }

  /// Returns CellStyle for Excel Table Headers
  static CellStyle getExcelHeaderStyle() {
    return CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#4F46E5'),
      horizontalAlign: HorizontalAlign.Center);
  }

  /// Exports the inventory to a beautifully styled PDF
  static Future<List<int>> exportInventoryToPdf(
    List<Product> products,
    String shopName, {
    bool showStock = false,
  }) async {
    final pdf = pw.Document();

    final tableHeaders = [
      'Product Name',
      'Category',
      'Price',
      if (showStock) 'Stock',
    ];

    final tableData = products.map((p) {
      return [
        p.name,
        p.category,
        'Rs ${p.price.toStringAsFixed(2)}',
        if (showStock) p.stockCount.toString(),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => buildPremiumPdfHeader(
          shopName,
          'Inventory Report',
          'Total Products: ${products.length}'),
        footer: buildPremiumPdfFooter,
        build: (context) {
          return [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: getPdfHeaderDecoration(),
                  children: tableHeaders.map((header) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        header,
                        style: getPdfHeaderStyle(),
                        textAlign: header == 'Price' || header == 'Stock' ? pw.TextAlign.right : pw.TextAlign.left));
                  }).toList()),
                ...tableData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  return pw.TableRow(
                    decoration: index % 2 != 0 ? const pw.BoxDecoration(color: bgLight) : const pw.BoxDecoration(color: PdfColors.white),
                    children: row.asMap().entries.map((cellEntry) {
                      final cIndex = cellEntry.key;
                      final text = cellEntry.value;
                      final isNumber = cIndex >= 2;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          text,
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: isNumber ? pw.TextAlign.right : pw.TextAlign.left));
                    }).toList());
                }),
              ]),
          ];
        }));

    return await pdf.save();
  }

  /// Exports the inventory to an Excel spreadsheet
  static Future<List<int>> exportInventoryToExcel(
    List<Product> products,
    String shopName, {
    bool showStock = false,
  }) async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Inventory'];
      excel.setDefaultSheet('Inventory');
      
      // Remove default 'Sheet1'
      if (excel.sheets.keys.contains('Sheet1') && excel.sheets.keys.length > 1) {
        excel.delete('Sheet1');
      }

      // Add Headers
      final headers = [
        'Product Name',
        'Category',
        'Price',
        if (showStock) 'Stock',
      ];
      
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Add Data
      for (var p in products) {
        final row = [
          TextCellValue(p.name),
          TextCellValue(p.category),
          DoubleCellValue(p.price),
          if (showStock) IntCellValue(p.stockCount),
        ];
        sheet.appendRow(row);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file');
      return bytes;
    } catch (e) {
      print('Error generating inventory excel: $e');
      rethrow;
    }
  }
}

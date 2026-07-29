import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;

class TamilBitmapCache {
  static final Map<String, img.Image> _memoryCache = {};

  static Future<img.Image?> getTamilBitmap(
    String text, {
    int width = 384,
  }) async {
    if (text.trim().isEmpty) return null;

    final cacheKey = '${text}_$width';

    // 1. Check memory cache
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // 2. Check disk cache
    final box = Hive.box<Uint8List>('tamil_bitmap_cache');
    if (box.containsKey(cacheKey)) {
      final bytes = box.get(cacheKey)!;
      final decoded = await compute(img.decodeImage, bytes);
      if (decoded != null) {
        _memoryCache[cacheKey] = decoded;
        return decoded;
      }
    }

    // 3. Generate new bitmap using dart:ui
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Draw white background
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), 1000),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF));

      final textStyle = ui.TextStyle(
        color: const ui.Color(0xFF000000),
        fontSize: 26,
        fontWeight: ui.FontWeight.bold,
        fontFamily: 'NotoSansTamil');

      final paragraphStyle = ui.ParagraphStyle(textAlign: ui.TextAlign.left);
      final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(textStyle)
        ..addText(text);

      final paragraph = paragraphBuilder.build();
      paragraph.layout(ui.ParagraphConstraints(width: width.toDouble()));

      // Calculate exactly how tall the text is with extra padding for Tamil descenders
      final height = paragraph.height.ceil() + 16;

      // Draw the text
      canvas.drawParagraph(paragraph, const ui.Offset(0, 8));

      final picture = recorder.endRecording();

      // Extract the exact tightly cropped image
      final image = await picture.toImage(width, height);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();

        // Save to disk cache
        box.put(cacheKey, pngBytes);

        // Save to memory cache
        final decoded = await compute(img.decodeImage, pngBytes);
        if (decoded != null) {
          _memoryCache[cacheKey] = decoded;
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('Error generating Tamil bitmap: $e');
    }

    return null;
  }
}

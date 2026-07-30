import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageUtils {
  static final Map<String, ImageProvider> _cache = {};

  static ImageProvider? safeImageProvider(String? imgPath) {
    if (imgPath == null || imgPath.isEmpty) return null;
    if (_cache.containsKey(imgPath)) return _cache[imgPath];

    try {
      if (imgPath.startsWith('http://') || imgPath.startsWith('https://')) {
        final provider = NetworkImage(imgPath);
        _cache[imgPath] = provider;
        return provider;
      } else if (imgPath.startsWith('/') ||
          imgPath.startsWith('C:') ||
          imgPath.contains('\\')) {
        final provider = FileImage(File(imgPath));
        _cache[imgPath] = provider;
        return provider;
      } else {
        // Clean base64 string
        String cleanBase64 = imgPath;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
        // Pad the base64 string if necessary
        while (cleanBase64.length % 4 != 0) {
          cleanBase64 += '=';
        }
        final bytes = base64Decode(cleanBase64);
        final provider = MemoryImage(bytes);
        _cache[imgPath] =
            provider; // cache with original string to save decoding time
        return provider;
      }
    } catch (e) {
      debugPrint('Error decoding image: $e');
      return null;
    }
  }
}

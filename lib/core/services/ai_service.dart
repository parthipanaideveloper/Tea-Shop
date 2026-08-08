import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../domain/models/product.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  
  GenerativeModel? _model;
  
  AiService._internal() {
    _initModel();
  }
  
  void _initModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      debugPrint('Warning: GEMINI_API_KEY is not configured properly.');
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
  }

  /// Processes Tanglish voice input and returns a map of Product ID to Quantity.
  Future<Map<String, double>> processVoiceOrder(String transcribedText, List<Product> currentInventory) async {
    if (_model == null) {
      debugPrint('AI Model not initialized. Check API Key.');
      return {};
    }

    final inventoryJson = currentInventory.map((p) => {
      'id': p.id,
      'name': p.name,
      'nameTamil': p.nameTamil ?? '',
    }).toList();

    final prompt = '''
You are an intelligent ordering assistant for a tea shop.
The user is speaking in natural Tanglish (Tamil mixed with English).
Your task is to identify which items they want to order from the inventory and in what quantities.

Current Inventory:
${jsonEncode(inventoryJson)}

User's spoken text:
"$transcribedText"

Rules:
1. Match the spoken items to the inventory based on 'name' or 'nameTamil'.
2. Return ONLY a valid JSON array of objects, with each object having "id" (string) and "quantity" (number). 
3. If no items match, return an empty array [].
4. Do NOT wrap the JSON in Markdown formatting like ```json ... ```. Just return the raw JSON array.
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '[]';
      
      final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final List<dynamic> parsed = jsonDecode(cleanText);
      final Map<String, double> result = {};
      
      for (var item in parsed) {
        if (item is Map && item.containsKey('id') && item.containsKey('quantity')) {
          result[item['id'].toString()] = (item['quantity'] as num).toDouble();
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error processing voice order: $e');
      return {};
    }
  }

  /// Generates a list of suggested menu items based on a prompt.
  Future<List<Product>> generateMenuItems(String userPrompt) async {
    if (_model == null) return [];

    final prompt = '''
You are an expert tea shop and cafe consultant.
The owner wants to add new items to their menu. 
Prompt: "$userPrompt"

Return a JSON array of 5 suggested products. 
Each object must have:
"name": string (English name)
"nameTamil": string (Tamil name)
"price": number (Suggested price in INR)
"categoryId": string (e.g. 'cat_tea', 'cat_coffee', 'cat_snacks', 'cat_cool_drinks')
"allowHalfPortion": boolean

Return ONLY raw JSON array.
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '[]';
      final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> parsed = jsonDecode(cleanText);
      
      return parsed.map((item) => Product(
        id: DateTime.now().millisecondsSinceEpoch.toString() + item['name'].toString(),
        name: item['name'],
        nameTamil: item['nameTamil'],
        price: (item['price'] as num).toDouble(),
        category: item['categoryId'] ?? 'cat_snacks',
        stockCount: 10,
        allowHalfPortion: item['allowHalfPortion'] ?? false,
      )).toList();
    } catch (e) {
      debugPrint('Error generating menu: $e');
      return [];
    }
  }

  /// Sales Assistant Q&A
  Future<String> askSalesAssistant(String userQuestion, Map<String, dynamic> salesData) async {
    if (_model == null) return "AI API key not configured.";

    final prompt = '''
You are an AI Sales Assistant for a Tea Shop.
The owner is asking you a question about today's sales.
Answer in natural Tanglish (Tamil and English mix) naturally.

Today's Sales Data:
${jsonEncode(salesData)}

Owner's Question:
"$userQuestion"
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? "Sorry, couldn't process that.";
    } catch (e) {
      debugPrint('Error in sales assistant: $e');
      return "Error connecting to AI.";
    }
  }
}

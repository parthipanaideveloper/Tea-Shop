import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResponse({required this.success, required this.message, this.data});
}

class ApiService {
  // Replace with your centralized server endpoint
  static const String baseUrl = 'https://api.dtsbakery.com/api';

  Future<ApiResponse> registerShop({
    required String shopName,
    required String ownerName,
    required String phone,
    required String email,
    required String deviceId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/shop/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'shopName': shopName,
              'ownerName': ownerName,
              'phone': phone,
              'email': email,
              'deviceId': deviceId,
            }))
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Shop registered successfully!',
          data: body['data']);
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Failed to register shop.');
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message:
            'Network error or backend offline. Please try again when connected.');
    }
  }

  Future<ApiResponse> activatePin({
    required String pin,
    required String deviceId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/license/activate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pin': pin, 'deviceId': deviceId}))
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'License PIN activated successfully!',
          data: body['data'], // Expecting encrypted license token in response
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Invalid subscription PIN.');
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message:
            'Could not connect to activation server. Check your internet connection.');
    }
  }

  Future<ApiResponse> uploadBackup({
    required String shopId,
    required String deviceId,
    required Map<String, dynamic> encryptedBackupPayload,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/backup/upload'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'shopId': shopId,
              'deviceId': deviceId,
              'backup': encryptedBackupPayload,
              'timestamp': DateTime.now().toIso8601String(),
            }))
          .timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          message: 'Cloud backup synced successfully.');
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Backup upload failed.');
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Cloud sync failed. Will retry later when online.');
    }
  }

  Future<ApiResponse> restoreBackup({
    required String shopId,
    required String deviceId,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/backup/restore?shopId=$shopId&deviceId=$deviceId'),
            headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          message: 'Backup data retrieved successfully.',
          data: body['data'], // Retrived encrypted databases
        );
      } else {
        return ApiResponse(
          success: false,
          message:
              body['message'] ?? 'No backups found for this shop and device.');
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to sync with backup server.');
    }
  }
}

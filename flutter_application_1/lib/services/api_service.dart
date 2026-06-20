import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://127.0.0.1:8000";

  static Future<List<dynamic>> getTransactions() async {
    final response = await http.get(
      Uri.parse("$baseUrl/transactions"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception("Veri alınamadı: ${response.statusCode}");
  }

  static Future<Map<String, dynamic>> addTransaction({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
  }) async {
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";

    final response = await http.post(
      Uri.parse("$baseUrl/transactions"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "title": title,
        "amount": amount,
        "category": category,
        "date": dateStr,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("İşlem eklenemedi: ${response.statusCode} - ${response.body}");
  }

  static Future<Map<String, dynamic>> uploadPdf({
    required List<int> bytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/upload-pdf"),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        bytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("PDF yüklenemedi: ${response.statusCode} - ${response.body}");
  }

  static Future<Map<String, dynamic>> getAnalytics() async {
    final response = await http.get(
      Uri.parse("$baseUrl/analytics"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("Analytics alınamadı");
  }

  static Future<Map<String, dynamic>> getPrediction() async {
    final response = await http.get(
      Uri.parse("$baseUrl/prediction"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("Tahmin alınamadı");
  }

  static Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(
      Uri.parse("$baseUrl/dashboard"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("Dashboard alınamadı: ${response.statusCode}");
  }
}
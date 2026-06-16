import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://127.0.0.1:8000";

  static Future<List<dynamic>> getTransactions() async {
    final response = await http.get(
      Uri.parse("$baseUrl/transactions"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception("Veri alınamadı");
  }
  static Future<Map<String, dynamic>> getAnalytics() async {
  final response = await http.get(
    Uri.parse("$baseUrl/analytics"),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }

  throw Exception("Analytics alınamadı");
}
static Future<Map<String, dynamic>> getPrediction() async {
  final response = await http.get(
    Uri.parse("$baseUrl/prediction"),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }

  throw Exception("Tahmin alınamadı");
}
}

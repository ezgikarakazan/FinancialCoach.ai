import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:8000";

  static Future<Map<String, String>> _jsonHeaders() async {
    return {"Content-Type": "application/json"};
  }

  static Map<String, String> _authHeaders(String token) {
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static String _extractError(http.Response response) {
    try {
      final body = _decodeBody(response);
      if (body is Map<String, dynamic> && body["detail"] != null) {
        return body["detail"].toString();
      }
    } catch (_) {}
    return "Sunucu hatasi: ${response.statusCode}";
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/register"),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 201) {
      return (_decodeBody(response) as Map<String, dynamic>);
    }

    throw Exception(_extractError(response));
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      return (_decodeBody(response) as Map<String, dynamic>);
    }

    throw Exception(_extractError(response));
  }

  static Future<Map<String, dynamic>> getMe({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse("$baseUrl/auth/me"),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 200) {
      return (_decodeBody(response) as Map<String, dynamic>);
    }

    throw Exception(_extractError(response));
  }

  static Future<List<dynamic>> getTransactions() async {
    final response = await http.get(Uri.parse("$baseUrl/transactions"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception("Veri alinamadi: ${response.statusCode}");
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
      headers: await _jsonHeaders(),
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

    throw Exception("Islem eklenemedi: ${response.statusCode} - ${response.body}");
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

    throw Exception("PDF yuklenemedi: ${response.statusCode} - ${response.body}");
  }

  static Future<Map<String, dynamic>> getAnalytics() async {
    final response = await http.get(Uri.parse("$baseUrl/analytics"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("Analytics alinamadi");
  }

  static Future<Map<String, dynamic>> getPrediction() async {
    final response = await http.get(Uri.parse("$baseUrl/prediction"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("Tahmin alinamadi");
  }

  static Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(Uri.parse("$baseUrl/dashboard"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("Dashboard alinamadi: ${response.statusCode}");
  }
}
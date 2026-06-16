import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  static const String baseUrl =
      'http://127.0.0.1:8000';

  static Future<Map<String, dynamic>>
      getDashboard() async {

    final response =
        await http.get(
      Uri.parse('$baseUrl/dashboard'),
    );

    return jsonDecode(response.body);
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';

class ApiService {
  ApiService._();
  static final instance = ApiService._();

  String? _token;

  void setToken(String t) => _token = t;
  void clearToken() => _token = null;
  String? get token => _token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> get(String path) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
    );
    _check(res);
    if (res.statusCode == 204) return null;
    return json.decode(utf8.decode(res.bodyBytes));
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
      body: json.encode(body),
    );
    _check(res);
    if (res.statusCode == 204) return {};
    return json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
      body: json.encode(body),
    );
    _check(res);
    if (res.statusCode == 204) return {};
    return json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
      body: json.encode(body),
    );
    _check(res);
    if (res.statusCode == 204) return {};
    return json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> delete(String path) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
    );
    _check(res);
  }

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API ${res.statusCode}: ${utf8.decode(res.bodyBytes)}');
    }
  }
}

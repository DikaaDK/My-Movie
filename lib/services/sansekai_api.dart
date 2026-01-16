import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class SansekaiApi {
  const SansekaiApi();

  static const _baseUrl = 'https://api.sansekai.my.id/api';
  static const _requestTimeout = Duration(seconds: 18);

  Future<List<Map<String, dynamic>>> fetchAnimeList(
    String endpoint, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$_baseUrl/$endpoint').replace(
      queryParameters: query,
    );
    final response = await _get(uri);
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw Exception('Permintaan Sansekai gagal (${response.statusCode}).');
      }
      return response;
    } on TimeoutException {
      throw Exception('Permintaan Sansekai melebihi batas waktu.');
    }
  }
}

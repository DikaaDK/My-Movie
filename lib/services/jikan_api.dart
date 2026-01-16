import 'dart:convert';

import 'package:http/http.dart' as http;

class JikanApi {
  const JikanApi();

  static const _baseUrl = 'https://api.jikan.moe/v4';

  Future<List<Map<String, dynamic>>> fetchSeasonNow() =>
      _fetchList('seasons/now');

  Future<List<Map<String, dynamic>>> fetchTopAnime() =>
      _fetchList('top/anime');

    Future<List<Map<String, dynamic>>> fetchStreamingForAnime(String malId) =>
      _fetchList('anime/$malId/streaming');

  Future<List<Map<String, dynamic>>> _fetchList(String segment) async {
    final uri = Uri.parse('$_baseUrl/$segment');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Failed to fetch Jikan data (${response.statusCode})',
        uri,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Future<JikanPageResult> fetchAnimePage(int page) async {
    final uri = Uri.parse('$_baseUrl/anime?page=$page');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Failed to fetch Jikan data (${response.statusCode})',
        uri,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      final pagination = decoded['pagination'];
      final entries = data is List
          ? data.whereType<Map<String, dynamic>>().toList()
          : const <Map<String, dynamic>>[];
      final hasNext = pagination is Map<String, dynamic>
          ? pagination['has_next_page'] == true
          : false;
      return JikanPageResult(entries, hasNext);
    }
    return const JikanPageResult([], false);
  }
}

class JikanPageResult {
  const JikanPageResult(this.entries, this.hasNextPage);

  final List<Map<String, dynamic>> entries;
  final bool hasNextPage;
}

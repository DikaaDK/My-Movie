import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dramabox_episode.dart';
import '../models/dramabox_item.dart';

class DramaBoxApi {
  const DramaBoxApi();

  static const _authority = 'dramabos.asia';
  static const _baseSegments = ['api', 'dramabox', 'api'];
  static const _requestTimeout = Duration(seconds: 12);
  static const _defaultLang = 'in';
  static const _defaultPageSize = 60;
  static const _maxPageSize = 60;
  static const _maxConcurrentStreamFetch = 6;

  Future<List<DramaBoxItem>> fetchLatest({int limit = 0}) async { 
    final maps = await _fetchPaginatedList(
      segmentsBuilder: (page) => ['new', '$page'],
      limit: limit,
    );
    final items = maps.map(DramaBoxItem.fromJson).toList();
    if (limit > 0 && items.length > limit) {
      return items.take(limit).toList();
    }
    return items;
  }

  Future<List<DramaBoxItem>> fetchTrending({int limit = 0}) async {
    final maps = await _fetchPaginatedList(
      segmentsBuilder: (page) => ['rank', '$page'],
      limit: limit,
    );
    final items = maps.map(DramaBoxItem.fromJson).toList();
    if (limit > 0 && items.length > limit) {
      return items.take(limit).toList();
    }
    return items;
  }

  Future<List<DramaBoxItem>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <DramaBoxItem>[];
    }
    final maps = await _fetchPaginatedList(
      segmentsBuilder: (page) => ['search', trimmed, '$page'],
      limit: limit,
    );
    final items = maps.map(DramaBoxItem.fromJson).toList();
    if (limit > 0 && items.length > limit) {
      return items.take(limit).toList();
    }
    return items;
  }

  Future<List<DramaEpisode>> fetchEpisodes(String bookId) async {
    final chapters = await _fetchChapterList(bookId);
    if (chapters.isEmpty) {
      return const <DramaEpisode>[];
    }

    final episodeSlots = List<DramaEpisode?>.filled(chapters.length, null);
    final pending = <Future<void>>[];

    for (var index = 0; index < chapters.length; index++) {
      final chapter = chapters[index];
      pending.add(
        _buildEpisode(chapter: chapter, bookId: bookId).then((episode) {
          episodeSlots[index] = episode;
        }),
      );
      if (pending.length >= _maxConcurrentStreamFetch) {
        await Future.wait(pending);
        pending.clear();
      }
    }

    if (pending.isNotEmpty) {
      await Future.wait(pending);
    }

    final episodes = episodeSlots.whereType<DramaEpisode>().toList();
    episodes.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    return episodes;
  }

  Future<DramaEpisode?> fetchFirstEpisode(String bookId) async {
    final chapters = await _fetchChapterList(bookId);
    if (chapters.isEmpty) {
      return null;
    }
    chapters.sort((a, b) {
      final aIndex = _asInt(a['chapterIndex']) ?? 0;
      final bIndex = _asInt(b['chapterIndex']) ?? 0;
      return aIndex.compareTo(bIndex);
    });
    final first = chapters.first;
    return _buildEpisode(chapter: first, bookId: bookId);
  }

  Future<DramaEpisode?> _buildEpisode({
    required Map<String, dynamic> chapter,
    required String bookId,
  }) async {
    final chapterId = chapter['chapterId']?.toString() ?? '';
    if (chapterId.isEmpty) {
      return null;
    }
    final chapterIndex = _asInt(chapter['chapterIndex']) ?? 0;
    final rawName = chapter['chapterName']?.toString();
    final chapterName = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : 'Episode ${chapterIndex + 1}';
    final streamPayload = await _fetchStreams(bookId, chapterIndex);
    return DramaEpisode(
      chapterId: chapterId,
      chapterIndex: chapterIndex,
      chapterName: chapterName,
      streams: streamPayload.streams,
      directStreamUrl: streamPayload.primaryUrl,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPaginatedList({
    required List<String> Function(int page) segmentsBuilder,
    int limit = 0,
  }) async {
    final results = <Map<String, dynamic>>[];
    var page = 1;
    var hasMore = true;

    while (hasMore) {
      final remaining = limit > 0 ? limit - results.length : 0;
      final query = _buildListQuery(remaining);
      final uri = _buildUri(segmentsBuilder(page), query);
      final response = await _get(uri);
      final listResponse = _parseListResponse(response.body);
      if (listResponse.items.isEmpty) {
        break;
      }
      results.addAll(listResponse.items);
      if (limit > 0 && results.length >= limit) {
        return results.take(limit).toList();
      }
      hasMore = listResponse.isMore;
      if (!hasMore) {
        break;
      }
      page += 1;
    }

    return results;
  }

  Uri _buildUri(List<String> segments, Map<String, String> query) {
    return Uri(
      scheme: 'https',
      host: _authority,
      pathSegments: [..._baseSegments, ...segments],
      queryParameters: query,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchChapterList(String bookId) async {
    final uri = _buildUri(['chapters', bookId], {'lang': _defaultLang});
    final response = await _get(uri);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Format data episode tidak sesuai');
    }
    if (decoded['success'] != true) {
      final message =
          decoded['message']?.toString() ??
          'Gagal memuat episode untuk drama ini.';
      throw Exception(message);
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      return const <Map<String, dynamic>>[];
    }
    final chapterList = data['chapterList'];
    if (chapterList is! List) {
      return const <Map<String, dynamic>>[];
    }
    return chapterList.whereType<Map<String, dynamic>>().toList();
  }

  Future<_PlayerStreamsResult> _fetchStreams(
    String bookId,
    int chapterIndex,
  ) async {
    final uri = _buildUri(['watch', 'player'], {'lang': _defaultLang});
    try {
      final response = await _postJson(
        uri,
        body: {
          'bookId': bookId,
          'chapterIndex': chapterIndex,
          'lang': _defaultLang,
        },
      );
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _PlayerStreamsResult(streams: const <DramaStream>[]);
      }
      if (decoded['success'] != true) {
        return _PlayerStreamsResult(streams: const <DramaStream>[]);
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return _PlayerStreamsResult(streams: const <DramaStream>[]);
      }
      final primaryUrlRaw = data['videoUrl']?.toString();
      final primaryUrl = primaryUrlRaw != null && primaryUrlRaw.isNotEmpty
          ? primaryUrlRaw
          : null;
      final qualities = data['qualities'];
      if (qualities is! List) {
        final fallbackStreams = primaryUrl != null
            ? <DramaStream>[
                DramaStream(quality: 0, url: primaryUrl, isDefault: true),
              ]
            : <DramaStream>[];
        return _PlayerStreamsResult(
          streams: fallbackStreams,
          primaryUrl: primaryUrl,
        );
      }
      final streams = <DramaStream>[];
      for (final entry in qualities) {
        if (entry is! Map<String, dynamic>) {
          continue;
        }
        final url = entry['videoPath']?.toString();
        if (url == null || url.isEmpty) {
          continue;
        }
        final quality = _asInt(entry['quality']) ?? 0;
        final isDefault = entry['isDefault'] == 1 || entry['isDefault'] == true;
        streams.add(
          DramaStream(quality: quality, url: url, isDefault: isDefault),
        );
      }
      if (streams.isEmpty && primaryUrl != null) {
        streams.add(DramaStream(quality: 0, url: primaryUrl, isDefault: true));
      }
      return _PlayerStreamsResult(streams: streams, primaryUrl: primaryUrl);
    } on Exception {
      return _PlayerStreamsResult(streams: const <DramaStream>[]);
    }
  }

  Future<http.Response> _postJson(
    Uri uri, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw Exception(
          'Permintaan pemutar DramaBox gagal dengan kode ${response.statusCode}.',
        );
      }
      return response;
    } on TimeoutException {
      throw Exception('Permintaan pemutar DramaBox melebihi batas waktu');
    }
  }

  Map<String, String> _buildListQuery(int remaining) {
    final requested = remaining > 0 ? remaining : _defaultPageSize;
    final pageSize = requested.clamp(1, _maxPageSize).toString();
    return {'lang': _defaultLang, 'pageSize': pageSize};
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw Exception(
          'Permintaan ke server DramaBox gagal dengan kode ${response.statusCode}.',
        );
      }
      return response;
    } on TimeoutException {
      throw Exception('Permintaan ke server DramaBox melebihi batas waktu');
    }
  }

  _ListResponse _parseListResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Format data tidak sesuai');
    }
    if (decoded['success'] != true) {
      final message =
          decoded['message']?.toString() ??
          'Permintaan ke layanan DramaBox gagal.';
      throw Exception(message);
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      return const _ListResponse(
        items: <Map<String, dynamic>>[],
        isMore: false,
      );
    }
    final list = data['list'];
    final items = list is List
        ? list.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final isMore = data['isMore'] == true;
    return _ListResponse(items: items, isMore: isMore);
  }
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

class _ListResponse {
  const _ListResponse({required this.items, required this.isMore});

  final List<Map<String, dynamic>> items;
  final bool isMore;
}

class _PlayerStreamsResult {
  const _PlayerStreamsResult({required this.streams, this.primaryUrl});

  final List<DramaStream> streams;
  final String? primaryUrl;
}

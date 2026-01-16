import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/content_origin.dart';
import '../models/dramabox_item.dart';
import '../models/playback_config.dart';

class MeloloApi {
  const MeloloApi();

  static const _baseUrl = 'https://dramabos.asia/api/melolo/api/v1';
  static const _requestTimeout = Duration(seconds: 12);
  static const _defaultCount = 20;
  static const _maxCount = 40;

  Future<List<DramaBoxItem>> fetchTrending({int limit = 0}) async {
    final count = _resolveCount(limit);
    final items = await _fetchHome(offset: 0, count: count);
    return _trim(items, limit);
  }

  Future<List<DramaBoxItem>> fetchLatest({int limit = 0}) async {
    final count = _resolveCount(limit);
    final offset = count;
    final items = await _fetchHome(offset: offset, count: count);
    return _trim(items, limit);
  }

  Future<String?> fetchStreamUrl(String videoId) async {
    final trimmed = videoId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.parse('$_baseUrl/video/$trimmed');
    final response = await _get(uri);
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat stream Melolo (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final url = decoded['url']?.toString();
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    return null;
  }

  Future<List<DramaBoxItem>> _fetchHome({
    required int offset,
    required int count,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/home',
    ).replace(queryParameters: {'offset': '$offset', 'count': '$count'});
    final response = await _get(uri);
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat data Melolo (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Format respons Melolo tidak sesuai');
    }
    final data = decoded['data'];
    if (data is! List) {
      return const <DramaBoxItem>[];
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(_mapHomeItem)
        .whereType<DramaBoxItem>()
        .toList();
  }

  DramaBoxItem? _mapHomeItem(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final name = json['name']?.toString();
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      return null;
    }

    final cover = json['cover']?.toString() ?? '';
    final summary = json['summary']?.toString() ?? '';
    final tagline = json['tagline']?.toString() ?? '';
    final description = tagline.isNotEmpty ? '$summary\n\n$tagline' : summary;
    final tags = _stringList(json['tags']);
    final episodes = _asInt(json['episodes']) ?? 0;
    final favorites = _asInt(json['favorites']);

    return DramaBoxItem(
      bookId: id,
      bookName: name,
      coverUrl: cover,
      introduction: description.trim(),
      tags: tags.take(6).toList(),
      chapterCount: episodes,
      author: json['author']?.toString() ?? '',
      protagonist: null,
      hotCode: favorites != null ? _formatFavorites(favorites) : null,
      shelfTime: null,
      origin: ContentOrigin.melolo,
      playback: PlaybackConfig.unavailable(
        message: 'Streaming Melolo belum diatur.',
        origin: ContentOrigin.melolo,
      ),
    );
  }

  int _resolveCount(int limit) {
    if (limit <= 0) {
      return _defaultCount;
    }
    return limit.clamp(1, _maxCount);
  }

  List<DramaBoxItem> _trim(List<DramaBoxItem> items, int limit) {
    if (limit > 0 && items.length > limit) {
      return items.take(limit).toList();
    }
    return items;
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await http.get(uri).timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception('Permintaan ke server Melolo melebihi batas waktu');
    }
  }
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return int.tryParse(value.toString());
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList();
  }
  if (value is String) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    return normalized
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

String _formatFavorites(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M favorit';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K favorit';
  }
  return '$value favorit';
}

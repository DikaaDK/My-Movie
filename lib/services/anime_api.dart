import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/content_origin.dart';
import '../models/dramabox_item.dart';
import '../models/playback_config.dart';

class AnimeApi {
  const AnimeApi();

  static const _baseUrl = 'https://hachi-api-kk19.onrender.com';
  static const _requestTimeout = Duration(seconds: 30);
  static const _detailCacheTtl = Duration(minutes: 10);
  static const _episodeCacheTtl = Duration(minutes: 5);

  static final Map<String, Map<String, dynamic>> _detailCache = {};
  static final Map<String, DateTime> _detailCacheStamp = {};
  static final Map<String, Map<String, dynamic>> _episodeCache = {};
  static final Map<String, DateTime> _episodeCacheStamp = {};
  static final Map<String, Map<String, dynamic>> _animeMetadata = {};

  Future<List<DramaBoxItem>> fetchLatest({int? limit}) =>
      _fetchAnimeworldList(
        endpoint: 'animeworld/new',
        dataKey: 'new_additions',
        limit: limit,
      );

  Future<List<DramaBoxItem>> fetchRecommended({int? limit}) =>
      _fetchAnimeworldList(
        endpoint: 'animeworld/top',
        dataKey: 'top_anime_today',
        limit: limit,
      );

  Future<List<DramaBoxItem>> fetchAll({bool sortByTitle = true}) async {
    final slices = await Future.wait([
      _fetchAnimeworldList(
        endpoint: 'animeworld/top',
        dataKey: 'top_anime_today',
      ),
      _fetchAnimeworldList(
        endpoint: 'animeworld/new',
        dataKey: 'new_additions',
      ),
    ]);
    final items = <DramaBoxItem>[];
    final seen = <String>{};
    for (final slice in slices) {
      for (final item in slice) {
        if (seen.add(item.bookId)) {
          items.add(item);
        }
      }
    }
    if (sortByTitle) {
      items.sort((a, b) => a.bookName.compareTo(b.bookName));
    }
    return items;
  }

  Future<PlaybackConfig?> fetchPlaybackConfigForAnime(DramaBoxItem item) async {
    final detail = await _fetchAnimeDetail(item.bookId);
    if (detail == null) {
      return null;
    }
    final episodes = _extractEpisodes(detail);
    if (episodes.isEmpty) {
      return null;
    }
    final slug = _asTrimmedString(episodes.first['url']);
    if (slug == null) {
      return null;
    }
    return _buildPlaybackConfigForSlug(slug);
  }

  Future<PlaybackConfig?> fetchEpisodePlaybackConfig(String slug) =>
      _buildPlaybackConfigForSlug(slug);

  Future<AnimeDetail?> fetchAnimeDetailInfo(String slug) async {
    final fetched = await _fetchAnimeDetail(slug);
    if (fetched == null) {
      return null;
    }
    final synopsis = _buildSynopsis(_animeMetadata[slug]);
    final episodes = _extractEpisodes(fetched)
        .map((entry) {
          final episodeSlug = _asTrimmedString(entry['url']);
          if (episodeSlug == null) {
            return null;
          }
          return AnimeDetailEpisode(
            title: _buildEpisodeTitle(entry),
            slug: episodeSlug,
          );
        })
        .whereType<AnimeDetailEpisode>()
        .toList();
    return AnimeDetail(synopsis: synopsis, episodes: episodes);
  }

  Future<String?> fetchCover(String slug) async {
    final metadata = _animeMetadata[slug];
    final cover = _asTrimmedString(metadata?['image']) ??
        _asTrimmedString(metadata?['cover']);
    if (cover != null) {
      return cover;
    }
    return null;
  }

  Future<List<DramaBoxItem>> _fetchAnimeworldList({
    required String endpoint,
    required String dataKey,
    int? limit,
  }) async {
    final payload = await _fetchApiData(endpoint);
    final rawEntries = _extractAnimeworldEntries(payload, dataKey);
    final items = <DramaBoxItem>[];
    final seen = <String>{};
    for (final entry in rawEntries) {
      final item = _buildAnimeworldItem(entry);
      if (item == null || !seen.add(item.bookId)) {
        continue;
      }
      items.add(item);
      if (limit != null && limit > 0 && items.length >= limit) {
        break;
      }
    }
    return items;
  }

  List<Map<String, dynamic>> _extractAnimeworldEntries(
    dynamic payload,
    String key,
  ) {
    if (payload is! Map<String, dynamic>) {
      return const <Map<String, dynamic>>[];
    }
    final data = payload[key];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  DramaBoxItem? _buildAnimeworldItem(Map<String, dynamic> entry) {
    final url = _asTrimmedString(entry['url']);
    final title = _asTrimmedString(entry['title']);
    if (url == null || title == null) {
      return null;
    }
    final cover = _asTrimmedString(entry['image']) ?? '';
    final introduction = _buildAnimeworldIntroduction(entry);
    final tags = _buildAnimeworldTags(entry);
    _animeMetadata[url] = Map<String, dynamic>.from(entry);
    return DramaBoxItem(
      bookId: url,
      bookName: title,
      coverUrl: cover,
      introduction: introduction,
      tags: tags,
      chapterCount: _extractChapterCount(entry),
      origin: ContentOrigin.animeApi,
      playback: const PlaybackConfig.unavailable(
        message: 'Streaming anime disediakan via Hachi API.',
        origin: ContentOrigin.animeApi,
      ),
    );
  }

  int _extractChapterCount(Map<String, dynamic> entry) {
    final candidates = <dynamic>[
      entry['episodes_count'],
      entry['chapter_count'],
      entry['total_episode'],
    ];
    for (final candidate in candidates) {
      final parsed = _asInt(candidate);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  List<String> _buildAnimeworldTags(Map<String, dynamic> entry) {
    final tags = <String>[];
    final japaneseTitle = _asTrimmedString(entry['japanese_title']);
    final rating = _asTrimmedString(entry['rating']);
    if (japaneseTitle != null && japaneseTitle.isNotEmpty) {
      tags.add(japaneseTitle);
    }
    if (rating != null && rating.isNotEmpty) {
      tags.add('Rating $rating');
    }
    if (tags.isEmpty) {
      tags.add('Anime');
    }
    return tags;
  }

  String _buildAnimeworldIntroduction(Map<String, dynamic> entry) {
    final parts = <String>[];
    final status = _asTrimmedString(entry['status']);
    final release = _asTrimmedString(entry['release_date']);
    final rating = _asTrimmedString(entry['rating']);
    final views = _asTrimmedString(entry['views']);
    if (status != null) {
      parts.add(status);
    }
    if (release != null) {
      parts.add('Rilis $release');
    }
    if (rating != null) {
      parts.add('★ $rating');
    }
    if (views != null) {
      parts.add('$views kali ditonton');
    }
    if (parts.isEmpty) {
      final japaneseTitle = _asTrimmedString(entry['japanese_title']);
      if (japaneseTitle != null) {
        parts.add('Judul Jepang: $japaneseTitle');
      }
    }
    return parts.isEmpty ? 'Streaming anime terbaru.' : parts.join(' · ');
  }

  String _buildEpisodeTitle(Map<String, dynamic> entry) {
    final label = _asTrimmedString(entry['title']);
    if (label != null && label.isNotEmpty) {
      return label;
    }
    final number = entry['number'];
    final parsedNumber = number is int ? number : _asInt(number);
    if (parsedNumber != null) {
      return 'Episode $parsedNumber';
    }
    return 'Episode';
  }

  Future<dynamic> _fetchApiData(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse('$_baseUrl/$endpoint').replace(
      queryParameters: queryParameters,
    );
    try {
      final response = await http.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw Exception(
          'Gagal memuat data anime (${response.statusCode}).',
        );
      }
      final decoded = jsonDecode(response.body);
      return decoded;
    } on TimeoutException {
      throw Exception('Permintaan anime melebihi batas waktu.');
    }
  }

  Future<Map<String, dynamic>?> _fetchAnimeDetail(String slug) async {
    if (slug.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final cached = _detailCache[slug];
    final stamp = _detailCacheStamp[slug];
    if (cached != null &&
        stamp != null &&
        now.difference(stamp) < _detailCacheTtl) {
      return cached;
    }
    final payload = await _fetchApiData(
      'animeworld/eps',
      queryParameters: {
        'url': slug,
      },
    );
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    _detailCache[slug] = payload;
    _detailCacheStamp[slug] = now;
    return payload;
  }

  Future<Map<String, dynamic>?> _fetchEpisodeStreams(String slug) async {
    if (slug.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final cached = _episodeCache[slug];
    final stamp = _episodeCacheStamp[slug];
    if (cached != null &&
        stamp != null &&
        now.difference(stamp) < _episodeCacheTtl) {
      return cached;
    }
    final payload = await _fetchApiData(
      'animeworld/watch',
      queryParameters: {
        'url': slug,
      },
    );
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    _episodeCache[slug] = payload;
    _episodeCacheStamp[slug] = now;
    return payload;
  }

  List<Map<String, dynamic>> _extractEpisodes(
    Map<String, dynamic> detail,
  ) {
    final episodes = detail['episodes'];
    if (episodes is List) {
      return episodes.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<PlaybackConfig?> _buildPlaybackConfigForSlug(String slug) async {
    if (slug.isEmpty) {
      return null;
    }
    final streamData = await _fetchEpisodeStreams(slug);
    return _buildPlaybackConfigFromStreamData(streamData);
  }

  PlaybackConfig? _buildPlaybackConfigFromStreamData(
    Map<String, dynamic>? streamData,
  ) {
    if (streamData == null) {
      return null;
    }
    final rawStreams = streamData['streams'] ?? streamData['stream'];
    final streams = (rawStreams as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList();
    if (streams == null || streams.isEmpty) {
      return null;
    }
    for (final entry in streams) {
      final link = _asTrimmedString(entry['url'] ?? entry['link']);
      if (link == null) {
        continue;
      }
      if (_isDirectStream(link)) {
        return PlaybackConfig.directStream(
          streamUrl: link,
          origin: ContentOrigin.animeApi,
        );
      }
    }
    final fallback = _asTrimmedString(
      streams.first['url'] ?? streams.first['link'],
    );
    if (fallback != null) {
      return PlaybackConfig.webEmbed(
        embedUrl: fallback,
        webUrl: fallback,
        origin: ContentOrigin.animeApi,
      );
    }
    return null;
  }

  bool _isDirectStream(String url) {
    final normalized = url.toLowerCase();
    return normalized.endsWith('.mp4') ||
        normalized.endsWith('.m3u8') ||
        normalized.endsWith('.webm');
  }
}

class AnimeDetail {
  const AnimeDetail({required this.synopsis, required this.episodes});

  final String synopsis;
  final List<AnimeDetailEpisode> episodes;
}

class AnimeDetailEpisode {
  const AnimeDetailEpisode({required this.title, required this.slug});

  final String title;
  final String slug;
}

String _buildSynopsis(Map<String, dynamic>? metadata) {
  if (metadata == null) {
    return 'Deskripsi tidak tersedia.';
  }
  final parts = <String>[];
  final japaneseTitle = _asTrimmedString(metadata['japanese_title']);
  final release = _asTrimmedString(metadata['release_date']);
  final status = _asTrimmedString(metadata['status']);
  if (japaneseTitle != null) {
    parts.add('Judul Jepang: $japaneseTitle');
  }
  if (release != null) {
    parts.add('Rilis $release');
  }
  if (status != null) {
    parts.add(status);
  }
  if (parts.isEmpty) {
    final rating = _asTrimmedString(metadata['rating']);
    if (rating != null) {
      parts.add('Rating: $rating');
    }
  }
  return parts.isEmpty ? 'Deskripsi tidak tersedia.' : parts.join(' · ');
}

String? _asTrimmedString(dynamic value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString().trim());
}

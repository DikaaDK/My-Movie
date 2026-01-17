import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class Lk21Api {
  const Lk21Api();

  static const _baseUrl =
      'https://lk21-api.leksaandanaoktaviansaa.workers.dev';
  static const _requestTimeout = Duration(seconds: 20);

  Future<List<MovieResult>> fetchMovies({
    String category = 'top-movie-today',
    int page = 1,
  }) async {
    final uri = Uri.parse('$_baseUrl/movies').replace(
      queryParameters: {
        'category': category,
        'page': page.toString(),
      },
    );
    final response = await _get(uri);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <MovieResult>[];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MovieResult.fromJson)
        .where((movie) => movie.isValid)
        .toList();
  }

  Future<List<MovieResult>> fetchAllMovies({
    String category = 'top-movie-today',
    int startPage = 1,
    int? maxPages,
  }) async {
    final aggregated = <MovieResult>[];
    final seenSlugs = <String>{};
    var page = startPage;

    while (true) {
      late final List<MovieResult> movies;
      try {
        movies = await fetchMovies(category: category, page: page);
      } catch (_) {
        break;
      }
      if (movies.isEmpty) {
        break;
      }
      for (final movie in movies) {
        if (seenSlugs.add(movie.slug)) {
          aggregated.add(movie);
        }
      }
      page += 1;
      if (maxPages != null && maxPages > 0 && page - startPage >= maxPages) {
        break;
      }
    }

    return aggregated;
  }

  Future<Lk21WatchResponse?> fetchWatch(String slug) async {
    final trimmed = slug.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.parse('$_baseUrl/watch/$trimmed');
    final response = await _get(uri);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return Lk21WatchResponse.fromJson(decoded);
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw Exception('LK21 API returned ${response.statusCode}.');
      }
      return response;
    } on TimeoutException {
      throw Exception('Permintaan ke LK21 API melebihi batas waktu.');
    }
  }

  Future<List<Lk21FilterOption>> fetchGenres() async {
    final uri = Uri.parse('$_baseUrl/filters');
    final response = await _get(uri);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const <Lk21FilterOption>[];
    }
    final rawGenres = decoded['genres'];
    if (rawGenres is! List) {
      return const <Lk21FilterOption>[];
    }
    final unique = <String>{};
    final genres = <Lk21FilterOption>[];
    for (final entry in rawGenres) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final option = Lk21FilterOption.fromJson(entry);
      if (option.title.isEmpty && option.parameter.isEmpty) {
        continue;
      }
      final key = option.parameter.isNotEmpty ? option.parameter : option.title;
      if (!unique.add(key)) {
        continue;
      }
      genres.add(option);
    }
    return genres;
  }
}

class MovieResult {
  const MovieResult({
    required this.title,
    required this.slug,
    this.poster,
    this.rating,
    this.quality,
    this.year,
    this.duration,
    this.url,
  });

  final String title;
  final String slug;
  final String? poster;
  final String? rating;
  final String? quality;
  final String? year;
  final String? duration;
  final String? url;

  bool get isValid => title.isNotEmpty && slug.isNotEmpty;

  factory MovieResult.fromJson(Map<String, dynamic> json) {
    final poster = json['poster']?.toString();
    return MovieResult(
      title: json['title']?.toString().trim() ?? '',
      slug: json['slug']?.toString().trim() ?? '',
      poster: (poster?.isEmpty == true) ? null : poster,
      rating: json['rating']?.toString(),
      quality: json['quality']?.toString(),
      year: json['year']?.toString(),
      duration: json['duration']?.toString(),
      url: json['url']?.toString(),
    );
  }
}

class Lk21FilterOption {
  const Lk21FilterOption({required this.title, required this.parameter});

  final String title;
  final String parameter;

  factory Lk21FilterOption.fromJson(Map<String, dynamic> json) {
    return Lk21FilterOption(
      title: json['title']?.toString().trim() ?? '',
      parameter: json['parameter']?.toString().trim() ?? '',
    );
  }
}

class Lk21WatchResponse {
  const Lk21WatchResponse({
    required this.title,
    required this.slug,
    required this.streams,
    this.fallbackStream,
  });

  final String title;
  final String slug;
  final List<Lk21StreamItem> streams;
  final Lk21StreamItem? fallbackStream;

  factory Lk21WatchResponse.fromJson(Map<String, dynamic> json) {
    final streams = <Lk21StreamItem>[];
    void collectStreams(dynamic raw) {
      if (raw is List) {
        for (final entry in raw) {
          if (entry is Map<String, dynamic>) {
            final item = Lk21StreamItem.fromJson(entry);
            if (item.url.isNotEmpty) {
              streams.add(item);
            }
          }
        }
      }
    }

    collectStreams(json['streams']);
    final data = json['data'];
    collectStreams(data?['streams']);

    final fallback = data is Map<String, dynamic>
        ? _extractFallbackStream(data)
        : null;

    return Lk21WatchResponse(
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      streams: streams,
      fallbackStream: fallback,
    );
  }

  static Lk21StreamItem? _extractFallbackStream(Map<String, dynamic> data) {
    final file = data['file']?.toString().trim();
    if (file == null || file.isEmpty) {
      return null;
    }
    final label = data['title']?.toString().trim() ??
        data['label']?.toString().trim() ??
        '';
    final type = data['type']?.toString().trim() ?? '';
    return Lk21StreamItem(
      label: label,
      type: type,
      url: file,
    );
  }
}

class Lk21StreamItem {
  const Lk21StreamItem({
    required this.label,
    required this.type,
    required this.url,
  });

  final String label;
  final String type;
  final String url;

  factory Lk21StreamItem.fromJson(Map<String, dynamic> json) {
    return Lk21StreamItem(
      label: json['label']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

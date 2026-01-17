import 'dart:async';

import 'package:flutter/foundation.dart';

import 'lk21_api.dart';

class Lk21CatalogCache extends ChangeNotifier {
  Lk21CatalogCache._();

  static final Lk21CatalogCache instance = Lk21CatalogCache._();

  final _api = const Lk21Api();
  final _movies = <MovieResult>[];
  final _slugs = <String>{};

  int _nextPage = 1;
  bool _hasReachedEnd = false;
  Duration _fetchInterval = const Duration(seconds: 2);
  Timer? _pageTimer;
  bool _initialBatchReady = false;
  Completer<void>? _initialBatchCompleter;

  List<MovieResult> get snapshot => List.unmodifiable(_movies);

  Future<void> ensureInitialBatch({int targetCount = 100}) {
    if (_initialBatchReady && _movies.length >= targetCount) {
      return Future.value();
    }
    if (_initialBatchCompleter != null) {
      return _initialBatchCompleter!.future;
    }
    final completer = Completer<void>();
    _initialBatchCompleter = completer;
    _doEnsureInitialBatch(targetCount).whenComplete(() {
      completer.complete();
      _initialBatchCompleter = null;
    });
    return completer.future;
  }

  Future<void> _doEnsureInitialBatch(int targetCount) async {
    while (_movies.length < targetCount && !_hasReachedEnd) {
      final movies = await _fetchPage(_nextPage);
      if (movies.isEmpty) {
        _hasReachedEnd = true;
        break;
      }
      _cacheMovies(movies);
      _nextPage += 1;
    }
    _initialBatchReady = true;
  }

  void startBackgroundFetching({Duration interval = const Duration(seconds: 2)}) {
    if (_hasReachedEnd) {
      return;
    }
    _fetchInterval = interval;
    if (_pageTimer != null) {
      return;
    }
    _scheduleNextFetch();
  }

  void _scheduleNextFetch() {
    _pageTimer = Timer(_fetchInterval, () async {
      _pageTimer = null;
      await _performBackgroundFetch();
    });
  }

  Future<void> _performBackgroundFetch() async {
    if (_hasReachedEnd) {
      return;
    }
    final movies = await _fetchPage(_nextPage);
    if (movies.isEmpty) {
      _hasReachedEnd = true;
      return;
    }
    _cacheMovies(movies);
    _nextPage += 1;
    if (!_hasReachedEnd) {
      _scheduleNextFetch();
    }
  }

  Future<List<MovieResult>> _fetchPage(int page) async {
    try {
      return await _api.fetchMovies(page: page);
    } catch (_) {
      return const <MovieResult>[];
    }
  }

  void _cacheMovies(List<MovieResult> movies) {
    var added = false;
    for (final movie in movies) {
      if (_slugs.add(movie.slug)) {
        _movies.add(movie);
        added = true;
      }
    }
    if (added) {
      notifyListeners();
    }
  }

  void reset() {
    _pageTimer?.cancel();
    _pageTimer = null;
    _movies.clear();
    _slugs.clear();
    _nextPage = 1;
    _hasReachedEnd = false;
    _initialBatchReady = false;
    _initialBatchCompleter = null;
    notifyListeners();
  }
}

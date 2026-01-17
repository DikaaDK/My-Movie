import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/content_origin.dart';
import '../models/dramabox_item.dart';
import '../models/playback_config.dart';
import '../pages/drama_player_page.dart';
import '../services/dramabox_api.dart';
import '../services/lk21_api.dart';
import '../services/lk21_catalog_cache.dart';
import '../services/melolo_api.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  static const _backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF071228), Color(0xFF0B1F4A), Color(0xFF114173)],
  );
  static const _heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F6FEB), Color(0xFF56CCF2)],
  );
  static const _fallbackGenres = <String>[
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Fantasy',
    'Sci-Fi',
    'Romance',
    'Slice of Life',
    'Horror',
    'Mystery',
    'Isekai',
  ];
  static const _defaultLk21Genres = <String>[
    'Action',
    'Adventure',
    'Animation',
    'Biography',
    'Comedy',
    'Crime',
    'Documentary',
    'Drama',
    'Family',
    'Fantasy',
    'Film-Noir',
    'Game-Show',
    'History',
    'Horror',
    'Music',
    'Mystery',
    'Psychological',
    'Reality-TV',
    'Romance',
    'Sci-fi',
    'Short',
    'Sport',
    'Supernatural',
    'TV Movie',
    'Talk-Show',
    'Thriller',
    'War',
    'Western',
    'Wrestling',
    '2025',
    '2024',
  ];
  static const _meloloGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE15B64), Color(0xFFFFA26F)],
  );
  static const _dracinGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F6FEB), Color(0xFFE15B64)],
  );
  static const _lk21Gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4C1D95), Color(0xFF0EA5E9)],
  );
  static const _skeletonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2C3E50), Color(0xFF1B2733)],
  );
  static const _cacheTtl = Duration(minutes: 10);
  static const _initialBatchSize = 20;
  static const _subsequentBatchSize = 16;
  static _ExploreData? _cachedData;
  static DateTime? _cacheTimestamp;

  final DramaBoxApi _dramaBoxApi = const DramaBoxApi();
  final MeloloApi _meloloApi = const MeloloApi();
  final Lk21Api _lk21Api = const Lk21Api();
  final Lk21CatalogCache _lk21CatalogCache = Lk21CatalogCache.instance;
  _SourceSlice? _pendingLk21Slice;

  TextEditingController? _searchController;
  final ValueNotifier<_ExploreViewState> _viewStateNotifier =
      ValueNotifier(const _ExploreViewState.loading());
  String _currentQuery = '';
  int _selectedGenre = -1;
  Set<_ContentSource>? _selectedSources;
  final ScrollController _scrollController = ScrollController();
  int _visibleItemCount = _initialBatchSize;
  bool _isLoadingMore = false;
  List<String> _availableLk21Genres = _defaultLk21Genres;

  @override
  void initState() {
    super.initState();
    _ensureSearchController();
    _resetPagination();
    unawaited(_loadDataAndNotify());
    unawaited(_loadLk21Genres());
    _lk21CatalogCache.addListener(_handleLk21CacheUpdated);
  }

  @override
  void dispose() {
    _searchController
      ?..removeListener(_handleSearchTextChanged)
      ..dispose();
    _scrollController.dispose();
    _lk21CatalogCache.removeListener(_handleLk21CacheUpdated);
    _viewStateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _backgroundGradient),
        child: SafeArea(
          child: ValueListenableBuilder<_ExploreViewState>(
            valueListenable: _viewStateNotifier,
            builder: (context, state, _) {
              switch (state.status) {
                case _ExploreStatus.loading:
                  return _buildLoadingSkeleton(theme);
                case _ExploreStatus.error:
                  return _buildError(
                    theme,
                    state.message ?? 'Gagal memuat data eksplorasi.',
                  );
                case _ExploreStatus.ready:
                  final data = state.data;
                  if (data == null) {
                    return _buildError(
                      theme,
                      'Data eksplorasi tidak tersedia dari layanan.',
                    );
                  }
                  return _buildLoadedContent(theme, data);
              }
            },
          ),
        ),
      ),
    );
  }

  TextEditingController _ensureSearchController() {
    final controller = _searchController;
    if (controller != null) {
      return controller;
    }
    final newController = TextEditingController();
    newController.addListener(_handleSearchTextChanged);
    _searchController = newController;
    return newController;
  }

  Future<_ExploreData> _fetchExploreData() async {
    final cached = _cachedData;
    final timestamp = _cacheTimestamp;
    final now = DateTime.now();
    final cacheValid =
        cached != null &&
        timestamp != null &&
        now.difference(timestamp) < _cacheTtl;
    if (cacheValid) {
      return cached!;
    }

    final dramaboxTrendingFuture = _safeFetch(_dramaBoxApi.fetchTrending);
    final dramaboxLatestFuture = _safeFetch(_dramaBoxApi.fetchLatest);
    final meloloTrendingFuture = _safeFetch(_meloloApi.fetchTrending);
    final meloloLatestFuture = _safeFetch(_meloloApi.fetchLatest);
    final slices = <_SourceSlice>[];

    void addSlice(_ContentSource source, List<DramaBoxItem> items) {
      if (items.isEmpty) {
        return;
      }
      slices.add(_SourceSlice(source, items));
    }

    addSlice(_ContentSource.dramaBox, await dramaboxTrendingFuture);
    addSlice(_ContentSource.dramaBox, await dramaboxLatestFuture);
    addSlice(_ContentSource.melolo, await meloloTrendingFuture);
    addSlice(_ContentSource.melolo, await meloloLatestFuture);
    final lk21Slice = await _createLk21Slice(ensureInitial: true);
    addSlice(_ContentSource.lk21, lk21Slice.items);

    var data = _ExploreData(slices);
    if (_pendingLk21Slice != null) {
      data = data.replaceSlice(_pendingLk21Slice!);
      _pendingLk21Slice = null;
    }
    return data;
  }

  Future<void> _loadLk21Genres() async {
    try {
      final filters = await _lk21Api.fetchGenres();
      if (!mounted || filters.isEmpty) {
        return;
      }
      final titles = filters
          .map((option) => option.title)
          .where((title) => title.isNotEmpty)
          .toList(growable: false);
      if (titles.isEmpty || listEquals(titles, _availableLk21Genres)) {
        return;
      }
      setState(() {
        _availableLk21Genres = titles;
        if (_selectedGenre >= titles.length) {
          _selectedGenre = titles.isEmpty ? -1 : 0;
        }
      });
    } catch (_) {
      // Keep the fallback list when the remote filters cannot be loaded.
    }
  }

  Future<List<DramaBoxItem>> _safeFetch(
    Future<List<DramaBoxItem>> Function() fetcher,
  ) async {
    try {
      return await fetcher();
    } catch (_) {
      return const <DramaBoxItem>[];
    }
  }

  Future<void> _onRefresh() async {
    _clearCache();
    setState(() {
      _resetPagination(shouldScrollToTop: true);
    });
    await _loadDataAndNotify();
  }

  Future<void> _loadDataAndNotify({bool showLoading = true}) async {
    if (showLoading) {
      _viewStateNotifier.value = const _ExploreViewState.loading();
    }
    try {
      final data = await _fetchExploreData();
      if (!mounted) {
        return;
      }
      _updateCachedData(data);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final errorMessage = error.toString();
      final message = errorMessage.isNotEmpty
          ? errorMessage
          : 'Gagal memuat data eksplorasi.';
      _viewStateNotifier.value = _ExploreViewState.error(message);
    }
  }

  Widget _buildLoadedContent(ThemeData theme, _ExploreData data) {
    final allItems = data.allItems;
    final filteredBySource = _selectedSources == null
        ? allItems
        : allItems
              .where((entry) => _selectedSources!.contains(entry.source))
              .toList();
    final filteredItems = _applySearch(filteredBySource, _currentQuery);
    final highlight = filteredItems.isNotEmpty ? filteredItems.first : null;
    final baseForTagExtraction = filteredBySource.isNotEmpty
        ? filteredBySource
        : allItems;
    final derivedGenres = _extractTopTags(
      baseForTagExtraction.map((entry) => entry.item).toList(),
      limit: _fallbackGenres.length,
    );
    final shouldUseLk21Genres = _isFilteringLk21;
    final genres = shouldUseLk21Genres
      ? _availableLk21Genres
      : (derivedGenres.isEmpty ? _fallbackGenres : derivedGenres);
    final selectedGenre = genres.isEmpty
      ? -1
      : (_selectedGenre >= genres.length ? 0 : _selectedGenre);
    final totalCount = filteredItems.length;
    final visibleCount = totalCount == 0
        ? 0
        : math.min(_visibleItemCount, totalCount);
    final visibleItems = visibleCount == 0
        ? const <_SourcedItem>[]
        : filteredItems.take(visibleCount).toList();
    final canLoadMore = visibleCount < totalCount;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.extentAfter < 400 &&
            canLoadMore &&
            !_isLoadingMore) {
          _handleLoadMore(totalCount);
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.white,
        backgroundColor: const Color(0xFF0B1F4A),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              if (highlight != null) ...[
                const SizedBox(height: 22),
                _buildHighlightCard(theme, highlight),
              ] else
                const SizedBox(height: 22),
              const SizedBox(height: 18),
              _buildSearchField(theme),
              const SizedBox(height: 18),
              _buildSourceFilters(theme),
              if (genres.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSectionTitle(theme, 'Genre'),
                const SizedBox(height: 14),
                _buildGenreDropdown(theme, genres, selectedGenre),
              ],
              const SizedBox(height: 28),
              _buildAllVideoHeader(theme, totalCount),
              const SizedBox(height: 18),
              if (totalCount == 0)
                _buildPlaceholderCard(
                  theme,
                  _currentQuery.isEmpty
                      ? 'Konten tidak tersedia pada sumber ini.'
                      : 'Tidak ada hasil untuk "$_currentQuery".',
                )
              else ...[
                _buildVideoGrid(theme, visibleItems),
                if (_isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: _buildLoadMoreIndicator(),
                  )
                else if (canLoadMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: _buildLoadMoreHint(theme),
                  ),
              ],
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(ThemeData theme) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eksplor Konten',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildSkeletonBar(width: 180, height: 18),
          const SizedBox(height: 18),
          _buildSkeletonCard(),
          const SizedBox(height: 16),
          _buildSkeletonSectionTitle(theme, 'Genre'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              5,
              (_) => _buildSkeletonBar(width: 90, height: 30),
            ),
          ),
          const SizedBox(height: 24),
          Column(children: List.generate(4, (_) => _buildSkeletonCard())),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _skeletonGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 12),
          _buildSkeletonBar(width: 140, height: 16),
          const SizedBox(height: 8),
          _buildSkeletonBar(width: 100, height: 12),
          const SizedBox(height: 14),
          Row(
            children: List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildSkeletonBar(width: 60, height: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonBar({
    double width = double.infinity,
    double height = 14,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buildSkeletonSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: Colors.white54,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  void _clearCache() {
    _cachedData = null;
    _cacheTimestamp = null;
    _pendingLk21Slice = null;
  }

  void _resetPagination({bool shouldScrollToTop = false}) {
    _visibleItemCount = _initialBatchSize;
    _isLoadingMore = false;
    if (!shouldScrollToTop) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _isSameSelection(Set<_ContentSource>? a, Set<_ContentSource>? b) {
    if (a == null || b == null) {
      return a == null && b == null;
    }
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (final value in a) {
      if (!b.contains(value)) {
        return false;
      }
    }
    return true;
  }

  void _handleLoadMore(int total) {
    if (_isLoadingMore || _visibleItemCount >= total) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
      final nextVisible = math.min(
        _visibleItemCount + _subsequentBatchSize,
        total,
      );
      _visibleItemCount = nextVisible;
    });
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingMore = false;
      });
    });
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Eksplor Konten',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Semua katalog video kini tampil di satu halaman.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: _heroGradient,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F6FEB).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.local_fire_department, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    final controller = _ensureSearchController();
    return TextField(
      controller: controller,
      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        hintText: 'Cari judul, genre, atau studio',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.55),
        ),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      cursorColor: Colors.white,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }

  Widget _buildSourceFilters(ThemeData theme) {
    const options = <_FilterOption>[
      _FilterOption('Semua Konten', null),
      _FilterOption('Dracin', {_ContentSource.dramaBox, _ContentSource.melolo}),
      _FilterOption('Film LK21', {_ContentSource.lk21}),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: options.map((option) {
        final isSelected = _isSameSelection(option.sources, _selectedSources);
        final baseGradient = _gradientForSources(option.sources);
        final gradient = isSelected ? baseGradient : null;
        final background = isSelected
            ? null
            : Colors.white.withValues(alpha: 0.08);
        final borderColor = isSelected
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.16);
        final glowColor = (gradient?.colors.first ?? baseGradient.colors.first)
            .withValues(alpha: 0.32);

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() {
              _selectedSources = option.sources?.toSet();
              _resetPagination(shouldScrollToTop: true);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: gradient,
              color: background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: 20,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              option.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildAllVideoHeader(ThemeData theme, int totalCount) {
    final subtitle = totalCount == 1 ? '1 judul' : '$totalCount judul';
    return Row(
      children: [
        Expanded(child: _buildSectionTitle(theme, 'Semua Video')),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }

  Widget _buildGenreDropdown(
    ThemeData theme,
    List<String> genres,
    int selectedGenreIndex,
  ) {
    final selectedValue = selectedGenreIndex >= 0
        ? genres[selectedGenreIndex]
        : null;
    final controller = _ensureSearchController();
    return GestureDetector(
      onTap: () => _showGenreSelectionModal(theme, genres, controller),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedValue ?? 'Pilih genre',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selectedValue == null
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.white,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  void _showGenreSelectionModal(
    ThemeData theme,
    List<String> genres,
    TextEditingController controller,
  ) {
    final maxHeight = math.min(360.0, genres.length * 56.0 + 120.0);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1F4A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return SizedBox(
          height: maxHeight,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pilih genre',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: genres.length + 1,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Colors.white12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        title: Text(
                          'Semua genre',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        onTap: () => _applyGenreSelection(
                          modalContext,
                          -1,
                          controller: controller,
                          genre: null,
                        ),
                      );
                    }
                    final actualIndex = index - 1;
                    final genre = genres[actualIndex];
                    final isSelected = actualIndex == _selectedGenre;
                    return ListTile(
                      title: Text(
                        genre,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFF1F6FEB))
                          : null,
                      onTap: () => _applyGenreSelection(
                        modalContext,
                        actualIndex,
                        controller: controller,
                        genre: genre,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyGenreSelection(
    BuildContext modalContext,
    int index, {
    required TextEditingController controller,
    required String? genre,
  }) {
    if (index == -1) {
      controller.clear();
    } else if (genre != null) {
      controller
        ..text = genre
        ..selection = TextSelection.collapsed(offset: genre.length);
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedGenre = index;
      _resetPagination(shouldScrollToTop: true);
    });
    Navigator.of(modalContext).pop();
  }

  Widget _buildHighlightCard(ThemeData theme, _SourcedItem entry) {
    final item = entry.item;
    final highlightBadges = <Widget>[
      _buildBadge(theme, entry.source.label, entry.source.gradient),
    ];
    final extraLabel = item.hotCode ?? item.primaryTag;
    if (extraLabel.isNotEmpty) {
      highlightBadges.add(
        _buildBadge(
          theme,
          extraLabel,
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x33000000), Color(0x66000000)],
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _openPlayer(item),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: entry.source.gradient.colors.first.withValues(
                  alpha: 0.35,
                ),
                blurRadius: 28,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Positioned.fill(
                  child: item.coverUrl.isEmpty
                      ? Container(color: Colors.black.withValues(alpha: 0.2))
                      : Image.network(item.coverUrl, fit: BoxFit.cover),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xAA040A15),
                          Color(0xAA081B36),
                          Color(0xCC0E2F59),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: highlightBadges,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        item.bookName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.description.isEmpty
                            ? 'Belum ada deskripsi untuk judul ini.'
                            : item.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: item.tags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              tag,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(ThemeData theme, String text, LinearGradient gradient) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVideoGrid(ThemeData theme, List<_SourcedItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = 16.0;
        const columns = 2;
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map((entry) => _buildVideoCard(theme, entry, itemWidth))
              .toList(),
        );
      },
    );
  }

  Widget _buildVideoCard(ThemeData theme, _SourcedItem entry, double width) {
    final item = entry.item;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openPlayer(item),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              color: Colors.white.withValues(alpha: 0.04),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(child: _buildCoverLayer(entry)),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: entry.source.gradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              entry.source.label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.bookName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatMeta(item, source: entry.source),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverLayer(_SourcedItem entry) {
    final item = entry.item;
    if (item.coverUrl.isNotEmpty) {
      return Image.network(item.coverUrl, fit: BoxFit.cover);
    }
    return const _CoverPlaceholder();
  }

  Widget _buildLoadMoreIndicator() {
    return const SizedBox(
      height: 42,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2.8)),
    );
  }

  Widget _buildLoadMoreHint(ThemeData theme) {
    return SizedBox(
      height: 32,
      child: Center(
        child: Text(
          'Scroll untuk memuat judul lain...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(ThemeData theme, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_empty, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  void _clearSearch() {
    final controller = _searchController;
    if (controller == null) {
      return;
    }
    controller.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _currentQuery = '';
      _selectedGenre = -1;
      _resetPagination(shouldScrollToTop: true);
    });
  }

  bool get _isFilteringLk21 {
    return _selectedSources != null &&
        _selectedSources!.length == 1 &&
        _selectedSources!.contains(_ContentSource.lk21);
  }

  void _handleSearchTextChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentQuery = _searchController?.text.trim() ?? '';
      if (_currentQuery.isEmpty) {
        _selectedGenre = -1;
      }
      _resetPagination(shouldScrollToTop: true);
    });
  }

  Widget _buildError(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 40),
            const SizedBox(height: 16),
            Text(
              'Ups, eksplorasi tidak dapat dimuat',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F6FEB),
              ),
              child: const Text('Coba Muat Ulang'),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlayer(DramaBoxItem item) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DramaPlayerPage(item: item)));
  }

  static const _ignoredGenreTags = <String>{'Anime'};

  List<String> _extractTopTags(List<DramaBoxItem> items, {int limit = 6}) {
    final counts = <String, int>{};
    for (final item in items) {
      for (final rawTag in item.tags) {
        final tag = rawTag.trim();
        if (tag.isEmpty || _ignoredGenreTags.contains(tag)) {
          continue;
        }
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final diff = b.value.compareTo(a.value);
        if (diff != 0) {
          return diff;
        }
        return a.key.compareTo(b.key);
      });
    return sorted.map((entry) => entry.key).take(limit).toList();
  }

  String _formatMeta(DramaBoxItem item, {_ContentSource? source}) {
    final info = <String>[];
    if (source != null) {
      info.add(source.label);
    }
    if (item.primaryTag.isNotEmpty) {
      info.add(item.primaryTag);
    }
    if (item.hotCode != null && item.hotCode!.isNotEmpty) {
      info.add(item.hotCode!);
    } else if (item.chapterCount > 0) {
      info.add('${item.chapterCount} eps');
    }
    return info.isEmpty ? 'Konten pilihan' : info.join(' · ');
  }

  List<_SourcedItem> _applySearch(List<_SourcedItem> items, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return items;
    }
    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return items;
    }
    return items.where((entry) => _matchesQuery(entry.item, tokens)).toList();
  }

  bool _matchesQuery(DramaBoxItem item, List<String> tokens) {
    final buffer = StringBuffer();
    void writeIfNotEmpty(String value) {
      if (value.isEmpty) {
        return;
      }
      buffer.write(value.toLowerCase());
      buffer.write(' ');
    }

    writeIfNotEmpty(item.bookName);
    writeIfNotEmpty(item.description);
    writeIfNotEmpty(item.author);
    writeIfNotEmpty(item.hotCode ?? '');
    if (item.tags.isNotEmpty) {
      writeIfNotEmpty(item.tags.join(' '));
    }

    final haystack = buffer.toString();
    return tokens.every((token) => haystack.contains(token));
  }

  DramaBoxItem? _buildDramaBoxItemFromLk21(MovieResult movie) {
    final slug = movie.slug.trim();
    final title = movie.title.trim();
    if (slug.isEmpty || title.isEmpty) {
      return null;
    }
    final tags = _buildLk21Tags(movie);
    return DramaBoxItem(
      bookId: slug,
      bookName: title,
      coverUrl: movie.poster ?? '',
      introduction: _buildLk21Introduction(movie),
      tags: tags,
      chapterCount: 1,
      hotCode: movie.rating != null && movie.rating!.isNotEmpty
          ? 'Rating ${movie.rating!.trim()}'
          : null,
      origin: ContentOrigin.lk21,
      playback: PlaybackConfig.unavailable(
        bookId: slug,
        origin: ContentOrigin.lk21,
        message: 'Sentuh untuk memuat streaming LK21.',
        webUrl: movie.url,
      ),
    );
  }

  List<String> _buildLk21Tags(MovieResult movie) {
    final tags = <String>[];
    void add(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return;
      }
      tags.add(trimmed);
    }

    add(movie.quality);
    add(movie.year);
    add(movie.duration);
    if (movie.rating != null && movie.rating!.trim().isNotEmpty) {
      tags.add('Rating ${movie.rating!.trim()}');
    }
    if (tags.isEmpty) {
      tags.add('Film LK21');
    }
    return tags;
  }

  String _buildLk21Introduction(MovieResult movie) {
    final parts = <String>[];
    void add(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return;
      }
      parts.add(trimmed);
    }

    add(movie.quality);
    add(movie.year);
    add(movie.duration);
    if (movie.rating != null && movie.rating!.trim().isNotEmpty) {
      parts.add('Rating ${movie.rating!.trim()}');
    }
    return parts.isEmpty ? 'Streaming LK21' : parts.join(' · ');
  }

  Future<_SourceSlice> _createLk21Slice({bool ensureInitial = false}) async {
    try {
      if (ensureInitial) {
        await _lk21CatalogCache.ensureInitialBatch();
      }
      var movies = _lk21CatalogCache.snapshot;
      if (movies.isEmpty) {
        movies = await _lk21Api.fetchMovies();
      }
      return _buildLk21SliceFromMovies(movies);
    } catch (_) {
      return const _SourceSlice(_ContentSource.lk21, []);
    }
  }

  _SourceSlice _buildLk21SliceFromMovies(List<MovieResult> movies) {
    final items = _convertLk21Movies(movies);
    return _SourceSlice(_ContentSource.lk21, items);
  }

  List<DramaBoxItem> _convertLk21Movies(List<MovieResult> movies) {
    return movies
        .map(_buildDramaBoxItemFromLk21)
        .whereType<DramaBoxItem>()
        .toList();
  }

  void _handleLk21CacheUpdated() {
    final movies = _lk21CatalogCache.snapshot;
    if (movies.isEmpty) {
      return;
    }
    final slice = _buildLk21SliceFromMovies(movies);
    if (slice.items.isEmpty) {
      return;
    }
    _applyLk21Slice(slice);
  }

  void _applyLk21Slice(_SourceSlice slice) {
    if (_cachedData == null) {
      _pendingLk21Slice = slice;
      return;
    }
    final updated = _cachedData!.replaceSlice(slice);
    if (!mounted) {
      _pendingLk21Slice = slice;
      return;
    }
    _updateCachedData(updated);
  }

  void _updateCachedData(_ExploreData data) {
    _cachedData = data;
    _cacheTimestamp = DateTime.now();
    _viewStateNotifier.value = _ExploreViewState.ready(data);
  }
}

class _ExploreData {
  const _ExploreData(this.slices);

  final List<_SourceSlice> slices;

  List<_SourcedItem> get allItems {
    return _mergeSourced(slices);
  }

  _ExploreData replaceSlice(_SourceSlice slice) {
    final updated = slices
        .map((existing) => existing.source == slice.source ? slice : existing)
        .toList();
    if (!updated.any((entry) => entry.source == slice.source)) {
      updated.add(slice);
    }
    return _ExploreData(updated);
  }
}

enum _ExploreStatus { loading, ready, error }

class _ExploreViewState {
  const _ExploreViewState._(this.status, this.data, this.message);

  const _ExploreViewState.loading()
      : this._(_ExploreStatus.loading, null, null);
  const _ExploreViewState.ready(_ExploreData data)
      : this._(_ExploreStatus.ready, data, null);
  const _ExploreViewState.error(String message)
      : this._(_ExploreStatus.error, null, message);

  final _ExploreStatus status;
  final _ExploreData? data;
  final String? message;
}

class _SourcedItem {
  const _SourcedItem({required this.item, required this.source});

  final DramaBoxItem item;
  final _ContentSource source;
}

class _SourceSlice {
  const _SourceSlice(this.source, this.items);

  final _ContentSource source;
  final List<DramaBoxItem> items;
}

List<_SourcedItem> _mergeSourced(List<_SourceSlice> slices) {
  final seen = <String>{};
  final result = <_SourcedItem>[];
  for (final slice in slices) {
    for (final item in slice.items) {
      final id = item.bookId;
      if (id.isEmpty) {
        continue;
      }
      final key = '${slice.source.name}::$id';
      if (!seen.add(key)) {
        continue;
      }
      result.add(_SourcedItem(item: item, source: slice.source));
    }
  }
  return result;
}

enum _ContentSource { dramaBox, melolo, lk21 }

extension _ContentSourceStyling on _ContentSource {
  String get label {
    switch (this) {
      case _ContentSource.dramaBox:
        return 'DramaBox';
      case _ContentSource.melolo:
        return 'Melolo';
      case _ContentSource.lk21:
        return 'LK21';
    }
  }

  LinearGradient get gradient {
    switch (this) {
      case _ContentSource.dramaBox:
        return _ExplorePageState._heroGradient;
      case _ContentSource.melolo:
        return _ExplorePageState._meloloGradient;
      case _ContentSource.lk21:
        return _ExplorePageState._lk21Gradient;
    }
  }
}

class _FilterOption {
  const _FilterOption(this.label, this.sources);

  final String label;
  final Set<_ContentSource>? sources;
}

LinearGradient _gradientForSources(Set<_ContentSource>? sources) {
  if (sources == null || sources.isEmpty) {
    return _ExplorePageState._heroGradient;
  }
  if (sources.length == 1) {
    return sources.first.gradient;
  }
  final dracinMembers = {_ContentSource.dramaBox, _ContentSource.melolo};
  final isDracin =
      sources.contains(_ContentSource.dramaBox) &&
      sources.contains(_ContentSource.melolo) &&
      sources.every(dracinMembers.contains);
  if (isDracin) {
    return _ExplorePageState._dracinGradient;
  }
  return _ExplorePageState._heroGradient;
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: const Icon(Icons.movie_creation_outlined, color: Colors.white70),
    );
  }
}


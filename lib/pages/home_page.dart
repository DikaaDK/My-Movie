import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mymovie/models/dramabox_item.dart';
import 'package:mymovie/pages/drama_player_page.dart';
import 'package:mymovie/services/dramabox_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF081225), Color(0xFF0D1F4E), Color(0xFF113873)],
  );

  static const _heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F6FEB), Color(0xFF56CCF2)],
  );

  static const _sections = [
    'Untukmu',
    'Film Populer',
    'Baru Rilis',
    'Top Series',
    'Kategori',
  ];

  final DramaBoxApi _api = const DramaBoxApi();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<DramaBoxItem>> _latestFuture;
  Future<List<DramaBoxItem>>? _searchFuture;
  String _currentQuery = '';

  final PageController _recommendationController = PageController();
  Timer? _recommendationTimer;
  List<DramaBoxItem> _recommendationItems = [];
  int _activeRecommendationIndex = 0;

  @override
  void initState() {
    super.initState();
    _setLatestFuture(_api.fetchLatest());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _recommendationController.dispose();
    _recommendationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: 28),
                _buildRecommendationCarousel(theme),
                const SizedBox(height: 28),
                _buildSearchField(theme),
                const SizedBox(height: 24),
                if (_searchFuture != null) ...[
                  _buildSearchResults(theme),
                ] else ...[
                  _buildSectionSelector(theme),
                  const SizedBox(height: 24),
                  _buildFeaturedSection(theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hai, MyMovie Lovers',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tentukan petualangan sinema malam ini.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: _heroGradient,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F6FEB).withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.person_outline, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildRecommendationCarousel(ThemeData theme) {
    if (_recommendationItems.isEmpty) {
      return _buildRecommendationPlaceholder(theme);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _recommendationController,
            itemCount: _recommendationItems.length,
            onPageChanged: _handleRecommendationPageChanged,
            itemBuilder: (context, index) {
              final item = _recommendationItems[index];
              return _RecommendationCard(
                item: item,
                onTap: () => _openPlayer(item),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_recommendationItems.length, (index) {
            final isActive = index == _activeRecommendationIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 22 : 10,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRecommendationPlaceholder(ThemeData theme) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 12),
          Text(
            'Menyiapkan rekomendasi terbaik untukmu…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    final hasText = _searchController.text.isNotEmpty;
    return TextField(
      controller: _searchController,
      onSubmitted: _performSearch,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        hintText: 'Cari judul, aktor, atau genre',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.6),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Colors.white.withValues(alpha: 0.75),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasText)
              IconButton(
                icon: const Icon(Icons.clear_rounded),
                color: Colors.white70,
                tooltip: 'Bersihkan',
                onPressed: _clearSearch,
              ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded),
              color: Colors.white,
              tooltip: 'Cari',
              onPressed: () => _performSearch(_searchController.text),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
        ),
      ),
    );
  }

  Widget _buildSectionSelector(ThemeData theme) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final label = _sections[index];
          final isActive = index == 0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isActive
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.16),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: isActive ? 0.95 : 0.7),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemCount: _sections.length,
      ),
    );
  }

  Widget _buildFeaturedSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilihan teratas untukmu',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.86),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: FutureBuilder<List<DramaBoxItem>>(
            future: _latestFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingList();
              }
              if (snapshot.hasError) {
                final message =
                    snapshot.error?.toString() ?? 'Terjadi kesalahan';
                return _buildErrorState(theme, message);
              }
              final items = snapshot.data ?? <DramaBoxItem>[];
              if (items.isEmpty) {
                return _buildEmptyState(theme);
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 18),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _FeaturedCard(
                    item: item,
                    onTap: () => _openPlayer(item),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildLoadingList() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(width: 18),
      itemBuilder: (context, index) {
        return Container(
          width: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
            'Gagal memuat rekomendasi',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _reloadLatest, child: const Text('Coba lagi')),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_empty_rounded, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
            'Belum ada rekomendasi',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Coba refresh untuk memuat koleksi terbaru.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _reloadLatest, child: const Text('Muat ulang')),
        ],
      ),
    );
  }

  void _reloadLatest() {
    _setLatestFuture(_api.fetchLatest());
  }

  void _setLatestFuture(Future<List<DramaBoxItem>> future) {
    _recommendationTimer?.cancel();
    setState(() {
      _latestFuture = future;
    });
    future.then((items) {
      if (!mounted) {
        return;
      }
      _updateRecommendations(items);
    });
  }

  void _updateRecommendations(List<DramaBoxItem> items) {
    _recommendationTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _recommendationItems = items;
      _activeRecommendationIndex = 0;
    });
    _startRecommendationAutoScroll(items.length);
  }

  void _startRecommendationAutoScroll(int itemCount) {
    if (itemCount <= 1) {
      return;
    }
    _recommendationTimer?.cancel();
    _recommendationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_recommendationController.hasClients) {
        return;
      }
      final nextPage = (_activeRecommendationIndex + 1) % itemCount;
      _recommendationController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _handleRecommendationPageChanged(int index) {
    setState(() {
      _activeRecommendationIndex = index;
    });
  }

  Widget _buildSearchResults(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Hasil pencarian "$_currentQuery"',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(onPressed: _clearSearch, child: const Text('Tutup')),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<DramaBoxItem>>(
          future: _searchFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              final message =
                  snapshot.error?.toString() ?? 'Pencarian gagal dilakukan';
              return _buildSearchErrorState(theme, message);
            }
            final items = snapshot.data ?? <DramaBoxItem>[];
            if (items.isEmpty) {
              return _buildEmptySearchState(theme);
            }
            return ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _SearchResultTile(
                  item: item,
                  onTap: () => _openPlayer(item),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptySearchState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
            'Tidak ada hasil untuk "$_currentQuery"',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Coba kata kunci lain atau periksa ejaan kamu.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _clearSearch, child: const Text('Kembali')),
        ],
      ),
    );
  }

  Widget _buildSearchErrorState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
            'Terjadi kesalahan saat mencari',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _performSearch(_currentQuery),
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  void _performSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _clearSearch();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _currentQuery = trimmed;
      _searchFuture = _api.search(trimmed, limit: 25);
    });
  }

  void _clearSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.clear();
      _searchFuture = null;
      _currentQuery = '';
    });
  }

  Future<void> _openPlayer(DramaBoxItem item) async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DramaPlayerPage(item: item)),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item, required this.onTap});

  final DramaBoxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[];
    if (item.primaryTag.isNotEmpty) {
      subtitleParts.add(item.primaryTag);
    }
    if (item.secondaryTag.isNotEmpty) {
      subtitleParts.add(item.secondaryTag);
    }
    if (item.chapterCount > 0) {
      subtitleParts.add('${item.chapterCount} eps');
    }
    final subtitle = subtitleParts.join(' · ');
    final badgeText = (item.hotCode?.isNotEmpty ?? false)
        ? item.hotCode!
        : 'Baru';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.coverUrl.isEmpty)
                        Container(
                          color: Colors.white.withValues(alpha: 0.06),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.movie_filter_outlined,
                            color: Colors.white70,
                            size: 40,
                          ),
                        )
                      else
                        Image.network(
                          item.coverUrl,
                          fit: BoxFit.cover,
                          color: const Color(0xFF081225).withValues(alpha: 0.1),
                          colorBlendMode: BlendMode.multiply,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.white.withValues(alpha: 0.06),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 36,
                              ),
                            );
                          },
                        ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: Color(0xFFFFD166),
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                badgeText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.bookName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle.isEmpty ? 'DramaBox Original' : subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.item, required this.onTap});

  final DramaBoxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeLabel = (item.hotCode?.isNotEmpty ?? false) ? item.hotCode! : 'Baru';
    final details = <String>[];
    if (item.primaryTag.isNotEmpty) {
      details.add(item.primaryTag);
    }
    if (item.secondaryTag.isNotEmpty) {
      details.add(item.secondaryTag);
    }
    if (item.chapterCount > 0) {
      details.add('${item.chapterCount} eps');
    }
    final subtitle = details.join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: item.coverUrl.isEmpty
                        ? Container(color: Colors.black.withValues(alpha: 0.4))
                        : Image.network(item.coverUrl, fit: BoxFit.cover),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xAA040A15), Color(0xB30D2149), Color(0xDD0F2B67)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFD166), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                badgeLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.bookName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          item.description.isEmpty ? 'Cerita menarik menunggu kamu.' : item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                            height: 1.3,
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
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item, required this.onTap});

  final DramaBoxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = item.tags.isEmpty ? 'Drama' : item.tags.take(3).join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: item.coverUrl.isEmpty
                    ? Container(
                        width: 80,
                        height: 110,
                        color: Colors.white.withValues(alpha: 0.06),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.movie_creation_outlined,
                          color: Colors.white70,
                        ),
                      )
                    : Image.network(
                        item.coverUrl,
                        width: 80,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 110,
                            color: Colors.white.withValues(alpha: 0.06),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white70,
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.bookName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.author.isEmpty ? tags : '${item.author} · $tags',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.description.isEmpty
                          ? 'Belum ada deskripsi untuk drama ini.'
                          : item.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

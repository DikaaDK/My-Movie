import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/content_origin.dart';
import '../models/dramabox_episode.dart';
import '../models/dramabox_item.dart';
import '../navigation_observer.dart';
import '../pages/drama_player_page.dart';
import '../services/dramabox_api.dart';

class CuplikanPage extends StatefulWidget {
  const CuplikanPage({
    super.key,
    this.currentIndexListenable,
  });

  final ValueListenable<int>? currentIndexListenable;

  @override
  State<CuplikanPage> createState() => _CuplikanPageState();
}

class _CuplikanPageState extends State<CuplikanPage> with RouteAware {
  static const _infoGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.center,
    colors: [Color(0xCC000000), Colors.transparent],
  );

  final DramaBoxApi _dramaApi = const DramaBoxApi();
  final PageController _pageController = PageController();
  final List<_ClipEntry> _clips = <_ClipEntry>[];

  bool _isLoading = true;
  String? _error;
  int _activeIndex = 0;
  bool _isRefreshingClips = false;
  VoidCallback? _currentIndexListener;
  bool _isTabActive = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentIndexListenable != null) {
      _currentIndexListener = _handleTabChange;
      widget.currentIndexListenable!.addListener(_currentIndexListener!);
    }
    _handleTabChange();
    _loadClips();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    if (_currentIndexListener != null) {
      widget.currentIndexListenable?.removeListener(_currentIndexListener!);
    }
    unawaited(_disposeAllClips());
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadClips({bool showLoading = true}) async {
    await _disposeAllClips();
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      _error = null;
    }

    try {
      final responses = await Future.wait<List<DramaBoxItem>>([
        _dramaApi.fetchTrending(),
        _dramaApi.fetchLatest(),
      ]);
      final combined = responses.expand((entry) => entry).toList();

      final seen = <String>{};
      final clips = <_ClipEntry>[];
      for (final item in combined) {
        if (clips.length >= 16) {
          break;
        }
        if (item.bookId.isEmpty || seen.contains(item.bookId)) {
          continue;
        }
        final clip = await _buildClipEntry(item);
        if (clip == null) {
          continue;
        }
        seen.add(item.bookId);
        clips.add(clip);
      }

      if (clips.isEmpty) {
        throw Exception(
          'Cuplikan tidak memiliki referensi episode valid untuk diputar.',
        );
      }

      _clips
        ..clear()
        ..addAll(clips);

      setState(() {
        _isLoading = false;
        _error = null;
        _activeIndex = 0;
      });

      if (_clips.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
          if (_isTabActive) {
            _activateClip(0);
          }
        });
      }
    } catch (e) {
      _clips.clear();
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _disposeAllClips() async {
    for (final clip in _clips) {
      await clip.dispose();
    }
    _clips.clear();
  }

  Future<_ClipEntry?> _buildClipEntry(DramaBoxItem item) async {
    if (item.bookId.isEmpty) {
      return null;
    }
    try {
      final referenceEpisode = await _tryFetchReferenceEpisode(item);
      if (referenceEpisode == null) {
        return null;
      }
      final preferredUrl = referenceEpisode.directStreamUrl;
      final stream = referenceEpisode.defaultStream;
      final streamUrl = (preferredUrl != null && preferredUrl.isNotEmpty)
          ? preferredUrl
          : stream?.url;
      if (streamUrl == null || streamUrl.isEmpty) {
        return null;
      }
      final clip = _ClipEntry(item)
        ..streamUrl = streamUrl
        ..episodeTitle = referenceEpisode.chapterName
        ..episodeIndex = referenceEpisode.chapterIndex;
      return clip;
    } catch (_) {
      return null;
    }
  }

  Future<DramaEpisode?> _tryFetchReferenceEpisode(DramaBoxItem item) async {
    if (item.origin != ContentOrigin.dramaBox) {
      return null;
    }
    try {
      return await _dramaApi.fetchFirstEpisode(item.bookId);
    } catch (_) {
      return null;
    }
  }

  void _handlePageChanged(int index) {
    setState(() {
      _activeIndex = index;
    });
    _activateClip(index);
    _maybeRefreshClips(index);
  }

  void _maybeRefreshClips(int index) {
    if (_isRefreshingClips) {
      return;
    }
    if (_clips.length < 16) {
      return;
    }
    if (index < _clips.length - 1) {
      return;
    }
    _isRefreshingClips = true;
    _loadClips(showLoading: false).whenComplete(() {
      _isRefreshingClips = false;
    });
  }

  Future<void> _activateClip(int index) async {
    if (index < 0 || index >= _clips.length) {
      return;
    }

    for (var i = 0; i < _clips.length; i++) {
      if (i == index) {
        continue;
      }
      final otherController = _clips[i].controller;
      if (otherController != null && otherController.value.isPlaying) {
        await otherController.pause();
      }
    }

    final clip = _clips[index];
    final streamUrl = clip.streamUrl;
    if (streamUrl == null || streamUrl.isEmpty) {
      setState(() {
        clip
          ..isLoading = false
          ..error = 'Stream tidak tersedia untuk cuplikan ini.';
      });
      return;
    }

    final existing = clip.controller;
    if (existing != null && existing.value.isInitialized) {
      await existing.play();
      setState(() {});
      return;
    }
    if (clip.isLoading) {
      return;
    }

    setState(() {
      clip
        ..isLoading = true
        ..error = null;
    });

    final controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
    try {
      await controller.initialize();
      controller
        ..setLooping(true)
        ..setVolume(1.0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        clip
          ..controller = controller
          ..isLoading = false
          ..error = null;
      });
    } catch (e) {
      await controller.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        clip
          ..isLoading = false
          ..error = 'Gagal memutar cuplikan: $e';
      });
    }
  }

  void _toggleClip(int index) {
    if (index < 0 || index >= _clips.length) {
      return;
    }
    final controller = _clips[index].controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  Future<void> _reloadClip(int index) async {
    if (index < 0 || index >= _clips.length) {
      return;
    }
    final clip = _clips[index];
    await clip.dispose();
    setState(() {
      clip
        ..error = null
        ..isLoading = true
        ..streamUrl = null
        ..controller = null;
    });
    try {
      final episode = await _tryFetchReferenceEpisode(clip.item);
      if (!mounted) {
        return;
      }
      if (episode == null) {
        setState(() {
          clip
            ..isLoading = false
            ..error = 'Episode referensi tidak ditemukan.';
        });
        return;
      }
      final stream = episode.defaultStream;
      final streamUrl =
          (episode.directStreamUrl != null &&
              episode.directStreamUrl!.isNotEmpty)
          ? episode.directStreamUrl
          : stream?.url;
      if (streamUrl == null || streamUrl.isEmpty) {
        setState(() {
          clip
            ..isLoading = false
            ..error = 'Stream tidak tersedia untuk cuplikan ini.';
        });
        return;
      }
      setState(() {
        clip
          ..streamUrl = streamUrl
          ..episodeTitle = episode.chapterName
          ..episodeIndex = episode.chapterIndex
          ..isLoading = false
          ..error = null;
      });
      await _activateClip(index);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        clip
          ..isLoading = false
          ..error = e.toString();
      });
    }
  }

  void _openPlayer(DramaBoxItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DramaPlayerPage(item: item)),
    );
  }

  @override
  void didPushNext() {
    _pauseAllClips();
  }

  @override
  void didPopNext() {
    if (!mounted) {
      return;
    }
    _activateClip(_activeIndex);
  }

  void _pauseAllClips() {
    for (final clip in _clips) {
      final controller = clip.controller;
      if (controller != null && controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  void _handleTabChange() {
    final listenable = widget.currentIndexListenable;
    if (listenable == null) {
      return;
    }
    final isActive = listenable.value == 2;
    _isTabActive = isActive;
    if (!isActive) {
      _pauseAllClips();
      return;
    }
    if (mounted) {
      _activateClip(_activeIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white70,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Gagal memuat cuplikan',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loadClips,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_clips.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.slideshow_rounded,
                  color: Colors.white70,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Cuplikan tidak tersedia saat ini.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tarik untuk menyegarkan halaman dan coba lagi nanti.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loadClips,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _clips.length,
        onPageChanged: _handlePageChanged,
        itemBuilder: (context, index) {
          final clip = _clips[index];
          return _CuplikanClipView(
            clip: clip,
            index: index,
            totalCount: _clips.length,
            gradient: _infoGradient,
            isActive: index == _activeIndex,
            onRetry: () => _reloadClip(index),
            onOpenDetail: () => _openPlayer(clip.item),
              onTogglePlay: () => _toggleClip(index),
          );
        },
      ),
    );
  }
}

class _CuplikanClipView extends StatelessWidget {
  const _CuplikanClipView({
    required this.clip,
    required this.index,
    required this.totalCount,
    required this.gradient,
    required this.isActive,
    required this.onRetry,
    required this.onOpenDetail,
    required this.onTogglePlay,
  });

  final _ClipEntry clip;
  final int index;
  final int totalCount;
  final LinearGradient gradient;
  final bool isActive;
  final VoidCallback onRetry;
  final VoidCallback onOpenDetail;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = clip.controller;
    final isInitialized = controller?.value.isInitialized ?? false;
    final showVideo =
        isActive && controller != null && isInitialized && clip.error == null;
    final hasStream = clip.streamUrl?.isNotEmpty ?? false;
    final canOpenDetail = hasStream && clip.error == null && !clip.isLoading;

    final Widget background = showVideo
        ? FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          )
        : _CoverImage(url: clip.item.coverUrl);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: background),
        Container(decoration: BoxDecoration(gradient: gradient)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Cuplikan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        '${index + 1}/$totalCount',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (clip.error != null)
                  _ClipError(message: clip.error!, onRetry: onRetry)
                else
                  _ClipInfo(
                    item: clip.item,
                    isActive: isActive,
                    onOpenDetail: onOpenDetail,
                    onTogglePlay: onTogglePlay,
                    isLoading: clip.isLoading,
                    canOpenDetail: canOpenDetail,
                    isPlaying: clip.controller?.value.isPlaying ?? false,
                    hasPlayer: clip.controller != null,
                    episodeTitle: clip.episodeTitle,
                    episodeIndex: clip.episodeIndex,
                  ),
              ],
            ),
          ),
        ),
        if (clip.isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ClipInfo extends StatelessWidget {
  const _ClipInfo({
    required this.item,
    required this.isActive,
    required this.onOpenDetail,
    required this.onTogglePlay,
    required this.isLoading,
    required this.canOpenDetail,
    this.episodeTitle,
    this.episodeIndex,
    this.isPlaying = false,
    this.hasPlayer = false,
  });

  final DramaBoxItem item;
  final bool isActive;
  final VoidCallback onOpenDetail;
  final VoidCallback onTogglePlay;
  final bool isLoading;
  final bool canOpenDetail;
  final String? episodeTitle;
  final int? episodeIndex;
  final bool isPlaying;
  final bool hasPlayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = item.introduction.isEmpty
        ? 'Cuplikan spesial untukmu.'
        : item.introduction;
    final episodeLabel =
        episodeTitle ??
        (episodeIndex != null ? 'Episode ${episodeIndex! + 1}' : null);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: isActive ? 1 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.tags.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                item.tags.take(2).join(' · '),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          if (episodeLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              episodeLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (hasPlayer)
                IconButton(
                  onPressed: onTogglePlay,
                  icon: Icon(
                    isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              FilledButton.icon(
                onPressed: canOpenDetail ? onOpenDetail : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  isLoading
                      ? 'Memuat...'
                      : canOpenDetail
                          ? 'Tonton'
                          : 'Tidak tersedia',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClipError extends StatelessWidget {
  const _ClipError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Gagal memutar cuplikan',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(
          Icons.slideshow_rounded,
          color: Colors.white38,
          size: 64,
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: Colors.white38,
          size: 64,
        ),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        );
      },
    );
  }
}

class _ClipEntry {
  _ClipEntry(this.item);

  final DramaBoxItem item;
  String? streamUrl;
  String? episodeTitle;
  int? episodeIndex;
  VideoPlayerController? controller;
  bool isLoading = false;
  String? error;

  Future<void> dispose() async {
    final player = controller;
    controller = null;
    if (player != null) {
      await player.dispose();
    }
  }
}

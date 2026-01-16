import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/content_origin.dart';
import '../models/dramabox_episode.dart';
import '../models/dramabox_item.dart';
import '../models/playback_config.dart';
import '../services/dramabox_api.dart';
import '../services/melolo_api.dart';

class DramaPlayerPage extends StatefulWidget {
  const DramaPlayerPage({super.key, required this.item});

  final DramaBoxItem item;

  @override
  State<DramaPlayerPage> createState() => _DramaPlayerPageState();
}

class _DramaPlayerPageState extends State<DramaPlayerPage> {
  static const _backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF050B1D), Color(0xFF0A1C3F), Color(0xFF123B6C)],
  );

  final DramaBoxApi _dramaApi = const DramaBoxApi();
  final MeloloApi _meloloApi = const MeloloApi();

  Future<List<DramaEpisode>>? _episodesFuture;
  VideoPlayerController? _videoController;
  WebViewController? _embedController;

  bool _isLoadingPlayer = true;
  String? _playerError;
  int _currentEpisodeIndex = 0;
  bool _hasScheduledInitialEpisode = false;
  bool _isLandscapePlayer = false;
  String? _activeEmbedUrl;
  String? _fallbackLink;
  bool _hasTriggeredEmbedFallback = false;

  static const _embedUserAgent =
      'Mozilla/5.0 (Linux; Android 13; MyMovie) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 MyMovie/1.0';

  bool get _hasEpisodes => widget.item.origin == ContentOrigin.dramaBox;

  @override
  void initState() {
    super.initState();
    if (_hasEpisodes) {
      _episodesFuture = _dramaApi.fetchEpisodes(widget.item.bookId);
    } else {
      _loadPlaybackForItem(widget.item);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.item.bookName),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: _backgroundGradient),
        child: SafeArea(
          child: _hasEpisodes
              ? _buildEpisodesBody(context)
              : _buildSingleBody(context),
        ),
      ),
    );
  }

  Widget _buildEpisodesBody(BuildContext context) {
    final theme = Theme.of(context);
    final future = _episodesFuture;
    if (future == null) {
      return _buildLoadError(theme, 'Episode tidak tersedia untuk konten ini.');
    }
    return FutureBuilder<List<DramaEpisode>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildLoadError(
            theme,
            snapshot.error?.toString() ?? 'Gagal memuat episode.',
            retry: () {
              setState(() {
                _episodesFuture = _dramaApi.fetchEpisodes(widget.item.bookId);
                _hasScheduledInitialEpisode = false;
              });
            },
          );
        }
        final episodes = snapshot.data ?? <DramaEpisode>[];
        if (episodes.isEmpty) {
          return _buildLoadError(
            theme,
            'Episode tidak tersedia untuk konten ini.',
          );
        }
        if (!_hasScheduledInitialEpisode) {
          _hasScheduledInitialEpisode = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            _loadEpisodePlayback(episodes[_currentEpisodeIndex]);
          });
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVideoPlayerArea(
                theme,
                onRetry: _playerError != null ? _retryCurrentEpisode : null,
              ),
              if (_fallbackLink != null && _playerError != null) ...[
                const SizedBox(height: 12),
                _buildFallbackLink(theme),
              ],
              const SizedBox(height: 18),
              Text(
                episodes[_currentEpisodeIndex].chapterName,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.item.introduction,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Episode Lainnya',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: episodes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final episode = episodes[index];
                  final isActive = index == _currentEpisodeIndex;
                  return _EpisodeTile(
                    episode: episode,
                    isActive: isActive,
                    onTap: () => _loadEpisodePlayback(episode, index: index),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSingleBody(BuildContext context) {
    final theme = Theme.of(context);
    final description = widget.item.introduction.isNotEmpty
        ? widget.item.introduction
        : 'Video ini belum memiliki deskripsi.';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVideoPlayerArea(
            theme,
            onRetry: _playerError != null
                ? () => _loadPlaybackForItem(widget.item)
                : null,
          ),
          if (_fallbackLink != null && _playerError != null) ...[
            const SizedBox(height: 12),
            _buildFallbackLink(theme),
          ],
          const SizedBox(height: 18),
          Text(
            widget.item.bookName,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerArea(ThemeData theme, {VoidCallback? onRetry}) {
    final controller = _videoController;
    final isInitialized = controller?.value.isInitialized ?? false;
    final isPlaying = controller?.value.isPlaying ?? false;

    Widget child;
    if (_playerError != null) {
      child = _buildPlayerErrorWidget(theme, _playerError!, onRetry: onRetry);
    } else if (_isLoadingPlayer) {
      child = const Center(child: CircularProgressIndicator());
    } else if (_activeEmbedUrl != null && _embedController != null) {
      child = WebViewWidget(controller: _embedController!);
    } else if (controller != null && isInitialized) {
      child = Stack(
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'play_pause',
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                  onPressed: () {
                    final video = _videoController;
                    if (video == null) {
                      return;
                    }
                    setState(() {
                      if (video.value.isPlaying) {
                        video.pause();
                      } else {
                        video.play();
                      }
                    });
                  },
                  child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: 10),
                _buildOrientationToggle(),
              ],
            ),
          ),
        ],
      );
    } else {
      child = const Center(child: CircularProgressIndicator());
    }

    final aspectRatio = _isLandscapePlayer ? 16 / 9 : 9 / 16;
    final cornerRadius = _isLandscapePlayer ? 14.0 : 18.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: _isLandscapePlayer ? 14 : 20,
            offset: Offset(0, _isLandscapePlayer ? 8 : 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: AspectRatio(aspectRatio: aspectRatio, child: child),
      ),
    );
  }

  Widget _buildOrientationToggle() {
    final isLandscape = _isLandscapePlayer;
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _togglePlayerOrientation,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            isLandscape ? Icons.portrait : Icons.landscape,
            color: Colors.white70,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _togglePlayerOrientation() {
    setState(() {
      _isLandscapePlayer = !_isLandscapePlayer;
    });
  }

  Widget _buildPlayerErrorWidget(
    ThemeData theme,
    String message, {
    VoidCallback? onRetry,
  }) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 32),
          const SizedBox(height: 8),
          Text(
            'Gagal memutar video',
            style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackLink(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_fallbackLink != null)
            SelectableText(
              _fallbackLink!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openFallbackLink({bool initiatedByUser = true}) async {
    final link = _fallbackLink;
    if (link == null) {
      return;
    }
    await _loadEmbedFromUrl(
      link,
      fallbackLink: link,
      resetFallbackTrigger: initiatedByUser,
    );
  }

  Widget _buildLoadError(
    ThemeData theme,
    String message, {
    VoidCallback? retry,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
            'Ups, ada masalah',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          if (retry != null) ...[
            const SizedBox(height: 18),
            TextButton(onPressed: retry, child: const Text('Muat ulang')),
          ],
        ],
      ),
    );
  }

  Future<void> _loadPlaybackForItem(DramaBoxItem item) async {
    setState(() {
      _isLoadingPlayer = true;
      _playerError = null;
      _activeEmbedUrl = null;
      _fallbackLink = null;
      _embedController = null;
    });
    final config = item.playback;
    await _resolvePlaybackConfig(config, item: item);
  }

  Future<void> _loadEpisodePlayback(DramaEpisode episode, {int? index}) async {
    setState(() {
      _playerError = null;
      if (index != null) {
        _currentEpisodeIndex = index;
      }
    });
    final directUrl = episode.directStreamUrl;
    final stream = episode.defaultStream;
    final targetUrl = (directUrl != null && directUrl.isNotEmpty)
        ? directUrl
        : stream?.url;
    if (!mounted) {
      return;
    }
    if (targetUrl == null || targetUrl.isEmpty) {
      setState(() {
        _isLoadingPlayer = false;
        _playerError = 'Stream untuk episode ini tidak tersedia.';
        _fallbackLink = null;
        _activeEmbedUrl = null;
        _embedController = null;
      });
      return;
    }
    await _playStream(targetUrl);
  }

  Future<void> _resolvePlaybackConfig(
    PlaybackConfig config, {
    required DramaBoxItem item,
  }) async {
    switch (config.kind) {
      case PlaybackKind.dramaboxEpisode:
        try {
          final targetBookId = config.bookId ?? item.bookId;
          final episode = await _dramaApi.fetchFirstEpisode(targetBookId);
          if (!mounted) {
            return;
          }
          if (episode == null) {
            setState(() {
              _isLoadingPlayer = false;
              _playerError = 'Episode belum tersedia untuk konten ini.';
            });
            return;
          }
          final directUrl = episode.directStreamUrl;
          final stream = episode.defaultStream;
          final targetUrl = (directUrl != null && directUrl.isNotEmpty)
              ? directUrl
              : stream?.url;
          if (targetUrl == null || targetUrl.isEmpty) {
            setState(() {
              _isLoadingPlayer = false;
              _playerError = 'Stream tidak ditemukan untuk episode awal.';
            });
            return;
          }
          await _playStream(targetUrl);
        } catch (e) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isLoadingPlayer = false;
            _playerError = e.toString();
          });
        }
        break;
      case PlaybackKind.directStream:
        final url = config.streamUrl;
        if (url == null || url.isEmpty) {
          setState(() {
            _isLoadingPlayer = false;
            _playerError = 'Stream langsung tidak tersedia.';
          });
          return;
        }
        final played = await _playStream(url, fallbackLink: config.webUrl);
        if (played) {
          return;
        }
        if (config.webUrl != null && config.webUrl!.isNotEmpty) {
          await _loadEmbedFromUrl(config.webUrl!, fallbackLink: config.webUrl);
          return;
        }
        break;
      case PlaybackKind.webEmbed:
        final embedUrl = config.embedUrl;
        if (embedUrl == null || embedUrl.isEmpty) {
          setState(() {
            _isLoadingPlayer = false;
            _playerError = 'Embed player tidak tersedia.';
          });
          return;
        }
        await _loadEmbedFromUrl(
          embedUrl,
          fallbackLink: config.webUrl ?? embedUrl,
        );
        break;
      case PlaybackKind.unavailable:
        final origin = config.origin ?? item.origin;
        if (origin == ContentOrigin.melolo) {
          try {
            final bookId = config.bookId ?? item.bookId;
            final streamUrl = await _meloloApi.fetchStreamUrl(bookId);
            if (!mounted) {
              return;
            }
            if (streamUrl == null || streamUrl.isEmpty) {
              setState(() {
                _isLoadingPlayer = false;
                _playerError = 'Stream Melolo tidak ditemukan.';
                _activeEmbedUrl = null;
                _embedController = null;
                _fallbackLink = null;
              });
              return;
            }
            await _playStream(streamUrl);
            return;
          } catch (e) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoadingPlayer = false;
              _playerError = e.toString();
              _activeEmbedUrl = null;
              _embedController = null;
              _fallbackLink = null;
            });
            return;
          }
        }
        setState(() {
          _isLoadingPlayer = false;
          _playerError =
              config.message ?? 'Streaming belum tersedia untuk konten ini.';
          _activeEmbedUrl = null;
          _embedController = null;
          _fallbackLink = null;
        });
        break;
    }
  }

  Future<void> _retryCurrentEpisode() async {
    final episodes = await (_episodesFuture ?? Future.value(<DramaEpisode>[]));
    if (!mounted || episodes.isEmpty) {
      setState(() {
        _playerError = 'Episode tidak tersedia.';
        _isLoadingPlayer = false;
        _activeEmbedUrl = null;
        _fallbackLink = null;
        _embedController = null;
      });
      return;
    }
    await _loadEpisodePlayback(episodes[_currentEpisodeIndex]);
  }

  Future<bool> _playStream(String url, {String? fallbackLink}) async {
    setState(() {
      _isLoadingPlayer = true;
      _playerError = null;
      _fallbackLink = fallbackLink;
      _activeEmbedUrl = null;
      _embedController = null;
    });

    await _disposeVideoController();

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      controller
        ..setLooping(false)
        ..setVolume(1.0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return false;
      }
      setState(() {
        _videoController = controller;
        _isLoadingPlayer = false;
        _playerError = null;
      });
      return true;
    } catch (e) {
      await controller.dispose();
      if (!mounted) {
        return false;
      }
      setState(() {
        _isLoadingPlayer = false;
        _playerError = 'Gagal memutar stream: $e';
        _fallbackLink = fallbackLink;
      });
      return false;
    }
  }

  Future<void> _disposeVideoController() async {
    final controller = _videoController;
    if (controller != null) {
      _videoController = null;
      await controller.dispose();
    }
  }

  Future<void> _loadEmbedFromUrl(
    String embedUrl, {
    String? fallbackLink,
    bool resetFallbackTrigger = true,
  }) async {
    await _disposeVideoController();
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingPlayer = true;
      _playerError = null;
      _activeEmbedUrl = embedUrl;
      _embedController = null;
      _fallbackLink = fallbackLink ?? embedUrl;
      if (resetFallbackTrigger) {
        _hasTriggeredEmbedFallback = false;
      }
    });

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoadingPlayer = true;
              _playerError = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoadingPlayer = false;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoadingPlayer = false;
              _playerError =
                  'Embed gagal dimuat (${error.errorCode}): ${error.description}';
              _embedController = null;
            });
            if (!_hasTriggeredEmbedFallback && _fallbackLink != null) {
              _hasTriggeredEmbedFallback = true;
              _openFallbackLink(initiatedByUser: false);
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse(embedUrl),
        headers: const {'User-Agent': _embedUserAgent},
      );
    if (!mounted) {
      return;
    }
    setState(() {
      _embedController = controller;
    });
  }

}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.isActive,
    required this.onTap,
  });

  final DramaEpisode episode;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isActive
        ? const LinearGradient(
            colors: [Color(0xFF1F6FEB), Color(0xFF56CCF2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;
    final borderColor = isActive
        ? Colors.white.withValues(alpha: 0.0)
        : Colors.white.withValues(alpha: 0.12);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: background,
          color: background == null
              ? Colors.white.withValues(alpha: 0.06)
              : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF1F6FEB).withValues(alpha: 0.3),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: isActive ? 0.28 : 0.1),
              ),
              alignment: Alignment.center,
              child: Icon(
                isActive ? Icons.play_arrow : Icons.play_circle_outline,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.chapterName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Episode ${episode.chapterIndex + 1}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}


import 'content_origin.dart';

enum PlaybackKind {
  dramaboxEpisode,
  directStream,
  webEmbed,
  unavailable,
}

class PlaybackConfig {
  const PlaybackConfig._({
    required this.kind,
    this.bookId,
    this.streamUrl,
    this.embedUrl,
    this.webUrl,
    this.message,
    this.origin,
  });

  const PlaybackConfig.dramabox({
    required String bookId,
    ContentOrigin origin = ContentOrigin.dramaBox,
  }) : this._(
          kind: PlaybackKind.dramaboxEpisode,
          bookId: bookId,
          origin: origin,
        );

  const PlaybackConfig.directStream({
    required String streamUrl,
    ContentOrigin? origin,
  }) : this._(
          kind: PlaybackKind.directStream,
          streamUrl: streamUrl,
          origin: origin,
        );

  const PlaybackConfig.webEmbed({
    required String embedUrl,
    String? webUrl,
    ContentOrigin? origin,
  }) : this._(
          kind: PlaybackKind.webEmbed,
          embedUrl: embedUrl,
          webUrl: webUrl,
          origin: origin,
        );

  const PlaybackConfig.unavailable({
    String? bookId,
    String? message,
    ContentOrigin? origin,
  }) : this._(
          kind: PlaybackKind.unavailable,
          message: message,
          bookId: bookId,
          origin: origin,
        );

  final PlaybackKind kind;
  final String? bookId;
  final String? streamUrl;
  final String? embedUrl;
  final String? webUrl;
  final String? message;
  final ContentOrigin? origin;

  bool get isPlayable =>
      kind == PlaybackKind.dramaboxEpisode ||
      kind == PlaybackKind.directStream ||
      kind == PlaybackKind.webEmbed;
}

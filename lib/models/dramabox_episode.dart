class DramaStream {
  const DramaStream({
    required this.quality,
    required this.url,
    required this.isDefault,
  });

  final int quality;
  final String url;
  final bool isDefault;
}

class DramaEpisode {
  const DramaEpisode({
    required this.chapterId,
    required this.chapterIndex,
    required this.chapterName,
    required this.streams,
    this.directStreamUrl,
  });

  final String chapterId;
  final int chapterIndex;
  final String chapterName;
  final List<DramaStream> streams;
  final String? directStreamUrl;

  DramaStream? get defaultStream {
    if (streams.isEmpty) {
      return null;
    }
    final preferred = streams.where((stream) => stream.isDefault).toList();
    if (preferred.isNotEmpty) {
      preferred.sort((a, b) => b.quality.compareTo(a.quality));
      return preferred.first;
    }
    streams.sort((a, b) => b.quality.compareTo(a.quality));
    return streams.first;
  }
}

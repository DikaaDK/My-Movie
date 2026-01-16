import 'content_origin.dart';
import 'playback_config.dart';

class DramaBoxItem {
  DramaBoxItem({
    required this.bookId,
    required this.bookName,
    required this.coverUrl,
    required this.introduction,
    required this.tags,
    required this.chapterCount,
    this.author = '',
    this.protagonist,
    this.hotCode,
    this.shelfTime,
    this.origin = ContentOrigin.dramaBox,
    PlaybackConfig? playback,
  }) : playback =
            playback ??
            PlaybackConfig.dramabox(bookId: bookId, origin: origin);

  final String bookId;
  final String bookName;
  final String coverUrl;
  final String introduction;
  final List<String> tags;
  final int chapterCount;
  final String author;
  final String? protagonist;
  final String? hotCode;
  final String? shelfTime;
  final ContentOrigin origin;
  final PlaybackConfig playback;

  factory DramaBoxItem.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] ?? json['tagNames'];
    final cover = json['coverWap'] ?? json['cover'];
    final rawAuthor = _asTrimmedString(json['author']);
    final rawProtagonist = _asTrimmedString(json['protagonist']);
    final computedAuthor = (rawAuthor != null && rawAuthor.isNotEmpty)
        ? rawAuthor
        : ((rawProtagonist != null && rawProtagonist.isNotEmpty)
              ? rawProtagonist.split(',').first.trim()
              : '');
    return DramaBoxItem(
      bookId: json['bookId']?.toString() ?? '',
      bookName: json['bookName']?.toString() ?? 'Tanpa Judul',
      coverUrl: cover?.toString() ?? '',
      introduction: json['introduction']?.toString() ?? '',
      tags: rawTags is List
          ? rawTags.map((tag) => tag.toString()).toList()
          : const <String>[],
      chapterCount: json['chapterCount'] is int
          ? json['chapterCount'] as int
          : int.tryParse(json['chapterCount']?.toString() ?? '') ?? 0,
      author: computedAuthor,
      protagonist: rawProtagonist,
      hotCode: json['rankVo'] is Map<String, dynamic>
          ? (json['rankVo']['hotCode']?.toString()) 
          : json['hotCode']?.toString(),
      shelfTime: json['shelfTime']?.toString(),
      origin: ContentOrigin.dramaBox,
    );
  }

  String get description => introduction;

  String get primaryTag {
    if (tags.isEmpty) {
      return 'Drama';
    }
    return tags.first;
  }

  String get secondaryTag {
    if (tags.length < 2) {
      return '';
    }
    return tags[1];
  }

  static String? _asTrimmedString(dynamic value) {
    if (value == null) {
      return null;
    }
    return value.toString().trim();
  }
}

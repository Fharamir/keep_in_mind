import 'dart:convert';

enum MemoryItemType {
  link,
  text,
  image,
  file;

  String get label {
    switch (this) {
      case MemoryItemType.link:
        return 'Link';
      case MemoryItemType.text:
        return 'Nota';
      case MemoryItemType.image:
        return 'Immagine';
      case MemoryItemType.file:
        return 'File';
    }
  }

  static MemoryItemType fromString(String? value) {
    switch (value) {
      case 'link':
        return MemoryItemType.link;
      case 'image':
        return MemoryItemType.image;
      case 'file':
        return MemoryItemType.file;
      case 'text':
      default:
        return MemoryItemType.text;
    }
  }
}

class MemoryItem {
  final String id;
  final MemoryItemType type;
  final String title;
  final String content;
  final String? url;
  final String? domain;
  final String? filePath;
  final String? fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? base64Data;
  final List<String> tags;
  final bool isPinned;
  final DateTime createdAt;
  final String source;

  const MemoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.url,
    this.domain,
    this.filePath,
    this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.base64Data,
    this.tags = const [],
    this.isPinned = false,
    required this.createdAt,
    this.source = 'Share to Self',
  });

  MemoryItem copyWith({
    String? id,
    MemoryItemType? type,
    String? title,
    String? content,
    String? url,
    String? domain,
    String? filePath,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    String? base64Data,
    bool clearAttachment = false,
    List<String>? tags,
    bool? isPinned,
    DateTime? createdAt,
    String? source,
  }) {
    return MemoryItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      url: url ?? this.url,
      domain: domain ?? this.domain,
      filePath: clearAttachment ? null : (filePath ?? this.filePath),
      fileName: clearAttachment ? null : (fileName ?? this.fileName),
      mimeType: clearAttachment ? null : (mimeType ?? this.mimeType),
      fileSizeBytes:
          clearAttachment ? null : (fileSizeBytes ?? this.fileSizeBytes),
      base64Data: clearAttachment ? null : (base64Data ?? this.base64Data),
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
    );
  }

  String get formattedFileSize {
    final bytes = fileSizeBytes;
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'content': content,
      'url': url,
      'domain': domain,
      'filePath': filePath,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSizeBytes': fileSizeBytes,
      'base64Data': base64Data,
      'tags': tags,
      'isPinned': isPinned,
      'createdAt': createdAt.toIso8601String(),
      'source': source,
    };
  }

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] as String? ?? '',
      type: MemoryItemType.fromString(json['type'] as String?),
      title: json['title'] as String? ?? 'Senza titolo',
      content: json['content'] as String? ?? '',
      url: json['url'] as String?,
      domain: json['domain'] as String?,
      filePath: json['filePath'] as String?,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSizeBytes: json['fileSizeBytes'] as int?,
      base64Data: json['base64Data'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      source: json['source'] as String? ?? 'Share to Self',
    );
  }

  /// Parses shared or manual input into a structured [MemoryItem].
  static MemoryItem fromSharedPayload({
    required String id,
    String? rawText,
    String? rawSubject,
    String? filePath,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    String? base64Data,
    List<String>? customTags,
    bool isPinned = false,
    String source = 'Share to Self',
    DateTime? createdAt,
  }) {
    final timestamp = createdAt ?? DateTime.now();
    final trimmedText = (rawText ?? '').trim();
    final trimmedSubject = (rawSubject ?? '').trim();

    if ((filePath != null && filePath.isNotEmpty) ||
        (base64Data != null && base64Data.isNotEmpty)) {
      final effectiveMime =
          (mimeType ?? _guessMimeType(fileName ?? filePath ?? '')).toLowerCase();
      final isImg = effectiveMime.startsWith('image/');
      final isAudio = effectiveMime.startsWith('audio/');
      final resolvedFileName = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim()
          : _extractFileName(
              filePath ?? (isImg ? 'immagine.jpg' : 'allegato.bin'));

      final resolvedTitle = trimmedSubject.isNotEmpty
          ? trimmedSubject
          : (trimmedText.isNotEmpty && !_isOnlyUrl(trimmedText)
              ? _firstLine(trimmedText, maxLength: 65)
              : resolvedFileName);

      final defaultMediaTag =
          isImg ? 'immagine' : (isAudio ? 'audio' : 'file');
      final autoTags = <String>{
        ...?customTags,
        defaultMediaTag,
      }.toList();

      return MemoryItem(
        id: id,
        type: isImg ? MemoryItemType.image : MemoryItemType.file,
        title: resolvedTitle,
        content: trimmedText,
        filePath: filePath,
        fileName: resolvedFileName,
        mimeType: effectiveMime,
        fileSizeBytes: fileSizeBytes,
        base64Data: base64Data,
        tags: autoTags,
        isPinned: isPinned,
        createdAt: timestamp,
        source: source,
      );
    }

    final extractedUrl = extractFirstUrl(trimmedText);
    if (extractedUrl != null) {
      final domain = extractDomain(extractedUrl);
      final textWithoutUrl = trimmedText
          .replaceAll(extractedUrl, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      String resolvedTitle;
      if (trimmedSubject.isNotEmpty) {
        resolvedTitle = trimmedSubject;
      } else if (textWithoutUrl.isNotEmpty) {
        resolvedTitle = _firstLine(textWithoutUrl, maxLength: 80);
      } else {
        resolvedTitle = _humanizeUrlTitle(extractedUrl, domain);
      }

      final autoTags = <String>{
        ...?customTags,
        'link',
      }.where((t) => t.isNotEmpty).toList();

      return MemoryItem(
        id: id,
        type: MemoryItemType.link,
        title: resolvedTitle,
        content: trimmedText,
        url: extractedUrl,
        domain: domain,
        tags: autoTags,
        isPinned: isPinned,
        createdAt: timestamp,
        source: source,
      );
    }

    final resolvedTitle = trimmedSubject.isNotEmpty
        ? trimmedSubject
        : (trimmedText.isNotEmpty
            ? _firstLine(trimmedText, maxLength: 65)
            : 'Nota veloce');

    final autoTags = <String>{
      ...?customTags,
      'nota',
    }.toList();

    return MemoryItem(
      id: id,
      type: MemoryItemType.text,
      title: resolvedTitle,
      content: trimmedText,
      tags: autoTags,
      isPinned: isPinned,
      createdAt: timestamp,
      source: source,
    );
  }

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s<>"]+)',
    caseSensitive: false,
  );

  static String? extractFirstUrl(String text) {
    if (text.isEmpty) return null;
    final match = _urlRegex.firstMatch(text);
    if (match == null) return null;
    var url = match.group(0)!;
    while (url.isNotEmpty && '.,;:!?)]'.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static String? extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) return null;
      return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
    } catch (_) {
      return null;
    }
  }

  static bool _isOnlyUrl(String text) {
    final url = extractFirstUrl(text);
    return url != null && text.trim() == url.trim();
  }

  static String _firstLine(String text, {int maxLength = 65}) {
    final first = text.split('\n').first.trim();
    if (first.length <= maxLength) return first;
    return '${first.substring(0, maxLength - 1)}…';
  }

  static String _humanizeUrlTitle(String url, String? domain) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final last = Uri.decodeComponent(segments.last)
            .replaceAll(RegExp(r'[-_]+'), ' ')
            .trim();
        if (last.length > 2) {
          final capitalized = last[0].toUpperCase() + last.substring(1);
          return domain != null ? '$capitalized ($domain)' : capitalized;
        }
      }
    } catch (_) {}
    return domain ?? url;
  }

  static String _extractFileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty && parts.last.isNotEmpty ? parts.last : 'allegato';
  }

  static String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return 'text/plain';
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return 'video/mp4';
    if (lower.endsWith('.mp3') || lower.endsWith('.wav')) return 'audio/mpeg';
    return 'application/octet-stream';
  }
}

class WidgetConfig {
  final int maxItems;
  final bool prioritizePinned;
  final MemoryItemType? filterType;
  final String? filterTag;
  final bool showTags;

  const WidgetConfig({
    this.maxItems = 3,
    this.prioritizePinned = true,
    this.filterType,
    this.filterTag,
    this.showTags = true,
  });

  WidgetConfig copyWith({
    int? maxItems,
    bool? prioritizePinned,
    MemoryItemType? filterType,
    bool clearFilterType = false,
    String? filterTag,
    bool clearFilterTag = false,
    bool? showTags,
  }) {
    return WidgetConfig(
      maxItems: (maxItems ?? this.maxItems).clamp(1, 5),
      prioritizePinned: prioritizePinned ?? this.prioritizePinned,
      filterType: clearFilterType ? null : (filterType ?? this.filterType),
      filterTag: clearFilterTag ? null : (filterTag ?? this.filterTag),
      showTags: showTags ?? this.showTags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxItems': maxItems.clamp(1, 5),
      'prioritizePinned': prioritizePinned,
      'filterType': filterType?.name,
      'filterTag': filterTag,
      'showTags': showTags,
    };
  }

  factory WidgetConfig.fromJson(Map<String, dynamic> json) {
    final rawFilter = json['filterType'] as String?;
    final rawTag = json['filterTag'] as String?;
    return WidgetConfig(
      maxItems: ((json['maxItems'] as int?) ?? 3).clamp(1, 5),
      prioritizePinned: json['prioritizePinned'] as bool? ?? true,
      filterType:
          rawFilter != null ? MemoryItemType.fromString(rawFilter) : null,
      filterTag: (rawTag != null && rawTag.isNotEmpty) ? rawTag : null,
      showTags: json['showTags'] as bool? ?? true,
    );
  }

  String toJsonString() => jsonEncode(toJson());
}


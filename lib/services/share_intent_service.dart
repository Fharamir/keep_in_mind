import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SharedIncomingPayload {
  final String? text;
  final String? subject;
  final String? filePath;
  final String? fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? openItemId;
  final bool quickAddRequested;
  final String source;

  const SharedIncomingPayload({
    this.text,
    this.subject,
    this.filePath,
    this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.openItemId,
    this.quickAddRequested = false,
    this.source = 'Share to Self',
  });

  bool get hasSharedContent =>
      (text != null && text!.trim().isNotEmpty) ||
      (filePath != null && filePath!.trim().isNotEmpty);

  factory SharedIncomingPayload.fromMap(Map<dynamic, dynamic> map) {
    return SharedIncomingPayload(
      text: map['text'] as String?,
      subject: map['subject'] as String?,
      filePath: map['filePath'] as String?,
      fileName: map['fileName'] as String?,
      mimeType: map['mimeType'] as String?,
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt(),
      openItemId: map['openItemId'] as String?,
      quickAddRequested: map['quickAdd'] as bool? ?? false,
      source: map['source'] as String? ?? 'Share to Self',
    );
  }
}

class ShareIntentService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.keep_in_mind/share');
  static const EventChannel _eventChannel =
      EventChannel('com.example.keep_in_mind/share_stream');

  StreamSubscription<dynamic>? _sub;
  final StreamController<SharedIncomingPayload> _controller =
      StreamController<SharedIncomingPayload>.broadcast(sync: true);

  Stream<SharedIncomingPayload> get incomingStream => _controller.stream;

  /// Initializes listeners for incoming OS share intents and widget actions.
  Future<void> init() async {
    if (kIsWeb) {
      _checkWebShareTargetParams();
      return;
    }

    // Check initial launch payload
    try {
      final initialData =
          await _methodChannel.invokeMethod<dynamic>('getInitialSharedPayload');
      _handleRawPayload(initialData);
    } catch (_) {}

    // Listen for incoming payloads while running
    try {
      _sub = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          _handleRawPayload(event);
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _handleRawPayload(dynamic raw) {
    if (raw == null) return;
    if (raw is List) {
      for (final elem in raw) {
        if (elem is Map) {
          _controller.add(SharedIncomingPayload.fromMap(elem));
        }
      }
    } else if (raw is Map) {
      final itemsList = raw['items'];
      if (itemsList is List && itemsList.isNotEmpty) {
        for (final elem in itemsList) {
          if (elem is Map) {
            _controller.add(SharedIncomingPayload.fromMap(elem));
          }
        }
      } else {
        _controller.add(SharedIncomingPayload.fromMap(raw));
      }
    }
  }

  void _checkWebShareTargetParams() {
    try {
      final params = Uri.base.queryParameters;
      final sharedTitle = params['title'];
      final sharedText = params['text'];
      final sharedUrl = params['url'];

      final combinedText = [
        if (sharedText != null && sharedText.trim().isNotEmpty)
          sharedText.trim(),
        if (sharedUrl != null &&
            sharedUrl.trim().isNotEmpty &&
            !(sharedText ?? '').contains(sharedUrl.trim()))
          sharedUrl.trim(),
      ].join('\n');

      if (combinedText.isNotEmpty ||
          (sharedTitle != null && sharedTitle.trim().isNotEmpty)) {
        Future.microtask(() {
          _controller.add(
            SharedIncomingPayload(
              text: combinedText.isNotEmpty ? combinedText : sharedTitle,
              subject: sharedTitle,
              source: 'Web Share Target',
            ),
          );
        });
      }
    } catch (_) {}
  }

  /// Emits a simulated share payload for testing.
  void simulateIncomingShare(SharedIncomingPayload payload) {
    _controller.add(payload);
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

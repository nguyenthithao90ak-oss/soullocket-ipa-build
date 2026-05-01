part of 'community_tab.dart';

class _RichPostTextSpanSegment {
  final RichPostTextSegment segment;
  final TapGestureRecognizer? recognizer;

  const _RichPostTextSpanSegment({
    required this.segment,
    this.recognizer,
  });

  String get text => segment.text;
  bool get isInteractive => segment.isInteractive;
  bool get isHashtag => segment.isHashtag;
}

class _RichPostText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _RichPostText({
    required this.text,
    required this.style,
  });

  @override
  State<_RichPostText> createState() => _RichPostTextState();
}

class _RichPostTextState extends State<_RichPostText> {
  List<_RichPostTextSpanSegment> _segments = const <_RichPostTextSpanSegment>[];

  @override
  void initState() {
    super.initState();
    _rebuildSegments();
  }

  @override
  void didUpdateWidget(covariant _RichPostText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _rebuildSegments();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _onHashtagTapped(String tag) async {
    final cleanTag = tag.substring(1).toLowerCase();
    int count = 0;
    try {
      final snap =
          await FirebaseDatabase.instance.ref('hashtags/$cleanTag/count').get();
      count = (snap.value as int?) ?? 1;
    } catch (_) {}

    if (!mounted) return;
    SLNotice.showInfo(
      context,
      'Hashtag $tag hiện đang có $count lượt sử dụng trên toàn server.',
    );
  }

  void _onMentionTapped(String mention) {
    SLNotice.showInfo(
      context,
      'Bạn vừa nhấn vào $mention. Tính năng mở trang cá nhân qua nhắc tên đang được phát triển.',
    );
  }

  void _disposeRecognizers() {
    for (final segment in _segments) {
      segment.recognizer?.dispose();
    }
  }

  void _rebuildSegments() {
    _disposeRecognizers();

    _segments = parseRichPostTextSegments(widget.text).map((segment) {
      if (!segment.isInteractive) {
        return _RichPostTextSpanSegment(segment: segment);
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (segment.isHashtag) {
            _onHashtagTapped(segment.text);
          } else {
            _onMentionTapped(segment.text);
          }
        };

      return _RichPostTextSpanSegment(
        segment: segment,
        recognizer: recognizer,
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_segments.length == 1 && !_segments.first.isInteractive) {
      return Text(
        _segments.first.text,
        style: widget.style,
      );
    }

    final spans = _segments
        .map(
          (segment) => TextSpan(
            text: segment.text,
            style: segment.isInteractive
                ? widget.style.copyWith(
                    color: segment.isHashtag
                        ? const Color(0xFFD81B60)
                        : const Color(0xFF2196F3),
                    fontWeight: FontWeight.w900,
                  )
                : widget.style,
            recognizer: segment.recognizer,
          ),
        )
        .toList(growable: false);

    return RichText(
      softWrap: true,
      text: TextSpan(children: spans),
    );
  }
}

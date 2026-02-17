class ForwardMessageCodec {
  static const String _marker = '__appchat_forwarded__:';

  static String encode(String content) {
    return '$_marker$content';
  }

  static bool isForwarded(String content) {
    return content.startsWith(_marker);
  }

  static String decode(String content) {
    if (!isForwarded(content)) return content;
    return content.substring(_marker.length);
  }
}

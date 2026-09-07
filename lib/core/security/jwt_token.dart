import 'dart:convert';

class JwtTokenInfo {
  const JwtTokenInfo({this.expiresAt, this.userId, this.issuer, this.audience});

  final DateTime? expiresAt;
  final String? userId;
  final String? issuer;
  final String? audience;

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return !expiry.isAfter(DateTime.now().toUtc());
  }

  static JwtTokenInfo? tryParse(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(payload);
      if (json is! Map) return null;
      final map = Map<String, dynamic>.from(json);
      final exp = map['exp'];
      final seconds = exp is num ? exp.toInt() : int.tryParse('$exp');
      return JwtTokenInfo(
        expiresAt: seconds == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
        userId: _text(map['uid'] ?? map['sub']),
        issuer: _text(map['iss']),
        audience: _text(map['aud']),
      );
    } catch (_) {
      return null;
    }
  }

  static String? _text(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

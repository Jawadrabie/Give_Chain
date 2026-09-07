import '../config/api_paths.dart';

abstract final class UrlResolver {
  static String resolve(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return uri.toString();
    final base = Uri.tryParse(ApiPaths.baseUrl.trim());
    if (base == null || !base.hasScheme) return raw;
    if (raw.startsWith('/')) {
      return base.replace(path: raw, query: null, fragment: null).toString();
    }
    final root = base.toString().endsWith('/')
        ? base.toString()
        : '${base.toString()}/';
    return Uri.parse(root).resolve(raw).toString();
  }

  static Uri? external(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme) return parsed;
    if (raw.startsWith('/') || !raw.contains('.')) {
      return Uri.tryParse(resolve(raw));
    }
    return Uri.tryParse('https://$raw');
  }
}

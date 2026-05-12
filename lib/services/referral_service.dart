class ReferralService {
  ReferralService._();

  static final instance = ReferralService._();

  String? _code;

  String? get code => _code;

  void captureFromUri(Uri uri) {
    final value = uri.queryParameters['ref'] ??
        uri.queryParameters['code'] ??
        uri.queryParameters['promoter'];
    if (value == null || value.trim().isEmpty) return;
    _code = normalize(value);
  }

  void setCode(String value) {
    if (value.trim().isEmpty) return;
    _code = normalize(value);
  }

  void clear() {
    _code = null;
  }

  static String normalize(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }
}

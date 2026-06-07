part of '../../consent_gate.dart';

class _ConsentHighlight {
  final IconData icon;
  final String title;
  final String description;

  _ConsentHighlight({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _StartupConsentResult {
  final String cookieLevel;

  const _StartupConsentResult({
    required this.cookieLevel,
  });
}

import 'package:web/web.dart' as web;

import 'session_marker.dart';

/// Web: sessionStorage sobrevive ao F5, mas nao a fechar a aba.
class _BrowserSessionMarker implements SessionMarker {
  static const _key = 'pastoral.session.active';

  @override
  bool get isActive => web.window.sessionStorage.getItem(_key) == '1';

  @override
  void activate() => web.window.sessionStorage.setItem(_key, '1');

  @override
  void clear() => web.window.sessionStorage.removeItem(_key);
}

SessionMarker createSessionMarker() => _BrowserSessionMarker();

import 'session_marker.dart';

/// Mobile/testes: o marcador vive em memoria e some quando o app e encerrado.
class _MemorySessionMarker implements SessionMarker {
  bool _active = false;

  @override
  bool get isActive => _active;

  @override
  void activate() => _active = true;

  @override
  void clear() => _active = false;
}

SessionMarker createSessionMarker() => _MemorySessionMarker();

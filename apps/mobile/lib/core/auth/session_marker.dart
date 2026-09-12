import 'session_marker_stub.dart'
    if (dart.library.js_interop) 'session_marker_web.dart'
    as impl;

/// Marca uma sessao "nao lembrada" enquanto a aba/processo estiver vivo.
abstract interface class SessionMarker {
  bool get isActive;
  void activate();
  void clear();
}

SessionMarker createSessionMarker() => impl.createSessionMarker();

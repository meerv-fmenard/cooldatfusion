import 'fullscreen_interface.dart';

/// Native (non-web) stub: there is no browser fullscreen, and the desktop app
/// already runs in its own window, so the gate is bypassed.
class _StubFullscreen implements FullscreenController {
  @override
  bool get supported => false;
  @override
  bool get isFullscreen => true;
  @override
  void request() {}
  @override
  void exit() {}
  @override
  void addListener(void Function() cb) {}
  @override
  void removeListener(void Function() cb) {}
  @override
  void dispose() {}
}

FullscreenController makeFullscreenController() => _StubFullscreen();

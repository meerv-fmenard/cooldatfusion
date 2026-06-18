/// Cross-platform handle to the browser Fullscreen API. On non-web platforms a
/// stub reports it is unsupported and always "fullscreen" so the gate is a
/// no-op there.
abstract class FullscreenController {
  /// Whether the Fullscreen API exists on this platform (true only on web).
  bool get supported;

  /// Whether the document is currently presented full screen.
  bool get isFullscreen;

  /// Request that the app enter full screen (must be a user gesture on web).
  void request();

  /// Leave full screen.
  void exit();

  void addListener(void Function() cb);
  void removeListener(void Function() cb);
  void dispose();
}

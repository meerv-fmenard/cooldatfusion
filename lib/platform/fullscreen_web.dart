import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'fullscreen_interface.dart';

/// Web implementation backed by the browser Fullscreen API.
class _WebFullscreen implements FullscreenController {
  _WebFullscreen() {
    _handler = ((web.Event _) {
      for (final l in List<void Function()>.of(_listeners)) {
        l();
      }
    }).toJS;
    web.document.addEventListener('fullscreenchange', _handler);
    web.document.addEventListener('webkitfullscreenchange', _handler);
  }

  final List<void Function()> _listeners = [];
  late final JSFunction _handler;

  @override
  bool get supported => true;

  @override
  bool get isFullscreen => web.document.fullscreenElement != null;

  @override
  void request() {
    final el = web.document.documentElement;
    if (el != null) el.requestFullscreen();
  }

  @override
  void exit() {
    if (web.document.fullscreenElement != null) {
      web.document.exitFullscreen();
    }
  }

  @override
  void addListener(void Function() cb) => _listeners.add(cb);

  @override
  void removeListener(void Function() cb) => _listeners.remove(cb);

  @override
  void dispose() {
    web.document.removeEventListener('fullscreenchange', _handler);
    web.document.removeEventListener('webkitfullscreenchange', _handler);
    _listeners.clear();
  }
}

FullscreenController makeFullscreenController() => _WebFullscreen();

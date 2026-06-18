export 'fullscreen_interface.dart';

import 'fullscreen_interface.dart';
import 'fullscreen_stub.dart'
    if (dart.library.html) 'fullscreen_web.dart' as impl;

/// Creates the right [FullscreenController] for the current platform.
FullscreenController createFullscreenController() =>
    impl.makeFullscreenController();

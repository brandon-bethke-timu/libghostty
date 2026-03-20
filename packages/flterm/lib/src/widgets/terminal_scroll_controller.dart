import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' show ScreenMode;
import 'package:meta/meta.dart';

/// Scroll controller that adapts to [ScreenMode].
///
/// In [ScreenMode.primary], behaves like a standard [ScrollController].
/// In [ScreenMode.alternate], the scroll position accepts all scroll
/// gestures by using infinite extents.
///
/// ```dart
/// final scrollController = TerminalScrollController();
///
/// TerminalView(
///   terminal: terminal,
///   scrollController: scrollController,
/// )
/// ```
class TerminalScrollController extends ScrollController {
  var _screenMode = ScreenMode.primary;

  TerminalScrollController();

  /// The active screen mode that controls scroll behavior.
  ScreenMode get screenMode => _screenMode;

  @internal
  set screenMode(ScreenMode value) {
    if (_screenMode == value) return;
    _screenMode = value;
    for (final position in positions) {
      (position as TerminalScrollPosition).screenMode = value;
    }
  }

  @override
  TerminalScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return TerminalScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      screenMode: _screenMode,
    );
  }
}

/// Scroll position that adapts behavior based on [ScreenMode].
///
/// In [ScreenMode.primary], behaves like
/// [ScrollPositionWithSingleContext]. In [ScreenMode.alternate],
/// overrides content dimensions to accept all scroll gestures.
class TerminalScrollPosition extends ScrollPositionWithSingleContext {
  double? _savedPixels;
  ScreenMode _screenMode;

  TerminalScrollPosition({
    required super.physics,
    required super.context,
    required ScreenMode screenMode,
    super.oldPosition,
  }) : _screenMode = screenMode;

  ScreenMode get screenMode => _screenMode;

  @internal
  set screenMode(ScreenMode value) {
    if (_screenMode == value) return;
    if (value == .alternate && hasPixels) {
      _savedPixels = pixels;
    }
    _screenMode = value;
    if (value == ScreenMode.primary && _savedPixels != null) {
      correctPixels(_savedPixels!);
      _savedPixels = null;
    }
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    return switch (_screenMode) {
      .alternate => super.applyContentDimensions(.negativeInfinity, .infinity),
      _ => super.applyContentDimensions(minScrollExtent, maxScrollExtent),
    };
  }
}

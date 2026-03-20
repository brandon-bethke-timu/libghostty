import 'package:flutter/foundation.dart';

import 'terminal_selection.dart';

/// Observable selection and focus state for the rendering layer.
abstract class TerminalRenderState implements Listenable {
  /// Whether the terminal view has keyboard focus.
  bool get hasFocus;

  /// The current text selection, or null if nothing is selected.
  TerminalSelection? get selection;
}

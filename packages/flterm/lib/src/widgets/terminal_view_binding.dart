import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

import '../foundation/terminal_selection.dart';

/// Internal bridge between the controller and the widget layer.
@internal
abstract interface class TerminalViewBinding {
  set focusNode(FocusNode? value);

  set onOutput(ValueChanged<Uint8List>? value);

  set selection(TerminalSelection? value);

  set terminal(Terminal? value);

  void attachInput({Brightness keyboardAppearance});

  void detachInput();

  Uint8List? encodeKeyboardEvent(KeyEvent event);

  MouseTracking? syncModes(TerminalModes modes);

  @visibleForTesting
  void testCommitText(String text);
}

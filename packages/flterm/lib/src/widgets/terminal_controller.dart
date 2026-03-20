import 'package:flutter/foundation.dart' hide Key;
import 'package:libghostty/libghostty.dart';

import '../foundation.dart';
import 'terminal_controller_impl.dart';

/// Controls a [TerminalView].
///
/// A [TerminalController] lets you send input, manage text selection, toggle
/// virtual modifier keys, and control keyboard visibility from code. It also
/// implements [TerminalRenderState], so the terminal view repaints
/// automatically when selection or focus changes.
///
/// A [TerminalController] should be created early (e.g. in [State.initState])
/// and disposed when the widget is removed from the tree.
///
/// ```dart
/// final controller = TerminalController();
///
/// // Attach to a TerminalView.
/// TerminalView(
///   terminal: terminal,
///   controller: controller,
///   onOutput: (bytes) => pty.write(bytes),
/// );
///
/// // Send input programmatically.
/// controller.sendText('ls -la\n');
///
/// // Read selected text.
/// controller.selectAll();
/// print(controller.selectedText);
/// ```
abstract class TerminalController extends ChangeNotifier
    implements TerminalRenderState {
  factory TerminalController() => TerminalControllerImpl();

  @internal
  TerminalController.base();

  /// Text content of the current selection. Empty string if no selection.
  String get selectedText;

  /// Currently active virtual modifier keys.
  ///
  /// Virtual modifiers merge with physical keyboard modifiers for key
  /// encoding and gesture detection. They auto-clear after producing
  /// output (sticky behavior).
  ///
  /// ```dart
  /// controller.toggleMod(Mods.ctrl);
  /// // Next keyboard input or sendKey encodes with Ctrl, then clears.
  /// ```
  Mods get virtualMods;

  /// Clears the terminal scrollback and sends a form feed to the shell.
  ///
  /// Does nothing on the alternate screen. Clears any active selection.
  void clear();

  /// Clears the current selection.
  void clearSelection();

  /// Clears all virtual modifiers.
  void clearVirtualMods();

  /// Hides the soft keyboard.
  void hideKeyboard();

  /// Requests keyboard focus for the terminal view.
  void requestFocus();

  /// Selects all content including scrollback history.
  void selectAll();

  /// Sends a key press as if typed on the keyboard.
  ///
  /// ```dart
  /// controller.sendKey(Key.enter);
  /// controller.sendKey(Key.keyC, mods: Mods.ctrl);
  /// ```
  void sendKey(Key key, {Mods mods = Mods.none});

  /// Sends text as if typed. Each character is UTF-8 encoded.
  ///
  /// ```dart
  /// controller.sendText('ls -la\n');
  /// ```
  void sendText(String text);

  /// Shows the soft keyboard.
  void showKeyboard();

  /// Toggles a virtual modifier on or off.
  ///
  /// ```dart
  /// controller.toggleMod(Mods.ctrl); // activates Ctrl
  /// controller.toggleMod(Mods.ctrl); // deactivates Ctrl
  /// ```
  void toggleMod(Mods mod);

  /// Removes keyboard focus from the terminal view.
  void unfocus();
}

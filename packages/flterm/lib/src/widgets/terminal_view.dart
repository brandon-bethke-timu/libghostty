import 'dart:async';
import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

import '../foundation.dart';
import '../rendering.dart' show TerminalRenderer, measureCellMetrics;
import 'terminal_controller.dart';
import 'terminal_gesture_detector.dart';
import 'terminal_scroll_controller.dart';
import 'terminal_shortcut_scope.dart';
import 'terminal_view_binding.dart';

final _appCursorDown = Uint8List.fromList([0x1b, 0x4f, 0x42]);
final _appCursorUp = Uint8List.fromList([0x1b, 0x4f, 0x41]);
final _cursorDown = Uint8List.fromList([0x1b, 0x5b, 0x42]);
final _cursorUp = Uint8List.fromList([0x1b, 0x5b, 0x41]);

Uint8List _encodePaste(String text, {required bool bracketedPaste}) {
  if (!bracketedPaste) return utf8.encode(text);
  return utf8.encode('\x1b[200~$text\x1b[201~');
}

/// A terminal widget that renders a working terminal with zero configuration
/// beyond providing a [Terminal] instance.
///
/// ```dart
/// TerminalView(terminal: terminal)
/// ```
///
/// For PTY integration, listen to terminal events and provide output/resize
/// callbacks:
///
/// ```dart
/// TerminalView(
///   terminal: terminal,
///   onOutput: (bytes) => pty.write(bytes),
///   onResize: (size) => pty.resize(size.cols, size.rows),
/// )
/// ```
///
/// For programmatic control, provide a [TerminalController]:
///
/// ```dart
/// final controller = TerminalController();
///
/// TerminalView(
///   terminal: terminal,
///   controller: controller,
///   onOutput: (bytes) => pty.write(bytes),
///   onResize: (size) => pty.resize(size.cols, size.rows),
/// )
///
/// controller.sendText('ls -la\n');
/// ```
class TerminalView extends StatefulWidget {
  /// The terminal instance to render.
  final Terminal terminal;

  /// Visual style. Defaults to [TerminalTheme.dark()] when null.
  final TerminalTheme? theme;

  /// Optional controller for programmatic interaction.
  ///
  /// If null, the widget creates one internally.
  final TerminalController? controller;

  /// Optional focus node. If null, the widget creates one internally.
  final FocusNode? focusNode;

  /// Whether to request focus when first inserted into the tree.
  final bool autofocus;

  /// Bytes that should be written to the PTY.
  ///
  /// Aggregates all output: keyboard input, paste, terminal responses,
  /// mouse tracking events, and programmatic [TerminalController.sendText]
  /// or [TerminalController.sendKey] calls.
  final ValueChanged<Uint8List>? onOutput;

  /// Fires when the terminal grid dimensions change during layout.
  final ValueChanged<TerminalSize>? onResize;

  /// Fires when the user taps a cell with an OSC 8 hyperlink.
  final ValueChanged<String>? onLinkTap;

  /// Additional shortcut bindings merged over platform defaults.
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// Whether the terminal accepts keyboard input.
  final TerminalInputMode inputMode;

  /// Whether to show the soft keyboard when the terminal receives focus.
  ///
  /// Set to `false` to prevent the keyboard from appearing automatically.
  /// Use [TerminalController.showKeyboard] to show it imperatively.
  final bool showKeyboard;

  /// Controls when the mouse cursor hides.
  ///
  /// Defaults to [MouseAutoHide.onInput], which hides the cursor on
  /// keyboard input and shows it again on mouse movement.
  final MouseAutoHide mouseAutoHide;

  /// Controls which selection gestures are enabled and how they behave.
  ///
  /// Defaults to [TerminalGestureSettings()] which enables all selection
  /// gestures with standard platform conventions.
  final TerminalGestureSettings gestureSettings;

  /// Inset padding around the terminal content.
  ///
  /// ```dart
  /// TerminalView(
  ///   terminal: terminal,
  ///   padding: EdgeInsets.all(8),
  /// )
  /// ```
  final EdgeInsets padding;

  /// Scroll physics for the terminal viewport.
  ///
  /// Controls momentum, bounce, and other scroll behavior. When null,
  /// platform-default physics apply.
  final ScrollPhysics? scrollPhysics;

  /// Optional scroll controller for programmatic scroll access.
  ///
  /// If null, the widget creates one internally.
  final TerminalScrollController? scrollController;

  const TerminalView({
    super.key,
    required this.terminal,
    this.theme,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onOutput,
    this.onResize,
    this.onLinkTap,
    this.shortcuts,
    this.inputMode = .interactive,
    this.showKeyboard = true,
    this.mouseAutoHide = .onInput,
    this.gestureSettings = const TerminalGestureSettings(),
    this.padding = const EdgeInsets.all(8),
    this.scrollPhysics,
    this.scrollController,
  });

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  late TerminalController _controller;
  late TerminalViewBinding _binding;
  late FocusNode _focusNode;
  late TerminalTheme _theme;
  late CellMetrics _metrics;

  late TerminalScrollController _scrollController;
  var _ownsController = false;
  var _ownsFocusNode = false;
  var _ownsScrollController = false;
  var _mouseMode = MouseTracking.none;
  var _mouseShape = MouseShape.text;
  var _mouseCursorHidden = false;
  var _screenMode = ScreenMode.primary;
  var _lastAlternatePixels = 0.0;
  var _cursorKeyApplication = false;
  final _cursorBlinking = true;
  var _visibleRows = 0;
  Timer? _blinkTimer;
  var _blinkVisible = true;
  String? _highlightedHyperlink;
  Offset? _lastHoverPosition;

  bool get _isAtBottom {
    if (_screenMode == .alternate) return true;
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return true;
    return position.pixels >= position.maxScrollExtent - 1.0;
  }

  @override
  Widget build(BuildContext context) {
    Widget terminal = Focus(
      onKeyEvent: _handleKeyEvent,
      child: TerminalShortcutScope(
        controller: _controller,
        onPaste: _handlePaste,
        enableSelectAll: widget.gestureSettings.enabledSelections.contains(
          SelectionGesture.selectAll,
        ),
        shortcuts: widget.shortcuts,
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onFocusChange: _handleFocusChange,
          child: TerminalGestureDetector(
            metrics: _metrics,
            mouseMode: _mouseMode,
            controller: _controller,
            visibleRows: _visibleRows,
            onOutput: widget.onOutput,
            onLinkTap: widget.onLinkTap,
            getHyperlinkAt: _hyperlinkAt,
            settings: widget.gestureSettings,
            scrollController: _scrollController,
            getScreen: () => widget.terminal.screen,
            onSelectionChanged: _handleSelectionChanged,
            onFocusRequest: () => _controller.requestFocus(),
            child: Scrollable(
              controller: _scrollController,
              physics: switch (_mouseMode) {
                .none => widget.scrollPhysics,
                _ => const NeverScrollableScrollPhysics(),
              },
              viewportBuilder: (_, offset) => _buildViewport(offset),
            ),
          ),
        ),
      ),
    );

    if (widget.padding != EdgeInsets.zero) {
      terminal = Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _controller.requestFocus(),
        child: ColoredBox(color: _theme.background, child: terminal),
      );
    }

    return terminal;
  }

  @override
  void didUpdateWidget(TerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _detachBinding();
      if (_ownsController) _controller.dispose();
      _controller = widget.controller ?? TerminalController();
      _binding = _asBinding(_controller);
      _ownsController = widget.controller == null;
      _attachBinding();
    }

    if (widget.focusNode != oldWidget.focusNode) {
      if (_ownsFocusNode) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
      _ownsFocusNode = widget.focusNode == null;
      _binding.focusNode = _focusNode;
    }

    if (widget.scrollController != oldWidget.scrollController) {
      _scrollController.removeListener(_onScrollChanged);
      if (_ownsScrollController) _scrollController.dispose();
      _scrollController = widget.scrollController ?? TerminalScrollController();
      _ownsScrollController = widget.scrollController == null;
      _scrollController.screenMode = _screenMode;
      _scrollController.addListener(_onScrollChanged);
    }

    if (widget.theme != oldWidget.theme) {
      final oldTheme = _theme;
      _theme = widget.theme ?? TerminalTheme.dark();
      _metrics = measureCellMetrics(
        fontSize: _theme.fontSize,
        fontFamily: _theme.fontFamily,
        fontFamilyFallback: _theme.fontFamilyFallback,
      );
      if (_theme.cursor.blinkInterval != oldTheme.cursor.blinkInterval &&
          _controller.hasFocus &&
          _isAtBottom) {
        _startBlink();
      }
    }

    if (widget.terminal != oldWidget.terminal) {
      _binding.terminal = widget.terminal;
      _syncModes(widget.terminal.modes);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _blinkTimer?.cancel();
    _detachBinding();
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    _scrollController.removeListener(_onScrollChanged);
    if (_ownsScrollController) _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? TerminalController();
    _binding = _asBinding(_controller);
    _ownsController = widget.controller == null;

    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;

    _theme = widget.theme ?? TerminalTheme.dark();
    _metrics = measureCellMetrics(
      fontSize: _theme.fontSize,
      fontFamily: _theme.fontFamily,
      fontFamilyFallback: _theme.fontFamilyFallback,
    );

    _scrollController = widget.scrollController ?? TerminalScrollController();
    _ownsScrollController = widget.scrollController == null;
    _scrollController.addListener(_onScrollChanged);

    _attachBinding();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  static TerminalViewBinding _asBinding(TerminalController controller) {
    assert(
      controller is TerminalViewBinding,
      'TerminalController must implement TerminalViewBinding. '
      'Use the TerminalController() factory constructor.',
    );
    return controller as TerminalViewBinding;
  }

  void _attachBinding() {
    _binding
      ..focusNode = _focusNode
      ..terminal = widget.terminal
      ..onOutput = _handleOutput;
  }

  Widget _buildViewport(ViewportOffset offset) {
    Widget viewport = MouseRegion(
      onHover: _handleMouseHover,
      onExit: _handleMouseExit,
      cursor: _effectiveMouseCursor(),
      child: TerminalRenderer(
        theme: _theme,
        offset: offset,
        metrics: _metrics,
        renderState: _controller,
        terminal: widget.terminal,
        blinkVisible: _blinkVisible,
        onResize: _handleResize,
        onEvent: _handleTerminalEvent,
        highlightedHyperlink: _highlightedHyperlink,
      ),
    );

    if (widget.padding != .zero) {
      viewport = Padding(padding: widget.padding, child: viewport);
    }

    return viewport;
  }

  int _contentOrigin() {
    if (_screenMode == .alternate) return 0;
    final sc = _scrollController;
    if (!sc.hasClients || _metrics.cellHeight <= 0) return 0;
    final scrollbackLen = widget.terminal.scrollback.length;
    if (scrollbackLen == 0) return 0;
    final maxExtent = scrollbackLen * _metrics.cellHeight;
    final pixels = sc.position.pixels.clamp(0.0, maxExtent);
    return (pixels / _metrics.cellHeight).floor();
  }

  void _detachBinding() {
    _binding
      ..detachInput()
      ..focusNode = null
      ..terminal = null
      ..onOutput = null;
  }

  MouseCursor _effectiveMouseCursor() {
    if (_mouseCursorHidden) return SystemMouseCursors.none;
    if (_highlightedHyperlink != null) return SystemMouseCursors.click;
    if (_mouseMode != MouseTracking.none) return SystemMouseCursors.basic;
    return cursorFromMouseShape(_mouseShape);
  }

  void _handleFocusChange(bool focused) {
    if (focused) {
      if (widget.inputMode == TerminalInputMode.interactive) {
        final brightness = _theme.background.computeLuminance() > 0.5
            ? Brightness.light
            : Brightness.dark;
        _binding.attachInput(keyboardAppearance: brightness);
        if (widget.showKeyboard) _controller.showKeyboard();
      }
      if (_isAtBottom) _startBlink();
    } else {
      _binding.detachInput();
      _controller.clearVirtualMods();
      _stopBlink();
    }
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event.logicalKey == .metaLeft || event.logicalKey == .metaRight) {
      _updateHighlightedHyperlink();
    }
    return false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.inputMode == TerminalInputMode.readOnly) {
      return KeyEventResult.ignored;
    }

    if (_tryExtendSelection(event)) return KeyEventResult.handled;

    final bytes = _binding.encodeKeyboardEvent(event);
    if (bytes == null) return KeyEventResult.ignored;

    if (_controller.selection != null) _handleSelectionChanged(null);

    widget.onOutput?.call(bytes);
    _resetBlink();

    if (widget.mouseAutoHide == MouseAutoHide.onInput && !_mouseCursorHidden) {
      setState(() => _mouseCursorHidden = true);
    }

    _scrollToBottom();

    return KeyEventResult.handled;
  }

  void _handleMouseExit(PointerExitEvent event) {
    _lastHoverPosition = null;
    if (_highlightedHyperlink != null) {
      setState(() => _highlightedHyperlink = null);
    }
  }

  void _handleMouseHover(PointerHoverEvent event) {
    if (_mouseCursorHidden) setState(() => _mouseCursorHidden = false);
    _lastHoverPosition = event.localPosition;
    _updateHighlightedHyperlink();
  }

  void _handleOutput(Uint8List bytes) {
    widget.onOutput?.call(bytes);
    _scrollToBottom();
    _resetBlink();
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) return;
    final bytes = _encodePaste(
      data.text!,
      bracketedPaste: widget.terminal.modes.bracketedPaste,
    );
    widget.onOutput?.call(bytes);
    _resetBlink();
    _scrollToBottom();
  }

  void _handleResize(TerminalSize size) {
    _visibleRows = size.rows;
    widget.onResize?.call(size);
  }

  void _handleSelectionChanged(TerminalSelection? selection) {
    _binding.selection = selection?.scroll(_contentOrigin());
  }

  String? _hyperlinkAt(int row, int col) {
    final terminal = widget.terminal;
    final screen = terminal.screen;
    if (col < 0 || col >= screen.cols) return null;
    final scrollbackLen = terminal.scrollback.length;
    final absRow = _contentOrigin() + row;
    if (absRow < 0) return null;
    if (absRow < scrollbackLen) {
      return terminal.scrollback.lineAt(absRow).cellAt(col).hyperlink;
    }
    final screenRow = absRow - scrollbackLen;
    if (screenRow < 0 || screenRow >= screen.rows) return null;
    return screen.cellAt(screenRow, col).hyperlink;
  }

  void _onScrollChanged() {
    if (_screenMode != .alternate) return;
    if (!_scrollController.hasClients) return;
    final cellHeight = _metrics.cellHeight;
    if (cellHeight <= 0) return;
    final pixels = _scrollController.position.pixels;
    final delta = pixels - _lastAlternatePixels;
    final lines = (delta / cellHeight).truncate();
    if (lines == 0) return;
    _lastAlternatePixels += lines * cellHeight;
    final up = _cursorKeyApplication ? _appCursorUp : _cursorUp;
    final down = _cursorKeyApplication ? _appCursorDown : _cursorDown;
    final key = lines < 0 ? up : down;
    final count = lines.abs();
    final bytes = Uint8List(key.length * count);
    for (var i = 0; i < count; i++) {
      bytes.setRange(i * key.length, (i + 1) * key.length, key);
    }
    widget.onOutput?.call(bytes);
  }

  void _resetBlink() {
    if (!_controller.hasFocus || !_isAtBottom) return;
    _startBlink();
  }

  void _scrollToBottom() {
    if (_screenMode == .alternate) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent) return;
    _scrollController.jumpTo(position.maxScrollExtent);
  }

  void _startBlink() {
    if (!_cursorBlinking) return;
    _blinkTimer?.cancel();
    if (!_blinkVisible) setState(() => _blinkVisible = true);
    _blinkTimer = Timer.periodic(_theme.cursor.blinkInterval, (_) {
      if (!mounted) return;
      setState(() => _blinkVisible = !_blinkVisible);
    });
  }

  void _stopBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    if (!_blinkVisible) setState(() => _blinkVisible = true);
  }

  void _handleTerminalEvent(TerminalEvent event) {
    switch (event) {
      // TODO(elias8): sync cursor blink state once upstream exposes it.
      case CursorChanged():
        break;
      case MouseShapeChanged(:final shape):
        if (shape != _mouseShape) {
          _mouseShape = shape;
          setState(() {});
        }
      case ModeChanged(:final modes):
        _syncModes(modes);
      case ResponseReceived(:final response):
        widget.onOutput?.call(response);
      default:
        break;
    }
  }

  void _syncModes(TerminalModes modes) {
    var needsRebuild = false;

    final newMouseMode = _binding.syncModes(modes);
    if (newMouseMode != null) {
      _mouseMode = newMouseMode;
      needsRebuild = true;
    }

    if (modes.screenMode != _screenMode) {
      final newScreenMode = modes.screenMode;
      _screenMode = newScreenMode;
      _scrollController.screenMode = newScreenMode;
      if (newScreenMode == .alternate && _scrollController.hasClients) {
        _lastAlternatePixels = _scrollController.position.pixels;
      }
      needsRebuild = true;
    }

    if (modes.cursorKeyApplication != _cursorKeyApplication) {
      _cursorKeyApplication = modes.cursorKeyApplication;
      needsRebuild = true;
    }

    if (needsRebuild) setState(() {});
  }

  bool _tryExtendSelection(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (_controller.selection == null) return false;
    if (!HardwareKeyboard.instance.isShiftPressed) return false;

    final (dRow, dCol) = switch (event.logicalKey) {
      .arrowRight => (0, 1),
      .arrowLeft => (0, -1),
      .arrowUp => (-1, 0),
      .arrowDown => (1, 0),
      _ => (0, 0),
    };
    if (dRow == 0 && dCol == 0) return false;

    final screen = widget.terminal.screen;
    _binding.selection = _controller.selection!.moveEnd(
      dRow,
      dCol,
      totalCols: screen.cols,
      totalRows: widget.terminal.scrollback.length + screen.rows,
    );
    return true;
  }

  void _updateHighlightedHyperlink() {
    String? uri;
    final pos = _lastHoverPosition;
    if (pos != null && HardwareKeyboard.instance.isMetaPressed) {
      final (row, col) = _metrics.cellAt(pos);
      uri = _hyperlinkAt(row, col);
    }
    if (uri != _highlightedHyperlink) {
      setState(() => _highlightedHyperlink = uri);
    }
  }
}

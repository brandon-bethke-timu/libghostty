import 'dart:typed_data';

/// Platform-independent, dart idiomatic interface for libghostty-vt bindings.
///
/// Implemented by `NativeBindings` (dart:ffi) and `WasmBindings`
/// (dart:js_interop). Handles are opaque `int` values on both platforms.
abstract interface class GhosttyBindings {
  // ghostty_key_event_new
  int keyEventNew();

  // ghostty_key_event_free
  void keyEventFree(int handle);

  // ghostty_key_event_set_action (GhosttyKeyAction)
  void keyEventSetAction(int handle, int action);

  // ghostty_key_event_get_action → GhosttyKeyAction
  int keyEventGetAction(int handle);

  // ghostty_key_event_set_key (GhosttyKey)
  void keyEventSetKey(int handle, int key);

  // ghostty_key_event_get_key → GhosttyKey
  int keyEventGetKey(int handle);

  // ghostty_key_event_set_mods (GhosttyMods bitmask)
  void keyEventSetMods(int handle, int mods);

  // ghostty_key_event_get_mods → GhosttyMods bitmask
  int keyEventGetMods(int handle);

  // ghostty_key_event_set_consumed_mods (GhosttyMods bitmask)
  void keyEventSetConsumedMods(int handle, int mods);

  // ghostty_key_event_get_consumed_mods → GhosttyMods bitmask
  int keyEventGetConsumedMods(int handle);

  // ghostty_key_event_set_composing
  void keyEventSetComposing(int handle, {required bool composing});

  // ghostty_key_event_get_composing
  bool keyEventGetComposing(int handle);

  // ghostty_key_event_set_utf8 (ptr + len)
  void keyEventSetUtf8(int handle, String? text);

  // ghostty_key_event_get_utf8 (ptr + out_len)
  String? keyEventGetUtf8(int handle);

  // ghostty_key_event_set_unshifted_codepoint
  void keyEventSetUnshiftedCodepoint(int handle, int codepoint);

  // ghostty_key_event_get_unshifted_codepoint
  int keyEventGetUnshiftedCodepoint(int handle);

  // ghostty_key_encoder_new
  int keyEncoderNew();

  // ghostty_key_encoder_free
  void keyEncoderFree(int handle);

  // ghostty_key_encoder_setopt (GhosttyKeyEncoderOption, bool*)
  void keyEncoderSetBoolOpt(int handle, int option, {required bool value});

  // ghostty_key_encoder_setopt (GHOSTTY_KEY_ENCODER_OPTION_KITTY_FLAGS, u8*)
  void keyEncoderSetKittyFlags(int handle, int flags);

  // ghostty_key_encoder_setopt
  //    (GHOSTTY_KEY_ENCODER_OPTION_MACOS_OPTION_AS_ALT, i32*)
  void keyEncoderSetOptionAsAlt(int handle, int value);

  // ghostty_key_encoder_encode (buf + buf_size + out_len)
  String keyEncoderEncode(int encoder, int event);

  // ghostty_osc_new
  int oscNew();

  // ghostty_osc_free
  void oscFree(int handle);

  // ghostty_osc_next
  void oscFeedByte(int handle, int byte);

  // ghostty_osc_end + ghostty_osc_command_type + ghostty_osc_command_data
  OscEndResult oscEnd(int handle, int terminator);

  // ghostty_osc_reset
  void oscReset(int handle);

  // ghostty_sgr_new
  int sgrNew();

  // ghostty_sgr_free
  void sgrFree(int handle);

  // ghostty_sgr_set_params + ghostty_sgr_next (iterated)
  List<RawSgrAttribute> sgrParse(
    int handle,
    List<int> params,
    List<String>? separators,
  );

  // ghostty_sgr_reset
  void sgrReset(int handle);

  // ghostty_paste_is_safe
  bool pasteIsSafe(String data);

  // ghostty_terminal_new
  int terminalNew(int cols, int rows);

  // ghostty_terminal_new_with_config (GhosttyTerminalConfig*)
  int terminalNewWithConfig(int cols, int rows, RawTerminalConfig config);

  // ghostty_terminal_free
  void terminalFree(int handle);

  // ghostty_terminal_write (ptr + len) → event flags bitmask
  int terminalWrite(int handle, Uint8List data);

  // ghostty_terminal_resize
  void terminalResize(int handle, int cols, int rows);

  // ghostty_render_state_update
  int renderStateUpdate(int handle);

  // ghostty_render_state_get_viewport (GhosttyCell* buf + buf_size)
  RawCells renderStateGetViewport(int handle, int cols, int rows);

  // ghostty_render_state_get_cols
  int renderStateGetCols(int handle);

  // ghostty_render_state_get_rows
  int renderStateGetRows(int handle);

  // ghostty_render_state_get_cursor_x
  int renderStateGetCursorX(int handle);

  // ghostty_render_state_get_cursor_y
  int renderStateGetCursorY(int handle);

  // ghostty_render_state_get_cursor_visible
  bool renderStateGetCursorVisible(int handle);

  // ghostty_render_state_get_cursor_style
  int renderStateGetCursorStyle(int handle);

  // ghostty_render_state_get_fg_color → packed 0xRRGGBB
  int renderStateGetFgColor(int handle);

  // ghostty_render_state_get_bg_color → packed 0xRRGGBB
  int renderStateGetBgColor(int handle);

  // ghostty_render_state_is_row_dirty
  bool renderStateIsRowDirty(int handle, int row);

  // ghostty_render_state_mark_clean
  void renderStateMarkClean(int handle);

  // ghostty_render_state_get_grapheme (u32* buf + buf_size)
  List<int> renderStateGetGrapheme(int handle, int row, int col);

  // ghostty_terminal_get_scrollback_length
  int terminalGetScrollbackLength(int handle);

  // ghostty_terminal_get_scrollback_line (GhosttyCell* buf + buf_size)
  RawCells? terminalGetScrollbackLine(int handle, int offset, int cols);

  // ghostty_terminal_is_alternate_screen
  bool terminalIsAlternateScreen(int handle);

  // ghostty_terminal_get_mode
  bool terminalGetMode(int handle, int mode, {required bool isAnsi});

  // ghostty_terminal_get_mouse_shape
  int terminalGetMouseShape(int handle);

  // ghostty_terminal_get_modes → GHOSTTY_MODE_* bitmask
  int terminalGetModes(int handle);

  // ghostty_terminal_get_palette_color → packed 0xRRGGBB
  int terminalGetPaletteColor(int handle, int index);

  // ghostty_terminal_get_bell_count
  int terminalGetBellCount(int handle);

  // ghostty_terminal_reset_bell_count
  void terminalResetBellCount(int handle);

  // ghostty_terminal_has_title_changed
  bool terminalHasTitleChanged(int handle);

  // ghostty_terminal_get_title (u8* buf + buf_size)
  String? terminalGetTitle(int handle);

  // ghostty_terminal_has_response
  bool terminalHasResponse(int handle);

  // ghostty_terminal_read_response (u8* buf + buf_size)
  Uint8List? terminalReadResponse(int handle);

  // ghostty_render_state_get_hyperlink (u8* buf + buf_size)
  String? renderStateGetHyperlink(int handle, int row, int col);

  // ghostty_render_state_is_row_wrapped
  bool renderStateIsRowWrapped(int handle, int row);

  // ghostty_terminal_get_scrollback_grapheme (u32* buf + buf_size)
  List<int> terminalGetScrollbackGrapheme(int handle, int offset, int col);

  // ghostty_terminal_get_scrollback_hyperlink (u8* buf + buf_size)
  String? terminalGetScrollbackHyperlink(int handle, int offset, int col);

  // ghostty_terminal_is_scrollback_row_wrapped
  bool terminalIsScrollbackRowWrapped(int handle, int offset);
}

// Mirrors GhosttyOscCommandType + GhosttyOscCommandData results.
class OscEndResult {
  OscEndResult({required this.commandType, this.windowTitle});

  final int commandType;
  final String? windowTitle;
}

/// Flat storage for GhosttyCell structs (24 bytes each, little-endian).
///
/// Provides indexed field accessors over a raw byte buffer, avoiding
/// per-cell Dart object allocations.
class RawCells {
  static const bytesPerCell = 24;
  static final empty = RawCells(ByteData(0), 0);

  final int length;
  final ByteData _data;

  RawCells(this._data, this.length);

  int codepoint(int i) => _data.getUint32(i * bytesPerCell, Endian.little);

  int fgR(int i) => _data.getUint8(i * bytesPerCell + 4);

  int fgG(int i) => _data.getUint8(i * bytesPerCell + 5);

  int fgB(int i) => _data.getUint8(i * bytesPerCell + 6);

  int bgR(int i) => _data.getUint8(i * bytesPerCell + 7);

  int bgG(int i) => _data.getUint8(i * bytesPerCell + 8);

  int bgB(int i) => _data.getUint8(i * bytesPerCell + 9);

  int flags(int i) => _data.getUint8(i * bytesPerCell + 10);

  int wide(int i) => _data.getUint8(i * bytesPerCell + 11);

  int underlineStyle(int i) => _data.getUint8(i * bytesPerCell + 12);

  int graphemeLen(int i) => _data.getUint8(i * bytesPerCell + 13);

  int ulR(int i) => _data.getUint8(i * bytesPerCell + 14);

  int ulG(int i) => _data.getUint8(i * bytesPerCell + 15);

  int ulB(int i) => _data.getUint8(i * bytesPerCell + 16);

  int ulSet(int i) => _data.getUint8(i * bytesPerCell + 17);

  int contentTag(int i) => _data.getUint8(i * bytesPerCell + 18);

  int semanticContent(int i) => _data.getUint8(i * bytesPerCell + 19);

  int hasHyperlink(int i) => _data.getUint8(i * bytesPerCell + 20);
}

// Mirrors GhosttyTerminalConfig fields from the C struct.
class RawTerminalConfig {
  const RawTerminalConfig({
    this.scrollbackLimit = 10000,
    this.fgR = 0,
    this.fgG = 0,
    this.fgB = 0,
    this.fgSet = false,
    this.bgR = 0,
    this.bgG = 0,
    this.bgB = 0,
    this.bgSet = false,
    this.cursorR = 0,
    this.cursorG = 0,
    this.cursorB = 0,
    this.cursorSet = false,
    this.palette = const [],
  });

  final int scrollbackLimit;
  final int fgR;
  final int fgG;
  final int fgB;
  final bool fgSet;
  final int bgR;
  final int bgG;
  final int bgB;
  final bool bgSet;
  final int cursorR;
  final int cursorG;
  final int cursorB;
  final bool cursorSet;

  /// ANSI palette overrides as packed 0xRRGGBB values.
  ///
  /// Entries with index >= 16 are ignored. Only non-null entries in the
  /// list at indices 0-15 are applied; all others keep their defaults.
  final List<int?> palette;
}

// Mirrors GhosttySgrAttribute (tag + value union) from the C struct.
class RawSgrAttribute {
  RawSgrAttribute({
    required this.tag,
    this.r = 0,
    this.g = 0,
    this.b = 0,
    this.paletteIndex = 0,
    this.underlineStyle = 0,
    this.unknownFull = const [],
    this.unknownPartial = const [],
  });

  final int tag;
  final int r;
  final int g;
  final int b;
  final int paletteIndex;
  final int underlineStyle;
  final List<int> unknownFull;
  final List<int> unknownPartial;
}

// Maps to GhosttyKeyEncoderOption enum values from the C API.
abstract final class KeyEncoderOpt {
  static const cursorKeyApplication = 0;
  static const keypadKeyApplication = 1;
  static const ignoreKeypadWithNumlock = 2;
  static const altEscPrefix = 3;
  static const modifyOtherKeysState2 = 4;
  static const kittyFlags = 5;
  static const macosOptionAsAlt = 6;
}

// Event flags returned by ghostty_terminal_write (GHOSTTY_TERMINAL_EVENT_*).
abstract final class TerminalEventFlag {
  static const none = 0;
  static const int bell = 1 << 0;
  static const int titleChanged = 1 << 1;
  static const int mouseShapeChanged = 1 << 2;
  static const int repaint = 1 << 3;
  static const int modeChanged = 1 << 4;
  static const int hasResponse = 1 << 5;
}

// Mode bitmask bits from ghostty_terminal_get_modes (GHOSTTY_MODE_*).
abstract final class TerminalModeBits {
  static const int cursorKeys = 1 << 0;
  static const int keypadApplication = 1 << 1;
  static const int autoWrap = 1 << 2;
  static const int origin = 1 << 3;
  static const int insert = 1 << 4;
  static const int bracketedPaste = 1 << 5;
  static const int mouseX10 = 1 << 6;
  static const int mouseNormal = 1 << 7;
  static const int mouseButtonEvent = 1 << 8;
  static const int mouseAnyEvent = 1 << 9;
  static const int alternateScreen = 1 << 10;
  static const int mouseAlternateScroll = 1 << 11;
}

// Bit flags from GhosttyCell.flags in the C struct.
abstract final class CellFlags {
  static const int bold = 1 << 0;
  static const int italic = 1 << 1;
  static const int strikethrough = 1 << 2;
  static const int inverse = 1 << 3;
  static const int invisible = 1 << 4;
  static const int blink = 1 << 5;
  static const int faint = 1 << 6;
  static const int overline = 1 << 7;
}

// Maps to GhosttyOscCommandData enum values from the C API.
abstract final class OscDataField {
  static const changeWindowTitleStr = 1;
}

// Maps to GhosttySgrAttributeTag enum values from the C API.
abstract final class SgrTag {
  static const unset = 0;
  static const unknown = 1;
  static const bold = 2;
  static const resetBold = 3;
  static const italic = 4;
  static const resetItalic = 5;
  static const faint = 6;
  static const underline = 7;
  static const underlineColor = 8;
  static const underlineColor256 = 9;
  static const resetUnderlineColor = 10;
  static const overline = 11;
  static const resetOverline = 12;
  static const blink = 13;
  static const resetBlink = 14;
  static const inverse = 15;
  static const resetInverse = 16;
  static const invisible = 17;
  static const resetInvisible = 18;
  static const strikethrough = 19;
  static const resetStrikethrough = 20;
  static const directColorFg = 21;
  static const directColorBg = 22;
  static const bg8 = 23;
  static const fg8 = 24;
  static const resetFg = 25;
  static const resetBg = 26;
  static const brightBg8 = 27;
  static const brightFg8 = 28;
  static const bg256 = 29;
  static const fg256 = 30;
}

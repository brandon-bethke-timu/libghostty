import 'dart:typed_data';

import '../ffi/libghostty_enums.g.dart';
import 'types/types.dart';

export 'types/types.dart';

/// Platform-independent interface for libghostty-vt bindings.
///
/// Implemented by `NativeBindings` (dart:ffi) and `WasmBindings`
/// (dart:js_interop). Handles are opaque `int` values on both platforms.
///
/// Methods that wrap C functions returning `GhosttyResult` return a [Result]
/// enum value. For methods that also produce a value, the return type is a
/// [CResult] record. Callers decide how to handle non-success results
/// (e.g. via [checkCode] or [check]).
abstract interface class GhosttyBindings {
  CResult<int> keyEventNew();
  void keyEventFree(int handle);
  void keyEventSetAction(int handle, KeyAction action);
  KeyAction keyEventGetAction(int handle);
  void keyEventSetKey(int handle, Key key);
  Key keyEventGetKey(int handle);
  void keyEventSetMods(int handle, int mods);
  int keyEventGetMods(int handle);
  void keyEventSetConsumedMods(int handle, int mods);
  int keyEventGetConsumedMods(int handle);
  void keyEventSetComposing(int handle, {required bool composing});
  bool keyEventGetComposing(int handle);
  void keyEventSetUtf8(int handle, String? text);
  String? keyEventGetUtf8(int handle);
  void keyEventSetUnshiftedCodepoint(int handle, int codepoint);
  int keyEventGetUnshiftedCodepoint(int handle);

  CResult<int> keyEncoderNew();
  void keyEncoderFree(int handle);
  void keyEncoderSetBoolOpt(
    int handle,
    KeyEncoderOption option, {
    required bool value,
  });
  void keyEncoderSetKittyFlags(int handle, int flags);
  void keyEncoderSetOptionAsAlt(int handle, OptionAsAlt value);
  void keyEncoderSetOptFromTerminal(int encoder, int terminal);
  CResult<String> keyEncoderEncode(int encoder, int event);

  CResult<int> mouseEventNew();
  void mouseEventFree(int handle);
  void mouseEventSetAction(int handle, MouseAction action);
  MouseAction mouseEventGetAction(int handle);
  void mouseEventSetButton(int handle, MouseButton button);
  void mouseEventClearButton(int handle);

  CResult<MouseButton> mouseEventGetButton(int handle);
  void mouseEventSetMods(int handle, int mods);
  int mouseEventGetMods(int handle);
  void mouseEventSetPosition(int handle, double x, double y);
  (double x, double y) mouseEventGetPosition(int handle);

  CResult<int> mouseEncoderNew();
  void mouseEncoderFree(int handle);
  void mouseEncoderSetBoolOpt(
    int handle,
    MouseEncoderOption option, {
    required bool value,
  });
  void mouseEncoderSetTrackingMode(int handle, MouseTrackingMode mode);
  void mouseEncoderSetFormat(int handle, MouseFormat format);
  void mouseEncoderSetSize(int handle, MouseEncoderSize size);
  void mouseEncoderSetOptFromTerminal(int encoder, int terminal);
  void mouseEncoderReset(int handle);
  CResult<String> mouseEncoderEncode(int encoder, int event);

  CResult<int> oscNew();
  void oscFree(int handle);
  void oscFeedByte(int handle, int byte);
  int oscEnd(int handle, int terminator);
  OscCommandType oscCommandType(int command);
  String? oscCommandWindowTitle(int command);
  void oscReset(int handle);

  CResult<int> sgrNew();
  void sgrFree(int handle);
  Result sgrSetParams(int handle, List<int> params, List<String>? separators);
  SgrAttribute? sgrNext(int handle);
  void sgrReset(int handle);

  bool pasteIsSafe(String data);

  CResult<int> terminalNew(int cols, int rows, int maxScrollback);
  void terminalFree(int handle);
  void terminalVtWrite(int handle, Uint8List data);
  Result terminalResize(
    int handle,
    int cols,
    int rows,
    int cellWidthPx,
    int cellHeightPx,
  );
  void terminalReset(int handle);
  void terminalScrollViewport(
    int handle,
    TerminalScrollViewportTag tag,
    int delta,
  );
  CResult<int> terminalGetCols(int handle);
  CResult<int> terminalGetRows(int handle);
  CResult<int> terminalGetCursorX(int handle);
  CResult<int> terminalGetCursorY(int handle);
  CResult<bool> terminalGetCursorVisible(int handle);
  CResult<bool> terminalGetCursorPendingWrap(int handle);
  CResult<TerminalScreen> terminalGetActiveScreen(int handle);
  CResult<int> terminalGetKittyKeyboardFlags(int handle);
  CResult<Scrollbar> terminalGetScrollbar(int handle);
  CResult<bool> terminalModeGet(int handle, int mode);
  Result terminalModeSet(int handle, int mode, {required bool value});
  CResult<String> terminalGetTitle(int handle);
  CResult<String> terminalGetPwd(int handle);
  CResult<int> terminalGetTotalRows(int handle);
  CResult<int> terminalGetScrollbackRows(int handle);
  CResult<int> terminalGetWidthPx(int handle);
  CResult<int> terminalGetHeightPx(int handle);
  Result terminalSetTitle(int handle, String? title);
  Result terminalSetPwd(int handle, String? pwd);
  Result terminalSetColorForeground(int handle, RgbColor? color);
  Result terminalSetColorBackground(int handle, RgbColor? color);
  Result terminalSetColorCursor(int handle, RgbColor? color);
  Result terminalSetColorPalette(int handle, List<RgbColor>? palette);

  CResult<RgbColor> terminalGetColorForeground(int handle);
  CResult<RgbColor> terminalGetColorBackground(int handle);
  CResult<RgbColor> terminalGetColorCursor(int handle);
  CResult<List<RgbColor>> terminalGetColorPalette(int handle);

  CResult<RgbColor> terminalGetColorForegroundDefault(int handle);
  CResult<RgbColor> terminalGetColorBackgroundDefault(int handle);
  CResult<RgbColor> terminalGetColorCursorDefault(int handle);
  CResult<List<RgbColor>> terminalGetColorPaletteDefault(int handle);

  CResult<Style> terminalGetCursorStyle(int handle);
  CResult<bool> terminalGetMouseTracking(int handle);

  CResult<int> terminalGetKittyImageStorageLimit(int handle);
  CResult<bool> terminalGetKittyImageMediumFile(int handle);
  CResult<bool> terminalGetKittyImageMediumTempFile(int handle);
  CResult<bool> terminalGetKittyImageMediumSharedMem(int handle);
  Result terminalSetKittyImageStorageLimit(int handle, int? limit);
  Result terminalSetKittyImageMediumFile(int handle, {bool? enabled});
  Result terminalSetKittyImageMediumTempFile(int handle, {bool? enabled});
  Result terminalSetKittyImageMediumSharedMem(int handle, {bool? enabled});

  CResult<Uint8List> pasteEncode(String data, {required bool bracketed});

  void terminalSetOnWritePty(int handle, ValueSetter<Uint8List>? callback);
  void terminalSetOnBell(int handle, VoidCallback? callback);
  void terminalSetOnTitleChanged(int handle, VoidCallback? callback);
  void terminalSetOnEnquiry(int handle, ValueGetter<Uint8List>? callback);
  void terminalSetOnXtversion(int handle, ValueGetter<String>? callback);
  void terminalSetOnColorScheme(
    int handle,
    ValueGetter<ColorScheme?>? callback,
  );
  void terminalSetOnSize(int handle, ValueGetter<TerminalSizeInfo?>? callback);
  void terminalSetOnDeviceAttributes(
    int handle,
    ValueGetter<DeviceAttributesResponse?>? callback,
  );
  void terminalDisposeCallbacks(int handle);

  CResult<int> renderStateNew();
  void renderStateFree(int handle);
  Result renderStateUpdate(int state, int terminal);
  CResult<int> renderStateGetCols(int state);
  CResult<int> renderStateGetRows(int state);
  CResult<RenderStateDirty> renderStateGetDirty(int state);
  Result renderStateSetDirty(int state, RenderStateDirty dirty);
  CResult<TerminalColors> renderStateGetColors(int state);
  CResult<RenderStateCursorVisualStyle> renderStateGetCursorVisualStyle(
    int state,
  );
  CResult<bool> renderStateGetCursorVisible(int state);
  CResult<bool> renderStateGetCursorBlinking(int state);
  CResult<bool> renderStateGetCursorPasswordInput(int state);
  CResult<bool> renderStateGetCursorInViewport(int state);
  CResult<int> renderStateGetCursorViewportX(int state);
  CResult<int> renderStateGetCursorViewportY(int state);
  CResult<bool> renderStateGetCursorViewportWideTail(int state);

  CResult<int> rowIteratorNew();
  void rowIteratorFree(int handle);

  /// Populates the iterator from the render state and resets its position.
  Result rowIteratorInit(int iterator, int renderState);
  bool rowIteratorNext(int iterator);
  CResult<bool> rowIteratorGetDirty(int iterator);
  Result rowIteratorSetDirty(int iterator, {required bool dirty});
  CResult<int> rowIteratorGetRawRow(int iterator);

  CResult<int> rowCellsNew();
  void rowCellsFree(int handle);

  /// Populates the cells from the current row in the iterator.
  Result rowCellsInit(int cells, int iterator);
  bool rowCellsNext(int cells);
  Result rowCellsSelect(int cells, int x);
  CResult<int> rowCellsGetRawCell(int cells);
  CResult<Style> rowCellsGetStyle(int cells);
  CResult<int> rowCellsGetGraphemeLen(int cells);
  CResult<List<int>> rowCellsGetGraphemes(int cells, int len);
  CResult<RgbColor> rowCellsGetBgColor(int cells);
  CResult<RgbColor> rowCellsGetFgColor(int cells);
  CResult<int> rowCellsGetBgColorArgb(int cells);
  CResult<int> rowCellsGetFgColorArgb(int cells);

  CResult<int> cellGetCodepoint(int cell);
  CResult<CellContentTag> cellGetContentTag(int cell);
  CResult<CellWide> cellGetWide(int cell);
  CResult<bool> cellGetHasText(int cell);
  CResult<bool> cellGetHasStyling(int cell);
  CResult<int> cellGetStyleId(int cell);
  CResult<bool> cellGetHasHyperlink(int cell);
  CResult<bool> cellGetProtected(int cell);
  CResult<CellSemanticContent> cellGetSemanticContent(int cell);
  CResult<int> cellGetColorPalette(int cell);
  CResult<RgbColor> cellGetColorRgb(int cell);

  CResult<bool> rowGetWrap(int row);
  CResult<bool> rowGetWrapContinuation(int row);
  CResult<bool> rowGetGrapheme(int row);
  CResult<bool> rowGetStyled(int row);
  CResult<bool> rowGetHyperlink(int row);
  CResult<RowSemanticPrompt> rowGetSemanticPrompt(int row);
  CResult<bool> rowGetKittyVirtualPlaceholder(int row);
  CResult<bool> rowGetDirty(int row);

  CResult<String> focusEncode(FocusEvent event);

  CResult<int> buildInfo(BuildInfo data);
  CResult<bool> buildInfoBool(BuildInfo data);
  CResult<String> buildInfoString(BuildInfo data);

  CResult<String> modeReportEncode(int mode, ModeReportState state);

  CResult<String> sizeReportEncode(
    SizeReportStyle style,
    int rows,
    int columns,
    int cellWidth,
    int cellHeight,
  );

  Style styleDefault();
  bool styleIsDefault(Style style);

  CResult<int> terminalGridRef(int terminal, PointTag pointTag, int x, int y);
  CResult<({int col, int row})> terminalPointFromGridRef(
    int terminal,
    int ref,
    PointTag pointTag,
  );
  void gridRefFree(int ref);
  CResult<int> gridRefCell(int ref);
  CResult<int> gridRefRow(int ref);
  CResult<Style> gridRefStyle(int ref);
  CResult<List<int>> gridRefGraphemes(int ref);
  CResult<String> gridRefHyperlinkUri(int ref);

  CResult<int> formatterTerminalNew(
    int terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
  });
  void formatterFree(int formatter);
  CResult<String> formatterFormat(int formatter);
}

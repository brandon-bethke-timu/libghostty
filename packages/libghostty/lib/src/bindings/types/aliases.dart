import 'dart:typed_data';

import '../../ffi/libghostty_enums.g.dart';

/// Cell wide property.
///
/// Describes the width behavior of a cell.
typedef CellWidth = CellWide;

/// Visual style of the cursor.
typedef CursorShape = RenderStateCursorVisualStyle;

/// Mouse tracking mode.
typedef MouseTracking = MouseTrackingMode;

/// Semantic content type of a cell.
///
/// Set by semantic prompt sequences (OSC 133) to distinguish between
/// command output, user input, and shell prompt text.
typedef SemanticContent = CellSemanticContent;

/// Row semantic prompt state.
///
/// Indicates whether any cells in a row are part of a shell prompt,
/// as reported by OSC 133 sequences.
typedef SemanticPrompt = RowSemanticPrompt;

/// Underline style types.
typedef UnderlineStyle = SgrUnderline;

typedef ValueGetter<T> = T Function();
typedef ValueSetter<T> = void Function(T value);
typedef VoidCallback = void Function();

/// A selection range addressed by `GridRef` handles. `rectangle` indicates
/// a rectangular (block) selection rather than a linear one.
typedef RawSelection = ({int start, int end, bool rectangle});

/// Callback invoked for each internal libghostty log message, after the
/// scope and message byte slices have been decoded to Dart strings.
typedef SysLogCallback =
    void Function(SysLogLevel level, String scope, String message);

/// An image decoded from PNG into top-to-bottom RGBA pixel bytes.
typedef DecodedImage = ({int width, int height, Uint8List rgba});

/// Callback that decodes PNG bytes to RGBA pixels.
///
/// Invoked by libghostty for every Kitty graphics payload received in
/// PNG form. Returning null signals a decode failure; the library
/// rejects the payload and no image is stored.
typedef PngDecoder = DecodedImage? Function(Uint8List pngBytes);

/// Raw placement metadata read from a Kitty graphics placement
/// iterator.
///
/// Sub-cell offsets and source rectangles are in pixels. `columns` and
/// `rows` may be zero when the protocol leaves the grid extent implicit
/// (the size is then derived from the image). `z` is signed; see
/// [KittyPlacementLayer] for how it maps to paint order.
typedef RawPlacement = ({
  int imageId,
  int placementId,
  bool isVirtual,
  int xOffset,
  int yOffset,
  int sourceX,
  int sourceY,
  int sourceWidth,
  int sourceHeight,
  int columns,
  int rows,
  int z,
});

/// Resolved rendering geometry for a placement, combining rendered
/// pixel size, grid extent, viewport-relative position, and the
/// clamped source rectangle.
///
/// `viewportCol`/`viewportRow` are meaningful only when
/// `viewportVisible` is true. Source rectangle fields have the
/// protocol's "0 means full image" semantics already applied and are
/// clamped to the image bounds.
typedef RawPlacementRenderInfo = ({
  int pixelWidth,
  int pixelHeight,
  int gridCols,
  int gridRows,
  int viewportCol,
  int viewportRow,
  bool viewportVisible,
  int sourceX,
  int sourceY,
  int sourceWidth,
  int sourceHeight,
});

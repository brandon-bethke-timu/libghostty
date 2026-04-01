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

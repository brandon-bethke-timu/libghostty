import 'package:flutter/foundation.dart';

import 'terminal_selection.dart';

/// A modifier key used to trigger gesture behaviors.
enum GestureModifier { alt, control, meta, shift }

/// How triple-click line selection determines the end column.
enum LineSelectMode {
  /// Selection ends at the last content cell, excluding trailing empties.
  content,

  /// Selection extends to the full row width.
  full,
}

/// A type of selection gesture.
enum SelectionGesture {
  /// Click+drag on desktop (mouse).
  drag,

  /// Double-tap word selection.
  word,

  /// Triple-tap line selection.
  line,

  /// Long press on touch devices.
  longPress,

  /// Select all via keyboard shortcut (Cmd+A / Ctrl+A).
  selectAll;

  static const all = <SelectionGesture>{
    .drag,
    .word,
    .line,
    .longPress,
    .selectAll,
  };
}

/// Controls which selection gestures are enabled and how they behave.
///
/// ```dart
/// TerminalView(
///   terminal: terminal,
///   gestureSettings: TerminalGestureSettings(
///     enabledSelections: {SelectionGesture.word, SelectionGesture.line},
///     blockSelectionModifier: GestureModifier.meta,
///   ),
/// )
/// ```
@immutable
final class TerminalGestureSettings {
  /// Which selection gestures are active.
  ///
  /// Defaults to all gestures enabled. Pass an empty set to disable
  /// selection entirely. Mouse tracking and focus gestures still work
  /// regardless of this setting.
  final Set<SelectionGesture> enabledSelections;

  /// How triple-click line selection determines the end column.
  ///
  /// Defaults to [LineSelectMode.content], which trims trailing empty
  /// cells. Set to [LineSelectMode.full] to always select the full
  /// row width.
  final LineSelectMode lineSelectMode;

  /// Modifier key that triggers block (rectangular) selection during drag.
  ///
  /// Set to null to disable block selection via modifier key.
  ///
  /// Avoid [GestureModifier.shift] here: Shift is also used to bypass
  /// mouse tracking, so the two behaviors would overlap.
  final GestureModifier? blockSelectionModifier;

  /// Selection mode used when long-pressing on touch devices.
  ///
  /// Defaults to [TerminalSelectionMode.normal]. Set to
  /// [TerminalSelectionMode.block] for rectangular selection on long press.
  final TerminalSelectionMode longPressSelectionMode;

  const TerminalGestureSettings({
    this.lineSelectMode = LineSelectMode.content,
    this.enabledSelections = SelectionGesture.all,
    this.blockSelectionModifier = GestureModifier.alt,
    this.longPressSelectionMode = TerminalSelectionMode.normal,
  });

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(enabledSelections),
    blockSelectionModifier,
    longPressSelectionMode,
    lineSelectMode,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalGestureSettings &&
          setEquals(enabledSelections, other.enabledSelections) &&
          blockSelectionModifier == other.blockSelectionModifier &&
          longPressSelectionMode == other.longPressSelectionMode &&
          lineSelectMode == other.lineSelectMode;
}

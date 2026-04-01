# libghostty

[![pub package](https://img.shields.io/pub/v/libghostty)](https://pub.dev/packages/libghostty)
[![GitHub Actions](https://github.com/elias8/libghostty/actions/workflows/build.yml/badge.svg)](https://github.com/elias8/libghostty/actions)

Dart FFI & WASM bindings to [libghostty-vt](https://github.com/ghostty-org/ghostty),
the terminal emulator library from [Ghostty](https://ghostty.org).

| Android | iOS | macOS | Linux | Windows | Web |
|:-------:|:---:|:-----:|:-----:|:-------:|:---:|
|    ✅    |  ✅  |   ✅   |   ✅   |    ✅    |  ✅  |

## Getting started

```yaml
dependencies:
  libghostty: ^0.0.4
```

## Usage

### Terminal emulation with effects

```dart
import 'dart:typed_data';
import 'package:libghostty/libghostty.dart';

void main() {
  final terminal = Terminal(cols: 80, rows: 24);

  // Register effects (callbacks invoked synchronously during write).
  terminal.onWritePty = (data) => pty.write(data);
  terminal.onBell = () => playSound();
  terminal.onTitleChanged = () => print('Title: ${terminal.title}');

  // Write VT data and resize.
  terminal.write(Uint8List.fromList(vtData));
  terminal.resize(cols: 120, rows: 40, cellWidthPx: 8, cellHeightPx: 16);

  // Read a single cell via grid reference (for ad-hoc lookups).
  final ref = terminal.gridRefAt(col: 0, row: 0);
  print(ref.content); // the character at (0, 0)
  ref.dispose();

  // Read screen via render state (for render loops).
  terminal.renderState.update();
  while (terminal.renderState.nextRow()) {
    while (terminal.renderState.nextCell()) {
      final cell = terminal.renderState.cell;
      if (cell.hasText) print(cell.content);
    }
  }
  terminal.renderState.markClean();

  terminal.dispose();
}
```

### Key encoding

```dart
final event = KeyEvent()
  ..action = .press
  ..key = .c
  ..mods = const Mods.ctrl();

final encoded = terminal.keyEncoder.encode(event);
if (encoded.isNotEmpty) pty.write(utf8.encode(encoded));
event.dispose();
```

### Mouse encoding

```dart
// Sync tracking mode from terminal after each write.
terminal.mouseEncoder.syncFrom(terminal);
terminal.mouseEncoder.setSize(const MouseEncoderSize(
  screenWidth: 640,
  screenHeight: 384,
  cellWidth: 8,
  cellHeight: 16,
));

final event = MouseEvent()
  ..action = .press
  ..button = .left;
event.setPosition(10.0, 5.0);

final encoded = terminal.mouseEncoder.encode(event);
if (encoded.isNotEmpty) pty.write(utf8.encode(encoded));
event.dispose();
```

### Formatting terminal content

```dart
final formatter = terminal.createFormatter(format: .plain);
print(formatter.format());
formatter.dispose();
```

### SGR and OSC parsing

```dart
// SGR: parse Select Graphic Rendition parameters.
final sgr = SgrParser();
for (final attr in sgr.parse([1, 38, 2, 255, 0, 0])) {
  switch (attr.tag) {
    case .bold:
      print('bold');
    case .directColorFg:
      print('fg: ${attr.color}');
    default:
      break;
  }
}
sgr.dispose();

// OSC: parse Operating System Command sequences.
final osc = OscParser();
osc.feedBytes(utf8.encode('0;My Title'));
final command = osc.end(0x07);
print(command.type);        // OscCommandType.changeWindowTitle
print(command.windowTitle); // My Title
osc.dispose();
```

### Paste safety

```dart
pasteIsSafe('hello');           // true
pasteIsSafe('rm -rf /\n');      // false
pasteIsSafe('\x1b[201~inject'); // false
```

### Web (WASM)

```dart
// Call once before using any bindings on web. No-op on other platforms.
await initializeForWeb(Uri.parse('assets/libghostty.wasm'));
```

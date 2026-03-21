# flterm

A high-performance terminal emulator renderer for Flutter, powered by
[Ghostty](https://ghostty.org)'s virtual terminal engine
([libghostty-vt](https://github.com/elias8/libghostty)).

| Android | iOS | Linux | macOS | Web | Windows |
|:-------:|:---:|:-----:|:-----:|:---:|:-------:|
|    ✅    |  ✅  |   ✅   |   ✅   |  ✅  |    ✅    |

> [!CAUTION]
> This package is under active development. The API is unstable and breaking
> changes are expected between releases.

## Features

- Three-layer rendering: content, cursor, and selection with per-row caching
- Wide character support (CJK, emoji) with correct selection snapping
- Multi-tap selection: word (double-click), line (triple-click), block (Alt+drag)
- Platform-adaptive shortcuts: copy, paste, select all, clear
- Soft keyboard input for mobile platforms
- Scrollback with smooth scrolling and alternate screen support
- Configurable theming: colors, cursor shape, hyperlink styles, font
- Runs on Android, iOS, Linux, macOS, Web, and Windows

## Getting started

Add `flterm` and `libghostty` to your `pubspec.yaml`:

```yaml
dependencies:
  flterm: ^0.0.1-dev.1
  libghostty: ^0.0.4
```

For web, call `initializeForWeb` before using the terminal:

```dart
import 'package:libghostty/libghostty.dart';

if (kIsWeb) {
  await initializeForWeb(Uri.parse('path/to/libghostty.wasm'));
}
```

## Usage

Minimal setup:

```dart
import 'package:flterm/flterm.dart';
import 'package:libghostty/libghostty.dart';

final terminal = Terminal(cols: 80, rows: 24);

TerminalView(terminal: terminal)
```

With PTY integration:

```dart
TerminalView(
  terminal: terminal,
  onOutput: (bytes) => pty.write(bytes),
  onResize: (size) => pty.resize(size.cols, size.rows),
)
```

With programmatic control:

```dart
final controller = TerminalController();

TerminalView(
  terminal: terminal,
  controller: controller,
);

controller.sendText('ls -la\n');
controller.selectAll();
print(controller.selectedText);
```

## License

MIT. See [LICENSE](LICENSE) for details.

import 'dart:convert';

import 'package:flterm/flterm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:libghostty/libghostty.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await initializeForWeb(
      Uri.parse('assets/assets/libghostty-wasm32-freestanding.wasm'),
    );
  }
  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'flterm_example',
      theme: ThemeData.dark(),
      home: const _DemoScreen(),
    );
  }
}

class _DemoScreen extends StatefulWidget {
  const _DemoScreen();

  @override
  State<_DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<_DemoScreen> {
  late final Terminal _terminal;
  late final TerminalController _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TerminalView(terminal: _terminal, controller: _controller),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _terminal.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(cols: 80, rows: 24);
    _controller = TerminalController();

    final buf = StringBuffer()
      ..write('\x1b[2J\x1b[H')
      ..write('\x1b[1m  flterm Demo\x1b[0m\r\n\r\n')
      ..write('  Attributes: ')
      ..write('\x1b[1mBold\x1b[0m \x1b[3mItalic\x1b[0m ')
      ..write('\x1b[2mFaint\x1b[0m \x1b[7mInverse\x1b[0m\r\n')
      ..write('  Underline:  ')
      ..write('\x1b[4mSingle\x1b[0m \x1b[4:2mDouble\x1b[0m ')
      ..write('\x1b[4:3mCurly\x1b[0m \x1b[4:4mDotted\x1b[0m ')
      ..write('\x1b[4:5mDashed\x1b[0m\r\n')
      ..write('  Colors:     ');
    for (var i = 0; i < 8; i++) {
      buf.write('\x1b[${40 + i}m  \x1b[0m');
    }
    buf.write(' ');
    for (var i = 0; i < 8; i++) {
      buf.write('\x1b[${100 + i}m  \x1b[0m');
    }
    buf.write('\r\n');

    _terminal.write(Uint8List.fromList(utf8.encode(buf.toString())));
  }
}

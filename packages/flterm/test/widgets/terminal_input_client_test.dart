import 'package:flterm/src/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TerminalInputClient handler;
  late List<String> commits;
  late List<int> deletes;
  late List<void> newlines;

  setUp(() {
    handler = TerminalInputClient();
    commits = [];
    deletes = [];
    newlines = [];
    handler.onTextCommitted = commits.add;
    handler.onDelete = deletes.add;
    handler.onNewline = () => newlines.add(null);
  });

  group('TerminalInputClient', () {
    test('insertion commits text', () {
      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: '',
          textInserted: 'a',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      ]);

      expect(commits, ['a']);
    });

    test('multi-char insertion commits all characters', () {
      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: '',
          textInserted: 'hello',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange.empty,
        ),
      ]);

      expect(commits, ['hello']);
    });

    test('deletion reports character count', () {
      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: '',
          textInserted: 'ab',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange.empty,
        ),
      ]);
      commits.clear();

      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaDeletion(
          oldText: 'ab',
          deletedRange: TextRange(start: 1, end: 2),
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      ]);

      expect(deletes, [1]);
    });

    test('multi-char deletion reports full count', () {
      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaDeletion(
          oldText: 'abc',
          deletedRange: TextRange(start: 0, end: 3),
          selection: TextSelection.collapsed(offset: 0),
          composing: TextRange.empty,
        ),
      ]);

      expect(deletes, [3]);
    });

    test('composing insertion does not commit', () {
      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: '',
          textInserted: 'n',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      ]);

      expect(commits, isEmpty);
    });

    test('composing commit sends final text', () {
      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: '',
          textInserted: 'n',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      ]);

      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaReplacement(
          oldText: 'n',
          replacementText: 'ni',
          replacedRange: TextRange(start: 0, end: 1),
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      ]);

      expect(commits, isEmpty);

      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaReplacement(
          oldText: 'ni',
          replacementText: '\u4f60',
          replacedRange: TextRange(start: 0, end: 2),
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      ]);

      expect(commits, ['\u4f60']);
    });

    test('composing fires onComposingChanged', () {
      final composing = <String>[];
      handler.onComposingChanged = composing.add;

      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: '',
          textInserted: 'n',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      ]);

      expect(composing, ['n']);

      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaReplacement(
          oldText: 'n',
          replacementText: 'ni',
          replacedRange: TextRange(start: 0, end: 1),
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      ]);

      expect(composing, ['n', 'ni']);
    });

    test('composing commit fires empty composing callback', () {
      final composing = <String>[];
      handler.onComposingChanged = composing.add;

      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: '',
          textInserted: 'a',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      ]);

      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaReplacement(
          oldText: 'a',
          replacementText: 'A',
          replacedRange: TextRange(start: 0, end: 1),
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
      ]);

      expect(composing, ['a', '']);
    });

    test('performAction newline fires onNewline', () {
      handler.performAction(TextInputAction.newline);
      expect(newlines, hasLength(1));
    });

    test('non-composing replacement commits replacement text', () {
      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: '',
          textInserted: 'ab',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange.empty,
        ),
      ]);
      commits.clear();

      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaReplacement(
          oldText: 'ab',
          replacementText: 'cd',
          replacedRange: TextRange(start: 0, end: 2),
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange.empty,
        ),
      ]);

      expect(commits, ['cd']);
    });

    test('nonTextUpdate does not fire any callback', () {
      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaNonTextUpdate(
          oldText: '',
          selection: TextSelection.collapsed(offset: 0),
          composing: TextRange.empty,
        ),
      ]);

      expect(commits, isEmpty);
      expect(deletes, isEmpty);
      expect(newlines, isEmpty);
    });

    test('attach closes existing connection', () {
      handler.attach();
      expect(handler.isAttached, isTrue);

      handler.attach(keyboardAppearance: Brightness.light);
      expect(handler.isAttached, isTrue);

      handler.detach();
    });

    test('detach resets state', () {
      handler.attach();
      handler.detach();
      expect(handler.isAttached, isFalse);
    });

    test('insertion strips newlines', () {
      handler.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: '',
          textInserted: 'a\nb\rc',
          insertionOffset: 0,
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange.empty,
        ),
      ]);

      expect(commits, ['abc']);
    });
  });
}

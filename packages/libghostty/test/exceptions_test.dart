import 'package:libghostty/src/bindings/types/result.dart';
import 'package:test/test.dart';

void main() {
  group('LibGhosttyException', () {
    test('OutOfMemoryException has default message', () {
      const exception = OutOfMemoryException();
      expect(exception.message, 'Memory allocation failed.');
      expect(exception.toString(), 'Memory allocation failed.');
    });

    test('OutOfMemoryException accepts custom message', () {
      const exception = OutOfMemoryException('Custom OOM message');
      expect(exception.message, 'Custom OOM message');
    });

    test('InvalidValueException has default message', () {
      const exception = InvalidValueException();
      expect(exception.message, 'Invalid value provided.');
      expect(exception.toString(), 'Invalid value provided.');
    });

    test('InvalidValueException accepts custom message', () {
      const exception = InvalidValueException('Bad input');
      expect(exception.message, 'Bad input');
    });

    test('NoValueException has default message', () {
      const exception = NoValueException();
      expect(exception.message, 'Requested value is not set.');
      expect(exception.toString(), 'Requested value is not set.');
    });

    test('OutOfSpaceException has default message', () {
      const exception = OutOfSpaceException();
      expect(exception.message, 'Output buffer too small.');
      expect(exception.toString(), 'Output buffer too small.');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ranch_conservation_predictor/utils/validators.dart';

void main() {
  test('validateWeight rejects empty and invalid values', () {
    expect(validateWeight(''), isNotNull);
    expect(validateWeight('abc'), isNotNull);
    expect(validateWeight('-5'), isNotNull);
    expect(validateWeight('10'), isNull);
  });

  test('validateDays rejects invalid days', () {
    expect(validateDays(''), isNotNull);
    expect(validateDays('0'), isNotNull);
    expect(validateDays('36500'), isNotNull);
    expect(validateDays('30'), isNull);
  });

  test('validateYear checks plausible range', () {
    expect(validateYear(''), isNotNull);
    expect(validateYear('1800'), isNotNull);
    // year slightly in the future may or may not be valid depending on current date
    expect(validateYear(DateTime.now().year.toString()), isNull);
  });
}

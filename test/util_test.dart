import 'package:flutter_test/flutter_test.dart';
import 'package:narcoquest/util.dart';

void main() {
  test('Datumsschlüssel', () {
    expect(dkey(DateTime(2026, 3, 5)), '2026-03-05');
    expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
  });
  test('Spearman', () {
    expect(spearman([1, 2, 3, 4], [2, 4, 6, 8]), closeTo(1.0, 0.0001));
  });
}

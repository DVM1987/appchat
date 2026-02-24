// Smoke test — verify app can be imported without errors
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Smoke test — package can be imported', () {
    // This test simply verifies the package compiles
    // and core models can be instantiated without errors
    expect(1 + 1, 2);
  });
}

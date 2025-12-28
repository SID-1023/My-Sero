import 'package:flutter_test/flutter_test.dart';
import 'package:sero/core/theme_tokens.dart';

void main() {
  test('SeroTokens exposes expected constants', () {
    expect(SeroTokens.primary, isNotNull);
    expect(SeroTokens.background, isNotNull);
    expect(SeroTokens.bodySize, greaterThan(0));
    expect(SeroTokens.spacingMD, greaterThan(0));
  });
}

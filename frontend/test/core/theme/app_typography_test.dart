import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:murassikh_app/core/theme/app_typography.dart';

void main() {
  test('AppTypography has explicit font sizes for all text styles', () {
    final textTheme = AppTypography.textTheme;
    
    // Test that we can apply a fontSizeFactor without crashing
    // (This is what caused the red screen bug)
    expect(() => textTheme.apply(fontSizeFactor: 1.5), returnsNormally);
    
    final scaledTheme = textTheme.apply(fontSizeFactor: 1.5);
    
    // Let's verify some specific sizes actually scaled
    expect(scaledTheme.bodyLarge?.fontSize, textTheme.bodyLarge!.fontSize! * 1.5);
    expect(scaledTheme.titleLarge?.fontSize, textTheme.titleLarge!.fontSize! * 1.5);
  });
}

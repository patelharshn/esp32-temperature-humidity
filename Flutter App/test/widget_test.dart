import 'package:flutter_test/flutter_test.dart';
import 'package:esp32_door_lock/core/theme/app_theme.dart';
import 'package:esp32_door_lock/widgets/custom_button.dart';
import 'package:esp32_door_lock/widgets/live_pulse_indicator.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('CustomButton renders text and triggers callback', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: CustomButton(
            text: 'Test Button',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Test Button'), findsOneWidget);
    await tester.tap(find.text('Test Button'));
    expect(tapped, isTrue);
  });

  testWidgets('LivePulseIndicator renders without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LivePulseIndicator(color: Colors.green),
        ),
      ),
    );

    expect(find.byType(LivePulseIndicator), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapstore/theme.dart';
import 'package:zapstore/widgets/onboarding/slot_machine.dart';

Future<List<FlutterErrorDetails>> _pumpAndCollectOverflow(
  WidgetTester tester,
  Widget child,
) async {
  final errors = <FlutterErrorDetails>[];
  final old = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) {
      errors.add(details);
    }
    old?.call(details);
  };

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [LabColors.dark()]),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();

  return errors;
}

void main() {
  const sampleNsec =
      'nsec1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijkl';

  testWidgets('SpinKeySlotMachine idle layout has no overflow', (tester) async {
    final errors = await _pumpAndCollectOverflow(
      tester,
      const SpinKeySlotMachine(initialNsec: sampleNsec),
    );
    FlutterError.onError = FlutterError.presentError;
    expect(errors, isEmpty);
  });

  testWidgets('SpinKeySlotMachine spin animation has no overflow', (
    tester,
  ) async {
    final errors = await _pumpAndCollectOverflow(
      tester,
      SpinKeySlotMachine(
        initialNsec: sampleNsec,
        settleDelay: Duration.zero,
      ),
    );

    await tester.drag(
      find
          .descendant(
            of: find.byType(SpinKeySlotMachine),
            matching: find.byType(GestureDetector),
          )
          .first,
      const Offset(0, 220),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    FlutterError.onError = FlutterError.presentError;
    expect(errors, isEmpty);
  });

  testWidgets('finale animation survives modal title swap', (tester) async {
    final revealed = ValueNotifier(false);
    final finaleProgress = ValueNotifier(0.0);
    final slotKey = GlobalKey<SpinKeySlotMachineState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [LabColors.dark()]),
        home: Scaffold(
          body: Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: revealed,
                builder: (_, isRevealed, __) =>
                    Text(isRevealed ? 'Great! 🎉' : 'Hey there!'),
              ),
              SpinKeySlotMachine(
                key: slotKey,
                initialNsec: sampleNsec,
                onFinaleProgress: (t) => finaleProgress.value = t,
                onFinaleComplete: () => revealed.value = true,
              ),
            ],
          ),
        ),
      ),
    );

    final stateRef = slotKey.currentState!;
    stateRef.debugStartFinale();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(slotKey.currentState, same(stateRef));
    expect(revealed.value, isFalse);
    expect(finaleProgress.value, greaterThan(0.2));
    expect(stateRef.finaleProgress, greaterThan(0.2));

    await tester.pump(const Duration(milliseconds: 300));

    expect(revealed.value, isTrue);
    expect(stateRef.finaleProgress, greaterThan(0.99));
  });
}

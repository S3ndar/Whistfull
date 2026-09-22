// ALTERATIONS.md (round 2) C3 — bar chart tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/stats/bar_chart.dart';
import 'package:whistly/theme/app_theme.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData(extensions: const [AppSemanticColors.light]),
        home: Scaffold(body: child),
      );

  testWidgets('11: a BarDatum list renders one row per datum', (tester) async {
    final data = [
      const BarDatum(label: 'Anke', value: 0.6, trailing: '60%'),
      const BarDatum(label: 'Bram', value: 0.4, trailing: '40%'),
      const BarDatum(label: 'Cato', value: 0.2, trailing: '20%'),
    ];
    await tester.pumpWidget(wrap(BarChart(data: data)));

    for (final datum in data) {
      expect(find.text(datum.label), findsOneWidget);
      expect(find.byKey(ValueKey('bar-fill-${datum.label}')), findsOneWidget);
    }
  });

  testWidgets('12: the largest value gets accent; the rest get ink', (tester) async {
    final data = [
      const BarDatum(label: 'Anke', value: 0.6, trailing: '60%'),
      const BarDatum(label: 'Bram', value: 0.4, trailing: '40%'),
    ];
    await tester.pumpWidget(wrap(BarChart(data: data)));

    final ankeFill = tester.widget<Container>(find.byKey(const ValueKey('bar-fill-Anke')));
    final bramFill = tester.widget<Container>(find.byKey(const ValueKey('bar-fill-Bram')));
    expect(ankeFill.color, AppSemanticColors.light.accent);
    expect(bramFill.color, AppSemanticColors.light.ink);
  });

  testWidgets('13: dimmed data renders in muted', (tester) async {
    final data = [
      const BarDatum(label: 'Anke', value: 1.0, trailing: '100%  n=1', dimmed: true),
      const BarDatum(label: 'Bram', value: 0.5, trailing: '50%  n=10'),
    ];
    await tester.pumpWidget(wrap(BarChart(data: data)));

    final ankeFill = tester.widget<Container>(find.byKey(const ValueKey('bar-fill-Anke')));
    // Anke is numerically the largest (1.0 > 0.5) but dimmed — must stay
    // muted, never accent. Bram, the largest ELIGIBLE bar, gets accent.
    expect(ankeFill.color, AppSemanticColors.light.muted);
    final bramFill = tester.widget<Container>(find.byKey(const ValueKey('bar-fill-Bram')));
    expect(bramFill.color, AppSemanticColors.light.accent);

    final ankeLabel = tester.widget<Text>(find.text('Anke'));
    expect(ankeLabel.style!.color, AppSemanticColors.light.muted);
  });

  testWidgets('14: an all-zero-value list renders full-height rows without throwing', (tester) async {
    final data = [
      const BarDatum(label: 'Anke', value: 0, trailing: '0%  n=0'),
      const BarDatum(label: 'Bram', value: 0, trailing: '0%  n=0'),
    ];
    // axisMax omitted: auto-derived from data, which is entirely zero —
    // this must not divide by zero or throw.
    await tester.pumpWidget(wrap(BarChart(data: data)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BarChart), findsOneWidget);
  });
}

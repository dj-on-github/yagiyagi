import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yagiyagi/antenna_design.dart';
import 'package:yagiyagi/main.dart';

void main() {
  testWidgets('Yagi designer renders settings and plots', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const YagiApp());

    expect(find.text('Antenna Designer'), findsOneWidget);
    expect(find.text('Antenna type'), findsOneWidget);
    expect(find.text('Design presets'), findsOneWidget);
    expect(find.text('Feed & matching'), findsOneWidget);
    expect(find.text('Horizontal (azimuth) gain pattern'), findsOneWidget);
    expect(find.text('Elevation gain pattern'), findsOneWidget);
    expect(find.text('Impedance & SWR vs frequency'), findsOneWidget);

    // Each column has its own scroll view; scroll the left (settings)
    // column independently to reach the summary card.
    expect(find.byType(SingleChildScrollView), findsNWidgets(2));
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -2000));
    await tester.pump();
    expect(find.text('Computed summary'), findsOneWidget);
  });

  testWidgets('Switching to dipole shows dipole configuration panels',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const YagiApp());
    expect(find.text('Design presets'), findsOneWidget);

    // Open the antenna-type dropdown and pick the dipole entry.
    await tester.tap(find.byType(DropdownButtonFormField<AntennaType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dipole antenna').last);
    await tester.pumpAndSettle();

    // Dipole-specific panels appear; yagi-only panels disappear.
    expect(find.text('Dipole dimensions'), findsOneWidget);
    expect(find.text('Environment'), findsOneWidget);
    expect(find.text('Design presets'), findsNothing);

    // Plots are still present and driven by the dipole design.
    expect(find.text('Horizontal (azimuth) gain pattern'), findsOneWidget);
    expect(find.text('Impedance & SWR vs frequency'), findsOneWidget);

    // Switch back to yagi.
    await tester.tap(find.byType(DropdownButtonFormField<AntennaType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yagi-Uda antenna').last);
    await tester.pumpAndSettle();
    expect(find.text('Design presets'), findsOneWidget);
    expect(find.text('Dipole dimensions'), findsNothing);
  });
  testWidgets('Switching to loop shows loop configuration panels',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const YagiApp());

    await tester.tap(find.byType(DropdownButtonFormField<AntennaType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loop antenna').last);
    await tester.pumpAndSettle();

    expect(find.text('Loop dimensions'), findsOneWidget);
    expect(find.text('Loop shape'), findsOneWidget);
    expect(find.text('Environment'), findsOneWidget);
    expect(find.text('Design presets'), findsNothing);
    expect(find.text('Dipole dimensions'), findsNothing);

    // Plots are driven by the loop design.
    expect(find.text('Horizontal (azimuth) gain pattern'), findsOneWidget);
    expect(find.text('Impedance & SWR vs frequency'), findsOneWidget);
  });
  testWidgets('Switching to cantenna shows waveguide configuration panels',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const YagiApp());

    await tester.tap(find.byType(DropdownButtonFormField<AntennaType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Waveguide antenna (cantenna)').last);
    await tester.pumpAndSettle();

    expect(find.text('Can dimensions'), findsOneWidget);
    expect(find.text('Probe feed'), findsOneWidget);
    expect(find.text('TE11 cutoff'), findsOneWidget);
    expect(find.textContaining('Single-mode'), findsOneWidget);
    expect(find.text('Design presets'), findsNothing);
    expect(find.text('Loop dimensions'), findsNothing);

    // Plots are driven by the cantenna design.
    expect(find.text('Horizontal (azimuth) gain pattern'), findsOneWidget);
    expect(find.text('Impedance & SWR vs frequency'), findsOneWidget);
  });
}

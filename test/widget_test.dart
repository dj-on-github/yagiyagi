import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yagiyagi/antenna_design.dart';
import 'package:yagiyagi/antenna_view3d.dart';
import 'package:yagiyagi/main.dart';
import 'package:yagiyagi/scene3d.dart';

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

  // Every antenna type: selecting it swaps in its own settings cards while
  // the three plots keep working.
  const panelMarkers = <AntennaType, List<String>>{
    AntennaType.vertical: ['Radiator', 'Ground system'],
    AntennaType.magLoop: ['Tuning capacitor', 'Loss budget'],
    AntennaType.lpda: ['Frequency range', 'Log-periodic geometry'],
    AntennaType.dish: ['Illumination', 'Surface accuracy'],
    AntennaType.helix: ['Helix geometry', 'Polarisation'],
    AntennaType.patch: ['Substrate', 'Q and efficiency'],
    AntennaType.moxon: ['Rectangle', 'Gap tuning'],
    AntennaType.horn: ['Horn aperture', 'Phase error'],
    AntennaType.phasedVerticals: ['Array geometry', 'Mutual coupling'],
    AntennaType.cornerReflector: [
      'Corner geometry',
      'Driven element impedance'
    ],
  };

  for (final entry in panelMarkers.entries) {
    testWidgets('Switching to ${entry.key.label} shows its panels',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const YagiApp());
      await selectAntennaType(tester, entry.key);

      for (final marker in entry.value) {
        // Some card titles are repeated as a readout label further down the
        // same panel, so one or more is the assertion.
        expect(find.text(marker), findsWidgets,
            reason: '${entry.key.label} should show a "$marker" card');
      }

      // Yagi-only panels are gone, and the plots still render.
      expect(find.text('Geometry'), findsNothing);
      expect(find.text('Horizontal (azimuth) gain pattern'), findsOneWidget);
      expect(find.text('Elevation gain pattern'), findsOneWidget);
      expect(find.text('Impedance & SWR vs frequency'), findsOneWidget);
    });
  }

  testWidgets('The 3D view sits below the plots and responds to the mouse',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const YagiApp());

    // It is the last card in the right-hand column.
    final plots = find.byType(SingleChildScrollView).last;
    await tester.drag(plots, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Antenna geometry'), findsOneWidget);

    final view = find.byType(AntennaView3d);
    expect(view, findsOneWidget);

    // Orbiting must not throw and must actually repaint.
    final before = tester.widget<CustomPaint>(find
        .descendant(of: view, matching: find.byType(CustomPaint))
        .first);
    await tester.drag(view, const Offset(60, 25));
    await tester.pumpAndSettle();
    final after = tester.widget<CustomPaint>(find
        .descendant(of: view, matching: find.byType(CustomPaint))
        .first);
    expect((before.painter as ScenePainter).camera.yawDeg,
        isNot((after.painter as ScenePainter).camera.yawDeg));

    // Double-click puts the camera back.
    await tester.tap(view);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(view);
    await tester.pumpAndSettle();
    final reset = tester.widget<CustomPaint>(find
        .descendant(of: view, matching: find.byType(CustomPaint))
        .first);
    expect((reset.painter as ScenePainter).camera.yawDeg,
        (before.painter as ScenePainter).camera.yawDeg);
  });

  testWidgets('The wheel zooms inside the 3D view and scrolls outside it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const YagiApp());
    await tester.drag(
        find.byType(SingleChildScrollView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();

    final view = find.byType(AntennaView3d);
    double cameraDistance() => (tester
            .widget<CustomPaint>(
                find.descendant(of: view, matching: find.byType(CustomPaint)).first)
            .painter as ScenePainter)
        .camera
        .distance;

    final mouse = TestPointer(1, PointerDeviceKind.mouse);

    // Over the 3D view: the camera moves and the column stays put.
    final anchorBefore = tester.getTopLeft(find.text('Antenna geometry'));
    final distanceBefore = cameraDistance();
    mouse.hover(tester.getCenter(view));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 160)));
    await tester.pumpAndSettle();

    expect(cameraDistance(), isNot(distanceBefore),
        reason: 'the wheel should zoom the 3D view');
    expect(tester.getTopLeft(find.text('Antenna geometry')), anchorBefore,
        reason: 'the plot column must not scroll while zooming');

    // Over the card's title, just outside the 3D view: the column scrolls
    // and the camera holds.
    final zoomed = cameraDistance();
    mouse.hover(tester.getCenter(find.text('Antenna geometry')));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -160)));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Antenna geometry')),
        isNot(anchorBefore),
        reason: 'the wheel should still scroll the column outside the view');
    expect(cameraDistance(), zoomed,
        reason: 'scrolling elsewhere must not move the camera');
  });

  testWidgets('A trackpad zooms the 3D view without scrolling the column',
      (tester) async {
    // macOS sends trackpad gestures as pan/zoom pointer events rather than
    // scroll signals; the web build sends wheel events for the same gesture.
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const YagiApp());
    await tester.drag(
        find.byType(SingleChildScrollView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();

    final view = find.byType(AntennaView3d);
    double cameraDistance() => (tester
            .widget<CustomPaint>(find
                .descendant(of: view, matching: find.byType(CustomPaint))
                .first)
            .painter as ScenePainter)
        .camera
        .distance;

    final anchor = tester.getTopLeft(find.text('Antenna geometry'));
    final before = cameraDistance();

    final pad = TestPointer(1, PointerDeviceKind.trackpad);
    final centre = tester.getCenter(view);
    // Move the mouse in first: that is what locks the column's scrolling.
    final mouse = TestPointer(2, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(centre));
    await tester.pumpAndSettle();

    // Two fingers moving down zooms in, matching what the same gesture does
    // to the web build through the wheel path.
    await tester.sendEventToBinding(pad.panZoomStart(centre));
    await tester.sendEventToBinding(
        pad.panZoomUpdate(centre, pan: const Offset(0, 60)));
    await tester.pumpAndSettle();

    expect(cameraDistance(), lessThan(before),
        reason: 'a two-finger scroll should zoom in');
    expect(tester.getTopLeft(find.text('Antenna geometry')), anchor,
        reason: 'the plot column must not scroll while the trackpad zooms');

    // Fingers back up zooms out again.
    final zoomedIn = cameraDistance();
    await tester.sendEventToBinding(
        pad.panZoomUpdate(centre, pan: const Offset(0, -30)));
    await tester.pumpAndSettle();
    expect(cameraDistance(), greaterThan(zoomedIn),
        reason: 'reversing the gesture should zoom back out');

    // Pinching apart zooms in.
    final panned = cameraDistance();
    await tester.sendEventToBinding(
        pad.panZoomUpdate(centre, pan: const Offset(0, -30), scale: 1.6));
    await tester.pumpAndSettle();
    expect(cameraDistance(), lessThan(panned),
        reason: 'a pinch should zoom too');

    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pumpAndSettle();
  });

  testWidgets('Every antenna type can be selected in turn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const YagiApp());
    for (final type in AntennaType.values) {
      await selectAntennaType(tester, type);
      expect(find.text('Computed summary'), findsOneWidget,
          reason: '${type.label} should render a summary card');
    }
  });
}

/// Opens the antenna-type dropdown and picks [type]. The menu is long
/// enough to need scrolling for the later entries.
Future<void> selectAntennaType(WidgetTester tester, AntennaType type) async {
  await tester.tap(find.byType(DropdownButtonFormField<AntennaType>));
  await tester.pumpAndSettle();

  final item = find.text(type.label).last;
  await tester.scrollUntilVisible(item, 100,
      scrollable: find.byType(Scrollable).last);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

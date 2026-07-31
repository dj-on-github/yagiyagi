import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yagiyagi/antenna_design.dart';
import 'package:yagiyagi/antenna_shapes.dart';
import 'package:yagiyagi/cantenna_model.dart';
import 'package:yagiyagi/corner_reflector_model.dart';
import 'package:yagiyagi/dipole_model.dart';
import 'package:yagiyagi/dish_model.dart';
import 'package:yagiyagi/helix_model.dart';
import 'package:yagiyagi/horn_model.dart';
import 'package:yagiyagi/loop_model.dart';
import 'package:yagiyagi/lpda_model.dart';
import 'package:yagiyagi/magloop_model.dart';
import 'package:yagiyagi/moxon_model.dart';
import 'package:yagiyagi/patch_model.dart';
import 'package:yagiyagi/phased_array_model.dart';
import 'package:yagiyagi/scene3d.dart';
import 'package:yagiyagi/vertical_model.dart';
import 'package:yagiyagi/yagi_model.dart';

/// One design per antenna type, paired with its enum value.
Map<AntennaType, AntennaDesign> designsByType() => {
      AntennaType.yagi: YagiDesign(YagiParameters()),
      AntennaType.dipole: DipoleDesign(DipoleParameters()),
      AntennaType.loop: LoopDesign(LoopParameters()),
      AntennaType.waveguide: CantennaDesign(CantennaParameters()),
      AntennaType.vertical: VerticalDesign(VerticalParameters()),
      AntennaType.magLoop: MagLoopDesign(MagLoopParameters()),
      AntennaType.lpda: LpdaDesign(LpdaParameters()),
      AntennaType.dish: DishDesign(DishParameters()),
      AntennaType.helix: HelixDesign(HelixParameters()),
      AntennaType.patch: PatchDesign(PatchParameters()),
      AntennaType.moxon: MoxonDesign(MoxonParameters()),
      AntennaType.horn: HornDesign(HornParameters()),
      AntennaType.phasedVerticals: PhasedArrayDesign(PhasedArrayParameters()),
      AntennaType.cornerReflector:
          CornerReflectorDesign(CornerReflectorParameters()),
    };

void main() {
  group('vector maths', () {
    test('cross products follow the right hand rule', () {
      final c = sideAxis.cross(upAxis);
      expect(c.x, closeTo(1, 1e-12));
      expect(forwardAxis.cross(sideAxis).z, closeTo(1, 1e-12));
      expect(forwardAxis.dot(sideAxis), 0);
    });

    test('normalising a zero vector does not produce NaN', () {
      expect(Vec3.zero.normalized.isFinite, isTrue);
    });

    test('the camera sits at the requested distance from its target', () {
      const target = Vec3(1, 2, 3);
      const cam = Camera(
          target: target, distance: 10, yawDeg: 35, pitchDeg: 20);
      expect((cam.eye - target).length, closeTo(10, 1e-9));
      // Positive pitch looks down from above.
      expect(cam.eye.z, greaterThan(target.z));
    });
  });

  group('scene building', () {
    test('every antenna type produces a drawable scene', () {
      designsByType().forEach((type, design) {
        final scene = buildScene(type, design);
        final name = type.label;

        expect(scene.items, isNotEmpty, reason: '$name has no geometry');
        expect(scene.radius, greaterThan(0), reason: '$name has no size');
        expect(scene.radius.isFinite, isTrue, reason: '$name radius');
        expect(scene.center.isFinite, isTrue, reason: '$name centre');

        for (final item in scene.items) {
          for (final p in item.points) {
            expect(p.isFinite, isTrue, reason: '$name has a non-finite point');
          }
          if (item is Facet) {
            expect(item.corners.length, greaterThanOrEqualTo(3),
                reason: '$name has a degenerate facet');
            expect(item.normal.isFinite, isTrue, reason: '$name facet normal');
          }
          if (item is Tube) {
            expect(item.radius, greaterThan(0), reason: '$name tube radius');
          }
        }
      });
    });

    test('scene sizes match the antennas they draw', () {
      final yagi = YagiDesign(YagiParameters());
      final yagiScene = buildScene(AntennaType.yagi, yagi);
      // Boom along x, elements along y, both within a few percent.
      expect(yagiScene.size.x, closeTo(yagi.boomLengthM, yagi.wavelengthM * 0.1));
      expect(yagiScene.size.y, closeTo(yagi.reflectorLengthM, 0.05));

      final dipole = DipoleDesign(DipoleParameters());
      final dipoleScene = buildScene(AntennaType.dipole, dipole);
      expect(dipoleScene.size.y, closeTo(dipole.totalLengthM, 1e-6));

      final dish = DishDesign(DishParameters());
      final dishScene = buildScene(AntennaType.dish, dish);
      expect(dishScene.size.y, closeTo(dish.p.diameterM, dish.p.diameterM * 0.02));
    });

    test('geometry follows the parameters', () {
      // A longer boom is a bigger drawing.
      final short = buildScene(
          AntennaType.yagi, YagiDesign(YagiParameters(elements: 3)));
      final long = buildScene(
          AntennaType.yagi, YagiDesign(YagiParameters(elements: 12)));
      expect(long.size.x, greaterThan(short.size.x * 2));

      // Raising an antenna lifts it off the ground plane.
      final low = buildScene(AntennaType.dipole,
          DipoleDesign(DipoleParameters(heightWl: 0.25)));
      final high = buildScene(AntennaType.dipole,
          DipoleDesign(DipoleParameters(heightWl: 1.5)));
      expect(high.high.z, greaterThan(low.high.z * 3));

      // More turns, longer helix.
      final few = buildScene(
          AntennaType.helix, HelixDesign(HelixParameters(turns: 4)));
      final many = buildScene(
          AntennaType.helix, HelixDesign(HelixParameters(turns: 24)));
      expect(many.size.x, greaterThan(few.size.x * 4));
    });

    test('a solid corner reflector becomes a rod grid', () {
      final solid = buildScene(AntennaType.cornerReflector,
          CornerReflectorDesign(CornerReflectorParameters(rodSpacingWl: 0)));
      final grid = buildScene(AntennaType.cornerReflector,
          CornerReflectorDesign(CornerReflectorParameters(rodSpacingWl: 0.05)));
      expect(solid.items.whereType<Facet>(), isNotEmpty);
      expect(grid.items.whereType<Facet>(), isEmpty);
      expect(grid.items.whereType<Tube>().length,
          greaterThan(solid.items.whereType<Tube>().length));
    });

    test('a below-cutoff cantenna still draws a can', () {
      final d = CantennaDesign(
          CantennaParameters(frequencyMHz: 500, canDiameterMm: 60));
      expect(d.propagates, isFalse);
      final scene = buildScene(AntennaType.waveguide, d);
      expect(scene.items, isNotEmpty);
      expect(scene.radius, greaterThan(0));
      for (final item in scene.items) {
        for (final p in item.points) {
          expect(p.isFinite, isTrue);
        }
      }
    });

    test('scenes stay small enough to paint every frame', () {
      designsByType().forEach((type, design) {
        expect(buildScene(type, design).items.length, lessThan(1500),
            reason: '${type.label} is too heavy to redraw on every slider '
                'change');
      });
      // The worst case in the app: a 30-turn helix.
      final big = buildScene(
          AntennaType.helix, HelixDesign(HelixParameters(turns: 30)));
      expect(big.items.length, lessThan(1500));
    });
  });

  group('projection', () {
    test('painting a scene touches every primitive without throwing', () {
      // Exercises the projection, clipping and shading paths for real
      // geometry rather than a synthetic case.
      designsByType().forEach((type, design) {
        final scene = buildScene(type, design);
        for (final pitch in [-88.0, 0.0, 45.0, 88.0]) {
          final painter = ScenePainter(
            scene: scene,
            camera: Camera(
              target: scene.center,
              distance: scene.radius * 2.6,
              yawDeg: 52,
              pitchDeg: pitch,
            ),
            background: const Color(0xFF101416),
          );
          expect(
            () => _paintToCanvas(painter, const Size(600, 400)),
            returnsNormally,
            reason: '${type.label} at pitch $pitch',
          );
        }
      });
    });

    test('a camera inside the scene does not blow up', () {
      final scene = buildScene(
          AntennaType.dish, DishDesign(DishParameters()));
      final painter = ScenePainter(
        scene: scene,
        camera: Camera(
          target: scene.center,
          distance: scene.radius * 0.05, // well inside the geometry
          yawDeg: 10,
          pitchDeg: 5,
        ),
        background: const Color(0xFF101416),
      );
      expect(() => _paintToCanvas(painter, const Size(600, 400)),
          returnsNormally);
    });
  });
}

void _paintToCanvas(ScenePainter painter, Size size) {
  final recorder = PictureRecorder();
  painter.paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

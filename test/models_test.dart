import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yagiyagi/antenna_design.dart';
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
import 'package:yagiyagi/vertical_model.dart';
import 'package:yagiyagi/yagi_model.dart';

/// One design per antenna type, at its default parameters.
List<AntennaDesign> allDesigns() => [
      YagiDesign(YagiParameters()),
      DipoleDesign(DipoleParameters()),
      LoopDesign(LoopParameters()),
      CantennaDesign(CantennaParameters()),
      VerticalDesign(VerticalParameters()),
      MagLoopDesign(MagLoopParameters()),
      LpdaDesign(LpdaParameters()),
      DishDesign(DishParameters()),
      HelixDesign(HelixParameters()),
      PatchDesign(PatchParameters()),
      MoxonDesign(MoxonParameters()),
      HornDesign(HornParameters()),
      PhasedArrayDesign(PhasedArrayParameters()),
      CornerReflectorDesign(CornerReflectorParameters()),
    ];

void main() {
  group('shared numerics', () {
    test('Bessel functions hit their known zeros', () {
      expect(besselJ0(0), closeTo(1.0, 1e-6));
      expect(besselJ1(0), closeTo(0.0, 1e-6));
      expect(besselJ0(2.404825), closeTo(0.0, 1e-4));
      expect(besselJ1(3.831706), closeTo(0.0, 1e-4));
      expect(besselJ1(1.0), closeTo(0.4400506, 1e-5));
      expect(besselJ0(5.0), closeTo(-0.1775968, 1e-5));
    });

    test('sine and cosine integrals match published values', () {
      expect(sineIntegral(1.0), closeTo(0.9460831, 1e-5));
      expect(sineIntegral(pi / 2), closeTo(1.3707621, 1e-5));
      expect(sineIntegral(20.0), closeTo(1.5482417, 1e-4));
      expect(cosineIntegral(1.0), closeTo(0.3374039, 1e-5));
      expect(cosineIntegral(2.0), closeTo(0.4229809, 1e-5));
    });

    test('mutual impedance of side-by-side half waves', () {
      // Classical values from the standard coupling curves.
      final half = mutualImpedanceHalfWave(0.5);
      expect(half.r, closeTo(-12.5, 1.5));
      expect(half.x, closeTo(-29.9, 2.0));
      final full = mutualImpedanceHalfWave(1.0);
      expect(full.r, closeTo(4.0, 1.5));
      expect(full.x, closeTo(17.7, 2.0));
    });

    test('numeric directivity of a short dipole is 1.76 dBi', () {
      double u(double thetaDeg, double phiDeg) =>
          pow(sin(thetaDeg * pi / 180), 2).toDouble();
      expect(directivityDbi(u), closeTo(1.76, 0.05));
    });

    test('bandwidth search resolves a very high Q', () {
      // Q of 1000 at 14.2 MHz: the 2:1 window is a couple of tens of kHz.
      double swr(double f) =>
          swrFromImpedance(rlcImpedance(f, 14.2, 50, 1000), 50);
      final bw = bandwidth2to1(14.2, swr, maxSpanFrac: 0.05);
      expect(bw, greaterThan(0.005));
      expect(bw, lessThan(0.020));
    });
  });

  group('every design', () {
    test('produces finite values everywhere', () {
      for (final d in allDesigns()) {
        final name = d.runtimeType.toString();
        expect(d.gainDbi.isFinite, isTrue, reason: '$name gain');
        expect(d.frontToBackDb.isFinite, isTrue, reason: '$name F/B');
        expect(d.hpbwAzDeg.isFinite, isTrue, reason: '$name HPBW az');
        expect(d.hpbwElDeg.isFinite, isTrue, reason: '$name HPBW el');
        expect(d.feedpointROhms.isFinite, isTrue, reason: '$name R');
        expect(d.qFactor.isFinite, isTrue, reason: '$name Q');
        expect(d.centerSwr.isFinite, isTrue, reason: '$name SWR');
        expect(d.bandwidth2to1MHz.isFinite, isTrue, reason: '$name BW');
        expect(d.sweepMinMHz, lessThan(d.sweepMaxMHz), reason: '$name sweep');
        for (var a = 0; a < 360; a += 2) {
          final az = d.azimuthDb(a.toDouble());
          final el = d.elevationDb(a.toDouble());
          expect(az.isFinite, isTrue, reason: '$name azimuth at $a');
          expect(el.isFinite, isTrue, reason: '$name elevation at $a');
          expect(az, lessThanOrEqualTo(0.01), reason: '$name azimuth at $a');
          expect(el, lessThanOrEqualTo(0.01), reason: '$name elevation at $a');
        }
        for (var i = 0; i <= 40; i++) {
          final f = d.sweepMinMHz +
              (d.sweepMaxMHz - d.sweepMinMHz) * i / 40;
          expect(d.impedanceAt(f).r.isFinite, isTrue, reason: '$name R($f)');
          expect(d.impedanceAt(f).x.isFinite, isTrue, reason: '$name X($f)');
          expect(d.swrAt(f).isFinite, isTrue, reason: '$name SWR($f)');
        }
      }
    });

    test('reports a plausible gain', () {
      for (final d in allDesigns()) {
        expect(d.gainDbi, greaterThan(-25),
            reason: '${d.runtimeType} gain too low');
        expect(d.gainDbi, lessThan(45),
            reason: '${d.runtimeType} gain too high');
      }
    });
  });

  group('quarter-wave vertical', () {
    test('perfect ground and a dense radial field are lossless', () {
      final d = VerticalDesign(VerticalParameters(
        ground: GroundQuality.perfect,
        radialCount: 120,
        radialDroopDeg: 0,
      ));
      expect(d.efficiency, closeTo(1.0, 0.01));
      expect(d.gainDbi, closeTo(5.15, 0.1));
      expect(d.takeoffAngleDeg, lessThan(2));
    });

    test('poor soil and two radials waste most of the power', () {
      final d = VerticalDesign(VerticalParameters(
        ground: GroundQuality.poor,
        radialCount: 2,
        radialDroopDeg: 0,
      ));
      expect(d.efficiency, lessThan(0.6));
      expect(d.takeoffAngleDeg, greaterThan(10));
    });

    test('radial droop lifts the feedpoint from 36 to 50 ohm', () {
      VerticalDesign at(double droop) => VerticalDesign(VerticalParameters(
            radialDroopDeg: droop,
            ground: GroundQuality.perfect,
            radialCount: 64,
          ));
      expect(at(0).feedpointROhms, closeTo(36.5, 1.0));
      expect(at(45).feedpointROhms, closeTo(50.0, 1.5));
    });
  });

  group('small transmitting loop', () {
    // A 1 m copper loop of 22 mm tube on 20 m - the canonical example.
    final d = MagLoopDesign(MagLoopParameters(
      frequencyMHz: 14.2,
      loopDiameterM: 1.0,
      conductorDiameterMm: 22,
    ));

    test('radiation resistance is a tenth of an ohm', () {
      expect(d.radiationROhms, closeTo(0.097, 0.01));
    });

    test('inductance and tuning capacitance are in the right place', () {
      expect(d.inductanceH * 1e6, closeTo(2.45, 0.2));
      expect(d.tuningCapacitancePf, closeTo(51, 6));
    });

    test('efficiency and Q land where a real loop does', () {
      expect(d.efficiency, inInclusiveRange(0.25, 0.65));
      expect(d.unloadedQ, inInclusiveRange(500, 1600));
    });

    test('the 2:1 bandwidth is only tens of kHz', () {
      expect(d.bandwidth2to1MHz * 1000, inInclusiveRange(8.0, 60.0));
    });

    test('a smaller loop on a lower band is far worse', () {
      final small = MagLoopDesign(MagLoopParameters(
        frequencyMHz: 3.6,
        loopDiameterM: 0.6,
        conductorDiameterMm: 10,
      ));
      expect(small.efficiency, lessThan(0.05));
      expect(small.gainDbi, lessThan(d.gainDbi));
    });
  });

  group('log-periodic', () {
    final d = LpdaDesign(LpdaParameters());

    test('geometry follows tau and sigma', () {
      expect(d.apexHalfAngleDeg, closeTo(9.46, 0.5));
      expect(d.elementCount, inInclusiveRange(10, 24));
      expect(d.elementLengthM(1) / d.elementLengthM(0),
          closeTo(d.p.tau, 1e-9));
    });

    test('gain sits in the log-periodic range', () {
      expect(d.gainDbi, inInclusiveRange(6.0, 11.5));
    });

    test('the match holds across most of the design band', () {
      expect(d.swrAt(d.fLowMHz * 1.05), lessThan(2.0));
      expect(d.swrAt(d.centerFrequencyMHz), lessThan(2.0));
      expect(d.swrAt(d.fHighMHz * 0.95), lessThan(2.0));
      // ... and falls apart outside it.
      expect(d.swrAt(d.fLowMHz * 0.75), greaterThan(3.0));
      expect(d.bandwidth2to1MHz, greaterThan(d.fHighMHz - d.fLowMHz) );
    });
  });

  group('parabolic dish', () {
    test('aperture efficiency is realistic at the usual edge taper', () {
      final d = DishDesign(DishParameters(surfaceRmsMm: 0.1));
      expect(d.apertureEfficiency, inInclusiveRange(0.45, 0.80));
      expect(d.gainDbi, inInclusiveRange(24.0, 30.0));
      expect(d.hpbwAzDeg, inInclusiveRange(5.0, 9.0));
    });

    test('the beamwidth follows 70 lambda / D', () {
      final d = DishDesign(DishParameters(diameterM: 2.4, surfaceRmsMm: 0.1));
      final expected = 70 * d.wavelengthM / 2.4;
      expect(d.hpbwAzDeg, closeTo(expected, expected * 0.25));
    });

    test('Ruze deletes the gain of a rough dish', () {
      // 6 mm RMS is nothing at 2.4 GHz and fatal at 5.76 GHz.
      final smooth = DishDesign(
          DishParameters(frequencyMHz: 5760, surfaceRmsMm: 0.1));
      final rough =
          DishDesign(DishParameters(frequencyMHz: 5760, surfaceRmsMm: 6.0));
      expect(rough.gainDbi, lessThan(smooth.gainDbi - 6));
      expect(rough.surfaceMarginal, isTrue);
      expect(smooth.surfaceMarginal, isFalse);
      // Going up in frequency only helps while the surface can keep up: the
      // same rough dish gains nothing at all from 2.4 GHz to 5.76 GHz, where
      // an accurate one would gain nearly 8 dB.
      final roughLow = DishDesign(DishParameters(surfaceRmsMm: 6.0));
      final smoothLow = DishDesign(DishParameters(surfaceRmsMm: 0.1));
      expect((rough.gainDbi - roughLow.gainDbi).abs(), lessThan(1.0));
      expect(smooth.gainDbi - smoothLow.gainDbi, greaterThan(6.0));
    });

    test('the pattern shows a real first sidelobe', () {
      final d = DishDesign(DishParameters(surfaceRmsMm: 0.1));
      expect(d.firstSidelobeDb, inInclusiveRange(-40.0, -15.0));
    });

    test('nothing radiates backwards through the reflector', () {
      // The aperture transform is written in sin(theta) and so is symmetric
      // front to back; the dish is not.
      final d = DishDesign(DishParameters(surfaceRmsMm: 0.1));
      expect(d.azimuthDb(0), closeTo(0, 0.01));
      expect(d.azimuthDb(180), lessThan(-25));
      expect(d.elevationDb(180), lessThan(-25));
      for (var a = 100; a <= 260; a += 5) {
        expect(d.azimuthDb(a.toDouble()), lessThan(-20),
            reason: 'rear lobe at $a degrees');
      }
    });
  });

  group('axial-mode helix', () {
    final d = HelixDesign(HelixParameters());

    test('Kraus relations give the expected gain and beamwidth', () {
      expect(d.gainDbi, inInclusiveRange(12.0, 16.0));
      expect(d.hpbwAzDeg, inInclusiveRange(28.0, 42.0));
      expect(d.feedpointROhms, closeTo(140, 1));
    });

    test('axial ratio improves with turns', () {
      final long = HelixDesign(HelixParameters(turns: 20));
      expect(long.axialRatio, lessThan(d.axialRatio));
      expect(d.polarization, Polarization.rhcp);
    });

    test('winding sense sets the hand', () {
      final lh = HelixDesign(HelixParameters(sense: WindingSense.leftHand));
      expect(lh.polarization, Polarization.lhcp);
    });

    test('leaving the axial-mode window collapses the gain', () {
      final off = HelixDesign(HelixParameters(circumferenceWl: 0.5));
      expect(off.inAxialMode, isFalse);
      expect(off.gainDbi, lessThan(4));
    });

    test('the usable bandwidth is wide', () {
      expect(100 * d.bandwidth2to1MHz / d.centerFrequencyMHz,
          greaterThan(20));
    });
  });

  group('microstrip patch', () {
    test('FR-4 at 2.4 GHz gives the textbook dimensions', () {
      final d = PatchDesign(PatchParameters());
      expect(d.widthMm, closeTo(38.0, 2.0));
      expect(d.lengthMm, closeTo(29.0, 2.0));
      expect(d.epsilonEff, inInclusiveRange(3.9, 4.3));
    });

    test('FR-4 loses about half the power, Rogers does not', () {
      final fr4 = PatchDesign(PatchParameters());
      final rogers = PatchDesign(PatchParameters(
        substrate: Substrate.rogers5880,
        heightMm: 1.575,
      ));
      expect(fr4.efficiency, inInclusiveRange(0.35, 0.60));
      expect(rogers.efficiency, greaterThan(0.75));
      expect(rogers.gainDbi, greaterThan(fr4.gainDbi + 2));
    });

    test('bandwidth is a couple of percent and follows thickness', () {
      final thin = PatchDesign(PatchParameters(heightMm: 0.8));
      final thick = PatchDesign(PatchParameters(heightMm: 3.2));
      final pct = 100 * thin.bandwidth2to1MHz / thin.centerFrequencyMHz;
      expect(pct, inInclusiveRange(0.5, 6.0));
      expect(thick.bandwidth2to1MHz, greaterThan(thin.bandwidth2to1MHz));
    });

    test('an edge feed is a bad match, an inset feed is not', () {
      final edge = PatchDesign(PatchParameters(feed: PatchFeed.edgeDirect));
      final inset = PatchDesign(PatchParameters());
      expect(edge.edgeResistanceOhms, greaterThan(120));
      expect(edge.centerSwr, greaterThan(2.5));
      expect(inset.centerSwr, closeTo(1.0, 0.05));
      expect(inset.insetDistanceMm, greaterThan(0));
      expect(inset.insetDistanceMm, lessThan(inset.lengthMm / 2));
    });
  });

  group('Moxon rectangle', () {
    final d = MoxonDesign(MoxonParameters());

    test('the rectangle is about 0.37 by 0.125 wavelengths', () {
      expect(d.widthWl, closeTo(0.37, 0.02));
      expect(d.depthWl, closeTo(0.125, 0.015));
    });

    test('it needs no matching network', () {
      expect(d.feedpointROhms, closeTo(50, 3));
      expect(d.centerSwr, lessThan(1.15));
    });

    test('the gap is what sets the rear null', () {
      final detuned = MoxonDesign(MoxonParameters(gapTrim: 1.12));
      expect(d.frontToBackDb, greaterThan(30));
      expect(detuned.frontToBackDb, lessThan(30));
      // Forward gain barely notices.
      expect((detuned.gainDbi - d.gainDbi).abs(), lessThan(0.5));
    });
  });

  group('pyramidal horn', () {
    test('an optimum horn lands on 51 percent aperture efficiency', () {
      // The model solves the apertures that put s and t on their optimum
      // values for a given axial length; feed those back in.
      final seed = HornDesign(HornParameters(axialLengthMm: 300));
      final d = HornDesign(HornParameters(
        axialLengthMm: 300,
        apertureAMm: seed.optimumAMm,
        apertureBMm: seed.optimumBMm,
      ));
      expect(d.sPhase, closeTo(0.25, 0.005));
      expect(d.tPhase, closeTo(0.375, 0.005));
      expect(d.apertureEfficiency, closeTo(0.51, 0.03));
    });

    test('a horn with no flare is a clean aperture', () {
      final d = HornDesign(HornParameters(
        apertureAMm: WaveguideSize.wr430.aMm,
        apertureBMm: WaveguideSize.wr430.bMm,
      ));
      expect(d.sPhase, 0);
      expect(d.tPhase, 0);
      expect(d.apertureEfficiency, closeTo(8 / (pi * pi), 0.01));
    });

    test('over-flaring costs gain', () {
      final optimum = HornDesign(HornParameters(
        apertureAMm: 274,
        apertureBMm: 224,
        axialLengthMm: 200,
      ));
      final overflared = HornDesign(HornParameters(
        apertureAMm: 700,
        apertureBMm: 600,
        axialLengthMm: 200,
      ));
      expect(overflared.apertureEfficiency,
          lessThan(optimum.apertureEfficiency));
      expect(overflared.sPhase, greaterThan(0.5));
    });

    test('below cutoff nothing radiates', () {
      final d = HornDesign(HornParameters(frequencyMHz: 1000));
      expect(d.propagates, isFalse);
      expect(d.gainDbi, 0);
      expect(d.bandwidth2to1MHz, 0);
    });
  });

  group('phased verticals', () {
    test('the cardioid preset points forward and nulls behind', () {
      final d = PhasedArrayDesign(PhasedArrayParameters(
        spacingWl: 0.25,
        phaseDeg: -90,
        ground: GroundQuality.perfect,
      ));
      expect(d.peakAzimuthDeg, closeTo(0, 1));
      expect(d.frontToBackDb, greaterThan(25));
      expect(d.arrayGainDb, inInclusiveRange(2.0, 5.0));
    });

    test('in-phase at half-wave spacing is broadside and bidirectional', () {
      final d = PhasedArrayDesign(PhasedArrayParameters(
        spacingWl: 0.5,
        phaseDeg: 0,
        ground: GroundQuality.perfect,
      ));
      expect(d.azimuthDb(90), closeTo(0, 0.1));
      expect(d.azimuthDb(0), lessThan(-20));
      expect(d.frontToBackDb, closeTo(0, 0.5));
    });

    test('coupling drives the two elements to different impedances', () {
      final d = PhasedArrayDesign(PhasedArrayParameters(
        spacingWl: 0.25,
        phaseDeg: -90,
        ground: GroundQuality.perfect,
        radialCount: 120,
      ));
      final z1 = d.element1Impedance, z2 = d.element2Impedance;
      expect((z1.r - z2.r).abs(), greaterThan(15));
      expect(z1.r, lessThan(z2.r));
    });
  });

  group('corner reflector', () {
    test('a 90 degree corner has three images', () {
      final d = CornerReflectorDesign(CornerReflectorParameters());
      expect(d.imageCount, 3);
      expect(d.gainDbi, inInclusiveRange(9.0, 14.0));
      expect(d.frontToBackDb, greaterThan(15));
    });

    test('a sharper corner gives more gain', () {
      CornerReflectorDesign at(ApexAngle a) => CornerReflectorDesign(
          CornerReflectorParameters(
              apex: a, reflectorLengthWl: 3.0, rodSpacingWl: 0));
      expect(at(ApexAngle.deg60).gainDbi,
          greaterThan(at(ApexAngle.deg90).gainDbi));
      expect(at(ApexAngle.deg90).gainDbi,
          greaterThan(at(ApexAngle.deg180).gainDbi));
    });

    test('apex spacing swings the feedpoint resistance hard', () {
      CornerReflectorDesign at(double s) =>
          CornerReflectorDesign(CornerReflectorParameters(spacingWl: s));
      expect(at(0.25).feedpointROhms, lessThan(at(0.5).feedpointROhms));
      expect(at(0.5).feedpointROhms, greaterThan(60));
    });

    test('the reflector shadows the rear, which the images alone do not', () {
      // The image array is symmetric front to back, so without the shadow
      // the model would claim as much radiation behind as in front.
      final d = CornerReflectorDesign(
          CornerReflectorParameters(reflectorLengthWl: 2.0, rodSpacingWl: 0));
      expect(d.azimuthDb(0), closeTo(0, 0.01));
      expect(d.azimuthDb(180), lessThan(-25));
      expect(d.elevationDb(180), lessThan(-25));
    });

    test('a small or leaky reflector costs gain and front-to-back', () {
      final good = CornerReflectorDesign(
          CornerReflectorParameters(reflectorLengthWl: 2.0, rodSpacingWl: 0));
      final poor = CornerReflectorDesign(
          CornerReflectorParameters(reflectorLengthWl: 0.6, rodSpacingWl: 0.2));
      expect(poor.gainDbi, lessThan(good.gainDbi));
      expect(poor.frontToBackDb, lessThan(good.frontToBackDb));
    });
  });
}

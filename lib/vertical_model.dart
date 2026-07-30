import 'dart:math';

import 'antenna_design.dart';

/// Soil quality under a ground-mounted vertical. Real ground both burns
/// power in the near field (loss resistance) and refuses to reflect at low
/// angles, which lifts the takeoff angle away from the horizon.
enum GroundQuality { perfect, good, average, poor }

extension GroundQualityInfo on GroundQuality {
  String get label => switch (this) {
        GroundQuality.perfect => 'Perfect',
        GroundQuality.good => 'Good',
        GroundQuality.average => 'Average',
        GroundQuality.poor => 'Poor',
      };

  /// Descriptive soil, roughly following the usual conductivity classes.
  String get detail => switch (this) {
        GroundQuality.perfect => 'salt water / dense radial screen',
        GroundQuality.good => 'wet, rich soil',
        GroundQuality.average => 'typical farmland',
        GroundQuality.poor => 'dry sand, rock, city',
      };

  /// Scales the near-field loss resistance left over after the radials.
  double get lossFactor => switch (this) {
        GroundQuality.perfect => 0.0,
        GroundQuality.good => 0.6,
        GroundQuality.average => 1.0,
        GroundQuality.poor => 1.6,
      };

  /// Far-field reflection loss at the pseudo-Brewster region, in dB.
  double get reflectionLossDb => switch (this) {
        GroundQuality.perfect => 0.0,
        GroundQuality.good => 1.0,
        GroundQuality.average => 2.0,
        GroundQuality.poor => 3.5,
      };

  /// Elevation angle below which real ground swallows the low-angle
  /// radiation, in degrees.
  double get takeoffDeg => switch (this) {
        GroundQuality.perfect => 0.0,
        GroundQuality.good => 12.0,
        GroundQuality.average => 18.0,
        GroundQuality.poor => 26.0,
      };
}

/// User-adjustable quarter-wave vertical / ground-plane parameters.
class VerticalParameters {
  double frequencyMHz;
  double lengthFactor; // radiator length as a fraction of a quarter wave
  double diameterMm;
  int radialCount;
  double radialDroopDeg; // 0 = flat ground plane, 45 = classic drooping GP
  GroundQuality ground;
  double feedOhms;

  VerticalParameters({
    this.frequencyMHz = 145.0,
    this.lengthFactor = 0.955,
    this.diameterMm = 6.0,
    this.radialCount = 4,
    this.radialDroopDeg = 45.0,
    this.ground = GroundQuality.average,
    this.feedOhms = 50.0,
  });
}

/// Simplified quarter-wave monopole over a radial ground system.
///
/// The two lessons this model exists to show are that radials buy back
/// efficiency (loss resistance falls as they are added) and that drooping
/// them raises the feedpoint resistance from the monopole's natural ~36 ohm
/// towards a coax-friendly 50 ohm.
class VerticalDesign extends AntennaDesign {
  final VerticalParameters p;
  VerticalDesign(this.p);

  double get wavelengthM => wavelengthMFor(p.frequencyMHz);
  double get radiatorLengthM => p.lengthFactor * wavelengthM / 4;
  double get radiatorWl => p.lengthFactor * 0.25;
  double get radialLengthM => wavelengthM / 4;

  /// A thin quarter-wave whip resonates near 0.239 lambda, i.e. a length
  /// factor of ~0.955 of the nominal quarter wave.
  double get resonanceMHz => p.frequencyMHz * (0.955 / p.lengthFactor);

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;
  @override
  Polarization get polarization => Polarization.vertical;

  // ---- resistances and efficiency ----

  /// Radiation resistance: 36.5 ohm for a flat ground plane, climbing as the
  /// radials droop and the antenna turns back into a dipole.
  double get radiationROhms => 36.5 + 0.30 * p.radialDroopDeg;

  /// Loss left in the ground after [radialCount] radials. Perfect ground and
  /// a dense radial field both drive this to zero.
  double get groundLossROhms =>
      p.ground.lossFactor * 25 * exp(-p.radialCount / 16);

  double get efficiency =>
      radiationROhms / (radiationROhms + groundLossROhms);

  double get efficiencyDb => 10 * log10(efficiency);

  /// Peak elevation and the -3 dB window around it, in degrees above the
  /// horizon. Computed once per design instance because the polar plot and
  /// the summary panel both ask for it.
  late final List<double> _lobe = _measureLobe();

  List<double> _measureLobe() {
    var peakEl = 0.0, peakDb = double.negativeInfinity;
    for (var e = 0.0; e <= 90; e += 0.25) {
      final v = elevationDb(e);
      if (v > peakDb) {
        peakDb = v;
        peakEl = e;
      }
    }
    double edge(int dir) {
      var e = peakEl;
      while (e >= 0 && e <= 90) {
        if (elevationDb(e) <= peakDb - 3) return e;
        e += dir * 0.25;
      }
      return dir < 0 ? 0.0 : 90.0;
    }

    return [peakEl, edge(-1), edge(1)];
  }

  /// Elevation angle of the main lobe, in degrees above the horizon.
  double get takeoffAngleDeg => _lobe[0];

  /// Lower and upper -3 dB elevation angles of the main lobe.
  double get lobeLowDeg => _lobe[1];
  double get lobeHighDeg => _lobe[2];

  // ---- gain / pattern ----

  /// A lossless quarter wave over perfect ground is 5.15 dBi at the horizon;
  /// conductor-to-ground losses and the imperfect reflection eat into that.
  @override
  double get gainDbi => 5.15 + efficiencyDb - p.ground.reflectionLossDb;

  @override
  double get frontToBackDb => 0; // omnidirectional

  @override
  double get hpbwAzDeg => 360; // omnidirectional in azimuth

  /// Elevation width of the main lobe between its -3 dB angles.
  @override
  double get hpbwElDeg => lobeHighDeg - lobeLowDeg;

  @override
  double azimuthDb(double angleDeg) => 0; // omnidirectional

  @override
  double elevationDb(double angleDeg) {
    final sinEl = sin(angleDeg * pi / 180);
    if (sinEl < 0) return -40; // nothing below the horizon
    final el = asin(sinEl.clamp(0.0, 1.0));
    final cosEl = cos(el);

    // Monopole element factor over a ground plane.
    final kh = 2 * pi * radiatorWl;
    final num = cos(kh * sinEl) - cos(kh);
    final f = cosEl.abs() < 1e-6 ? 0.0 : (num / cosEl).abs();

    // Real ground refuses to reflect at grazing angles, which lifts the
    // lobe clear of the horizon.
    final takeoff = p.ground.takeoffDeg;
    final ground = takeoff <= 0
        ? 1.0
        : 1 - exp(-pow(el * 180 / pi / takeoff, 2).toDouble());

    final fMax = 1 - cos(kh); // element factor at the horizon
    final gn = (f * ground / fMax).clamp(1e-4, 1.0);
    return (20 * log10(gn)).clamp(-40.0, 0.0);
  }

  // ---- impedance / SWR ----

  @override
  double get feedpointROhms => radiationROhms + groundLossROhms;

  /// A fat radiator is a lower-Q radiator. A monopole is half a dipole, so
  /// it runs a little higher Q than the dipole model for the same tubing.
  @override
  double get qFactor => 13 * pow(6 / p.diameterMm, 0.35).toDouble();

  @override
  Impedance impedanceAt(double fMHz) =>
      rlcImpedance(fMHz, resonanceMHz, feedpointROhms, qFactor);

  @override
  double get bandwidth2to1MHz => bandwidth2to1(resonanceMHz, swrAt);
}

import 'dart:math';

import 'antenna_design.dart';

enum WindingSense { rightHand, leftHand }

extension WindingSenseLabel on WindingSense {
  String get label => switch (this) {
        WindingSense.rightHand => 'Right hand',
        WindingSense.leftHand => 'Left hand',
      };
}

enum HelixMatch { none, quarterWave }

extension HelixMatchLabel on HelixMatch {
  String get label => switch (this) {
        HelixMatch.none => 'Direct (no match)',
        HelixMatch.quarterWave => 'Quarter-wave strip',
      };
}

/// User-adjustable axial-mode helix parameters.
class HelixParameters {
  double frequencyMHz;
  int turns;
  double circumferenceWl; // turn circumference in wavelengths
  double pitchAngleDeg;
  double groundPlaneWl; // reflector diameter in wavelengths
  double conductorDiameterMm;
  WindingSense sense;
  HelixMatch match;
  double feedOhms;

  HelixParameters({
    this.frequencyMHz = 1296.0,
    this.turns = 10,
    this.circumferenceWl = 1.0,
    this.pitchAngleDeg = 12.5,
    this.groundPlaneWl = 0.9,
    this.conductorDiameterMm = 4.0,
    this.sense = WindingSense.rightHand,
    this.match = HelixMatch.quarterWave,
    this.feedOhms = 50.0,
  });
}

/// Axial-mode helix: circular polarisation from a coil of wire.
///
/// Kraus' relations carry the whole design. The useful ones are that gain
/// grows with the number of turns, that the axial mode only exists while the
/// turn circumference stays between about 0.75 and 1.33 wavelengths - which
/// is where the wide bandwidth comes from - and that the feedpoint sits near
/// 140 ohm, so it wants a matching section.
class HelixDesign extends AntennaDesign {
  final HelixParameters p;
  HelixDesign(this.p);

  double get wavelengthM => wavelengthMFor(p.frequencyMHz);
  double get circumferenceM => p.circumferenceWl * wavelengthM;
  double get turnDiameterM => circumferenceM / pi;
  double get spacingWl => p.circumferenceWl * tan(p.pitchAngleDeg * pi / 180);
  double get spacingM => spacingWl * wavelengthM;
  double get axialLengthM => p.turns * spacingM;
  double get groundPlaneM => p.groundPlaneWl * wavelengthM;

  /// Total conductor length: each turn is the hypotenuse of circumference
  /// and pitch.
  double get wireLengthM =>
      p.turns * sqrt(circumferenceM * circumferenceM + spacingM * spacingM);

  /// Turn circumference in wavelengths at an arbitrary frequency.
  double circumferenceWlAt(double fMHz) =>
      p.circumferenceWl * fMHz / p.frequencyMHz;

  static const double axialModeLow = 0.75;
  static const double axialModeHigh = 1.33;

  bool get inAxialMode =>
      p.circumferenceWl >= axialModeLow && p.circumferenceWl <= axialModeHigh;

  bool get pitchOutOfRange =>
      p.pitchAngleDeg < 12.0 || p.pitchAngleDeg > 15.0;

  bool get groundPlaneSmall => p.groundPlaneWl < 0.75;

  /// Low and high frequency edges of the axial-mode window.
  double get axialLowMHz => p.frequencyMHz * axialModeLow / p.circumferenceWl;
  double get axialHighMHz => p.frequencyMHz * axialModeHigh / p.circumferenceWl;

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;

  @override
  Polarization get polarization => p.sense == WindingSense.rightHand
      ? Polarization.rhcp
      : Polarization.lhcp;

  /// Axial ratio of the radiated field, (2N+1)/(2N). More turns, rounder
  /// polarisation.
  double get axialRatio => (2 * p.turns + 1) / (2 * p.turns);
  double get axialRatioDb => 20 * log10(axialRatio);

  // ---- gain / pattern ----

  /// Kraus' axial-mode gain, tempered by the correction that measurements
  /// have always demanded of it - about a dB overall, and more for long
  /// helices where the formula runs away.
  @override
  double get gainDbi {
    if (!inAxialMode) {
      // Outside the axial-mode window the helix collapses towards a normal
      // mode radiator with barely any gain.
      return 2.0;
    }
    final g = 11.8 +
        10 * log10(pow(p.circumferenceWl, 2).toDouble() * p.turns * spacingWl);
    final longHelixPenalty = 8 * max(0.0, log10(p.turns / 12));
    final pitchPenalty = 2.5 * max(0.0, (p.pitchAngleDeg - 14).abs() - 1);
    return max(2.0, g - 1.0 - longHelixPenalty - pitchPenalty);
  }

  @override
  double get frontToBackDb => (12 + 12 * p.groundPlaneWl).clamp(8.0, 24.0);

  /// Kraus: HPBW = 52 / (C_lambda sqrt(N S_lambda)) degrees, in both planes.
  double get _hpbw => inAxialMode
      ? (52 / (p.circumferenceWl * sqrt(p.turns * spacingWl)))
          .clamp(12.0, 140.0)
      : 140.0;

  @override
  double get hpbwAzDeg => _hpbw;
  @override
  double get hpbwElDeg => _hpbw; // rotationally symmetric

  @override
  double azimuthDb(double angleDeg) =>
      lobePatternDb(angleDeg, hpbwAzDeg, frontToBackDb);

  @override
  double elevationDb(double angleDeg) =>
      lobePatternDb(angleDeg, hpbwElDeg, frontToBackDb);

  // ---- impedance ----

  /// Kraus: R = 140 C_lambda ohms, which is why a bare helix into 50 ohm
  /// coax reads close to 3:1.
  @override
  double get feedpointROhms => (140 * p.circumferenceWl).clamp(20.0, 400.0);

  /// The axial-mode window is wide, so the equivalent Q is low.
  @override
  double get qFactor => 2.5;

  /// A quarter-wave strip over the ground plane transforms the feedpoint to
  /// the line impedance at the design frequency.
  double get transformRatio => p.match == HelixMatch.quarterWave
      ? p.feedOhms / feedpointROhms
      : 1.0;

  @override
  Impedance impedanceAt(double fMHz) {
    final cl = circumferenceWlAt(fMHz);
    var r = (140 * cl).clamp(20.0, 400.0);
    // Mild ripple through the axial-mode window.
    var x = 0.10 * r * sin(6 * (cl - 1.0));

    if (cl < axialModeLow) {
      final rel = (axialModeLow - cl) / axialModeLow;
      r *= exp(-8 * rel);
      x -= 105 * 10 * rel;
    } else if (cl > axialModeHigh) {
      final rel = (cl - axialModeHigh) / axialModeHigh;
      r *= exp(-6 * rel);
      x += 105 * 10 * rel;
    }
    return Impedance(r * transformRatio, x * transformRatio);
  }

  @override
  double get bandwidth2to1MHz =>
      bandwidth2to1(p.frequencyMHz, swrAt, maxSpanFrac: 0.6);

  @override
  double get sweepMinMHz => p.frequencyMHz * 0.6;
  @override
  double get sweepMaxMHz => p.frequencyMHz * 1.5;
}

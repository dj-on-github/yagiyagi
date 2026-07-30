import 'dart:math';

import 'antenna_design.dart';

enum FeedType { splitDipole, foldedDipole, gammaMatch }

extension FeedTypeLabel on FeedType {
  String get label => switch (this) {
        FeedType.splitDipole => 'Split dipole',
        FeedType.foldedDipole => 'Folded dipole',
        FeedType.gammaMatch => 'Gamma match',
      };
}

/// User-adjustable Yagi-Uda antenna parameters.
class YagiParameters {
  int elements;
  double frequencyMHz;
  double spacingWl; // element-to-element spacing, fraction of wavelength
  double elementDiameterMm;
  double reflectorFactor; // reflector length relative to driven element
  double directorFactor; // director length relative to driven element
  double taper; // extra progressive shortening per director (0..0.03)
  FeedType feedType;
  double feedOhms; // feedline impedance, 50 or 75

  YagiParameters({
    this.elements = 5,
    this.frequencyMHz = 145.0,
    this.spacingWl = 0.18,
    this.elementDiameterMm = 6.0,
    this.reflectorFactor = 1.05,
    this.directorFactor = 0.95,
    this.taper = 0.0,
    this.feedType = FeedType.gammaMatch,
    this.feedOhms = 50.0,
  });
}

/// Simplified analytical Yagi model: gain, front/back, beamwidths,
/// polar patterns, feedpoint impedance and SWR versus frequency.
///
/// This is a parametric engineering approximation (empirical gain/bandwidth
/// relations + a shaped two-lobe pattern model), not a full NEC/MoM solve.
class YagiDesign implements AntennaDesign {
  final YagiParameters p;
  YagiDesign(this.p);

  double get wavelengthM => 299.792458 / p.frequencyMHz;
  int get directors => max(0, p.elements - 2);
  double get spacingM => p.spacingWl * wavelengthM;
  double get boomLengthM => spacingM * (p.elements - 1);
  double get boomWl => p.spacingWl * (p.elements - 1);

  double get drivenLengthM => 0.478 * wavelengthM;
  double get reflectorLengthM => drivenLengthM * p.reflectorFactor;
  double directorLengthM(int index) =>
      drivenLengthM * p.directorFactor * (1 - p.taper * index);

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;

  // ---- gain / pattern ----

  @override
  double get gainDbi {
    double g = 2.15 + 10 * log10(1.5 * p.elements);
    final d = (p.spacingWl - 0.19) / 0.15;
    g -= 2.2 * d * d; // penalty for spacing away from the optimum
    return max(2.15, g);
  }

  @override
  double get frontToBackDb =>
      (6 + 2.4 * p.elements - 18 * (p.spacingWl - 0.16).abs()).clamp(6.0, 32.0);

  double get _gainLin => pow(10, gainDbi / 10).toDouble();

  @override
  double get hpbwAzDeg => (175 / sqrt(_gainLin)).clamp(15.0, 120.0);
  @override
  double get hpbwElDeg =>
      (41253 / (_gainLin * hpbwAzDeg)).clamp(20.0, 130.0);

  /// Relative gain (dB, 0 dB = boresight) at [angleDeg]; 0 deg = forward.
  double _patternDb(double angleDeg, double hpbwDeg) =>
      lobePatternDb(angleDeg, hpbwDeg, frontToBackDb);

  @override
  double azimuthDb(double angleDeg) => _patternDb(angleDeg, hpbwAzDeg);
  @override
  double elevationDb(double angleDeg) => _patternDb(angleDeg, hpbwElDeg);

  // ---- impedance / SWR ----

  /// Parasitic coupling factor: more elements and tighter spacing
  /// pull the dipole's 73 ohm feedpoint resistance down.
  double get _coupling =>
      (0.10 * p.elements * (1.3 - 2.5 * p.spacingWl)).clamp(0.0, 0.8);

  @override
  double get feedpointROhms => 73 * (1 - _coupling);

  /// Thicker elements -> lower Q -> wider bandwidth.
  @override
  double get qFactor => 11 * pow(6 / p.elementDiameterMm, 0.35).toDouble();

  double get transformRatio => switch (p.feedType) {
        FeedType.splitDipole => 1.0,
        FeedType.foldedDipole => 4.0,
        FeedType.gammaMatch => p.feedOhms / feedpointROhms,
      };

  /// Feedline-referred impedance at [fMHz] (series RLC approximation).
  @override
  Impedance impedanceAt(double fMHz) {
    final z = rlcImpedance(fMHz, p.frequencyMHz, feedpointROhms, qFactor);
    return Impedance(z.r * transformRatio, z.x * transformRatio);
  }

  @override
  double swrAt(double fMHz) =>
      swrFromImpedance(impedanceAt(fMHz), p.feedOhms);

  @override
  double get centerSwr => swrAt(p.frequencyMHz);

  /// Contiguous bandwidth around the center frequency where SWR <= 2:1.
  @override
  double get bandwidth2to1MHz => bandwidth2to1(p.frequencyMHz, swrAt);
}

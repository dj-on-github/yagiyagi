import 'dart:math';

import 'antenna_design.dart';

/// User-adjustable open-ended circular waveguide ("cantenna") parameters.
class CantennaParameters {
  double frequencyMHz;
  double canDiameterMm;
  double probeDistanceFactor; // probe distance from the back wall, x guide wl
  double probeLengthFactor; // probe length, x free-space wavelength
  double feedOhms;

  CantennaParameters({
    this.frequencyMHz = 2400.0,
    this.canDiameterMm = 95.0,
    this.probeDistanceFactor = 0.25,
    this.probeLengthFactor = 0.22,
    this.feedOhms = 50.0,
  });
}

/// Simplified model of a probe-fed, open-ended circular waveguide
/// radiator (the classic Pringles-can / coffee-can WiFi antenna).
///
/// Covers TE11/TM01 cutoff behaviour, guide wavelength, aperture gain and
/// a probe impedance model. Below the TE11 cutoff the guide is evanescent
/// and the SWR climbs steeply - visible as a wall in the SWR plot.
class CantennaDesign implements AntennaDesign {
  final CantennaParameters p;
  CantennaDesign(this.p);

  double get wavelengthM => 299.792458 / p.frequencyMHz;
  double get wavelengthMm => wavelengthM * 1000;
  double get diameterM => p.canDiameterMm / 1000;

  /// TE11 cutoff: fc = 1.8412 * c / (pi * D). Below this the dominant
  /// mode cannot propagate.
  double get cutoffTe11MHz =>
      1.8412 * 299792.458 / (pi * p.canDiameterMm);

  /// TM01 cutoff: the next higher mode. Above this the guide is over-moded.
  double get cutoffTm01MHz =>
      2.4048 * 299792.458 / (pi * p.canDiameterMm);

  bool get propagates => p.frequencyMHz > cutoffTe11MHz;
  bool get overModed => p.frequencyMHz > cutoffTm01MHz;

  /// Guide wavelength: lambda_g = lambda / sqrt(1 - (fc/f)^2).
  double get guideWavelengthMm {
    if (!propagates) return double.infinity;
    final r = cutoffTe11MHz / p.frequencyMHz;
    return wavelengthMm / sqrt(1 - r * r);
  }

  double get probeDistanceMm =>
      propagates ? p.probeDistanceFactor * guideWavelengthMm : 0;
  double get probeLengthMm => p.probeLengthFactor * wavelengthMm;

  /// Recommended can length: 3/4 guide wavelength from back wall to open end.
  double get recommendedCanLengthMm =>
      propagates ? 0.75 * guideWavelengthMm : 0;

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;

  // ---- gain / pattern ----

  /// Aperture gain of the open end: G = eff * (pi D / lambda)^2.
  @override
  double get gainDbi {
    if (!propagates) return 0;
    final gLin = 0.85 * pow(pi * diameterM / wavelengthM, 2).toDouble();
    return max(1.0, 10 * log10(gLin));
  }

  @override
  double get frontToBackDb => 15; // open, unflanged aperture

  @override
  double get hpbwAzDeg => propagates
      ? (65 * wavelengthM / diameterM).clamp(20.0, 120.0)
      : 120;

  @override
  double get hpbwElDeg => (hpbwAzDeg * 0.9).clamp(18.0, 120.0);

  @override
  double azimuthDb(double angleDeg) =>
      propagates ? lobePatternDb(angleDeg, hpbwAzDeg, frontToBackDb) : -40;

  @override
  double elevationDb(double angleDeg) =>
      propagates ? lobePatternDb(angleDeg, hpbwElDeg, frontToBackDb) : -40;

  // ---- impedance / SWR ----

  /// Probe coupling: a probe around 0.22 lambda long presents ~50 ohm;
  /// shorter/longer probes move the resistance roughly quadratically.
  @override
  double get feedpointROhms =>
      (50 * pow(p.probeLengthFactor / 0.22, 2).toDouble()).clamp(8.0, 300.0);

  @override
  double get qFactor => 9;

  @override
  Impedance impedanceAt(double fMHz) {
    if (fMHz < cutoffTe11MHz) {
      // Evanescent guide: low R, large capacitive reactance.
      final depth = cutoffTe11MHz / fMHz - 1;
      return Impedance(8, -250 * (1 + depth));
    }
    return rlcImpedance(fMHz, p.frequencyMHz, feedpointROhms, qFactor);
  }

  @override
  double swrAt(double fMHz) => swrFromImpedance(impedanceAt(fMHz), feedOhms);

  @override
  double get centerSwr => swrAt(p.frequencyMHz);

  @override
  double get bandwidth2to1MHz =>
      propagates ? bandwidth2to1(p.frequencyMHz, swrAt) : 0;
}

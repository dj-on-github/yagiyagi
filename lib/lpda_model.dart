import 'dart:math';

import 'antenna_design.dart';

/// User-adjustable log-periodic dipole array parameters.
class LpdaParameters {
  double fLowMHz;
  double fHighMHz;
  double tau; // scaling constant between successive elements
  double sigma; // relative spacing, d / (2 L)
  double elementDiameterMm;
  double feederZ0; // impedance of the boom transmission line
  double feedOhms;

  LpdaParameters({
    this.fLowMHz = 100.0,
    this.fHighMHz = 500.0,
    this.tau = 0.90,
    this.sigma = 0.15,
    this.elementDiameterMm = 10.0,
    this.feederZ0 = 100.0,
    this.feedOhms = 50.0,
  });
}

/// Log-periodic dipole array: the Yagi's wideband cousin.
///
/// Where a Yagi trades everything for gain in one narrow band, an LPDA holds
/// a modest 6-11 dBi and a usable match over an octave or a decade, because
/// only the few elements near resonance - the active region - are doing the
/// work at any one frequency. tau and sigma set the whole geometry.
class LpdaDesign extends AntennaDesign {
  final LpdaParameters p;
  LpdaDesign(this.p);

  double get fLowMHz => min(p.fLowMHz, p.fHighMHz * 0.99);
  double get fHighMHz => max(p.fHighMHz, p.fLowMHz * 1.01);

  @override
  double get centerFrequencyMHz => sqrt(fLowMHz * fHighMHz);

  @override
  double get feedOhms => p.feedOhms;

  double get wavelengthLowM => wavelengthMFor(fLowMHz);

  /// Apex half-angle: cot(alpha) = 4 sigma / (1 - tau).
  double get apexHalfAngleDeg =>
      atan((1 - p.tau) / (4 * p.sigma)) * 180 / pi;

  /// Bandwidth of the active region - how much spectrum either side of the
  /// operating frequency is actually carrying current.
  double get activeRegionBandwidth =>
      1.1 + 7.7 * pow(1 - p.tau, 2).toDouble() * (4 * p.sigma / (1 - p.tau));

  /// Total structure bandwidth the array has to span.
  double get structureBandwidth =>
      (fHighMHz / fLowMHz) * activeRegionBandwidth;

  /// Element count needed to cover the structure bandwidth.
  int get elementCount {
    final n = 1 + log(structureBandwidth) / log(1 / p.tau);
    return n.ceil().clamp(3, 30);
  }

  /// Longest element: a half wave at the low-frequency edge.
  double get longestElementM => wavelengthLowM / 2;

  double elementLengthM(int index) =>
      longestElementM * pow(p.tau, index).toDouble();

  /// Spacing from element [index] to the next one: d = 2 sigma L.
  double spacingM(int index) => 2 * p.sigma * elementLengthM(index);

  double elementPositionM(int index) {
    var x = 0.0;
    for (var i = 0; i < index; i++) {
      x += spacingM(i);
    }
    return x;
  }

  double get boomLengthM => elementPositionM(elementCount - 1);
  double get shortestElementM => elementLengthM(elementCount - 1);

  // ---- gain / pattern ----

  /// Carrel's optimum relative spacing for a given tau.
  double get optimumSigma => 0.243 * p.tau - 0.051;

  /// Empirical fit to the Carrel gain contours: gain climbs with both tau
  /// (more elements per octave) and sigma (a longer boom), and rolls off
  /// again once sigma passes the optimum ridge.
  @override
  double get gainDbi {
    final g = 6.3 +
        20 * (p.tau - 0.80) +
        20 * (p.sigma - 0.05) -
        35 * pow(p.sigma - optimumSigma, 2).toDouble();
    return g.clamp(4.5, 11.5);
  }

  @override
  double get frontToBackDb =>
      (10 + 45 * (p.tau - 0.80) + 40 * (p.sigma - 0.05)).clamp(10.0, 25.0);

  double get _gainLin => pow(10, gainDbi / 10).toDouble();

  @override
  double get hpbwAzDeg => (175 / sqrt(_gainLin)).clamp(30.0, 120.0);

  @override
  double get hpbwElDeg =>
      (41253 / (_gainLin * hpbwAzDeg)).clamp(40.0, 150.0);

  @override
  double azimuthDb(double angleDeg) =>
      lobePatternDb(angleDeg, hpbwAzDeg, frontToBackDb);

  @override
  double elevationDb(double angleDeg) =>
      lobePatternDb(angleDeg, hpbwElDeg, frontToBackDb);

  // ---- impedance ----

  /// Mean element length-to-diameter ratio, used for the element's own
  /// average characteristic impedance.
  double get _meanElementM =>
      longestElementM * pow(p.tau, (elementCount - 1) / 2).toDouble();

  double get elementZa =>
      120 * max(1.0, log(_meanElementM / (p.elementDiameterMm / 1000)) - 2.25);

  double get _sigmaPrime => p.sigma / sqrt(p.tau);

  /// Carrel's input resistance for a log-periodic fed by a boom line of
  /// characteristic impedance Z0.
  @override
  double get feedpointROhms {
    final z0 = p.feederZ0;
    return z0 / sqrt(1 + z0 / (4 * _sigmaPrime * elementZa));
  }

  /// Log-periodic structures have no single resonance. This reports the
  /// equivalent Q implied by the 2:1 window, purely so the shared readouts
  /// have something meaningful to print.
  late final double _equivalentQ =
      bandwidth2to1MHz > 0 ? centerFrequencyMHz / bandwidth2to1MHz : 0;

  @override
  double get qFactor => _equivalentQ;

  @override
  Impedance impedanceAt(double fMHz) {
    final r0 = feedpointROhms;
    // Inside the design band the match ripples with a period of ln(1/tau) in
    // log frequency - the log-periodic signature.
    final phase = 2 * pi * log(fMHz / fLowMHz) / log(1 / p.tau);
    final r = r0 * (1 + 0.10 * sin(phase));
    var x = r0 * 0.18 * cos(phase);

    if (fMHz < fLowMHz) {
      // Below the band the longest element can no longer resonate: the
      // active region runs off the back of the array.
      final rel = (fLowMHz - fMHz) / fLowMHz;
      return Impedance(r * exp(-12 * rel), x - r0 * 14 * rel);
    }
    if (fMHz > fHighMHz) {
      // Above the band the array is truncated at the front.
      final rel = (fMHz - fHighMHz) / fHighMHz;
      return Impedance(r * exp(-10 * rel), x + r0 * 12 * rel);
    }
    return Impedance(r, x);
  }

  @override
  double get bandwidth2to1MHz =>
      bandwidth2to1(centerFrequencyMHz, swrAt, maxSpanFrac: 2.0);

  @override
  double get sweepMinMHz => fLowMHz / 1.5;
  @override
  double get sweepMaxMHz => fHighMHz * 1.5;
}

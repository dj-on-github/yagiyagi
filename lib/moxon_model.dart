import 'dart:math';

import 'antenna_design.dart';

/// User-adjustable Moxon rectangle parameters.
class MoxonParameters {
  double frequencyMHz;
  double wireDiameterMm;
  double gapTrim; // multiplies the nominal tip-to-tip gap
  double heightWl; // height above ground; 0 = free space
  double feedOhms;

  MoxonParameters({
    this.frequencyMHz = 145.0,
    this.wireDiameterMm = 3.0,
    this.gapTrim = 1.0,
    this.heightWl = 0.0,
    this.feedOhms = 50.0,
  });
}

/// Moxon rectangle: a two-element beam whose element tips are folded towards
/// each other until the rear radiation cancels.
///
/// It gives up about a dB of forward gain against a conventional two-element
/// Yagi and buys a front-to-back ratio a five-element Yagi cannot reach,
/// plus a feedpoint that lands on 50 ohm without a matching network. The
/// catch is the tip gap: it is the tuning control for the null, and it is
/// sharp.
class MoxonDesign extends AntennaDesign {
  final MoxonParameters p;
  MoxonDesign(this.p);

  double get wavelengthM => wavelengthMFor(p.frequencyMHz);
  bool get overGround => p.heightWl > 0.0;

  /// Wire diameter in wavelengths, as a log - the Moxon dimensions are
  /// mildly sensitive to it in exactly this way.
  double get _dLog =>
      (log10(p.wireDiameterMm / 1000 / wavelengthM)).clamp(-5.0, -2.0);

  /// A: overall width, tip to tip across the antenna.
  double get widthWl => 0.345 - 0.0075 * _dLog;

  /// B: the folded tails on the driven element.
  double get drivenTailWl => 0.0355 - 0.0025 * _dLog;

  /// C: the gap between the driven and reflector tips - the tuning control.
  double get gapWl => (0.0105 - 0.0005 * _dLog) * p.gapTrim;

  /// D: the folded tails on the reflector.
  double get reflectorTailWl => 0.059 - 0.002 * _dLog;

  /// E: total front-to-back depth of the rectangle.
  double get depthWl => drivenTailWl + gapWl + reflectorTailWl;

  double get widthM => widthWl * wavelengthM;
  double get depthM => depthWl * wavelengthM;
  double get drivenTailM => drivenTailWl * wavelengthM;
  double get reflectorTailM => reflectorTailWl * wavelengthM;
  double get gapM => gapWl * wavelengthM;

  /// Straight length of driven element wire before folding.
  double get drivenWireM => widthM + 2 * drivenTailM;
  double get reflectorWireM => widthM + 2 * reflectorTailM;

  double get _trimError => p.gapTrim - 1.0;

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;

  /// Detuning the gap also drags resonance around.
  double get resonanceMHz => p.frequencyMHz * (1 + 0.05 * _trimError);

  // ---- gain / pattern ----

  double get freeSpaceGainDbi =>
      6.1 - 3.0 * pow(_trimError, 2).toDouble();

  @override
  double get gainDbi => overGround
      ? freeSpaceGainDbi + 5.5 * min(1.0, p.heightWl * 4)
      : freeSpaceGainDbi;

  /// The whole point of the antenna, and the reason the gap matters.
  @override
  double get frontToBackDb =>
      (35 - 575 * pow(_trimError, 2).toDouble()).clamp(8.0, 35.0);

  @override
  double get hpbwAzDeg => 76;

  @override
  double get hpbwElDeg => overGround
      ? (60 / (1 + 2 * p.heightWl)).clamp(15.0, 120.0)
      : 128;

  @override
  double azimuthDb(double angleDeg) =>
      lobePatternDb(angleDeg, hpbwAzDeg, frontToBackDb);

  /// Free space shows the element's own vertical lobe; over ground the
  /// reflection lobes dominate, exactly as for the dipole and loop.
  @override
  double elevationDb(double angleDeg) => overGround
      ? groundReflectionDb(angleDeg, p.heightWl)
      : lobePatternDb(angleDeg, hpbwElDeg, frontToBackDb);

  // ---- impedance ----

  /// Close to 50 ohm in free space - a Moxon needs no matching network.
  @override
  double get feedpointROhms {
    final base = 50 - 30 * _trimError;
    if (!overGround) return base.clamp(20.0, 90.0);
    return (base - 15 * exp(-1.5 * p.heightWl) * cos(4 * pi * p.heightWl))
        .clamp(20.0, 90.0);
  }

  @override
  double get qFactor => 12 * pow(6 / p.wireDiameterMm, 0.35).toDouble();

  @override
  Impedance impedanceAt(double fMHz) =>
      rlcImpedance(fMHz, resonanceMHz, feedpointROhms, qFactor);

  @override
  double get bandwidth2to1MHz => bandwidth2to1(resonanceMHz, swrAt);
}

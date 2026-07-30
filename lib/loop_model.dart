import 'dart:math';

import 'antenna_design.dart';

enum LoopShape { circular, square }

extension LoopShapeLabel on LoopShape {
  String get label => switch (this) {
        LoopShape.circular => 'Circular',
        LoopShape.square => 'Square (quad)',
      };
}

/// User-adjustable full-wave loop antenna parameters.
class LoopParameters {
  double frequencyMHz;
  double circumferenceFactor; // loop circumference, fraction of a wavelength
  double wireDiameterMm;
  LoopShape shape;
  double heightWl; // height of loop center above ground; 0 = free space
  double feedOhms;

  LoopParameters({
    this.frequencyMHz = 145.0,
    this.circumferenceFactor = 1.02,
    this.wireDiameterMm = 2.0,
    this.shape = LoopShape.circular,
    this.heightWl = 0.0,
    this.feedOhms = 75.0,
  });
}

/// Simplified analytical full-wave loop model (vertical loop, quad-style).
///
/// A one-wavelength loop radiates broadside to its plane with ~3.3 dBi gain
/// and a feedpoint resistance near 100-120 ohm, which is why 75 ohm coax is
/// the classic feed. Azimuth is a broad figure-8; elevation uses the same
/// perfect-ground reflection factor as the dipole model.
class LoopDesign implements AntennaDesign {
  final LoopParameters p;
  LoopDesign(this.p);

  double get wavelengthM => 299.792458 / p.frequencyMHz;
  double get circumferenceM => p.circumferenceFactor * wavelengthM;
  double get diameterM => circumferenceM / pi; // circular loop
  double get sideM => circumferenceM / 4; // square loop
  bool get overGround => p.heightWl > 0.0;

  /// Thin-wire loops resonate at a circumference of about 1.02 lambda.
  double get resonanceMHz =>
      p.frequencyMHz * (1.02 / p.circumferenceFactor);

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;

  double get _freeSpaceGainDbi =>
      p.shape == LoopShape.circular ? 3.3 : 3.1;

  @override
  double get gainDbi => overGround
      ? _freeSpaceGainDbi + 5.5 * min(1.0, p.heightWl * 4)
      : _freeSpaceGainDbi;

  @override
  double get frontToBackDb => 0; // bidirectional

  @override
  double get hpbwAzDeg => 90; // broad figure-8 of a full-wave loop

  @override
  double get hpbwElDeg =>
      overGround ? (60 / (1 + 2 * p.heightWl)).clamp(15.0, 120.0) : 120;

  @override
  double azimuthDb(double angleDeg) {
    // Broad figure-8, maximum broadside to the loop plane.
    final a = angleDeg * pi / 180;
    final f = pow(cos(a).abs(), 1.2).toDouble();
    if (f < 1e-4) return -40;
    return (20 * log10(f)).clamp(-40.0, 0.0);
  }

  @override
  double elevationDb(double angleDeg) {
    if (!overGround) return 0;
    final a = angleDeg * pi / 180;
    final sinEl = sin(a);
    if (sinEl <= 0) return -40; // perfect ground: nothing below horizon
    final gMax = 2 * sin(min(2 * pi * p.heightWl, pi / 2));
    final g = 2 * sin(2 * pi * p.heightWl * sinEl).abs();
    final gn = (g / gMax).clamp(1e-4, 1.0);
    return (20 * log10(gn)).clamp(-40.0, 0.0);
  }

  double get _freeSpaceROhms =>
      p.shape == LoopShape.circular ? 120.0 : 105.0;

  @override
  double get feedpointROhms {
    if (!overGround) return _freeSpaceROhms;
    return (_freeSpaceROhms -
            40 * exp(-1.5 * p.heightWl) * cos(4 * pi * p.heightWl))
        .clamp(30.0, 200.0);
  }

  /// Wire loops use thin conductors and are fairly high-Q.
  @override
  double get qFactor => 11 * pow(6 / p.wireDiameterMm, 0.35).toDouble();

  @override
  Impedance impedanceAt(double fMHz) =>
      rlcImpedance(fMHz, resonanceMHz, feedpointROhms, qFactor);

  @override
  double swrAt(double fMHz) => swrFromImpedance(impedanceAt(fMHz), feedOhms);

  @override
  double get centerSwr => swrAt(p.frequencyMHz);

  @override
  double get bandwidth2to1MHz => bandwidth2to1(resonanceMHz, swrAt);
}

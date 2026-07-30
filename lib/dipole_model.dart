import 'dart:math';

import 'antenna_design.dart';

/// User-adjustable dipole antenna parameters.
class DipoleParameters {
  double frequencyMHz;
  double lengthFactor; // total length as a fraction of a half wavelength
  double diameterMm;
  double heightWl; // height above ground in wavelengths; 0 = free space
  double feedOhms;

  DipoleParameters({
    this.frequencyMHz = 145.0,
    this.lengthFactor = 0.956,
    this.diameterMm = 6.0,
    this.heightWl = 0.0,
    this.feedOhms = 50.0,
  });
}

/// Simplified analytical half-wave dipole model.
///
/// Azimuth uses the classic dipole element factor (figure-8); elevation is
/// shown in the plane perpendicular to the wire, with a perfect-ground
/// reflection factor when a height above ground is set.
class DipoleDesign implements AntennaDesign {
  final DipoleParameters p;
  DipoleDesign(this.p);

  double get wavelengthM => 299.792458 / p.frequencyMHz;
  double get totalLengthM => p.lengthFactor * wavelengthM / 2;
  double get legLengthM => totalLengthM / 2;
  bool get overGround => p.heightWl > 0.0;

  /// A thin half-wave dipole resonates near 0.478 lambda, i.e. a length
  /// factor of ~0.956. Shorter/longer wires move resonance up/down.
  double get resonanceMHz => p.frequencyMHz * (0.956 / p.lengthFactor);

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;

  @override
  double get gainDbi =>
      overGround ? 2.15 + 5.5 * min(1.0, p.heightWl * 4) : 2.15;

  @override
  double get frontToBackDb => 0; // bidirectional

  @override
  double get hpbwAzDeg => 78; // classic half-wave dipole azimuth beamwidth

  @override
  double get hpbwElDeg =>
      overGround ? (60 / (1 + 2 * p.heightWl)).clamp(15.0, 120.0) : 120;

  @override
  double azimuthDb(double angleDeg) {
    // Element factor cos(pi/2 * sin a) / cos a: nulls off the wire ends.
    final a = angleDeg * pi / 180;
    final ca = cos(a);
    if (ca.abs() < 1e-3) return -40;
    final f = (cos(pi / 2 * sin(a)) / ca).abs();
    if (f < 1e-4) return -40;
    return (20 * log10(f)).clamp(-40.0, 0.0);
  }

  @override
  double elevationDb(double angleDeg) {
    if (!overGround) return 0; // perpendicular plane: omnidirectional
    final a = angleDeg * pi / 180;
    final sinEl = sin(a); // positive above horizon, negative below
    if (sinEl <= 0) return -40; // perfect ground: nothing below horizon
    final gMax = 2 * sin(min(2 * pi * p.heightWl, pi / 2));
    final g = 2 * sin(2 * pi * p.heightWl * sinEl).abs();
    final gn = (g / gMax).clamp(1e-4, 1.0);
    return (20 * log10(gn)).clamp(-40.0, 0.0);
  }

  @override
  double get feedpointROhms {
    if (!overGround) return 73;
    // Image-antenna effect: R oscillates around 73 ohm with height.
    return (73 - 40 * exp(-1.5 * p.heightWl) * cos(4 * pi * p.heightWl))
        .clamp(15.0, 120.0);
  }

  @override
  double get qFactor => 11 * pow(6 / p.diameterMm, 0.35).toDouble();

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

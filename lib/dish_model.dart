import 'dart:math';

import 'antenna_design.dart';

/// User-adjustable prime-focus parabolic dish parameters.
class DishParameters {
  double frequencyMHz;
  double diameterM;
  double fOverD; // focal length divided by aperture diameter
  double edgeTaperDb; // feed illumination at the rim, below boresight
  double surfaceRmsMm; // RMS deviation from a true paraboloid
  double blockagePercent; // feed and strut shadow, as a percentage of D
  double feedROhms; // resistance the feed itself presents at resonance
  double feedOhms;

  DishParameters({
    this.frequencyMHz = 2400.0,
    this.diameterM = 1.2,
    this.fOverD = 0.40,
    this.edgeTaperDb = 11.0,
    this.surfaceRmsMm = 1.0,
    this.blockagePercent = 8.0,
    this.feedROhms = 45.0,
    this.feedOhms = 50.0,
  });
}

/// Prime-focus parabolic reflector.
///
/// A dish is an exercise in aperture efficiency: the rim half-angle set by
/// f/D decides how hard the feed has to work, the edge taper trades
/// illumination against spillover, and Ruze's law quietly deletes the gain
/// of a dish that is not accurate to a small fraction of a wavelength.
class DishDesign extends AntennaDesign {
  final DishParameters p;
  DishDesign(this.p);

  double get wavelengthM => wavelengthMFor(p.frequencyMHz);
  double get diameterWl => p.diameterM / wavelengthM;
  double get focalLengthM => p.fOverD * p.diameterM;

  /// Half-angle subtended by the rim as seen from the focus.
  double get rimHalfAngleDeg => 2 * atan(1 / (4 * p.fOverD)) * 180 / pi;

  /// A dish smaller than a few wavelengths is not really an aperture.
  bool get tooSmall => diameterWl < 3;

  /// Beyond about lambda/32 RMS, Ruze is costing more than half a dB.
  bool get surfaceMarginal => p.surfaceRmsMm / 1000 > wavelengthM / 32;

  // ---- efficiency ----

  /// Feed pattern exponent n in cos^n(theta) that produces the requested
  /// edge taper at the rim.
  double get feedExponent {
    final t0 = rimHalfAngleDeg * pi / 180;
    final denom = -20 * log10(max(1e-6, cos(t0)));
    return (p.edgeTaperDb / denom).clamp(0.2, 40.0);
  }

  /// Combined illumination and spillover efficiency for a cos^n feed:
  /// cot^2(theta0/2) |integral of sqrt(G_f) tan(theta/2) dtheta|^2.
  late final double _apertureIllumination = _computeIllumination();

  double _computeIllumination() {
    final t0 = rimHalfAngleDeg * pi / 180;
    final n = feedExponent;
    final g0 = 2 * (2 * n + 1); // peak gain of a cos^n feed
    const steps = 400;
    final h = t0 / steps;
    double f(double t) => pow(cos(t), n).toDouble() * tan(t / 2);
    var s = f(0) + f(t0);
    for (var i = 1; i < steps; i++) {
      s += f(i * h) * (i.isOdd ? 4 : 2);
    }
    final integral = s * h / 3;
    final cot = 1 / tan(t0 / 2);
    return (cot * cot * g0 * integral * integral).clamp(0.0, 1.0);
  }

  /// Ruze: random surface error costs exp(-(4 pi eps / lambda)^2).
  double get surfaceEfficiency {
    final e = p.surfaceRmsMm / 1000 / wavelengthM;
    return exp(-pow(4 * pi * e, 2).toDouble());
  }

  /// Aperture blockage by the feed and its supports.
  double get blockageEfficiency =>
      pow(1 - pow(p.blockagePercent / 100, 2), 2).toDouble();

  double get apertureEfficiency =>
      _apertureIllumination * surfaceEfficiency * blockageEfficiency;

  double get ruzeLossDb => -10 * log10(surfaceEfficiency);

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;

  // ---- gain / pattern ----

  @override
  double get gainDbi {
    final gLin = apertureEfficiency * pow(pi * diameterWl, 2).toDouble();
    return max(0.0, 10 * log10(gLin));
  }

  /// Voltage pedestal at the rim implied by the edge taper.
  double get _pedestal => pow(10, -p.edgeTaperDb / 20).toDouble();

  /// Circular aperture, parabolic-on-a-pedestal illumination. Unlike the
  /// shaped single-lobe model used elsewhere in the app, this is the real
  /// aperture transform, so the sidelobe rings appear on the polar plot.
  double _apertureDb(double angleDeg) {
    final a = (((angleDeg + 180) % 360) - 180) * pi / 180;
    final u = pi * diameterWl * sin(a);
    final p0 = _pedestal;
    double f;
    if (u.abs() < 1e-6) {
      f = 1.0;
    } else {
      final lam1 = 2 * besselJ1(u) / u;
      final lam2 = 8 * besselJ2(u) / (u * u);
      f = (2 * p0 * lam1 + (1 - p0) * lam2) / (1 + p0);
    }
    // The transform is written in sin(theta) and so is symmetric front to
    // back; the reflector is not. Behind the rim there is only spillover,
    // which fills in a floor around -30 dB.
    final main = cos(a) > 0 ? f * f : 0.0;
    final floor = 1e-3 * (0.05 + 0.95 * (1 - cos(a)) / 2);
    return 10 * log10(main + floor);
  }

  late final double _hpbw = hpbwOf(_apertureDb, stepDeg: 0.1);

  @override
  double get hpbwAzDeg => _hpbw;
  @override
  double get hpbwElDeg => _hpbw; // circularly symmetric aperture

  /// First sidelobe level in dB below the main lobe, read off the pattern.
  late final double _sidelobeDb = _findFirstSidelobe();

  double _findFirstSidelobe() {
    var falling = true;
    var prev = _apertureDb(0);
    for (var a = 0.1; a < 90; a += 0.1) {
      final v = _apertureDb(a);
      if (falling) {
        if (v > prev) falling = false;
      } else if (v < prev) {
        return prev;
      }
      prev = v;
    }
    return -40;
  }

  double get firstSidelobeDb => _sidelobeDb;

  @override
  double get frontToBackDb => 30;

  @override
  double azimuthDb(double angleDeg) =>
      _apertureDb(angleDeg).clamp(-40.0, 0.0);

  @override
  double elevationDb(double angleDeg) =>
      _apertureDb(angleDeg).clamp(-40.0, 0.0);

  // ---- impedance ----

  /// The reflector does not set the impedance - the feed does. This models
  /// a typical moderately broadband feed at the design frequency.
  @override
  double get feedpointROhms => p.feedROhms;

  @override
  double get qFactor => 6;

  @override
  Impedance impedanceAt(double fMHz) =>
      rlcImpedance(fMHz, p.frequencyMHz, feedpointROhms, qFactor);
}

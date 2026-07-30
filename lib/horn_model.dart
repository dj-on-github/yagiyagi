import 'dart:math';

import 'antenna_design.dart';

/// Standard rectangular waveguide sizes that fall inside this app's
/// frequency range.
enum WaveguideSize { wr1500, wr975, wr650, wr430, wr284, wr187, wr137 }

extension WaveguideSizeInfo on WaveguideSize {
  String get label => switch (this) {
        WaveguideSize.wr1500 => 'WR-1500',
        WaveguideSize.wr975 => 'WR-975',
        WaveguideSize.wr650 => 'WR-650',
        WaveguideSize.wr430 => 'WR-430',
        WaveguideSize.wr284 => 'WR-284',
        WaveguideSize.wr187 => 'WR-187',
        WaveguideSize.wr137 => 'WR-137',
      };

  /// Broad wall, mm.
  double get aMm => switch (this) {
        WaveguideSize.wr1500 => 381.00,
        WaveguideSize.wr975 => 247.65,
        WaveguideSize.wr650 => 165.10,
        WaveguideSize.wr430 => 109.22,
        WaveguideSize.wr284 => 72.14,
        WaveguideSize.wr187 => 47.55,
        WaveguideSize.wr137 => 34.85,
      };

  /// Narrow wall, mm.
  double get bMm => switch (this) {
        WaveguideSize.wr1500 => 190.50,
        WaveguideSize.wr975 => 123.83,
        WaveguideSize.wr650 => 82.55,
        WaveguideSize.wr430 => 54.61,
        WaveguideSize.wr284 => 34.04,
        WaveguideSize.wr187 => 22.15,
        WaveguideSize.wr137 => 15.80,
      };

  /// Recommended operating band, MHz.
  String get bandLabel => switch (this) {
        WaveguideSize.wr1500 => '490 - 750 MHz',
        WaveguideSize.wr975 => '750 - 1120 MHz',
        WaveguideSize.wr650 => '1.12 - 1.70 GHz',
        WaveguideSize.wr430 => '1.70 - 2.60 GHz',
        WaveguideSize.wr284 => '2.60 - 3.95 GHz',
        WaveguideSize.wr187 => '3.95 - 5.85 GHz',
        WaveguideSize.wr137 => '5.85 - 8.20 GHz',
      };
}

/// User-adjustable pyramidal horn parameters.
class HornParameters {
  double frequencyMHz;
  WaveguideSize guide;
  double apertureAMm; // H-plane aperture width
  double apertureBMm; // E-plane aperture height
  double axialLengthMm; // guide mouth to aperture, along the axis
  double transitionROhms; // coax-to-guide probe transition
  double feedOhms;

  HornParameters({
    this.frequencyMHz = 2400.0,
    this.guide = WaveguideSize.wr430,
    this.apertureAMm = 334.0,
    this.apertureBMm = 252.0,
    this.axialLengthMm = 200.0,
    this.transitionROhms = 50.0,
    this.feedOhms = 50.0,
  });
}

/// Pyramidal horn.
///
/// A horn is an aperture with a phase error. Flaring the guide buys area,
/// but the walls are further from the throat at the edges than at the
/// centre, and that path difference is what stops gain from growing with
/// aperture forever. The two normalised phase errors s and t are the whole
/// story: an optimum horn sits at s = 0.25 and t = 0.375, where the aperture
/// efficiency has fallen to the familiar 0.51.
class HornDesign extends AntennaDesign {
  final HornParameters p;
  HornDesign(this.p);

  double get wavelengthMm => wavelengthMFor(p.frequencyMHz) * 1000;
  double get guideAMm => p.guide.aMm;
  double get guideBMm => p.guide.bMm;

  /// Apertures can never be smaller than the guide that feeds them.
  double get apertureAMm => max(p.apertureAMm, guideAMm);
  double get apertureBMm => max(p.apertureBMm, guideBMm);

  /// TE10 cutoff: nothing propagates below it.
  double get cutoffTe10MHz => 299792.458 / (2 * guideAMm);

  /// TE20 cutoff: above it the guide is over-moded.
  double get cutoffTe20MHz => 299792.458 / guideAMm;

  bool get propagates => p.frequencyMHz > cutoffTe10MHz;
  bool get overModed => p.frequencyMHz > cutoffTe20MHz;

  double get guideWavelengthMm {
    if (!propagates) return double.infinity;
    final r = cutoffTe10MHz / p.frequencyMHz;
    return wavelengthMm / sqrt(1 - r * r);
  }

  /// Slant distances from the flare apex to the aperture.
  double get rhoEMm {
    final d = apertureBMm - guideBMm;
    return d < 1e-6 ? double.infinity : p.axialLengthMm * apertureBMm / d;
  }

  double get rhoHMm {
    final d = apertureAMm - guideAMm;
    return d < 1e-6 ? double.infinity : p.axialLengthMm * apertureAMm / d;
  }

  /// Normalised E-plane quadratic phase error; the optimum horn sits at 0.25.
  double get sPhase => rhoEMm.isInfinite
      ? 0
      : apertureBMm * apertureBMm / (8 * wavelengthMm * rhoEMm);

  /// Normalised H-plane phase error; the optimum horn sits at 0.375.
  double get tPhase => rhoHMm.isInfinite
      ? 0
      : apertureAMm * apertureAMm / (8 * wavelengthMm * rhoHMm);

  /// Optimum-gain apertures for the current axial length.
  ///
  /// The textbook rules b1 = sqrt(2 lambda rho_E) and a1 = sqrt(3 lambda
  /// rho_H) are written in terms of the slant distances, which themselves
  /// depend on the aperture. Substituting rho = L a1 / (a1 - a) turns each
  /// into a quadratic with one positive root.
  double get optimumAMm =>
      (guideAMm +
          sqrt(guideAMm * guideAMm + 12 * wavelengthMm * p.axialLengthMm)) /
      2;

  double get optimumBMm =>
      (guideBMm +
          sqrt(guideBMm * guideBMm + 8 * wavelengthMm * p.axialLengthMm)) /
      2;

  // ---- aperture efficiency by direct integration ----

  /// |integral over the normalised aperture|^2, for a uniform (E-plane) or
  /// cosine (H-plane) distribution carrying a quadratic phase error.
  double _phaseLoss(double phase, {required bool cosineTaper}) {
    const steps = 400;
    const lo = -0.5, hi = 0.5;
    final h = (hi - lo) / steps;
    double amp(double x) => cosineTaper ? cos(pi * x) : 1.0;
    double phi(double x) => 8 * pi * phase * x * x;

    var re = 0.0, im = 0.0;
    for (var i = 0; i <= steps; i++) {
      final x = lo + i * h;
      final w = (i == 0 || i == steps) ? 1.0 : (i.isOdd ? 4.0 : 2.0);
      final a = amp(x);
      re += w * a * cos(phi(x));
      im -= w * a * sin(phi(x));
    }
    re *= h / 3;
    im *= h / 3;
    final ideal = cosineTaper ? 2 / pi : 1.0;
    return (re * re + im * im) / (ideal * ideal);
  }

  late final double _lossE = _phaseLoss(sPhase, cosineTaper: false);
  late final double _lossH = _phaseLoss(tPhase, cosineTaper: true);

  double get ePlaneLossDb => -10 * log10(max(1e-6, _lossE));
  double get hPlaneLossDb => -10 * log10(max(1e-6, _lossH));

  /// 8/pi^2 for the cosine taper in the H plane, times the two phase-error
  /// loss factors. An optimum horn lands on 0.51, as it should.
  double get apertureEfficiency => 8 / (pi * pi) * _lossE * _lossH;

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;

  // ---- gain / pattern ----

  @override
  double get gainDbi {
    if (!propagates) return 0;
    final gLin = apertureEfficiency *
        4 *
        pi *
        apertureAMm *
        apertureBMm /
        (wavelengthMm * wavelengthMm);
    return max(0.0, 10 * log10(gLin));
  }

  @override
  double get frontToBackDb => 28; // flared, flanged aperture

  /// H-plane, in the azimuth cut.
  @override
  double get hpbwAzDeg {
    final base = 70 * wavelengthMm / apertureAMm;
    final broaden = 1 + 0.4 * max(0.0, tPhase / 0.375 - 1);
    return (base * broaden).clamp(6.0, 140.0);
  }

  /// E-plane, in the elevation cut.
  @override
  double get hpbwElDeg {
    final base = 51 * wavelengthMm / apertureBMm;
    final broaden = 1 + 0.5 * max(0.0, sPhase / 0.25 - 1);
    return (base * broaden).clamp(6.0, 140.0);
  }

  @override
  double azimuthDb(double angleDeg) => propagates
      ? lobePatternDb(angleDeg, hpbwAzDeg, frontToBackDb)
      : -40;

  @override
  double elevationDb(double angleDeg) => propagates
      ? lobePatternDb(angleDeg, hpbwElDeg, frontToBackDb)
      : -40;

  // ---- impedance ----

  @override
  double get feedpointROhms => p.transitionROhms;

  @override
  double get qFactor => 4;

  @override
  Impedance impedanceAt(double fMHz) {
    if (fMHz <= cutoffTe10MHz) {
      final depth = cutoffTe10MHz / fMHz - 1;
      return Impedance(8, -250 * (1 + depth));
    }
    // Broad probe resonance, plus the reactive wall the guide throws up as
    // it approaches cutoff.
    final base = rlcImpedance(fMHz, p.frequencyMHz, feedpointROhms, qFactor);
    final rel = cutoffTe10MHz / fMHz;
    final wall = 1 / (1 - rel * rel) - 1;
    return Impedance(base.r, base.x - p.feedOhms * 0.8 * wall);
  }

  @override
  double get bandwidth2to1MHz =>
      propagates ? bandwidth2to1(p.frequencyMHz, swrAt, maxSpanFrac: 0.6) : 0;

  @override
  double get sweepMinMHz => max(cutoffTe10MHz * 0.92, p.frequencyMHz * 0.5);
  @override
  double get sweepMaxMHz => max(cutoffTe20MHz * 1.05, p.frequencyMHz * 1.2);
}

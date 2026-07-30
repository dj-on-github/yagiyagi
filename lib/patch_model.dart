import 'dart:math';

import 'antenna_design.dart';

/// Common microwave laminates.
enum Substrate { rogers5880, rogers4003, fr4, alumina }

extension SubstrateInfo on Substrate {
  String get label => switch (this) {
        Substrate.rogers5880 => 'RT/duroid 5880',
        Substrate.rogers4003 => 'RO4003C',
        Substrate.fr4 => 'FR-4',
        Substrate.alumina => 'Alumina',
      };

  double get epsilonR => switch (this) {
        Substrate.rogers5880 => 2.20,
        Substrate.rogers4003 => 3.55,
        Substrate.fr4 => 4.40,
        Substrate.alumina => 9.80,
      };

  double get tanDelta => switch (this) {
        Substrate.rogers5880 => 0.0009,
        Substrate.rogers4003 => 0.0027,
        Substrate.fr4 => 0.0200,
        Substrate.alumina => 0.0001,
      };
}

/// How the patch is driven.
enum PatchFeed { insetMicrostrip, coaxProbe, edgeDirect }

extension PatchFeedLabel on PatchFeed {
  String get label => switch (this) {
        PatchFeed.insetMicrostrip => 'Inset line',
        PatchFeed.coaxProbe => 'Coax probe',
        PatchFeed.edgeDirect => 'Edge (direct)',
      };
}

/// User-adjustable rectangular microstrip patch parameters.
class PatchParameters {
  double frequencyMHz;
  Substrate substrate;
  double heightMm; // substrate thickness
  double widthFactor; // patch width relative to the standard design width
  PatchFeed feed;
  double feedOhms;

  PatchParameters({
    this.frequencyMHz = 2400.0,
    this.substrate = Substrate.fr4,
    this.heightMm = 1.6,
    this.widthFactor = 1.0,
    this.feed = PatchFeed.insetMicrostrip,
    this.feedOhms = 50.0,
  });
}

/// Rectangular microstrip patch, built on the standard transmission-line
/// design equations.
///
/// The patch is the one antenna in this app that really is a high-Q
/// resonator, so the series-RLC impedance model is honest here: the same
/// substrate choice that sets the efficiency also sets the Q, and the Q sets
/// the bandwidth. FR-4 at 1.6 mm lands near 3 % and about half the power
/// arrives as heat; a thicker, lower-permittivity laminate fixes both.
class PatchDesign extends AntennaDesign {
  final PatchParameters p;
  PatchDesign(this.p);

  double get epsilonR => p.substrate.epsilonR;
  double get wavelengthM => wavelengthMFor(p.frequencyMHz);
  double get heightM => p.heightMm / 1000;
  double get frequencyHz => p.frequencyMHz * 1e6;

  /// Standard design width: half a wavelength scaled for the average of the
  /// air and substrate permittivity.
  double get designWidthM =>
      wavelengthM / 2 * sqrt(2 / (epsilonR + 1));

  double get widthM => p.widthFactor * designWidthM;
  double get widthMm => widthM * 1000;

  /// Effective permittivity seen by the patch's fringing fields.
  double get epsilonEff =>
      (epsilonR + 1) / 2 +
      (epsilonR - 1) / 2 / sqrt(1 + 12 * heightM / widthM);

  /// Fringing extends the patch electrically at both radiating edges.
  double get deltaLM {
    final wh = widthM / heightM;
    return 0.412 *
        heightM *
        ((epsilonEff + 0.3) * (wh + 0.264)) /
        ((epsilonEff - 0.258) * (wh + 0.8));
  }

  double get lengthM =>
      max(1e-4, wavelengthM / (2 * sqrt(epsilonEff)) - 2 * deltaLM);
  double get lengthMm => lengthM * 1000;

  // ---- radiation, loss and Q ----

  /// Slot conductance of one radiating edge.
  double get slotConductance {
    final wl = widthM / wavelengthM;
    return wl < 0.35 ? pow(wl, 2).toDouble() / 90 : wl / 120;
  }

  /// Resistance looking into a radiating edge of the patch.
  double get edgeResistanceOhms => 1 / (2 * slotConductance);

  /// Radiation Q of a thin patch.
  double get qRadiation =>
      wavelengthM * sqrt(epsilonR) / (4 * heightM);

  double get qDielectric => 1 / p.substrate.tanDelta;

  /// Conductor Q: substrate thickness divided by the copper skin depth.
  double get qConductor {
    const rhoCu = 1.72e-8;
    final skinDepth = sqrt(rhoCu / (pi * frequencyHz * 4e-7 * pi));
    return heightM / skinDepth;
  }

  /// Fraction of the radiated power trapped in substrate surface waves.
  double get surfaceWaveFraction =>
      (20 * (1 - 1 / epsilonR) * heightM / wavelengthM).clamp(0.0, 0.6);

  double get qSurfaceWave {
    final s = surfaceWaveFraction;
    return s <= 1e-4 ? 1e6 : qRadiation * (1 - s) / s;
  }

  double get qTotal => 1 /
      (1 / qRadiation + 1 / qDielectric + 1 / qConductor + 1 / qSurfaceWave);

  double get efficiency => qTotal / qRadiation;
  double get efficiencyDb => 10 * log10(efficiency);

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;

  // ---- gain / pattern ----

  /// Directivity scales with the radiating edge width; a high-permittivity
  /// laminate shrinks the patch and takes directivity with it.
  double get directivityLin {
    final reference = wavelengthM / 2 * sqrt(2 / (2.2 + 1));
    return (6.6 * widthM / reference).clamp(3.0, 12.0);
  }

  double get directivityDbiValue => 10 * log10(directivityLin);

  @override
  double get gainDbi => directivityDbiValue + efficiencyDb;

  /// A patch sits on a ground plane, so the back lobe is modest.
  @override
  double get frontToBackDb => 15;

  @override
  double get hpbwAzDeg => (175 / sqrt(directivityLin)).clamp(50.0, 140.0);

  @override
  double get hpbwElDeg =>
      (41253 / (directivityLin * hpbwAzDeg)).clamp(50.0, 150.0);

  @override
  double azimuthDb(double angleDeg) =>
      lobePatternDb(angleDeg, hpbwAzDeg, frontToBackDb);

  @override
  double elevationDb(double angleDeg) =>
      lobePatternDb(angleDeg, hpbwElDeg, frontToBackDb);

  // ---- feed and impedance ----

  /// Inset distance from the radiating edge that transforms the edge
  /// resistance down to the feedline: R(y) = R_edge cos^2(pi y / L).
  double get insetDistanceM {
    final ratio = (p.feedOhms / edgeResistanceOhms).clamp(0.0, 1.0);
    return lengthM / pi * acos(sqrt(ratio));
  }

  double get insetDistanceMm => insetDistanceM * 1000;

  /// Microstrip width for the feedline impedance (Hammerstad synthesis,
  /// wide-strip branch).
  double get feedLineWidthMm {
    final b = 377 * pi / (2 * p.feedOhms * sqrt(epsilonR));
    final wh = 2 /
        pi *
        (b -
            1 -
            log(2 * b - 1) +
            (epsilonR - 1) /
                (2 * epsilonR) *
                (log(b - 1) + 0.39 - 0.61 / epsilonR));
    return wh * p.heightMm;
  }

  /// An inset line or a correctly placed probe is matched by construction;
  /// a direct edge feed shows the patch's raw edge resistance.
  @override
  double get feedpointROhms => p.feed == PatchFeed.edgeDirect
      ? edgeResistanceOhms
      : p.feedOhms;

  @override
  double get qFactor => qTotal;

  @override
  Impedance impedanceAt(double fMHz) =>
      rlcImpedance(fMHz, p.frequencyMHz, feedpointROhms, qFactor);

  double get _spanFrac => (6 / qTotal).clamp(0.02, 0.12);

  @override
  double get sweepMinMHz => p.frequencyMHz * (1 - _spanFrac);
  @override
  double get sweepMaxMHz => p.frequencyMHz * (1 + _spanFrac);
}

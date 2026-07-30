import 'dart:math';

import 'antenna_design.dart';

/// Loop conductor material, as bulk resistivity in ohm-metres.
enum LoopConductor { copper, aluminium, brass }

extension LoopConductorInfo on LoopConductor {
  String get label => switch (this) {
        LoopConductor.copper => 'Copper',
        LoopConductor.aluminium => 'Aluminium',
        LoopConductor.brass => 'Brass',
      };

  double get resistivity => switch (this) {
        LoopConductor.copper => 1.72e-8,
        LoopConductor.aluminium => 2.82e-8,
        LoopConductor.brass => 7.0e-8,
      };
}

/// Tuning capacitor type. In a small loop the capacitor sits in series with
/// a radiation resistance of a few tens of milliohms, so its own loss is
/// rarely negligible.
enum TuningCapacitor { vacuum, butterfly, splitStator }

extension TuningCapacitorInfo on TuningCapacitor {
  String get label => switch (this) {
        TuningCapacitor.vacuum => 'Vacuum',
        TuningCapacitor.butterfly => 'Butterfly',
        TuningCapacitor.splitStator => 'Split stator',
      };

  /// Unloaded Q of the capacitor itself.
  double get q => switch (this) {
        TuningCapacitor.vacuum => 5000,
        TuningCapacitor.butterfly => 2500,
        TuningCapacitor.splitStator => 1200,
      };
}

/// User-adjustable small transmitting ("magnetic") loop parameters.
class MagLoopParameters {
  double frequencyMHz;
  double loopDiameterM;
  double conductorDiameterMm;
  LoopConductor conductor;
  TuningCapacitor capacitor;
  double heightWl; // height above ground; 0 = free space
  double powerW; // transmit power, for the capacitor voltage readout
  double feedOhms;

  MagLoopParameters({
    this.frequencyMHz = 14.2,
    this.loopDiameterM = 1.0,
    this.conductorDiameterMm = 22.0,
    this.conductor = LoopConductor.copper,
    this.capacitor = TuningCapacitor.butterfly,
    this.heightWl = 0.0,
    this.powerW = 100.0,
    this.feedOhms = 50.0,
  });
}

/// Small transmitting loop: a series-resonant ring whose radiation
/// resistance is measured in milliohms.
///
/// Everything interesting about this antenna falls out of one comparison -
/// radiation resistance against conductor and capacitor loss. That ratio is
/// the efficiency, and the same numbers set a Q in the hundreds or
/// thousands, which is why the 2:1 bandwidth is a few kHz wide.
class MagLoopDesign extends AntennaDesign {
  final MagLoopParameters p;
  MagLoopDesign(this.p);

  double get wavelengthM => wavelengthMFor(p.frequencyMHz);
  double get frequencyHz => p.frequencyMHz * 1e6;
  double get circumferenceM => pi * p.loopDiameterM;
  double get areaM2 => pi * pow(p.loopDiameterM / 2, 2).toDouble();
  double get conductorRadiusM => p.conductorDiameterMm / 2000;
  double get circumferenceWl => circumferenceM / wavelengthM;
  bool get overGround => p.heightWl > 0.0;

  /// Above about a quarter wavelength of circumference the current is no
  /// longer uniform and the small-loop formulas start to flatter the design.
  bool get tooLarge => circumferenceWl > 0.25;

  // ---- resistances ----

  /// Small-loop radiation resistance, 31171 (A / lambda^2)^2 ohms.
  double get radiationROhms =>
      31171 * pow(areaM2 / (wavelengthM * wavelengthM), 2).toDouble();

  /// Surface resistance of the conductor at this frequency, ohms/square.
  double get surfaceResistance =>
      sqrt(pi * frequencyHz * 4e-7 * pi * p.conductor.resistivity);

  /// Skin-effect loss around the loop.
  double get conductorLossROhms =>
      circumferenceM / (pi * p.conductorDiameterMm / 1000) * surfaceResistance;

  /// Loss in the tuning capacitor, X / Q.
  double get capacitorLossROhms => inductiveReactance / p.capacitor.q;

  double get totalROhms =>
      radiationROhms + conductorLossROhms + capacitorLossROhms;

  double get efficiency => radiationROhms / totalROhms;
  double get efficiencyDb => 10 * log10(efficiency);

  // ---- resonator ----

  /// Self-inductance of a single-turn circular loop.
  double get inductanceH {
    final a = p.loopDiameterM / 2;
    return 4e-7 * pi * a * max(0.1, log(8 * a / conductorRadiusM) - 2);
  }

  double get inductiveReactance => 2 * pi * frequencyHz * inductanceH;

  /// Capacitance needed to resonate the loop here.
  double get tuningCapacitancePf =>
      1e12 / (2 * pi * frequencyHz * inductiveReactance);

  /// Unloaded Q of the resonator.
  double get unloadedQ => inductiveReactance / totalROhms;

  /// RMS loop current at the operating power.
  double get loopCurrentA => sqrt(p.powerW / totalROhms);

  /// RMS voltage across the tuning capacitor. This is the number that
  /// decides whether the capacitor survives.
  double get capacitorVoltageV => loopCurrentA * inductiveReactance;

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;

  /// A loop mounted in a vertical plane radiates vertically polarised.
  @override
  Polarization get polarization => Polarization.vertical;

  // ---- gain / pattern ----

  /// Power pattern of a magnetic dipole lying along y (the loop plane
  /// contains the 0 degree axis), optionally with its in-phase ground image.
  double _powerLin(double thetaDeg, double phiDeg) {
    final t = thetaDeg * pi / 180, ph = phiDeg * pi / 180;
    final u = 1 - pow(sin(t) * sin(ph), 2).toDouble();
    if (!overGround) return u;
    // Vertical polarisation reflects in phase, so the image reinforces the
    // horizon rather than nulling it.
    return u * pow(2 * cos(2 * pi * p.heightWl * cos(t)), 2).toDouble();
  }

  late final double _directivity =
      directivityDbi(_powerLin, hemisphere: overGround);

  @override
  double get gainDbi => _directivity + efficiencyDb;

  @override
  double get frontToBackDb => 0; // bidirectional

  @override
  double get hpbwAzDeg => 90; // cosine figure-8 in the plane of the loop

  late final double _hpbwEl = hpbwOf(elevationDb);

  @override
  double get hpbwElDeg => overGround ? _hpbwEl : 180;

  @override
  double azimuthDb(double angleDeg) {
    final f = cos(angleDeg * pi / 180).abs();
    if (f < 1e-4) return -40;
    return (20 * log10(f)).clamp(-40.0, 0.0);
  }

  @override
  double elevationDb(double angleDeg) {
    final sinEl = sin(angleDeg * pi / 180);
    if (sinEl < 0) return -40; // nothing below the horizon
    if (!overGround) return 0; // free space: circular in this cut
    final g = cos(2 * pi * p.heightWl * sinEl).abs();
    return (20 * log10(g.clamp(1e-4, 1.0))).clamp(-40.0, 0.0);
  }

  // ---- impedance / SWR ----

  /// The loop itself is a fraction of an ohm; a coupling loop or gamma rod
  /// transforms that up to the feedline. Assume it is adjusted for a match
  /// at the tuned frequency - which is what the capacitor guarantees.
  @override
  double get feedpointROhms => p.feedOhms;

  /// Critical coupling halves the unloaded Q.
  @override
  double get qFactor => unloadedQ / 2;

  @override
  Impedance impedanceAt(double fMHz) =>
      rlcImpedance(fMHz, p.frequencyMHz, feedpointROhms, qFactor);

  @override
  double get bandwidth2to1MHz =>
      bandwidth2to1(p.frequencyMHz, swrAt, maxSpanFrac: 0.05);

  /// The 2:1 window is a few parts in ten thousand wide, so the sweep has to
  /// zoom in or the plot degenerates into a vertical line.
  double get _spanFrac => max(0.002, 4 / qFactor);

  @override
  double get sweepMinMHz => p.frequencyMHz * (1 - _spanFrac);
  @override
  double get sweepMaxMHz => p.frequencyMHz * (1 + _spanFrac);
}

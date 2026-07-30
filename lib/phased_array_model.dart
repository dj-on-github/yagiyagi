import 'dart:math';

import 'antenna_design.dart';
import 'vertical_model.dart';

/// User-adjustable two-element phased vertical array parameters.
class PhasedArrayParameters {
  double frequencyMHz;
  double spacingWl;
  double phaseDeg; // phase of element 2 relative to element 1
  double amplitudeRatio; // current in element 2, relative to element 1
  double diameterMm;
  int radialCount;
  GroundQuality ground;
  double feedOhms;

  PhasedArrayParameters({
    this.frequencyMHz = 7.1,
    this.spacingWl = 0.25,
    this.phaseDeg = -90.0,
    this.amplitudeRatio = 1.0,
    this.diameterMm = 25.0,
    this.radialCount = 16,
    this.ground = GroundQuality.average,
    this.feedOhms = 50.0,
  });
}

/// Two quarter-wave verticals, spaced and phased.
///
/// Nothing moves and no reflector is added, yet the pattern can be steered
/// from bidirectional broadside through a cardioid to endfire purely by
/// changing the phase of the second element. The price is paid at the
/// feedpoints: mutual coupling drives the two elements to wildly different
/// impedances, which is why phasing networks are harder than they look.
class PhasedArrayDesign extends AntennaDesign {
  final PhasedArrayParameters p;
  PhasedArrayDesign(this.p);

  double get wavelengthM => wavelengthMFor(p.frequencyMHz);
  double get spacingM => p.spacingWl * wavelengthM;
  double get elementHeightM => 0.239 * wavelengthM;

  /// The array is built from the same quarter-wave vertical modelled
  /// elsewhere in the app, so radials and soil behave identically.
  late final VerticalDesign element = VerticalDesign(VerticalParameters(
    frequencyMHz: p.frequencyMHz,
    diameterMm: p.diameterMm,
    radialCount: p.radialCount,
    radialDroopDeg: 0,
    ground: p.ground,
    feedOhms: p.feedOhms,
  ));

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;
  @override
  Polarization get polarization => Polarization.vertical;

  double get _beta => p.phaseDeg * pi / 180;

  // ---- array factor ----

  /// |1 + a exp(j(k d u + beta))|, with u the direction cosine along the
  /// array axis. Element 2 sits towards 0 degrees.
  double _arrayFactor(double u, double dWl) {
    final psi = 2 * pi * dWl * u + _beta;
    final a = p.amplitudeRatio;
    final re = 1 + a * cos(psi);
    final im = a * sin(psi);
    return sqrt(re * re + im * im);
  }

  /// Azimuth cut, at the horizon.
  double _azLin(double angleDeg) =>
      _arrayFactor(cos(angleDeg * pi / 180), p.spacingWl);

  late final List<double> _azScan = _scanAzimuth();

  List<double> _scanAzimuth() {
    var best = 0.0, bestAt = 0.0;
    for (var a = 0.0; a < 360; a += 0.5) {
      final v = _azLin(a);
      if (v > best) {
        best = v;
        bestAt = a;
      }
    }
    return [best, bestAt];
  }

  double get _azPeak => _azScan[0];

  /// Azimuth of the strongest lobe, in degrees.
  double get peakAzimuthDeg => _azScan[1];

  @override
  double azimuthDb(double angleDeg) {
    final v = _azLin(angleDeg) / max(1e-9, _azPeak);
    return (20 * log10(v.clamp(1e-4, 1.0))).clamp(-40.0, 0.0);
  }

  /// Elevation cut taken through the peak azimuth, so the plot shows the
  /// lobe the array actually makes.
  @override
  double elevationDb(double angleDeg) {
    final sinEl = sin(angleDeg * pi / 180);
    if (sinEl < 0) return -40;
    final cosEl = cos(asin(sinEl.clamp(0.0, 1.0)));
    // Angles past 90 degrees are the opposite side of the same cut.
    final side = angleDeg <= 90 ? 1.0 : -1.0;
    final u = side * cosEl * cos(peakAzimuthDeg * pi / 180);
    final af = _arrayFactor(u, p.spacingWl);
    final elDb = element.elevationDb(angleDeg);
    return (elDb + 20 * log10((af / max(1e-9, _azPeak)).clamp(1e-4, 4.0)))
        .clamp(-40.0, 0.0);
  }

  // ---- gain ----

  double _powerLin(double thetaDeg, double phiDeg) {
    final elDb = element.elevationDb(90 - thetaDeg);
    final elLin = pow(10, elDb / 10).toDouble();
    final u = sin(thetaDeg * pi / 180) * cos(phiDeg * pi / 180);
    final af = _arrayFactor(u, p.spacingWl);
    return elLin * af * af;
  }

  double _elementPowerLin(double thetaDeg, double phiDeg) =>
      pow(10, element.elevationDb(90 - thetaDeg) / 10).toDouble();

  late final double _arrayD =
      directivityDbi(_powerLin, hemisphere: true, stepDeg: 3);
  late final double _elementD =
      directivityDbi(_elementPowerLin, hemisphere: true, stepDeg: 3);

  /// Directivity the array adds over one element on its own.
  double get arrayGainDb => _arrayD - _elementD;

  @override
  double get gainDbi => element.gainDbi + arrayGainDb;

  @override
  double get frontToBackDb {
    final front = _azLin(peakAzimuthDeg);
    final back = _azLin(peakAzimuthDeg + 180);
    if (back <= 1e-6) return 40;
    return (20 * log10(front / back)).clamp(0.0, 40.0);
  }

  late final double _hpbwAz = hpbwOf((a) => azimuthDb(a + peakAzimuthDeg));

  @override
  double get hpbwAzDeg => _hpbwAz;

  late final double _hpbwEl = hpbwOf(elevationDb);

  @override
  double get hpbwElDeg => _hpbwEl;

  // ---- mutual coupling and drive impedances ----

  /// Mutual impedance changes with electrical spacing, and the impedance
  /// plot sweeps frequency, so the Ci/Si evaluation is tabulated once per
  /// design and interpolated.
  late final List<Impedance> _mutualTable = _buildMutualTable();
  static const int _tableSteps = 40;
  double get _tableLo => p.spacingWl * 0.5;
  double get _tableHi => p.spacingWl * 1.6;

  List<Impedance> _buildMutualTable() {
    final out = <Impedance>[];
    for (var i = 0; i <= _tableSteps; i++) {
      final d = _tableLo + (_tableHi - _tableLo) * i / _tableSteps;
      final z = mutualImpedanceHalfWave(d);
      // Monopoles over a ground plane couple half as hard as dipoles.
      out.add(Impedance(z.r / 2, z.x / 2));
    }
    return out;
  }

  Impedance mutualAt(double dWl) {
    final t = ((dWl - _tableLo) / (_tableHi - _tableLo) * _tableSteps)
        .clamp(0.0, _tableSteps.toDouble());
    final i = t.floor().clamp(0, _tableSteps - 1);
    final f = t - i;
    final a = _mutualTable[i], b = _mutualTable[i + 1];
    return Impedance(a.r + (b.r - a.r) * f, a.x + (b.x - a.x) * f);
  }

  Impedance get mutualImpedance => mutualAt(p.spacingWl);

  /// Self resistance of one element, including its ground losses.
  double get selfROhms => element.feedpointROhms;

  /// Drive-point impedance of element 1 (the reference element) and
  /// element 2, including the current flowing in the other element.
  List<Impedance> driveImpedancesAt(double fMHz) {
    final self = rlcImpedance(fMHz, element.resonanceMHz, selfROhms, qFactor);
    final d = p.spacingWl * fMHz / p.frequencyMHz;
    final m = mutualAt(d);
    final a = p.amplitudeRatio;
    final cb = cos(_beta), sb = sin(_beta);

    final z1 = Impedance(
      self.r + a * (m.r * cb - m.x * sb),
      self.x + a * (m.r * sb + m.x * cb),
    );
    final z2 = Impedance(
      self.r + (m.r * cb + m.x * sb) / a,
      self.x + (-m.r * sb + m.x * cb) / a,
    );
    return [z1, z2];
  }

  Impedance get element1Impedance => driveImpedancesAt(p.frequencyMHz)[0];
  Impedance get element2Impedance => driveImpedancesAt(p.frequencyMHz)[1];

  /// True when coupling has pushed an element into negative resistance -
  /// it is absorbing power from the other element rather than radiating.
  bool get negativeResistance =>
      element1Impedance.r < 0 || element2Impedance.r < 0;

  /// The shared readouts follow element 1.
  @override
  double get feedpointROhms => element1Impedance.r;

  @override
  double get qFactor => 13 * pow(6 / p.diameterMm, 0.35).toDouble();

  @override
  Impedance impedanceAt(double fMHz) => driveImpedancesAt(fMHz)[0];

  @override
  double get bandwidth2to1MHz => bandwidth2to1(element.resonanceMHz, swrAt);
}

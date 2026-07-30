import 'dart:math';

import 'antenna_design.dart';

/// Corner apex angles for which the image expansion is exact, i.e. those
/// that divide 180 degrees a whole number of times.
enum ApexAngle { deg45, deg60, deg90, deg120, deg180 }

extension ApexAngleInfo on ApexAngle {
  double get degrees => switch (this) {
        ApexAngle.deg45 => 45,
        ApexAngle.deg60 => 60,
        ApexAngle.deg90 => 90,
        ApexAngle.deg120 => 120,
        ApexAngle.deg180 => 180,
      };

  String get label => switch (this) {
        ApexAngle.deg180 => 'Flat',
        _ => '${degrees.toStringAsFixed(0)}°',
      };

  /// Number of image sets: alpha = 180 / n.
  int get n => (180 / degrees).round();
}

/// User-adjustable corner reflector parameters.
class CornerReflectorParameters {
  double frequencyMHz;
  ApexAngle apex;
  double spacingWl; // driven element to apex
  double reflectorLengthWl; // side length of each reflector panel
  double rodSpacingWl; // gap between grid rods; 0 = solid sheet
  double feedOhms;

  CornerReflectorParameters({
    this.frequencyMHz = 433.0,
    this.apex = ApexAngle.deg90,
    this.spacingWl = 0.5,
    this.reflectorLengthWl = 1.2,
    this.rodSpacingWl = 0.05,
    this.feedOhms = 50.0,
  });
}

/// Corner reflector: a dipole and two flat panels, solved by images.
///
/// For an apex angle that divides 180 degrees exactly, the reflector can be
/// replaced by 2n-1 image dipoles spaced around the apex with alternating
/// signs. That makes the pattern, the gain and the driven-element impedance
/// all fall out of ordinary array arithmetic - and it explains why the
/// feedpoint resistance swings so violently with apex spacing.
class CornerReflectorDesign extends AntennaDesign {
  final CornerReflectorParameters p;
  CornerReflectorDesign(this.p);

  double get wavelengthM => wavelengthMFor(p.frequencyMHz);
  double get spacingM => p.spacingWl * wavelengthM;
  double get reflectorLengthM => p.reflectorLengthWl * wavelengthM;
  double get drivenLengthM => 0.478 * wavelengthM;

  /// Aperture width across the mouth of the corner.
  double get apertureWidthM =>
      2 * reflectorLengthM * sin(p.apex.degrees * pi / 360);

  @override
  double get centerFrequencyMHz => p.frequencyMHz;
  @override
  double get feedOhms => p.feedOhms;

  // ---- image expansion ----

  /// Driven element plus its images: position angle in radians, radius is
  /// always the apex spacing, and the sign alternates around the corner.
  late final List<List<double>> _elements = _buildElements();

  List<List<double>> _buildElements() {
    final out = <List<double>>[];
    final alpha = p.apex.degrees * pi / 180;
    // A corner of 180/n degrees has 2n-1 images, so 2n elements in all.
    final count = 2 * p.apex.n;
    for (var m = 0; m < count; m++) {
      final ang = m * alpha;
      final sign = m.isEven ? 1.0 : -1.0;
      out.add([p.spacingWl * cos(ang), p.spacingWl * sin(ang), sign]);
    }
    return out;
  }

  int get imageCount => _elements.length - 1;

  /// Array factor magnitude in the direction given by the direction cosines
  /// along the corner's x and y axes.
  double _arrayFactor(double ux, double uy) {
    var re = 0.0, im = 0.0;
    for (final e in _elements) {
      final phase = 2 * pi * (e[0] * ux + e[1] * uy);
      re += e[2] * cos(phase);
      im += e[2] * sin(phase);
    }
    return sqrt(re * re + im * im);
  }

  /// Element factor of the vertical half-wave driven element, as a function
  /// of the polar angle from the apex line.
  double _elementFactor(double cosTheta) {
    final sinTheta = sqrt(max(0.0, 1 - cosTheta * cosTheta));
    if (sinTheta < 1e-6) return 0;
    return cos(pi / 2 * cosTheta) / sinTheta;
  }

  double _azLin(double angleDeg) {
    final a = angleDeg * pi / 180;
    return _arrayFactor(cos(a), sin(a));
  }

  late final double _azPeak = () {
    var best = 1e-9;
    for (var a = 0.0; a < 360; a += 0.5) {
      best = max(best, _azLin(a));
    }
    return best;
  }();

  // ---- gain ----

  /// The image expansion is only valid in front of the reflector. Behind the
  /// mouth the panels block the field, and what leaks past is set by their
  /// size and by how coarse the grid is - not by the image array, which is
  /// symmetric front to back and would report no directivity at all.
  double _shadowDb(double offBoresightDeg) {
    final over = offBoresightDeg.abs() - 90;
    if (over <= 0) return 0;
    return -frontToBackDb * (over / 90);
  }

  /// A reflector shorter than twice the apex spacing starts leaking around
  /// the edges.
  double get sizeLossDb {
    final ratio = p.reflectorLengthWl / (2 * p.spacingWl);
    return ratio >= 1 ? 0.0 : 2.5 * pow(1 - ratio, 2).toDouble();
  }

  /// A grid of rods behaves like a sheet only while the gaps stay small.
  double get gridLossDb =>
      min(4.0, 20.0 * max(0.0, p.rodSpacingWl - 0.08));

  /// The images are not independent sources: all the radiated power still
  /// comes from the driven element, so the gain is the array's field
  /// enhancement referred back to the power actually delivered.
  ///
  ///   G = |AF|^2 * D_dipole * R_dipole / R_in
  ///
  /// which is why a corner that pulls the feedpoint resistance down is also
  /// a corner that gains - up to the point where the element can no longer
  /// be matched or the copper losses take over.
  @override
  double get gainDbi {
    final g = _azPeak * _azPeak * 1.64 * 73.1 / feedpointROhms;
    return 10 * log10(g) - sizeLossDb - gridLossDb;
  }

  /// Gain over the driven dipole on its own.
  double get gainOverDipoleDb => gainDbi - 2.15;

  /// A solid, generously sized reflector gets close to 30 dB; edge
  /// diffraction and grid leakage are what give it back.
  @override
  double get frontToBackDb =>
      (30 - 6 * sizeLossDb - 5 * gridLossDb).clamp(8.0, 35.0);

  late final double _hpbwAz = hpbwOf(azimuthDb);
  late final double _hpbwEl = hpbwOf(elevationDb);

  @override
  double get hpbwAzDeg => _hpbwAz;
  @override
  double get hpbwElDeg => _hpbwEl;

  @override
  double azimuthDb(double angleDeg) {
    final v = _azLin(angleDeg) / _azPeak;
    final off = ((angleDeg + 180) % 360) - 180;
    return (20 * log10(v.clamp(1e-4, 1.0)) + _shadowDb(off))
        .clamp(-40.0, 0.0);
  }

  /// Vertical plane through boresight. There is no ground in this model, so
  /// the pattern is symmetric about the horizon.
  @override
  double elevationDb(double angleDeg) {
    final a = angleDeg * pi / 180;
    final f = _elementFactor(sin(a));
    final af = _arrayFactor(cos(a), 0);
    final v = f * af / _azPeak;
    final off = ((angleDeg + 180) % 360) - 180;
    return (20 * log10(v.clamp(1e-4, 1.0)) + _shadowDb(off))
        .clamp(-40.0, 0.0);
  }

  // ---- driven element impedance ----

  /// Self impedance plus the contribution of every image, which is what
  /// makes a corner reflector's feedpoint so sensitive to apex spacing.
  late final Impedance _drivenImpedance = _computeDrivenImpedance();

  Impedance _computeDrivenImpedance() {
    var r = 73.1, x = 42.5; // free-space half-wave dipole
    final me = _elements.first;
    for (var i = 1; i < _elements.length; i++) {
      final e = _elements[i];
      final dx = e[0] - me[0], dy = e[1] - me[1];
      final d = sqrt(dx * dx + dy * dy);
      final z = mutualImpedanceHalfWave(d);
      r += e[2] * z.r;
      x += e[2] * z.x;
    }
    return Impedance(r, x);
  }

  /// Resistance seen by the feedline once the element is retuned.
  @override
  double get feedpointROhms => _drivenImpedance.r.clamp(5.0, 400.0);

  /// Reactance the images couple in. The driven element has to be shortened
  /// or lengthened until this is gone.
  double get coupledReactanceOhms => _drivenImpedance.x - 42.5;

  bool get lowImpedance => _drivenImpedance.r < 20;

  @override
  double get qFactor => 12;

  @override
  Impedance impedanceAt(double fMHz) =>
      rlcImpedance(fMHz, p.frequencyMHz, feedpointROhms, qFactor);
}

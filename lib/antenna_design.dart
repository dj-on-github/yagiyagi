import 'dart:math';

double log10(double x) => log(x) / ln10;

enum AntennaType { yagi, dipole, loop, waveguide }

extension AntennaTypeLabel on AntennaType {
  String get label => switch (this) {
        AntennaType.yagi => 'Yagi-Uda antenna',
        AntennaType.dipole => 'Dipole antenna',
        AntennaType.loop => 'Loop antenna',
        AntennaType.waveguide => 'Waveguide antenna (cantenna)',
      };
}

/// Shaped two-lobe pattern: a forward ((1+cos)/2)^n main lobe matched to
/// [hpbwDeg], plus a low-level rear lobe at [frontToBackDb] below boresight.
double lobePatternDb(double angleDeg, double hpbwDeg, double frontToBackDb) {
  final a = angleDeg * pi / 180;
  final c = (1 + cos(hpbwDeg * pi / 360)) / 2;
  final exp = log(0.5) / log(c);
  final fwd = pow((1 + cos(a)) / 2, exp).toDouble();
  final back = pow(10, -frontToBackDb / 10).toDouble() *
      pow((1 - cos(a)) / 2, 1.4).toDouble();
  return 10 * log10(fwd + back);
}

class Impedance {
  final double r;
  final double x;
  const Impedance(this.r, this.x);
}

/// Series-RLC approximation of a resonant antenna's impedance near
/// resonance: R rises slightly off-resonance, X sweeps through zero.
Impedance rlcImpedance(
    double fMHz, double fResMHz, double rResOhms, double q) {
  final dfr = (fMHz - fResMHz) / fResMHz;
  final r = rResOhms * (1 + 1.5 * dfr.abs());
  final x = 2 * rResOhms * q * dfr;
  return Impedance(r, x);
}

double swrFromImpedance(Impedance z, double z0) {
  final num = sqrt(pow(z.r - z0, 2) + z.x * z.x);
  final den = sqrt(pow(z.r + z0, 2) + z.x * z.x);
  final g = (num / den).toDouble();
  if (g >= 1) return 60;
  return ((1 + g) / (1 - g)).clamp(1.0, 60.0);
}

/// Contiguous bandwidth around [fStartMHz] where SWR <= 2:1.
double bandwidth2to1(double fStartMHz, double Function(double) swrAt) {
  double edge(int dir) {
    var f = fStartMHz;
    for (var i = 0; i < 600; i++) {
      f += dir * fStartMHz * 0.0005;
      if (swrAt(f) > 2) return f;
    }
    return f;
  }

  return edge(1) - edge(-1);
}

/// Common interface implemented by every antenna model so the plots and
/// readouts can work with any antenna type.
abstract class AntennaDesign {
  double get centerFrequencyMHz;
  double get feedOhms;
  double get gainDbi;
  double get frontToBackDb;
  double get hpbwAzDeg;
  double get hpbwElDeg;
  double get feedpointROhms;
  double get qFactor;

  /// Relative gain (dB, 0 dB = boresight) at azimuth [angleDeg].
  double azimuthDb(double angleDeg);

  /// Relative gain (dB) at polar elevation [angleDeg]; 0 = forward horizon.
  double elevationDb(double angleDeg);

  Impedance impedanceAt(double fMHz);
  double swrAt(double fMHz);
  double get centerSwr;
  double get bandwidth2to1MHz;
}

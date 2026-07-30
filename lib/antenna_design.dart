import 'dart:math';

double log10(double x) => log(x) / ln10;

/// Free-space wavelength in metres for a frequency in MHz.
double wavelengthMFor(double fMHz) => 299.792458 / fMHz;

enum AntennaType {
  yagi,
  dipole,
  loop,
  waveguide,
  vertical,
  magLoop,
  lpda,
  dish,
  helix,
  patch,
  moxon,
  horn,
  phasedVerticals,
  cornerReflector,
}

extension AntennaTypeLabel on AntennaType {
  String get label => switch (this) {
        AntennaType.yagi => 'Yagi-Uda antenna',
        AntennaType.dipole => 'Dipole antenna',
        AntennaType.loop => 'Loop antenna',
        AntennaType.waveguide => 'Waveguide antenna (cantenna)',
        AntennaType.vertical => 'Quarter-wave vertical / ground plane',
        AntennaType.magLoop => 'Small transmitting (magnetic) loop',
        AntennaType.lpda => 'Log-periodic dipole array',
        AntennaType.dish => 'Parabolic dish',
        AntennaType.helix => 'Axial-mode helix',
        AntennaType.patch => 'Microstrip patch',
        AntennaType.moxon => 'Moxon rectangle',
        AntennaType.horn => 'Pyramidal horn',
        AntennaType.phasedVerticals => 'Two-element phased verticals',
        AntennaType.cornerReflector => 'Corner reflector',
      };

  /// Short tag for the app bar.
  String get shortLabel => switch (this) {
        AntennaType.yagi => 'yagi',
        AntennaType.dipole => 'dipole',
        AntennaType.loop => 'loop',
        AntennaType.waveguide => 'cantenna',
        AntennaType.vertical => 'vertical',
        AntennaType.magLoop => 'mag loop',
        AntennaType.lpda => 'LPDA',
        AntennaType.dish => 'dish',
        AntennaType.helix => 'helix',
        AntennaType.patch => 'patch',
        AntennaType.moxon => 'moxon',
        AntennaType.horn => 'horn',
        AntennaType.phasedVerticals => 'phased pair',
        AntennaType.cornerReflector => 'corner',
      };
}

/// Far-field polarisation of an antenna.
enum Polarization { linear, horizontal, vertical, rhcp, lhcp }

extension PolarizationLabel on Polarization {
  String get label => switch (this) {
        Polarization.linear => 'Linear (follows element orientation)',
        Polarization.horizontal => 'Horizontal',
        Polarization.vertical => 'Vertical',
        Polarization.rhcp => 'Circular, right hand (RHCP)',
        Polarization.lhcp => 'Circular, left hand (LHCP)',
      };

  bool get isCircular =>
      this == Polarization.rhcp || this == Polarization.lhcp;
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
///
/// The band edges are bracketed by geometric expansion and then bisected,
/// so this stays accurate for both a magnetic loop (Q in the thousands,
/// bandwidth of a few kHz) and a log-periodic (bandwidth of a decade).
/// [maxSpanFrac] caps how far either edge is chased, as a fraction of
/// [fStartMHz].
double bandwidth2to1(double fStartMHz, double Function(double) swrAt,
    {double maxSpanFrac = 0.3}) {
  if (swrAt(fStartMHz) > 2) return 0;

  final maxStep = fStartMHz * maxSpanFrac;

  double edge(int dir) {
    var good = fStartMHz; // known SWR <= 2
    var step = fStartMHz * 1e-7;
    double bad = double.nan;
    while (true) {
      final capped = min(step, maxStep);
      final f = fStartMHz + dir * capped;
      if (f <= 0) break;
      if (swrAt(f) > 2) {
        bad = f;
        break;
      }
      good = f;
      if (capped >= maxStep) break; // still matched at the edge of the search
      step *= 1.5;
    }
    if (bad.isNaN) return good; // never left the 2:1 window within the span
    for (var i = 0; i < 60; i++) {
      final mid = (good + bad) / 2;
      if (swrAt(mid) <= 2) {
        good = mid;
      } else {
        bad = mid;
      }
    }
    return good;
  }

  return (edge(1) - edge(-1)).abs();
}

/// Perfect-ground reflection factor for a horizontal antenna [heightWl]
/// wavelengths above ground, in dB relative to the strongest lobe.
///
/// [angleDeg] is the polar angle used by the elevation plot: 0 and 180 are
/// the horizon, 90 is the zenith, and anything below the horizon is dark.
double groundReflectionDb(double angleDeg, double heightWl) {
  if (heightWl <= 0) return 0;
  final sinEl = sin(angleDeg * pi / 180);
  if (sinEl <= 0) return -40;
  final gMax = 2 * sin(min(2 * pi * heightWl, pi / 2));
  final g = 2 * sin(2 * pi * heightWl * sinEl).abs();
  return (20 * log10((g / gMax).clamp(1e-4, 1.0))).clamp(-40.0, 0.0);
}

/// Numerically measure the -3 dB beamwidth of a pattern that is sampled in
/// degrees around its peak. Returns 360 for a pattern with no -3 dB point
/// (i.e. omnidirectional).
double hpbwOf(double Function(double) patternDb, {double stepDeg = 0.5}) {
  var peak = double.negativeInfinity, peakAt = 0.0;
  for (var a = -180.0; a <= 180.0; a += stepDeg) {
    final v = patternDb(a);
    if (v > peak) {
      peak = v;
      peakAt = a;
    }
  }
  double edge(int dir) {
    for (var d = stepDeg; d <= 180; d += stepDeg) {
      if (patternDb(peakAt + dir * d) <= peak - 3) return d;
    }
    return 180;
  }

  return (edge(1) + edge(-1)).clamp(1.0, 360.0);
}

/// Numeric directivity in dBi of a linear-power pattern U(theta, phi), with
/// theta measured in degrees from the zenith and phi in degrees around it.
///
/// Set [hemisphere] for antennas over a perfect ground, where all the power
/// is radiated into the upper half space and the lower half is not counted
/// as loss.
double directivityDbi(double Function(double thetaDeg, double phiDeg) powerLin,
    {bool hemisphere = false, double stepDeg = 2}) {
  final thetaMax = hemisphere ? 90.0 : 180.0;
  final dRad = stepDeg * pi / 180;
  var integral = 0.0, peak = 0.0;
  for (var t = stepDeg / 2; t < thetaMax; t += stepDeg) {
    final st = sin(t * pi / 180);
    for (var ph = stepDeg / 2; ph < 360; ph += stepDeg) {
      final u = powerLin(t, ph);
      if (u > peak) peak = u;
      integral += u * st * dRad * dRad;
    }
  }
  if (integral <= 0 || peak <= 0) return 0;
  return 10 * log10(4 * pi * peak / integral);
}

// ---------------------------------------------------------------------------
// Special functions used by the aperture and mutual-coupling models.
// ---------------------------------------------------------------------------

/// Sine integral Si(x) = integral of sin(t)/t from 0 to x.
double sineIntegral(double x) {
  if (x < 0) return -sineIntegral(-x);
  if (x == 0) return 0;
  final n = max(64, (x * 24).ceil() * 2); // even sample count for Simpson
  final h = x / n;
  double f(double t) => t == 0 ? 1.0 : sin(t) / t;
  var s = f(0) + f(x);
  for (var i = 1; i < n; i++) {
    s += f(i * h) * (i.isOdd ? 4 : 2);
  }
  return s * h / 3;
}

/// Cosine integral Ci(x) = gamma + ln(x) + integral of (cos(t)-1)/t from 0 to x.
double cosineIntegral(double x) {
  const gamma = 0.5772156649015329;
  if (x <= 0) return double.negativeInfinity;
  final n = max(64, (x * 24).ceil() * 2);
  final h = x / n;
  double f(double t) => t == 0 ? 0.0 : (cos(t) - 1) / t;
  var s = f(0) + f(x);
  for (var i = 1; i < n; i++) {
    s += f(i * h) * (i.isOdd ? 4 : 2);
  }
  return gamma + log(x) + s * h / 3;
}

/// Mutual impedance between two parallel, side-by-side half-wave dipoles
/// separated by [dWl] wavelengths (the classical Ci/Si result).
///
/// For quarter-wave monopoles over a perfect ground plane, halve both parts.
Impedance mutualImpedanceHalfWave(double dWl) {
  if (dWl <= 1e-4) return const Impedance(73.1, 42.5); // self impedance
  final k = 2 * pi;
  final d = dWl;
  const l = 0.5; // half-wave element, in wavelengths
  final diag = sqrt(d * d + l * l);
  final u0 = k * d;
  final u1 = k * (diag + l);
  final u2 = k * (diag - l);
  final r = 30 * (2 * cosineIntegral(u0) - cosineIntegral(u1) - cosineIntegral(u2));
  final x =
      -30 * (2 * sineIntegral(u0) - sineIntegral(u1) - sineIntegral(u2));
  return Impedance(r, x);
}

/// Bessel function of the first kind, order 0 (Abramowitz & Stegun 9.4).
double besselJ0(double x) {
  final ax = x.abs();
  if (ax < 3.0) {
    final t = x / 3.0;
    final y = t * t;
    return 1.0 +
        y *
            (-2.2499997 +
                y *
                    (1.2656208 +
                        y *
                            (-0.3163866 +
                                y *
                                    (0.0444479 +
                                        y * (-0.0039444 + y * 0.0002100)))));
  }
  final z = 3.0 / ax;
  final f = 0.79788456 +
      z *
          (-0.00000077 +
              z *
                  (-0.00552740 +
                      z *
                          (-0.00009512 +
                              z *
                                  (0.00137237 +
                                      z * (-0.00072805 + z * 0.00014476)))));
  final theta = ax -
      0.78539816 +
      z *
          (-0.04166397 +
              z *
                  (-0.00003954 +
                      z *
                          (0.00262573 +
                              z *
                                  (-0.00054125 +
                                      z * (-0.00029333 + z * 0.00013558)))));
  return f * cos(theta) / sqrt(ax);
}

/// Bessel function of the first kind, order 1 (Abramowitz & Stegun 9.4).
double besselJ1(double x) {
  final ax = x.abs();
  double result;
  if (ax < 3.0) {
    final t = x / 3.0;
    final y = t * t;
    result = ax *
        (0.5 +
            y *
                (-0.56249985 +
                    y *
                        (0.21093573 +
                            y *
                                (-0.03954289 +
                                    y *
                                        (0.00443319 +
                                            y *
                                                (-0.00031761 +
                                                    y * 0.00001109))))));
  } else {
    final z = 3.0 / ax;
    final f = 0.79788456 +
        z *
            (0.00000156 +
                z *
                    (0.01659667 +
                        z *
                            (0.00017105 +
                                z *
                                    (-0.00249511 +
                                        z * (0.00113653 + z * -0.00020033)))));
    final theta = ax -
        2.35619449 +
        z *
            (0.12499612 +
                z *
                    (0.00005650 +
                        z *
                            (-0.00637879 +
                                z *
                                    (0.00074348 +
                                        z * (0.00079824 + z * -0.00029166)))));
    result = f * cos(theta) / sqrt(ax);
  }
  return x < 0 ? -result : result;
}

/// Bessel function of the first kind, order 2, via the recurrence relation.
double besselJ2(double x) {
  if (x.abs() < 1e-8) return 0;
  return 2 * besselJ1(x) / x - besselJ0(x);
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

  double swrAt(double fMHz) => swrFromImpedance(impedanceAt(fMHz), feedOhms);
  double get centerSwr => swrAt(centerFrequencyMHz);
  double get bandwidth2to1MHz => bandwidth2to1(centerFrequencyMHz, swrAt);

  /// Far-field polarisation. Most element-based antennas simply follow the
  /// orientation they are mounted in, and report [Polarization.linear].
  Polarization get polarization => Polarization.linear;

  /// Frequency span drawn by the impedance/SWR plot. Narrowband designs
  /// (a magnetic loop) and decade-wide ones (a log-periodic) override this.
  double get sweepMinMHz => centerFrequencyMHz * 0.88;
  double get sweepMaxMHz => centerFrequencyMHz * 1.12;
}

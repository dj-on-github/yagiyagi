import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'antenna_design.dart';
import 'corner_reflector_model.dart';
import 'dipole_model.dart';
import 'helix_model.dart';
import 'loop_model.dart';
import 'lpda_model.dart';
import 'magloop_model.dart';
import 'moxon_model.dart';
import 'phased_array_model.dart';
import 'vertical_model.dart';
import 'yagi_model.dart';

/// Export of the current design as a NECfull `.nful` model file: real wire
/// geometry, built from the same dimension formulas the analytic models use,
/// ready for a method-of-moments solve in NECfull.
///
/// The aperture antennas (dish, horn, patch, cantenna) cannot be exported:
/// a thin-wire MoM file has no way to represent solid conducting surfaces
/// or waveguides.

/// Reason a type cannot be exported, or null if it can.
String? nfulExportBlockedReason(AntennaType type) => switch (type) {
      AntennaType.dish ||
      AntennaType.horn ||
      AntennaType.patch ||
      AntennaType.waveguide =>
        '${type.label} is an aperture antenna - it cannot be represented '
            'as thin-wire geometry for NECfull.',
      _ => null,
    };

// ---------------------------------------------------------------------------
// JSON building blocks (matching NECfull's .nful format, version 1)
// ---------------------------------------------------------------------------

Map<String, dynamic> _wire(
        List<double> e1, List<double> e2, double diaMm, int segs) =>
    {'end1': e1, 'end2': e2, 'diameterMm': diaMm, 'segments': segs};

Map<String, dynamic> _src(int wire, double pos,
        {double volts = 1, double phase = 0}) =>
    {
      'wire': wire,
      'positionPercent': pos,
      'voltage': volts,
      'phaseDeg': phase,
    };

Map<String, dynamic> _model({
  required String name,
  required double freqMhz,
  String ground = 'free',
  double epsR = 13,
  double sigma = 0.005,
  required List<Map<String, dynamic>> wires,
  required List<Map<String, dynamic>> sources,
  List<Map<String, dynamic>> loads = const [],
}) =>
    {
      'format': 'nful',
      'version': 1,
      'name': name,
      'freqMhz': freqMhz,
      'ground': ground,
      'epsR': epsR,
      'sigma': sigma,
      'zOffsetM': 0.0,
      'wires': wires,
      'sources': sources,
      'loads': loads,
    };

/// NECfull ground constants for a yagiyagi soil class.
(String, double, double) _groundOf(GroundQuality q) => switch (q) {
      GroundQuality.perfect => ('perfect', 13, 0.005),
      GroundQuality.good => ('real', 20, 0.0303),
      GroundQuality.average => ('real', 13, 0.005),
      GroundQuality.poor => ('real', 5, 0.001),
    };

String _fmtMhz(double f) => f >= 1000
    ? '${(f / 1000).toStringAsFixed(2)} GHz'
    : '${f.toStringAsFixed(f < 10 ? 2 : 1)} MHz';

/// Heights just above zero would weld the antenna to ground in the solver;
/// keep anything airborne at least 0.02 wavelengths up.
double _safeHeightWl(double hWl) => hWl <= 0 ? 0 : max(hWl, 0.02);

// ---------------------------------------------------------------------------
// Per-type geometry builders
// ---------------------------------------------------------------------------

Map<String, dynamic> _dipoleNful(DipoleParameters p) {
  final wl = wavelengthMFor(p.frequencyMHz);
  final len = p.lengthFactor * wl / 2;
  final h = _safeHeightWl(p.heightWl);
  final z = h * wl;
  return _model(
    name: 'Dipole ${_fmtMhz(p.frequencyMHz)}',
    freqMhz: p.frequencyMHz,
    ground: h > 0 ? 'real' : 'free',
    wires: [
      _wire([0, -len / 2, z], [0, len / 2, z], p.diameterMm, 14),
    ],
    sources: [_src(0, 50)],
  );
}

Map<String, dynamic> _yagiNful(YagiParameters p) {
  final d = YagiDesign(p);
  final wires = <Map<String, dynamic>>[];
  for (var i = 0; i < p.elements; i++) {
    final double len;
    if (i == 0 && p.elements >= 2) {
      len = d.reflectorLengthM;
    } else if (i == (p.elements >= 2 ? 1 : 0)) {
      len = d.drivenLengthM;
    } else {
      len = d.directorLengthM(i - 2);
    }
    wires.add(_wire(
      [i * d.spacingM, -len / 2, 0],
      [i * d.spacingM, len / 2, 0],
      p.elementDiameterMm,
      i == 1 ? 12 : 11,
    ));
  }
  // Center beam (boom), modeled as insulated and mounted just below the
  // elements. Bonding it through the element centers would short the split
  // feed of the driven element; offset slightly, it is present in the model
  // and parasitically coupled, matching elements-on-insulators construction.
  if (p.elements >= 2) {
    final boomDiaMm = 3 * p.elementDiameterMm;
    final boomLen = (p.elements - 1) * d.spacingM;
    final overhang = 2 * boomDiaMm / 1000;
    // Clearance scales with conductor size to keep the thin-wire
    // approximation valid between boom and elements.
    final zBoom =
        -(1.5 * (p.elementDiameterMm / 2 + boomDiaMm / 2) / 1000 + 0.005);
    final segs =
        ((boomLen + 2 * overhang) / (0.05 * d.wavelengthM)).ceil().clamp(3, 25);
    wires.add(_wire(
      [-overhang, 0, zBoom],
      [boomLen + overhang, 0, zBoom],
      boomDiaMm,
      segs,
    ));
  }
  return _model(
    name: '${p.elements}-element Yagi ${_fmtMhz(p.frequencyMHz)}',
    freqMhz: p.frequencyMHz,
    wires: wires,
    sources: [_src(p.elements >= 2 ? 1 : 0, 50)],
  );
}

Map<String, dynamic> _loopNful(LoopParameters p) {
  final d = LoopDesign(p);
  final h = _safeHeightWl(p.heightWl);
  final zc = h * d.wavelengthM;
  final wires = <Map<String, dynamic>>[];
  if (p.shape == LoopShape.square) {
    final s = d.sideM;
    final zb = zc - s / 2, zt = zc + s / 2;
    wires.addAll([
      _wire([0, -s / 2, zb], [0, s / 2, zb], p.wireDiameterMm, 8), // fed
      _wire([0, s / 2, zb], [0, s / 2, zt], p.wireDiameterMm, 7),
      _wire([0, s / 2, zt], [0, -s / 2, zt], p.wireDiameterMm, 7),
      _wire([0, -s / 2, zt], [0, -s / 2, zb], p.wireDiameterMm, 7),
    ]);
  } else {
    // Octagon, perimeter matched to the circular circumference.
    final r = d.circumferenceM / (16 * sin(pi / 8));
    final pts = <List<double>>[];
    for (var k = 0; k < 8; k++) {
      final a = (k - 0.5) * 2 * pi / 8;
      pts.add([0, r * sin(a), zc - r * cos(a)]);
    }
    for (var k = 0; k < 8; k++) {
      wires.add(_wire(
          pts[k], pts[(k + 1) % 8], p.wireDiameterMm, k == 0 ? 6 : 5));
    }
  }
  return _model(
    name:
        '${p.shape == LoopShape.square ? 'Square' : 'Circular'} loop '
        '${_fmtMhz(p.frequencyMHz)}',
    freqMhz: p.frequencyMHz,
    ground: h > 0 ? 'real' : 'free',
    wires: wires,
    sources: [_src(0, 50)],
  );
}

Map<String, dynamic> _verticalNful(VerticalParameters p) {
  final d = VerticalDesign(p);
  final wl = d.wavelengthM;
  final droop = p.radialDroopDeg * pi / 180;
  final drop = d.radialLengthM * sin(droop);
  final hf = max(0.25 * wl, drop + 0.02 * wl);
  final (ground, epsR, sigma) = _groundOf(p.ground);
  final wires = <Map<String, dynamic>>[
    _wire([0, 0, hf], [0, 0, hf + d.radiatorLengthM], p.diameterMm, 10),
  ];
  for (var k = 0; k < p.radialCount; k++) {
    final az = 2 * pi * k / p.radialCount;
    wires.add(_wire(
      [0, 0, hf],
      [
        d.radialLengthM * cos(droop) * cos(az),
        d.radialLengthM * cos(droop) * sin(az),
        hf - drop,
      ],
      p.diameterMm,
      5,
    ));
  }
  return _model(
    name: 'Ground plane ${_fmtMhz(p.frequencyMHz)} '
        '(${p.radialCount} radials)',
    freqMhz: p.frequencyMHz,
    ground: ground,
    epsR: epsR,
    sigma: sigma,
    wires: wires,
    sources: [_src(0, 0)],
  );
}

Map<String, dynamic> _magLoopNful(MagLoopParameters p) {
  final d = MagLoopDesign(p);
  final h = _safeHeightWl(p.heightWl);
  final zc = h * d.wavelengthM;
  // Octagon, perimeter matched to pi*D so the tuning capacitance computed
  // from the circular-loop inductance stays valid.
  final r = pi * p.loopDiameterM / (16 * sin(pi / 8));
  if (h > 0 && zc - r <= 0.02 * d.wavelengthM) {
    throw ArgumentError('Loop bottom would be at or below ground - '
        'raise the mounting height.');
  }
  final pts = <List<double>>[];
  for (var k = 0; k < 8; k++) {
    final a = (k - 0.5) * 2 * pi / 8;
    pts.add([r * sin(a), 0, zc - r * cos(a)]);
  }
  final wires = <Map<String, dynamic>>[];
  for (var k = 0; k < 8; k++) {
    wires.add(_wire(
        pts[k], pts[(k + 1) % 8], p.conductorDiameterMm, 4));
  }
  return _model(
    name: 'Magnetic loop ${p.loopDiameterM.toStringAsFixed(1)} m @ '
        '${_fmtMhz(p.frequencyMHz)}',
    freqMhz: p.frequencyMHz,
    ground: h > 0 ? 'real' : 'free',
    wires: wires,
    sources: [_src(0, 50)],
    loads: [
      {
        'wire': 4, // top of the octagon
        'positionPercent': 50.0,
        'kind': 'seriesRlc',
        'r': d.conductorLossROhms + d.capacitorLossROhms,
        'x': 0.0,
        'lUh': 0.0,
        'cPf': d.tuningCapacitancePf,
      },
    ],
  );
}

Map<String, dynamic> _lpdaNful(LpdaParameters p) {
  final d = LpdaDesign(p);
  final rawN = d.elementCount;
  final n = rawN.clamp(3, 14);
  final truncated = rawN > n;
  final wlHigh = wavelengthMFor(d.fHighMHz);
  final l0 = d.longestElementM;
  final lengths = [for (var k = 0; k < n; k++) d.elementLengthM(k)];
  final xs = <double>[0];
  for (var k = 0; k < n - 1; k++) {
    xs.add(xs.last + d.spacingM(k));
  }
  final sep =
      max(0.008, max(6 * p.elementDiameterMm / 1000, 0.02 * wlHigh));

  final wires = <Map<String, dynamic>>[];
  for (var k = 0; k < n; k++) {
    final plusZ = k.isEven ? sep / 2 : -sep / 2;
    final minusZ = k.isEven ? -sep / 2 : sep / 2;
    final segs = max(3, (7 * lengths[k] / l0).round());
    wires.add(_wire([xs[k], 0, plusZ], [xs[k], lengths[k] / 2, plusZ],
        p.elementDiameterMm, segs));
    wires.add(_wire([xs[k], 0, minusZ], [xs[k], -lengths[k] / 2, minusZ],
        p.elementDiameterMm, segs));
  }
  for (var k = 0; k < n - 1; k++) {
    final segs = ((xs[k + 1] - xs[k]) / (wlHigh / 15)).ceil().clamp(1, 10);
    for (final z in [sep / 2, -sep / 2]) {
      wires.add(_wire(
          [xs[k], 0, z], [xs[k + 1], 0, z], p.elementDiameterMm, segs));
    }
  }
  wires.add(_wire([xs[n - 1], 0, -sep / 2], [xs[n - 1], 0, sep / 2],
      p.elementDiameterMm, 2));

  return _model(
    name: 'LPDA ${_fmtMhz(d.fLowMHz)}-${_fmtMhz(d.fHighMHz)} '
        '($n el${truncated ? ' of $rawN, truncated' : ''})',
    freqMhz: d.centerFrequencyMHz,
    wires: wires,
    sources: [_src(wires.length - 1, 50)],
  );
}

Map<String, dynamic> _helixNful(HelixParameters p) {
  final d = HelixDesign(p);
  final wl = d.wavelengthM;
  final s = d.spacingM; // rise per turn
  final sense = p.sense == WindingSense.rightHand ? 1.0 : -1.0;
  var perTurn = 10;
  while (p.turns * perTurn > 160 && perTurn > 6) {
    perTurn--;
  }
  // Circumradius scaled so the polygonized turn perimeter is correct.
  final a = p.circumferenceWl * wl / (2 * pi) *
      (pi / perTurn) / sin(pi / perTurn);
  List<double> pt(int i) {
    final phi = sense * 2 * pi * i / perTurn;
    return [a * cos(phi), a * sin(phi), s * i / perTurn];
  }

  final wires = <Map<String, dynamic>>[];
  for (var i = 0; i < p.turns * perTurn; i++) {
    wires.add(_wire(pt(i), pt(i + 1), p.conductorDiameterMm, 1));
  }
  return _model(
    name: '${p.turns}-turn helix ${_fmtMhz(p.frequencyMHz)}',
    freqMhz: p.frequencyMHz,
    // Infinite perfect ground stands in for the reflector plane.
    ground: 'perfect',
    wires: wires,
    sources: [_src(0, 0)],
  );
}

Map<String, dynamic> _moxonNful(MoxonParameters p) {
  final d = MoxonDesign(p);
  final h = _safeHeightWl(p.heightWl);
  final z = h * d.wavelengthM;
  final aW = d.widthM, bW = d.drivenTailM, dW = d.reflectorTailM;
  final eW = d.depthM;
  final dia = p.wireDiameterMm;
  return _model(
    name: 'Moxon rectangle ${_fmtMhz(p.frequencyMHz)}',
    freqMhz: p.frequencyMHz,
    ground: h > 0 ? 'real' : 'free',
    wires: [
      // Driven element at the front (x = eW), boresight along +x.
      _wire([eW, -aW / 2, z], [eW, aW / 2, z], dia, 10),
      _wire([eW, -aW / 2, z], [eW - bW, -aW / 2, z], dia, 3),
      _wire([eW, aW / 2, z], [eW - bW, aW / 2, z], dia, 3),
      _wire([0, -aW / 2, z], [0, aW / 2, z], dia, 11),
      _wire([0, -aW / 2, z], [dW, -aW / 2, z], dia, 3),
      _wire([0, aW / 2, z], [dW, aW / 2, z], dia, 3),
    ],
    sources: [_src(0, 50)],
  );
}

Map<String, dynamic> _phasedNful(PhasedArrayParameters p) {
  final wl = wavelengthMFor(p.frequencyMHz);
  final d = p.spacingWl * wl;
  final h = 0.239 * wl;
  final (ground, epsR, sigma) = _groundOf(p.ground);
  Map<String, dynamic> vertical(double x) =>
      _wire([x, 0, 0], [x, 0, h], p.diameterMm, 10);
  return _model(
    name: 'Phased verticals ${_fmtMhz(p.frequencyMHz)} '
        '(${p.phaseDeg.toStringAsFixed(0)}°)',
    freqMhz: p.frequencyMHz,
    ground: ground == 'free' ? 'real' : ground,
    epsR: epsR,
    sigma: sigma,
    wires: [vertical(-d / 2), vertical(d / 2)],
    sources: [
      _src(0, 0),
      _src(1, 0, volts: p.amplitudeRatio, phase: p.phaseDeg),
    ],
  );
}

Map<String, dynamic> _cornerNful(CornerReflectorParameters p) {
  final d = CornerReflectorDesign(p);
  final wl = d.wavelengthM;
  final rodSp = max(0.03, p.rodSpacingWl) * wl; // 0 (solid) -> fine grid
  final rodLen = 0.75 * wl;
  final wires = <Map<String, dynamic>>[
    _wire([d.spacingM, 0, -d.drivenLengthM / 2],
        [d.spacingM, 0, d.drivenLengthM / 2], 6, 10),
  ];
  for (final sgn in [1.0, -1.0]) {
    final theta = sgn * p.apex.degrees / 2 * pi / 180;
    final dx = cos(theta), dy = sin(theta);
    final count = (d.reflectorLengthM / rodSp).floor().clamp(3, 24);
    final actual = d.reflectorLengthM / count;
    for (var j = 0; j < count; j++) {
      final t = (j + 0.5) * actual;
      wires.add(_wire(
          [t * dx, t * dy, -rodLen / 2], [t * dx, t * dy, rodLen / 2], 6, 5));
    }
  }
  return _model(
    name: 'Corner reflector ${p.apex.degrees.toStringAsFixed(0)}° '
        '${_fmtMhz(p.frequencyMHz)}',
    freqMhz: p.frequencyMHz,
    wires: wires,
    sources: [_src(0, 50)],
  );
}

// ---------------------------------------------------------------------------
// Entry points
// ---------------------------------------------------------------------------

/// Build the .nful JSON for the current design, or throw [ArgumentError]
/// with a user-facing message (unsupported type, impossible geometry).
Map<String, dynamic> nfulForDesign({
  required AntennaType type,
  required YagiParameters yagi,
  required DipoleParameters dipole,
  required LoopParameters loop,
  required VerticalParameters vertical,
  required MagLoopParameters magLoop,
  required LpdaParameters lpda,
  required HelixParameters helix,
  required MoxonParameters moxon,
  required PhasedArrayParameters phased,
  required CornerReflectorParameters corner,
}) {
  final blocked = nfulExportBlockedReason(type);
  if (blocked != null) throw ArgumentError(blocked);
  return switch (type) {
    AntennaType.yagi => _yagiNful(yagi),
    AntennaType.dipole => _dipoleNful(dipole),
    AntennaType.loop => _loopNful(loop),
    AntennaType.vertical => _verticalNful(vertical),
    AntennaType.magLoop => _magLoopNful(magLoop),
    AntennaType.lpda => _lpdaNful(lpda),
    AntennaType.helix => _helixNful(helix),
    AntennaType.moxon => _moxonNful(moxon),
    AntennaType.phasedVerticals => _phasedNful(phased),
    AntennaType.cornerReflector => _cornerNful(corner),
    _ => throw ArgumentError(nfulExportBlockedReason(type) ?? 'Unsupported'),
  };
}

/// Show a save dialog and write [model] as a .nful file.
/// Returns a user-facing status message, or null if the user cancelled.
Future<String?> saveNfulDialog(Map<String, dynamic> model) async {
  final name = (model['name'] as String)
      .replaceAll(RegExp(r'[^\w\- ]'), '')
      .trim();
  final suggested = '${name.isEmpty ? 'antenna' : name}.nful';
  final location = await getSaveLocation(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'NECfull model', extensions: ['nful']),
    ],
    suggestedName: suggested,
  );
  if (location == null) return null;
  var path = location.path;
  if (!path.toLowerCase().endsWith('.nful')) path = '$path.nful';
  final text = const JsonEncoder.withIndent('  ').convert(model);
  final bytes = Uint8List.fromList(utf8.encode(text));
  await XFile.fromData(bytes, mimeType: 'application/json', name: suggested)
      .saveTo(path);
  return 'Saved $path';
}

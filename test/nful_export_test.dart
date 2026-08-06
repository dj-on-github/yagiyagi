import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yagiyagi/antenna_design.dart';
import 'package:yagiyagi/corner_reflector_model.dart';
import 'package:yagiyagi/dipole_model.dart';
import 'package:yagiyagi/helix_model.dart';
import 'package:yagiyagi/loop_model.dart';
import 'package:yagiyagi/lpda_model.dart';
import 'package:yagiyagi/magloop_model.dart';
import 'package:yagiyagi/moxon_model.dart';
import 'package:yagiyagi/nful_export.dart';
import 'package:yagiyagi/phased_array_model.dart';
import 'package:yagiyagi/vertical_model.dart';
import 'package:yagiyagi/yagi_model.dart';

Map<String, dynamic> exportType(AntennaType t) => nfulForDesign(
      type: t,
      yagi: YagiParameters(),
      dipole: DipoleParameters(),
      loop: LoopParameters(),
      vertical: VerticalParameters(),
      magLoop: MagLoopParameters(),
      lpda: LpdaParameters(),
      helix: HelixParameters(),
      moxon: MoxonParameters(),
      phased: PhasedArrayParameters(),
      corner: CornerReflectorParameters(),
    );

const supported = [
  AntennaType.yagi,
  AntennaType.dipole,
  AntennaType.loop,
  AntennaType.vertical,
  AntennaType.magLoop,
  AntennaType.lpda,
  AntennaType.helix,
  AntennaType.moxon,
  AntennaType.phasedVerticals,
  AntennaType.cornerReflector,
];

const blocked = [
  AntennaType.dish,
  AntennaType.horn,
  AntennaType.patch,
  AntennaType.waveguide,
];

/// Validate the structural contract NECfull's .nful parser relies on.
void validateNful(Map<String, dynamic> m, String context) {
  expect(m['format'], 'nful', reason: context);
  expect(m['version'], 1, reason: context);
  expect(m['name'], isA<String>(), reason: context);
  expect((m['freqMhz'] as num).toDouble(), greaterThan(0), reason: context);
  expect(['free', 'perfect', 'real'], contains(m['ground']),
      reason: context);

  final wires = m['wires'] as List;
  expect(wires, isNotEmpty, reason: context);
  for (final w in wires) {
    final wm = w as Map<String, dynamic>;
    for (final key in ['end1', 'end2']) {
      final e = wm[key] as List;
      expect(e.length, 3, reason: context);
      for (final c in e) {
        expect((c as num).isFinite, isTrue, reason: context);
      }
    }
    expect((wm['diameterMm'] as num).toDouble(), greaterThan(0),
        reason: context);
    expect(wm['segments'], isA<int>(), reason: context);
    expect(wm['segments'] as int, greaterThanOrEqualTo(1), reason: context);
    // Non-zero wire length.
    final e1 = wm['end1'] as List, e2 = wm['end2'] as List;
    var d2 = 0.0;
    for (var i = 0; i < 3; i++) {
      final d = (e1[i] as num) - (e2[i] as num);
      d2 += d * d;
    }
    expect(d2, greaterThan(1e-12), reason: '$context zero-length wire');
  }

  final sources = m['sources'] as List;
  expect(sources, isNotEmpty, reason: context);
  for (final s in sources) {
    final sm = s as Map<String, dynamic>;
    final wi = sm['wire'] as int;
    expect(wi, inInclusiveRange(0, wires.length - 1), reason: context);
    final pos = (sm['positionPercent'] as num).toDouble();
    // Center feeds need an even segment count so a junction lands at 50 %.
    if ((pos - 50).abs() < 1e-9) {
      final segs = (wires[wi] as Map<String, dynamic>)['segments'] as int;
      expect(segs.isEven, isTrue,
          reason: '$context source at 50% on odd-segment wire');
    }
  }

  for (final l in (m['loads'] as List? ?? [])) {
    final lm = l as Map<String, dynamic>;
    expect(lm['wire'] as int, inInclusiveRange(0, wires.length - 1),
        reason: context);
    expect(['impedance', 'seriesRlc'], contains(lm['kind']),
        reason: context);
  }

  // The whole thing must be JSON-encodable.
  final text = json.encode(m);
  expect(json.decode(text), isA<Map<String, dynamic>>(), reason: context);
}

void main() {
  test('every supported type exports a structurally valid .nful model', () {
    for (final t in supported) {
      validateNful(exportType(t), t.name);
    }
  });

  test('aperture types are blocked with a reason', () {
    for (final t in blocked) {
      expect(nfulExportBlockedReason(t), isNotNull, reason: t.name);
      expect(() => exportType(t), throwsArgumentError, reason: t.name);
    }
    for (final t in supported) {
      expect(nfulExportBlockedReason(t), isNull, reason: t.name);
    }
  });

  test('exported dimensions follow the design formulas', () {
    // Yagi driven element is 0.478 wavelengths.
    final yagi = exportType(AntennaType.yagi);
    final driven = (yagi['wires'] as List)[1] as Map<String, dynamic>;
    final y1 = ((driven['end1'] as List)[1] as num).toDouble();
    final y2 = ((driven['end2'] as List)[1] as num).toDouble();
    final wl = 299.792458 / 145.0;
    expect((y2 - y1).abs(), closeTo(0.478 * wl, 1e-9));

    // The yagi includes a center beam (boom): one wire more than the
    // element count, running along x (y = 0) at a small negative z so it
    // stays clear of the split feed, spanning all element positions.
    final yagiWires = yagi['wires'] as List;
    expect(yagiWires.length, YagiParameters().elements + 1);
    final boom = yagiWires.last as Map<String, dynamic>;
    final b1 = boom['end1'] as List, b2 = boom['end2'] as List;
    expect((b1[1] as num).toDouble(), 0);
    expect((b2[1] as num).toDouble(), 0);
    expect((b1[2] as num).toDouble(), lessThan(0));
    expect((b1[2] as num).toDouble(), (b2[2] as num).toDouble());
    final spacingM = 0.18 * wl;
    expect((b1[0] as num).toDouble(), lessThan(0));
    expect((b2[0] as num).toDouble(),
        greaterThan((YagiParameters().elements - 1) * spacingM - 1e-9));

    // Magnetic loop carries a series-RLC tuning load with plausible C.
    final loop = exportType(AntennaType.magLoop);
    final load = (loop['loads'] as List).single as Map<String, dynamic>;
    expect((load['cPf'] as num).toDouble(), greaterThan(1));
    expect((load['r'] as num).toDouble(), greaterThan(0));

    // Phased verticals carry the phase on source 2.
    final phased = exportType(AntennaType.phasedVerticals);
    final s2 = (phased['sources'] as List)[1] as Map<String, dynamic>;
    expect((s2['phaseDeg'] as num).toDouble(), closeTo(-90, 1e-9));
  });
}

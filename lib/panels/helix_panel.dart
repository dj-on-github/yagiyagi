import 'package:flutter/material.dart';

import '../antenna_design.dart';
import '../helix_model.dart';
import '../ui_kit.dart';

List<Widget> helixCards(HelixParameters p, HelixDesign d, Update update) {
  return [
    card('Frequency', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f),
          fMin: 100, fMax: 6000),
      bandChips(
        (f) => update(() => p.frequencyMHz = f),
        bands: const [145.0, 435.0, 1296.0, 2400.0],
      ),
      const SizedBox(height: 8),
      infoLine('Wavelength', '${(d.wavelengthM * 1000).toStringAsFixed(1)} mm'),
      infoLine('Axial-mode window',
          '${d.axialLowMHz.toStringAsFixed(0)} – ${d.axialHighMHz.toStringAsFixed(0)} MHz'),
    ]),
    card('Helix geometry', [
      slider(
        'Turns: ${p.turns}',
        p.turns.toDouble(),
        3,
        30,
        27,
        (v) => update(() => p.turns = v.round()),
      ),
      slider(
        'Turn circumference: ${p.circumferenceWl.toStringAsFixed(2)} λ '
        '(⌀ ${(d.turnDiameterM * 1000).toStringAsFixed(0)} mm)',
        p.circumferenceWl,
        0.60,
        1.50,
        45,
        (v) => update(() => p.circumferenceWl = v),
      ),
      slider(
        'Pitch angle: ${p.pitchAngleDeg.toStringAsFixed(1)}° '
        '(${(d.spacingM * 1000).toStringAsFixed(0)} mm per turn)',
        p.pitchAngleDeg,
        8,
        20,
        48,
        (v) => update(() => p.pitchAngleDeg = v),
      ),
      slider(
        'Ground plane: ${p.groundPlaneWl.toStringAsFixed(2)} λ '
        '(⌀ ${(d.groundPlaneM * 1000).toStringAsFixed(0)} mm)',
        p.groundPlaneWl,
        0.4,
        2.0,
        32,
        (v) => update(() => p.groundPlaneWl = v),
      ),
      slider(
        'Conductor diameter: ${p.conductorDiameterMm.toStringAsFixed(1)} mm',
        p.conductorDiameterMm,
        1,
        20,
        38,
        (v) => update(() => p.conductorDiameterMm = v),
      ),
      const Divider(height: 20),
      infoLine('Axial length', '${d.axialLengthM.toStringAsFixed(3)} m'),
      infoLine('Wire needed', '${d.wireLengthM.toStringAsFixed(2)} m'),
      const SizedBox(height: 6),
      if (!d.inAxialMode)
        statusBad('Outside the 0.75 – 1.33 λ circumference window the helix '
            'leaves axial mode and stops behaving like a beam.')
      else if (d.pitchOutOfRange)
        statusWarn('Pitch angle is outside the usual 12 – 15° range.')
      else if (d.groundPlaneSmall)
        statusWarn('A ground plane under 0.75 λ lets the back lobe grow.')
      else
        statusOk('Solidly in axial mode.'),
    ]),
    card('Polarisation', [
      caption('Winding sense'),
      choices<WindingSense>(WindingSense.values, p.sense, (s) => s.label,
          (s) => update(() => p.sense = s)),
      const SizedBox(height: 10),
      infoLine('Polarisation', d.polarization.label),
      infoLine('Axial ratio',
          '${d.axialRatio.toStringAsFixed(3)} (${d.axialRatioDb.toStringAsFixed(2)} dB)'),
      note('A helix only talks to its own hand. Work a satellite with the '
          'wrong sense and the mismatch is worth tens of dB, not tenths.'),
    ]),
    card('Feed & matching', [
      caption('Matching section'),
      choices<HelixMatch>(HelixMatch.values, p.match, (m) => m.label,
          (m) => update(() => p.match = m)),
      const SizedBox(height: 10),
      caption('Feedline impedance'),
      feedlineSelector(p.feedOhms, (v) => update(() => p.feedOhms = v)),
      const Divider(height: 20),
      infoLine('Raw feedpoint R',
          '${d.feedpointROhms.toStringAsFixed(0)} Ω (140 × C/λ)'),
      infoLine('SWR at center', '${d.centerSwr.toStringAsFixed(2)} : 1'),
      infoLine(
        '2:1 bandwidth',
        d.bandwidth2to1MHz <= 0
            ? '— (no 2:1 window)'
            : '${formatBandwidth(d.bandwidth2to1MHz)} '
                '(${(100 * d.bandwidth2to1MHz / d.centerFrequencyMHz).toStringAsFixed(0)} %)',
      ),
      note('The feedpoint tracks circumference in wavelengths, so it drifts '
          'across the band rather than resonating. That is also why the '
          'usable bandwidth is so wide.'),
    ]),
    card('Computed summary', [
      infoLine('Gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
      infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(0)} dB'),
      infoLine('HPBW (both planes)', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
      const Divider(height: 20),
      dataTable([
        dataRow('Dimension', 'Value', bold: true),
        dataRow('Turn diameter',
            '${(d.turnDiameterM * 1000).toStringAsFixed(0)} mm'),
        dataRow('Turn spacing', '${(d.spacingM * 1000).toStringAsFixed(0)} mm'),
        dataRow('Axial length',
            '${(d.axialLengthM * 1000).toStringAsFixed(0)} mm'),
        dataRow('Ground plane ⌀',
            '${(d.groundPlaneM * 1000).toStringAsFixed(0)} mm'),
      ]),
    ]),
  ];
}

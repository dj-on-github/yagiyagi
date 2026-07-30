import 'package:flutter/material.dart';

import '../moxon_model.dart';
import '../ui_kit.dart';

List<Widget> moxonCards(MoxonParameters p, MoxonDesign d, Update update) {
  return [
    card('Frequency', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f),
          fMin: 7, fMax: 1300),
      bandChips(
        (f) => update(() => p.frequencyMHz = f),
        bands: const [14.2, 28.5, 50.0, 145.0, 433.0],
      ),
      const SizedBox(height: 8),
      infoLine('Wavelength', '${d.wavelengthM.toStringAsFixed(3)} m'),
      infoLine('Resonance', '${d.resonanceMHz.toStringAsFixed(3)} MHz'),
    ]),
    card('Rectangle', [
      slider(
        'Wire diameter: ${p.wireDiameterMm.toStringAsFixed(1)} mm',
        p.wireDiameterMm,
        0.5,
        25,
        49,
        (v) => update(() => p.wireDiameterMm = v),
      ),
      const Divider(height: 20),
      dataTable([
        dataRow('Dimension', 'Value (m)', bold: true),
        dataRow('A — width', d.widthM.toStringAsFixed(3)),
        dataRow('B — driven tails', d.drivenTailM.toStringAsFixed(3)),
        dataRow('C — gap', d.gapM.toStringAsFixed(4)),
        dataRow('D — reflector tails', d.reflectorTailM.toStringAsFixed(3)),
        dataRow('E — total depth', d.depthM.toStringAsFixed(3)),
      ]),
      note('Footprint is about 0.37 λ by 0.125 λ — roughly 70 % of the '
          'turning radius of a two-element Yagi.'),
    ]),
    card('Gap tuning', [
      slider(
        'Tip gap trim: ×${p.gapTrim.toStringAsFixed(2)} '
        '(${(d.gapM * 1000).toStringAsFixed(1)} mm)',
        p.gapTrim,
        0.80,
        1.20,
        40,
        (v) => update(() => p.gapTrim = v),
      ),
      infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(1)} dB'),
      const SizedBox(height: 6),
      if (d.frontToBackDb > 30)
        statusOk('The rear null is right where it should be.')
      else if (d.frontToBackDb > 18)
        statusWarn('The null is off. A millimetre of gap is worth several dB '
            'here.')
      else
        statusBad('The gap is far enough off that the rear null has '
            'collapsed — this is now just a mediocre two-element beam.'),
      note('The gap is the only critical dimension on a Moxon, and it is '
          'critical: forward gain barely notices, but the front-to-back '
          'falls off a cliff.'),
    ]),
    card('Environment', [
      slider(
        p.heightWl == 0
            ? 'Height above ground: free space'
            : 'Height above ground: ${p.heightWl.toStringAsFixed(2)} λ '
                '(${(p.heightWl * d.wavelengthM).toStringAsFixed(2)} m)',
        p.heightWl,
        0,
        2.0,
        40,
        (v) => update(() => p.heightWl = v),
      ),
      note('Perfect ground, horizontal polarisation.'),
    ]),
    card('Feed & matching', [
      caption('Feedline impedance'),
      feedlineSelector(p.feedOhms, (v) => update(() => p.feedOhms = v)),
      note('A Moxon lands on 50 Ω on its own. No gamma, no hairpin, no '
          'matching section.'),
      const Divider(height: 20),
      ...matchSummary(
        feedpointROhms: d.feedpointROhms,
        qFactor: d.qFactor,
        centerSwr: d.centerSwr,
        bandwidthMHz: d.bandwidth2to1MHz,
        referenceMHz: d.resonanceMHz,
      ),
    ]),
    card('Computed summary', [
      infoLine('Forward gain',
          '${d.gainDbi.toStringAsFixed(1)} dBi ${d.overGround ? "(lobe peak over ground)" : "(free space)"}'),
      infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(1)} dB'),
      infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
      infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
      const Divider(height: 20),
      dataTable([
        dataRow('Wire run', 'Length (m)', bold: true),
        dataRow('Driven element', d.drivenWireM.toStringAsFixed(3)),
        dataRow('Reflector', d.reflectorWireM.toStringAsFixed(3)),
      ]),
      note('Cut each wire straight to the length above, then fold the tails '
          'towards each other.'),
    ]),
  ];
}

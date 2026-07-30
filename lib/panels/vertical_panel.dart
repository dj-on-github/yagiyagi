import 'package:flutter/material.dart';

import '../antenna_design.dart';
import '../ui_kit.dart';
import '../vertical_model.dart';

List<Widget> verticalCards(
    VerticalParameters p, VerticalDesign d, Update update) {
  return [
    card('Frequency', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f),
          fMin: 1.8, fMax: 1300),
      bandChips(
        (f) => update(() => p.frequencyMHz = f),
        bands: const [3.6, 7.1, 14.2, 28.5, 50.0, 145.0],
      ),
      const SizedBox(height: 8),
      infoLine('Wavelength', '${d.wavelengthM.toStringAsFixed(3)} m'),
      infoLine('Resonance', '${d.resonanceMHz.toStringAsFixed(3)} MHz'),
    ]),
    card('Radiator', [
      slider(
        'Length factor: ${p.lengthFactor.toStringAsFixed(3)} × λ/4  '
        '(${d.radiatorLengthM.toStringAsFixed(3)} m)',
        p.lengthFactor,
        0.85,
        1.10,
        50,
        (v) => update(() => p.lengthFactor = v),
      ),
      slider(
        'Radiator diameter: ${p.diameterMm.toStringAsFixed(0)} mm',
        p.diameterMm,
        2,
        60,
        58,
        (v) => update(() => p.diameterMm = v),
      ),
      infoLine('Electrical height', '${d.radiatorWl.toStringAsFixed(3)} λ'),
    ]),
    card('Ground system', [
      slider(
        'Radials: ${p.radialCount}',
        p.radialCount.toDouble(),
        2,
        120,
        118,
        (v) => update(() => p.radialCount = v.round()),
      ),
      slider(
        'Radial droop: ${p.radialDroopDeg.toStringAsFixed(0)}°'
        '${p.radialDroopDeg == 0 ? ' (flat ground plane)' : ''}',
        p.radialDroopDeg,
        0,
        60,
        60,
        (v) => update(() => p.radialDroopDeg = v),
      ),
      const SizedBox(height: 6),
      caption('Soil under the antenna'),
      dropdown<GroundQuality>(GroundQuality.values, p.ground,
          (g) => '${g.label} — ${g.detail}', (g) => update(() => p.ground = g)),
      const Divider(height: 20),
      infoLine('Radiation resistance',
          '${d.radiationROhms.toStringAsFixed(1)} Ω'),
      infoLine('Ground loss resistance',
          '${d.groundLossROhms.toStringAsFixed(2)} Ω'),
      infoLine('Efficiency',
          '${(100 * d.efficiency).toStringAsFixed(1)} % (${d.efficiencyDb.toStringAsFixed(1)} dB)'),
      const SizedBox(height: 6),
      if (d.efficiency < 0.5)
        statusWarn('More than half the power is heating the ground. '
            'Add radials.')
      else if (d.efficiency < 0.85)
        statusWarn('Ground losses are still costing '
            '${(-d.efficiencyDb).toStringAsFixed(1)} dB.')
      else
        statusOk('Ground system is doing its job.'),
      note('Radial droop trades pattern for match: flat radials give the '
          'monopole its natural 36 Ω, 45° of droop lands on 50 Ω.'),
    ]),
    card('Feed & matching', [
      caption('Feedline impedance'),
      feedlineSelector(p.feedOhms, (v) => update(() => p.feedOhms = v)),
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
      infoLine('Gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
      infoLine('Pattern', 'Omnidirectional in azimuth'),
      infoLine('Polarisation', d.polarization.label),
      infoLine('Takeoff angle', '${d.takeoffAngleDeg.toStringAsFixed(0)}°'),
      infoLine('Main lobe (−3 dB)',
          '${d.lobeLowDeg.toStringAsFixed(0)}° – ${d.lobeHighDeg.toStringAsFixed(0)}°'),
      infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
      const Divider(height: 20),
      dataTable([
        dataRow('Dimension', 'Length (m)', bold: true),
        dataRow('Radiator', d.radiatorLengthM.toStringAsFixed(3)),
        dataRow('Each radial', d.radialLengthM.toStringAsFixed(3)),
        dataRow('Total radial wire',
            (d.radialLengthM * p.radialCount).toStringAsFixed(1)),
      ]),
    ]),
  ];
}

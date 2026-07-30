import 'package:flutter/material.dart';

import '../antenna_design.dart';
import '../dipole_model.dart';
import '../ui_kit.dart';

List<Widget> dipoleCards(
    DipoleParameters p, DipoleDesign d, Update update) {
  return [
    card('Frequency', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f)),
      bandChips((f) => update(() => p.frequencyMHz = f)),
      const SizedBox(height: 8),
      infoLine('Wavelength', '${d.wavelengthM.toStringAsFixed(3)} m'),
      infoLine('Resonance', '${d.resonanceMHz.toStringAsFixed(2)} MHz'),
    ]),
    card('Dipole dimensions', [
      slider(
        'Length factor: ${p.lengthFactor.toStringAsFixed(3)} × λ/2  '
        '(total ${d.totalLengthM.toStringAsFixed(3)} m)',
        p.lengthFactor,
        0.90,
        1.02,
        48,
        (v) => update(() => p.lengthFactor = v),
      ),
      slider(
        'Element diameter: ${p.diameterMm.toStringAsFixed(0)} mm',
        p.diameterMm,
        1,
        25,
        48,
        (v) => update(() => p.diameterMm = v),
      ),
      infoLine('Each leg', '${d.legLengthM.toStringAsFixed(3)} m'),
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
      note('Perfect ground. Set height above 0 to see ground-reflection '
          'lobes in the elevation plot.'),
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
      infoLine('Gain',
          '${d.gainDbi.toStringAsFixed(1)} dBi ${d.overGround ? "(lobe peak over ground)" : "(free space)"}'),
      infoLine('Pattern', 'Bidirectional (figure-8)'),
      infoLine('Polarisation', d.polarization.label),
      infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
      infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
      const Divider(height: 20),
      dataTable([
        dataRow('Dimension', 'Length (m)', bold: true),
        dataRow('Total length', d.totalLengthM.toStringAsFixed(3)),
        dataRow('Each leg', d.legLengthM.toStringAsFixed(3)),
      ]),
    ]),
  ];
}

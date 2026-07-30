import 'package:flutter/material.dart';

import '../antenna_design.dart';
import '../loop_model.dart';
import '../ui_kit.dart';

List<Widget> loopCards(LoopParameters p, LoopDesign d, Update update) {
  return [
    card('Frequency', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f)),
      bandChips((f) => update(() => p.frequencyMHz = f)),
      const SizedBox(height: 8),
      infoLine('Wavelength', '${d.wavelengthM.toStringAsFixed(3)} m'),
      infoLine('Resonance', '${d.resonanceMHz.toStringAsFixed(2)} MHz'),
    ]),
    card('Loop dimensions', [
      caption('Loop shape'),
      choices<LoopShape>(LoopShape.values, p.shape, (s) => s.label,
          (s) => update(() => p.shape = s)),
      const SizedBox(height: 10),
      slider(
        'Circumference: ${p.circumferenceFactor.toStringAsFixed(3)} λ  '
        '(${d.circumferenceM.toStringAsFixed(3)} m)',
        p.circumferenceFactor,
        0.95,
        1.10,
        60,
        (v) => update(() => p.circumferenceFactor = v),
      ),
      slider(
        'Wire diameter: ${p.wireDiameterMm.toStringAsFixed(1)} mm',
        p.wireDiameterMm,
        0.5,
        10,
        38,
        (v) => update(() => p.wireDiameterMm = v),
      ),
      infoLine(
        p.shape == LoopShape.circular ? 'Loop diameter' : 'Side length',
        '${(p.shape == LoopShape.circular ? d.diameterM : d.sideM).toStringAsFixed(3)} m',
      ),
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
      note('Perfect ground, loop center height. Set height above 0 to see '
          'ground-reflection lobes in the elevation plot.'),
    ]),
    card('Feed & matching', [
      caption('Feedline impedance'),
      feedlineSelector(p.feedOhms, (v) => update(() => p.feedOhms = v)),
      note('A full-wave loop presents ~100-120 Ω, so 75 Ω coax is the '
          'classic direct feed.'),
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
      infoLine('Pattern', 'Bidirectional (broad figure-8)'),
      infoLine('Polarisation', d.polarization.label),
      infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
      infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
      const Divider(height: 20),
      dataTable([
        dataRow('Dimension', 'Length (m)', bold: true),
        dataRow('Circumference', d.circumferenceM.toStringAsFixed(3)),
        if (p.shape == LoopShape.circular)
          dataRow('Diameter', d.diameterM.toStringAsFixed(3))
        else
          dataRow('Side length', d.sideM.toStringAsFixed(3)),
      ]),
    ]),
  ];
}

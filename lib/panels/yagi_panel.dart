import 'package:flutter/material.dart';

import '../ui_kit.dart';
import '../yagi_model.dart';

List<Widget> yagiCards(YagiParameters p, YagiDesign d, Update update) {
  Widget presetChip(String label, int elements, double spacing) {
    final selected = p.elements == elements && p.spacingWl == spacing;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => update(() {
        p.elements = elements;
        p.spacingWl = spacing;
      }),
    );
  }

  return [
    card('Design presets', [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          presetChip('2-el short', 2, 0.12),
          presetChip('3-el portable', 3, 0.16),
          presetChip('5-el general', 5, 0.18),
          presetChip('8-el long boom', 8, 0.20),
          presetChip('10-el contest', 10, 0.22),
        ],
      ),
    ]),
    card('Frequency & elements', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f)),
      bandChips((f) => update(() => p.frequencyMHz = f)),
      const SizedBox(height: 8),
      slider(
        'Elements: ${p.elements}  '
        '(1 reflector, 1 driven, ${d.directors} directors)',
        p.elements.toDouble(),
        2,
        12,
        10,
        (v) => update(() => p.elements = v.round()),
      ),
      infoLine('Wavelength', '${d.wavelengthM.toStringAsFixed(3)} m'),
      infoLine('Driven element', '${d.drivenLengthM.toStringAsFixed(3)} m'),
    ]),
    card('Geometry', [
      slider(
        'Element spacing: ${p.spacingWl.toStringAsFixed(2)} λ '
        '(${d.spacingM.toStringAsFixed(3)} m)',
        p.spacingWl,
        0.08,
        0.30,
        44,
        (v) => update(() => p.spacingWl = v),
      ),
      infoLine('Boom length',
          '${d.boomLengthM.toStringAsFixed(2)} m (${d.boomWl.toStringAsFixed(2)} λ)'),
      slider(
        'Element diameter: ${p.elementDiameterMm.toStringAsFixed(0)} mm',
        p.elementDiameterMm,
        1,
        25,
        48,
        (v) => update(() => p.elementDiameterMm = v),
      ),
      slider(
        'Reflector length: ×${p.reflectorFactor.toStringAsFixed(3)} '
        '(${d.reflectorLengthM.toStringAsFixed(3)} m)',
        p.reflectorFactor,
        1.00,
        1.10,
        40,
        (v) => update(() => p.reflectorFactor = v),
      ),
      slider(
        'Director length: ×${p.directorFactor.toStringAsFixed(3)}',
        p.directorFactor,
        0.88,
        1.00,
        48,
        (v) => update(() => p.directorFactor = v),
      ),
      slider(
        'Director taper: ${(p.taper * 100).toStringAsFixed(1)} %/el',
        p.taper,
        0,
        0.03,
        30,
        (v) => update(() => p.taper = v),
      ),
    ]),
    card('Feed & matching', [
      caption('Feed system'),
      choices<FeedType>(FeedType.values, p.feedType, (t) => t.label,
          (t) => update(() => p.feedType = t)),
      const SizedBox(height: 12),
      caption('Feedline impedance'),
      feedlineSelector(p.feedOhms, (v) => update(() => p.feedOhms = v)),
      const Divider(height: 20),
      infoLine('Feedpoint R at resonance',
          '${d.feedpointROhms.toStringAsFixed(1)} Ω (before match)'),
      ...matchSummary(
        feedpointROhms: d.feedpointROhms,
        qFactor: d.qFactor,
        centerSwr: d.centerSwr,
        bandwidthMHz: d.bandwidth2to1MHz,
        referenceMHz: p.frequencyMHz,
      ).skip(1),
    ]),
    card('Computed summary', [
      infoLine('Forward gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
      infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(0)} dB'),
      infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
      infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
      const Divider(height: 20),
      dataTable([
        dataRow('Element', 'Length (m)', bold: true),
        dataRow('Reflector', d.reflectorLengthM.toStringAsFixed(3)),
        dataRow('Driven', d.drivenLengthM.toStringAsFixed(3)),
        for (var i = 0; i < d.directors; i++)
          dataRow('Director ${i + 1}', d.directorLengthM(i).toStringAsFixed(3)),
      ]),
    ]),
  ];
}

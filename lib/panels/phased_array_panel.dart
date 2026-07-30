import 'package:flutter/material.dart';

import '../antenna_design.dart';
import '../phased_array_model.dart';
import '../ui_kit.dart';
import '../vertical_model.dart';

List<Widget> phasedArrayCards(
    PhasedArrayParameters p, PhasedArrayDesign d, Update update) {
  Widget presetChip(String label, double spacing, double phase) {
    final selected =
        (p.spacingWl - spacing).abs() < 1e-6 && (p.phaseDeg - phase).abs() < 1e-6;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => update(() {
        p.spacingWl = spacing;
        p.phaseDeg = phase;
      }),
    );
  }

  String describe(Impedance z) =>
      '${z.r.toStringAsFixed(1)} ${z.x >= 0 ? '+' : '−'} '
      'j${z.x.abs().toStringAsFixed(1)} Ω';

  return [
    card('Design presets', [
      Wrap(spacing: 8, runSpacing: 4, children: [
        presetChip('Cardioid', 0.25, -90),
        presetChip('Broadside', 0.50, 0),
        presetChip('Endfire', 0.50, 180),
        presetChip('Wide cardioid', 0.375, -135),
      ]),
      note('Same two antennas every time. Only the phase changes.'),
    ]),
    card('Frequency', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f),
          fMin: 1.8, fMax: 450),
      bandChips(
        (f) => update(() => p.frequencyMHz = f),
        bands: const [3.6, 7.1, 14.2, 28.5, 50.0],
      ),
      const SizedBox(height: 8),
      infoLine('Wavelength', '${d.wavelengthM.toStringAsFixed(2)} m'),
      infoLine('Element height', '${d.elementHeightM.toStringAsFixed(2)} m'),
    ]),
    card('Array geometry', [
      slider(
        'Spacing: ${p.spacingWl.toStringAsFixed(3)} λ '
        '(${d.spacingM.toStringAsFixed(2)} m)',
        p.spacingWl,
        0.10,
        1.00,
        36,
        (v) => update(() => p.spacingWl = v),
      ),
      slider(
        'Phase of element 2: ${p.phaseDeg.toStringAsFixed(0)}°',
        p.phaseDeg,
        -180,
        180,
        72,
        (v) => update(() => p.phaseDeg = v),
      ),
      slider(
        'Current ratio: ${p.amplitudeRatio.toStringAsFixed(2)}',
        p.amplitudeRatio,
        0.4,
        1.6,
        48,
        (v) => update(() => p.amplitudeRatio = v),
      ),
      const Divider(height: 20),
      infoLine('Peak azimuth', '${d.peakAzimuthDeg.toStringAsFixed(0)}°'),
      infoLine('Array gain over one element',
          '${d.arrayGainDb.toStringAsFixed(2)} dB'),
      infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(1)} dB'),
      note('Element 2 sits towards 0° on the plots. Retard it by a quarter '
          'cycle at a quarter-wave spacing and the rear signal cancels.'),
    ]),
    card('Elements & ground', [
      slider(
        'Element diameter: ${p.diameterMm.toStringAsFixed(0)} mm',
        p.diameterMm,
        5,
        80,
        75,
        (v) => update(() => p.diameterMm = v),
      ),
      slider(
        'Radials per element: ${p.radialCount}',
        p.radialCount.toDouble(),
        2,
        120,
        118,
        (v) => update(() => p.radialCount = v.round()),
      ),
      const SizedBox(height: 6),
      caption('Soil under the array'),
      dropdown<GroundQuality>(GroundQuality.values, p.ground,
          (g) => '${g.label} — ${g.detail}', (g) => update(() => p.ground = g)),
      const Divider(height: 20),
      infoLine('Element efficiency',
          '${(100 * d.element.efficiency).toStringAsFixed(1)} %'),
      infoLine('Takeoff angle',
          '${d.element.takeoffAngleDeg.toStringAsFixed(0)}°'),
    ]),
    card('Mutual coupling', [
      infoLine('Mutual impedance', describe(d.mutualImpedance)),
      const Divider(height: 20),
      infoLine('Element 1 drive point', describe(d.element1Impedance)),
      infoLine('Element 2 drive point', describe(d.element2Impedance)),
      const SizedBox(height: 6),
      if (d.negativeResistance)
        statusBad('One element shows negative resistance: it is absorbing '
            'power from the other rather than radiating. The phasing network '
            'has to deal with this.')
      else if ((d.element1Impedance.r - d.element2Impedance.r).abs() > 20)
        statusWarn('The two elements are more than 20 Ω apart. A single '
            'coax-line phasing network will not feed both correctly.')
      else
        statusOk('The two drive points are close enough to feed simply.'),
      note('Each element sees its own impedance plus whatever the other '
          'element couples into it — which depends on both spacing and '
          'phase. This is why phased arrays are harder than they look.'),
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
        referenceMHz: d.element.resonanceMHz,
        feedpointLabel: 'Element 1 R at resonance',
      ),
      note('The plots follow element 1.'),
    ]),
    card('Computed summary', [
      infoLine('Gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
      infoLine('Polarisation', d.polarization.label),
      infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
      infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
    ]),
  ];
}

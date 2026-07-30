import 'package:flutter/material.dart';

import '../dish_model.dart';
import '../ui_kit.dart';

List<Widget> dishCards(DishParameters p, DishDesign d, Update update) {
  return [
    card('Frequency', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f),
          fMin: 400, fMax: 6000),
      bandChips(
        (f) => update(() => p.frequencyMHz = f),
        bands: const [1296.0, 2400.0, 3400.0, 5760.0],
      ),
      const SizedBox(height: 8),
      infoLine('Wavelength', '${(d.wavelengthM * 1000).toStringAsFixed(1)} mm'),
      infoLine('Aperture', '${d.diameterWl.toStringAsFixed(1)} λ across'),
      const SizedBox(height: 6),
      if (d.tooSmall)
        statusBad('Under three wavelengths across — this is not really an '
            'aperture antenna yet, and the gain figure is optimistic.')
      else
        statusOk('Aperture is large enough for the gain model to hold.'),
    ]),
    card('Reflector', [
      slider(
        'Diameter: ${p.diameterM.toStringAsFixed(2)} m',
        p.diameterM,
        0.3,
        5.0,
        47,
        (v) => update(() => p.diameterM = v),
      ),
      slider(
        'f/D: ${p.fOverD.toStringAsFixed(2)}  '
        '(focus ${d.focalLengthM.toStringAsFixed(2)} m)',
        p.fOverD,
        0.25,
        0.80,
        55,
        (v) => update(() => p.fOverD = v),
      ),
      infoLine('Rim half-angle', '${d.rimHalfAngleDeg.toStringAsFixed(1)}°'),
      note('A deep dish (low f/D) hides the feed from outside noise but asks '
          'it to illuminate a very wide angle.'),
    ]),
    card('Illumination', [
      slider(
        'Edge taper: −${p.edgeTaperDb.toStringAsFixed(1)} dB at the rim',
        p.edgeTaperDb,
        4,
        20,
        32,
        (v) => update(() => p.edgeTaperDb = v),
      ),
      slider(
        'Blockage: ${p.blockagePercent.toStringAsFixed(0)} % of diameter',
        p.blockagePercent,
        0,
        25,
        25,
        (v) => update(() => p.blockagePercent = v),
      ),
      infoLine('Implied feed pattern', 'cos^${d.feedExponent.toStringAsFixed(2)} θ'),
      note('Illuminating harder fills the aperture but throws more power '
          'past the rim. The trade bottoms out near −11 dB.'),
    ]),
    card('Surface accuracy', [
      slider(
        'Surface RMS error: ${p.surfaceRmsMm.toStringAsFixed(2)} mm',
        p.surfaceRmsMm,
        0,
        10,
        50,
        (v) => update(() => p.surfaceRmsMm = v),
      ),
      infoLine('λ/32 tolerance',
          '${(d.wavelengthM * 1000 / 32).toStringAsFixed(2)} mm'),
      infoLine('Ruze loss', '${d.ruzeLossDb.toStringAsFixed(2)} dB'),
      const SizedBox(height: 6),
      if (d.surfaceMarginal)
        statusBad('Surface error is past λ/32. Ruze is taking the gain away '
            'faster than a bigger dish can add it.')
      else
        statusOk('Surface is accurate enough for this frequency.'),
    ]),
    card('Efficiency budget', [
      infoLine('Illumination + spillover',
          '${(100 * d.apertureEfficiency / (d.surfaceEfficiency * d.blockageEfficiency)).toStringAsFixed(1)} %'),
      infoLine('Surface (Ruze)',
          '${(100 * d.surfaceEfficiency).toStringAsFixed(1)} %'),
      infoLine('Blockage',
          '${(100 * d.blockageEfficiency).toStringAsFixed(1)} %'),
      const Divider(height: 20),
      infoLine('Total aperture efficiency',
          '${(100 * d.apertureEfficiency).toStringAsFixed(1)} %'),
    ]),
    card('Feed & matching', [
      slider(
        'Feed resistance at resonance: ${p.feedROhms.toStringAsFixed(0)} Ω',
        p.feedROhms,
        20,
        120,
        50,
        (v) => update(() => p.feedROhms = v),
      ),
      caption('Feedline impedance'),
      feedlineSelector(p.feedOhms, (v) => update(() => p.feedOhms = v)),
      const Divider(height: 20),
      ...matchSummary(
        feedpointROhms: d.feedpointROhms,
        qFactor: d.qFactor,
        centerSwr: d.centerSwr,
        bandwidthMHz: d.bandwidth2to1MHz,
        referenceMHz: p.frequencyMHz,
        feedpointLabel: 'Feed R at resonance',
        qLabel: 'Feed Q',
      ),
      note('The reflector has no impedance of its own — everything the SWR '
          'plot shows belongs to the feed.'),
    ]),
    card('Computed summary', [
      infoLine('Gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
      infoLine('HPBW', '${d.hpbwAzDeg.toStringAsFixed(2)}°'),
      infoLine('First sidelobe',
          '${d.firstSidelobeDb.toStringAsFixed(1)} dB'),
      infoLine('Polarisation', 'Follows the feed'),
      note('The polar plots are the real circular-aperture transform, so '
          'the sidelobe rings are the ones the taper actually produces.'),
    ]),
  ];
}

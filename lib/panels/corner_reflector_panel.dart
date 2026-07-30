import 'package:flutter/material.dart';

import '../corner_reflector_model.dart';
import '../ui_kit.dart';

List<Widget> cornerReflectorCards(CornerReflectorParameters p,
    CornerReflectorDesign d, Update update) {
  return [
    card('Frequency', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f),
          fMin: 50, fMax: 6000),
      bandChips(
        (f) => update(() => p.frequencyMHz = f),
        bands: const [145.0, 433.0, 1296.0, 2400.0],
      ),
      const SizedBox(height: 8),
      infoLine('Wavelength', '${d.wavelengthM.toStringAsFixed(3)} m'),
      infoLine('Driven element', '${d.drivenLengthM.toStringAsFixed(3)} m'),
    ]),
    card('Corner geometry', [
      caption('Apex angle'),
      choices<ApexAngle>(ApexAngle.values, p.apex, (a) => a.label,
          (a) => update(() => p.apex = a)),
      const SizedBox(height: 10),
      slider(
        'Driven element to apex: ${p.spacingWl.toStringAsFixed(3)} λ '
        '(${d.spacingM.toStringAsFixed(3)} m)',
        p.spacingWl,
        0.20,
        1.00,
        32,
        (v) => update(() => p.spacingWl = v),
      ),
      slider(
        'Reflector side length: ${p.reflectorLengthWl.toStringAsFixed(2)} λ '
        '(${d.reflectorLengthM.toStringAsFixed(2)} m)',
        p.reflectorLengthWl,
        0.5,
        3.0,
        50,
        (v) => update(() => p.reflectorLengthWl = v),
      ),
      slider(
        p.rodSpacingWl == 0
            ? 'Reflector: solid sheet'
            : 'Grid rod spacing: ${p.rodSpacingWl.toStringAsFixed(3)} λ '
                '(${(p.rodSpacingWl * d.wavelengthM * 1000).toStringAsFixed(0)} mm)',
        p.rodSpacingWl,
        0,
        0.25,
        25,
        (v) => update(() => p.rodSpacingWl = v),
      ),
      const Divider(height: 20),
      infoLine('Images', '${d.imageCount} (apex divides 180° '
          '${p.apex.n}×)'),
      infoLine('Mouth width', '${d.apertureWidthM.toStringAsFixed(2)} m'),
      infoLine('Edge-leak loss', '${d.sizeLossDb.toStringAsFixed(2)} dB'),
      infoLine('Grid-leak loss', '${d.gridLossDb.toStringAsFixed(2)} dB'),
      const SizedBox(height: 6),
      if (p.reflectorLengthWl < 2 * p.spacingWl)
        statusWarn('Reflector panels shorter than twice the apex spacing '
            'start leaking around the edges.')
      else if (p.rodSpacingWl > 0.1)
        statusWarn('Rods more than 0.1 λ apart no longer look like a sheet.')
      else
        statusOk('Reflector is big enough and tight enough to behave.'),
    ]),
    card('Driven element impedance', [
      infoLine('Feedpoint R', '${d.feedpointROhms.toStringAsFixed(1)} Ω'),
      infoLine('Coupled reactance',
          '${d.coupledReactanceOhms >= 0 ? '+' : '−'}'
          'j${d.coupledReactanceOhms.abs().toStringAsFixed(1)} Ω'),
      const SizedBox(height: 6),
      if (d.lowImpedance)
        statusWarn('Below 20 Ω. Pull the driven element away from the apex, '
            'or accept a matching network and higher losses.')
      else
        statusOk('Feedpoint is in workable territory.'),
      note('Every image contributes mutual impedance to the driven element, '
          'so moving it towards the apex swings the feedpoint resistance far '
          'harder than it changes the gain. Retune the element to cancel the '
          'coupled reactance shown above.'),
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
        referenceMHz: p.frequencyMHz,
      ),
    ]),
    card('Computed summary', [
      infoLine('Gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
      infoLine('Gain over a dipole',
          '${d.gainOverDipoleDb.toStringAsFixed(1)} dBd'),
      infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(0)} dB'),
      infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
      infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
      note('Free space — no ground reflection is modelled here. The pattern '
          'comes from summing the driven element with its images, so the '
          'nulls are the real ones.'),
    ]),
  ];
}

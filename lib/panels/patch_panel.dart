import 'package:flutter/material.dart';

import '../patch_model.dart';
import '../ui_kit.dart';

List<Widget> patchCards(PatchParameters p, PatchDesign d, Update update) {
  return [
    card('Frequency', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f),
          fMin: 400, fMax: 6000),
      bandChips(
        (f) => update(() => p.frequencyMHz = f),
        bands: const [868.0, 1575.0, 2400.0, 5800.0],
      ),
      const SizedBox(height: 8),
      infoLine('Wavelength', '${(d.wavelengthM * 1000).toStringAsFixed(1)} mm'),
    ]),
    card('Substrate', [
      caption('Laminate'),
      dropdown<Substrate>(
          Substrate.values,
          p.substrate,
          (s) => '${s.label}  (εr ${s.epsilonR}, tanδ ${s.tanDelta})',
          (s) => update(() => p.substrate = s)),
      const SizedBox(height: 12),
      slider(
        'Thickness: ${p.heightMm.toStringAsFixed(2)} mm '
        '(${(p.heightMm / 1000 / d.wavelengthM * 1000).toStringAsFixed(1)} ‰ of λ)',
        p.heightMm,
        0.2,
        6.0,
        58,
        (v) => update(() => p.heightMm = v),
      ),
      infoLine('Effective εr', d.epsilonEff.toStringAsFixed(3)),
      note('Thicker and lower-permittivity means wider bandwidth and better '
          'efficiency, at the cost of a physically larger patch and more '
          'power lost to surface waves.'),
    ]),
    card('Patch dimensions', [
      slider(
        'Width factor: ${p.widthFactor.toStringAsFixed(2)} × design width',
        p.widthFactor,
        0.6,
        1.6,
        50,
        (v) => update(() => p.widthFactor = v),
      ),
      const Divider(height: 20),
      dataTable([
        dataRow('Dimension', 'Value (mm)', bold: true),
        dataRow('Width W', d.widthMm.toStringAsFixed(2)),
        dataRow('Length L', d.lengthMm.toStringAsFixed(2)),
        dataRow('Fringe ΔL', (d.deltaLM * 1000).toStringAsFixed(3)),
        dataRow('Feedline width', d.feedLineWidthMm.toStringAsFixed(2)),
      ]),
    ]),
    card('Q and efficiency', [
      infoLine('Radiation Q', d.qRadiation.toStringAsFixed(1)),
      infoLine('Dielectric Q', d.qDielectric.toStringAsFixed(0)),
      infoLine('Conductor Q', d.qConductor.toStringAsFixed(0)),
      infoLine('Surface-wave Q', d.qSurfaceWave.toStringAsFixed(0)),
      const Divider(height: 20),
      infoLine('Total Q', d.qTotal.toStringAsFixed(1)),
      infoLine('Efficiency',
          '${(100 * d.efficiency).toStringAsFixed(1)} % (${d.efficiencyDb.toStringAsFixed(1)} dB)'),
      const SizedBox(height: 6),
      if (d.efficiency < 0.5)
        statusWarn('Over half the power is lost before it radiates — mostly '
            'in the laminate.')
      else if (d.efficiency < 0.75)
        statusWarn('Losses are costing ${(-d.efficiencyDb).toStringAsFixed(1)} '
            'dB of gain.')
      else
        statusOk('Good efficiency for a printed antenna.'),
      note('The same Q sets the bandwidth: a patch is a genuine high-Q '
          'resonator, which is why the SWR dip is so narrow.'),
    ]),
    card('Feed & matching', [
      caption('Feed method'),
      choices<PatchFeed>(PatchFeed.values, p.feed, (f) => f.label,
          (f) => update(() => p.feed = f)),
      const SizedBox(height: 10),
      caption('Feedline impedance'),
      feedlineSelector(p.feedOhms, (v) => update(() => p.feedOhms = v)),
      const Divider(height: 20),
      infoLine('Edge resistance',
          '${d.edgeResistanceOhms.toStringAsFixed(0)} Ω'),
      infoLine(
          'Inset for ${p.feedOhms.toStringAsFixed(0)} Ω',
          p.feed == PatchFeed.edgeDirect
              ? '— (fed at the edge)'
              : '${d.insetDistanceMm.toStringAsFixed(2)} mm'),
      ...matchSummary(
        feedpointROhms: d.feedpointROhms,
        qFactor: d.qFactor,
        centerSwr: d.centerSwr,
        bandwidthMHz: d.bandwidth2to1MHz,
        referenceMHz: p.frequencyMHz,
        qLabel: 'Loaded Q',
      ),
      if (p.feed == PatchFeed.edgeDirect)
        note('A bare radiating edge sits at a couple of hundred ohms. This '
            'is why nobody feeds a patch there directly.'),
    ]),
    card('Computed summary', [
      infoLine('Directivity',
          '${d.directivityDbiValue.toStringAsFixed(1)} dBi'),
      infoLine('Gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
      infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(0)} dB'),
      infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
      infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
    ]),
  ];
}

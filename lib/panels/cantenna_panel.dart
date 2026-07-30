import 'package:flutter/material.dart';

import '../cantenna_model.dart';
import '../ui_kit.dart';

List<Widget> cantennaCards(
    CantennaParameters p, CantennaDesign d, Update update) {
  Widget modeStatus() {
    if (!d.propagates) {
      return statusBad(
          'Below TE11 cutoff — the waveguide does not propagate at this '
          'frequency. Increase the can diameter or the frequency.');
    }
    if (d.overModed) {
      return statusWarn(
          'Above TM01 cutoff — the guide is over-moded; pattern and match '
          'will be erratic. Reduce diameter or frequency.');
    }
    return statusOk('Single-mode (TE11) operation.');
  }

  return [
    card('Frequency', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f)),
      bandChips(
        (f) => update(() => p.frequencyMHz = f),
        bands: const [433.0, 915.0, 2400.0, 5800.0],
      ),
      const SizedBox(height: 8),
      infoLine('Wavelength', '${d.wavelengthMm.toStringAsFixed(1)} mm'),
    ]),
    card('Can dimensions', [
      slider(
        'Can diameter: ${p.canDiameterMm.toStringAsFixed(0)} mm '
        '(${(d.diameterM / d.wavelengthM).toStringAsFixed(2)} λ)',
        p.canDiameterMm,
        30,
        300,
        90,
        (v) => update(() => p.canDiameterMm = v),
      ),
      infoLine('TE11 cutoff', '${d.cutoffTe11MHz.toStringAsFixed(0)} MHz'),
      infoLine('TM01 cutoff', '${d.cutoffTm01MHz.toStringAsFixed(0)} MHz'),
      infoLine(
          'Guide wavelength',
          d.propagates
              ? '${d.guideWavelengthMm.toStringAsFixed(1)} mm'
              : '— (below cutoff)'),
      infoLine(
          'Recommended can length',
          d.propagates
              ? '${d.recommendedCanLengthMm.toStringAsFixed(0)} mm (¾ λg)'
              : '—'),
      const SizedBox(height: 6),
      modeStatus(),
    ]),
    card('Probe feed', [
      slider(
        'Probe distance from back: '
        '${p.probeDistanceFactor.toStringAsFixed(2)} λg'
        '${d.propagates ? ' (${d.probeDistanceMm.toStringAsFixed(1)} mm)' : ''}',
        p.probeDistanceFactor,
        0.15,
        0.35,
        40,
        (v) => update(() => p.probeDistanceFactor = v),
      ),
      slider(
        'Probe length: ${p.probeLengthFactor.toStringAsFixed(2)} λ '
        '(${d.probeLengthMm.toStringAsFixed(1)} mm)',
        p.probeLengthFactor,
        0.15,
        0.35,
        40,
        (v) => update(() => p.probeLengthFactor = v),
      ),
      note('Classic starting point: probe λg/4 from the closed back, '
          'about λ/4 long.'),
    ]),
    card('Feed & matching', [
      caption('Feedline impedance'),
      feedlineSelector(p.feedOhms, (v) => update(() => p.feedOhms = v)),
      const Divider(height: 20),
      infoLine('Feedpoint R at resonance',
          '${d.feedpointROhms.toStringAsFixed(1)} Ω'),
      infoLine('Antenna Q', d.qFactor.toStringAsFixed(1)),
      infoLine('SWR at center',
          d.propagates ? '${d.centerSwr.toStringAsFixed(2)} : 1' : 'off scale'),
      infoLine(
        '2:1 bandwidth',
        d.propagates
            ? '${formatBandwidth(d.bandwidth2to1MHz)} '
                '(${(100 * d.bandwidth2to1MHz / d.centerFrequencyMHz).toStringAsFixed(1)} %)'
            : '— (below cutoff)',
      ),
    ]),
    card('Computed summary', [
      infoLine('Gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
      infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(0)} dB'),
      infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
      infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
      const Divider(height: 20),
      dataTable([
        dataRow('Dimension', 'Value', bold: true),
        dataRow('Can diameter', '${p.canDiameterMm.toStringAsFixed(0)} mm'),
        dataRow(
            'Can length (rec.)',
            d.propagates
                ? '${d.recommendedCanLengthMm.toStringAsFixed(0)} mm'
                : '—'),
        dataRow('Probe from back', '${d.probeDistanceMm.toStringAsFixed(1)} mm'),
        dataRow('Probe length', '${d.probeLengthMm.toStringAsFixed(1)} mm'),
      ]),
    ]),
  ];
}

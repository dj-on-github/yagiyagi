import 'package:flutter/material.dart';

import '../lpda_model.dart';
import '../ui_kit.dart';

List<Widget> lpdaCards(LpdaParameters p, LpdaDesign d, Update update) {
  Widget presetChip(String label, double lo, double hi) {
    final selected = p.fLowMHz == lo && p.fHighMHz == hi;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => update(() {
        p.fLowMHz = lo;
        p.fHighMHz = hi;
      }),
    );
  }

  return [
    card('Design presets', [
      Wrap(spacing: 8, runSpacing: 4, children: [
        presetChip('VHF/UHF scanner', 100, 500),
        presetChip('TV band', 470, 800),
        presetChip('2 m – 70 cm', 140, 450),
        presetChip('Decade', 200, 2000),
      ]),
    ]),
    card('Frequency range', [
      freqSlider(p.fLowMHz, (f) => update(() => p.fLowMHz = f),
          fMin: 30, fMax: 3000, label: 'Low edge'),
      freqSlider(p.fHighMHz, (f) => update(() => p.fHighMHz = f),
          fMin: 30, fMax: 6000, label: 'High edge'),
      infoLine('Design ratio',
          '${(d.fHighMHz / d.fLowMHz).toStringAsFixed(2)} : 1'),
      infoLine('Geometric center',
          '${d.centerFrequencyMHz.toStringAsFixed(1)} MHz'),
    ]),
    card('Log-periodic geometry', [
      slider(
        'τ (scaling): ${p.tau.toStringAsFixed(3)}',
        p.tau,
        0.80,
        0.96,
        32,
        (v) => update(() => p.tau = v),
      ),
      slider(
        'σ (relative spacing): ${p.sigma.toStringAsFixed(3)}',
        p.sigma,
        0.03,
        0.20,
        34,
        (v) => update(() => p.sigma = v),
      ),
      slider(
        'Element diameter: ${p.elementDiameterMm.toStringAsFixed(0)} mm',
        p.elementDiameterMm,
        2,
        40,
        38,
        (v) => update(() => p.elementDiameterMm = v),
      ),
      const Divider(height: 20),
      infoLine('Optimum σ for this τ', d.optimumSigma.toStringAsFixed(3)),
      infoLine('Apex half-angle', '${d.apexHalfAngleDeg.toStringAsFixed(1)}°'),
      infoLine('Active region BW',
          '${d.activeRegionBandwidth.toStringAsFixed(2)} : 1'),
      infoLine('Elements', '${d.elementCount}'),
      infoLine('Boom length', '${d.boomLengthM.toStringAsFixed(2)} m'),
      const SizedBox(height: 6),
      if ((p.sigma - d.optimumSigma).abs() < 0.015)
        statusOk('σ is on the optimum ridge for this τ.')
      else if (p.sigma < d.optimumSigma)
        statusWarn('σ is below optimum: shorter boom, but gain is left on '
            'the table.')
      else
        statusWarn('σ is past optimum: the boom is growing faster than the '
            'gain.'),
    ]),
    card('Feed & matching', [
      slider(
        'Boom feeder Z₀: ${p.feederZ0.toStringAsFixed(0)} Ω',
        p.feederZ0,
        50,
        250,
        40,
        (v) => update(() => p.feederZ0 = v),
      ),
      caption('Feedline impedance'),
      feedlineSelector(p.feedOhms, (v) => update(() => p.feedOhms = v)),
      const Divider(height: 20),
      infoLine('Input resistance',
          '${d.feedpointROhms.toStringAsFixed(1)} Ω (Carrel)'),
      infoLine('Mean element Zₐ', '${d.elementZa.toStringAsFixed(0)} Ω'),
      infoLine('SWR at center', '${d.centerSwr.toStringAsFixed(2)} : 1'),
      infoLine(
        '2:1 bandwidth',
        '${formatBandwidth(d.bandwidth2to1MHz)} '
            '(${(100 * d.bandwidth2to1MHz / d.centerFrequencyMHz).toStringAsFixed(0)} %)',
      ),
      infoLine('Equivalent Q', d.qFactor.toStringAsFixed(2)),
      note('There is no resonance here to speak of. The impedance ripples '
          'with a period of ln(1/τ) in log frequency — the log-periodic '
          'signature — and only falls apart past the band edges.'),
    ]),
    card('Computed summary', [
      infoLine('Forward gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
      infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(0)} dB'),
      infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
      infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
      const Divider(height: 20),
      dataTable([
        dataRow('Element', 'Length / position (m)', bold: true),
        for (var i = 0; i < d.elementCount; i++)
          dataRow(
            'El ${i + 1}',
            '${d.elementLengthM(i).toStringAsFixed(3)}  @  '
                '${d.elementPositionM(i).toStringAsFixed(3)}',
          ),
      ]),
      note('Element 1 is the longest, at the back of the boom. Lengths are '
          'tip to tip.'),
    ]),
  ];
}

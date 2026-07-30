import 'package:flutter/material.dart';

import '../horn_model.dart';
import '../ui_kit.dart';

List<Widget> hornCards(HornParameters p, HornDesign d, Update update) {
  Widget modeStatus() {
    if (!d.propagates) {
      return statusBad('Below the TE10 cutoff of ${p.guide.label} '
          '(${d.cutoffTe10MHz.toStringAsFixed(0)} MHz). Nothing propagates.');
    }
    if (d.overModed) {
      return statusWarn('Above TE20 cutoff — the guide is over-moded and the '
          'pattern will misbehave.');
    }
    return statusOk('Single-mode TE10 operation.');
  }

  String phaseVerdict() {
    final ds = (d.sPhase - 0.25).abs(), dt = (d.tPhase - 0.375).abs();
    if (ds < 0.05 && dt < 0.08) return 'optimum';
    if (d.sPhase < 0.20 && d.tPhase < 0.30) return 'under-flared';
    return 'over-flared';
  }

  return [
    card('Frequency & waveguide', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f),
          fMin: 400, fMax: 6000),
      const SizedBox(height: 8),
      caption('Feed waveguide'),
      dropdown<WaveguideSize>(
          WaveguideSize.values,
          p.guide,
          (g) => '${g.label}  ${g.aMm.toStringAsFixed(1)} × '
              '${g.bMm.toStringAsFixed(1)} mm  (${g.bandLabel})',
          (g) => update(() => p.guide = g)),
      const SizedBox(height: 12),
      infoLine('Wavelength', '${d.wavelengthMm.toStringAsFixed(1)} mm'),
      infoLine('TE10 cutoff', '${d.cutoffTe10MHz.toStringAsFixed(0)} MHz'),
      infoLine('TE20 cutoff', '${d.cutoffTe20MHz.toStringAsFixed(0)} MHz'),
      infoLine(
          'Guide wavelength',
          d.propagates
              ? '${d.guideWavelengthMm.toStringAsFixed(1)} mm'
              : '— (below cutoff)'),
      const SizedBox(height: 6),
      modeStatus(),
    ]),
    card('Horn aperture', [
      slider(
        'H-plane width a₁: ${d.apertureAMm.toStringAsFixed(0)} mm',
        p.apertureAMm,
        20,
        900,
        88,
        (v) => update(() => p.apertureAMm = v),
      ),
      slider(
        'E-plane height b₁: ${d.apertureBMm.toStringAsFixed(0)} mm',
        p.apertureBMm,
        20,
        700,
        68,
        (v) => update(() => p.apertureBMm = v),
      ),
      slider(
        'Axial length: ${p.axialLengthMm.toStringAsFixed(0)} mm',
        p.axialLengthMm,
        20,
        1200,
        118,
        (v) => update(() => p.axialLengthMm = v),
      ),
      const SizedBox(height: 4),
      ActionChip(
        label: const Text('Set optimum apertures for this length'),
        onPressed: () => update(() {
          p.apertureAMm = d.optimumAMm;
          p.apertureBMm = d.optimumBMm;
        }),
      ),
      note('Optimum for this axial length: a₁ ≈ '
          '${d.optimumAMm.toStringAsFixed(0)} mm, b₁ ≈ '
          '${d.optimumBMm.toStringAsFixed(0)} mm.'),
    ]),
    card('Phase error', [
      infoLine('s (E-plane)',
          '${d.sPhase.toStringAsFixed(3)}  (optimum 0.250)'),
      infoLine('t (H-plane)',
          '${d.tPhase.toStringAsFixed(3)}  (optimum 0.375)'),
      infoLine('E-plane loss', '${d.ePlaneLossDb.toStringAsFixed(2)} dB'),
      infoLine('H-plane loss', '${d.hPlaneLossDb.toStringAsFixed(2)} dB'),
      const Divider(height: 20),
      infoLine('Aperture efficiency',
          '${(100 * d.apertureEfficiency).toStringAsFixed(1)} %'),
      const SizedBox(height: 6),
      switch (phaseVerdict()) {
        'optimum' => statusOk('Close to an optimum-gain horn: efficiency '
            'lands near the classic 51 %.'),
        'under-flared' => statusWarn('Barely flared — the aperture is clean '
            'but small. A longer flare would buy gain.'),
        _ => statusBad('Over-flared for this axial length: the aperture is '
            'growing but the phase error is eating the gain.'),
      },
      note('The path from the throat to the aperture edge is longer than to '
          'its centre. s and t measure that error in wavelengths, and they '
          'are the reason gain stops following area.'),
    ]),
    card('Feed & matching', [
      slider(
        'Transition resistance: ${p.transitionROhms.toStringAsFixed(0)} Ω',
        p.transitionROhms,
        20,
        120,
        50,
        (v) => update(() => p.transitionROhms = v),
      ),
      caption('Feedline impedance'),
      feedlineSelector(p.feedOhms, (v) => update(() => p.feedOhms = v)),
      const Divider(height: 20),
      infoLine('Feedpoint R', '${d.feedpointROhms.toStringAsFixed(1)} Ω'),
      infoLine('SWR at center',
          d.propagates ? '${d.centerSwr.toStringAsFixed(2)} : 1' : 'off scale'),
      infoLine(
        '2:1 bandwidth',
        d.propagates
            ? '${formatBandwidth(d.bandwidth2to1MHz)} '
                '(${(100 * d.bandwidth2to1MHz / d.centerFrequencyMHz).toStringAsFixed(0)} %)'
            : '— (below cutoff)',
      ),
      note('The coax-to-guide probe is what the SWR plot is showing; the '
          'wall on the left is the guide approaching cutoff.'),
    ]),
    card('Computed summary', [
      infoLine('Gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
      infoLine('HPBW azimuth (H)', '${d.hpbwAzDeg.toStringAsFixed(1)}°'),
      infoLine('HPBW elevation (E)', '${d.hpbwElDeg.toStringAsFixed(1)}°'),
      infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(0)} dB'),
      const Divider(height: 20),
      dataTable([
        dataRow('Dimension', 'Value (mm)', bold: true),
        dataRow('Guide a × b',
            '${d.guideAMm.toStringAsFixed(1)} × ${d.guideBMm.toStringAsFixed(1)}'),
        dataRow('Aperture a₁ × b₁',
            '${d.apertureAMm.toStringAsFixed(0)} × ${d.apertureBMm.toStringAsFixed(0)}'),
        dataRow('Axial length', p.axialLengthMm.toStringAsFixed(0)),
        dataRow('ρ_E',
            d.rhoEMm.isFinite ? d.rhoEMm.toStringAsFixed(0) : '∞'),
        dataRow('ρ_H',
            d.rhoHMm.isFinite ? d.rhoHMm.toStringAsFixed(0) : '∞'),
      ]),
    ]),
  ];
}

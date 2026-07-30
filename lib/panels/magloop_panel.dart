import 'package:flutter/material.dart';

import '../antenna_design.dart';
import '../magloop_model.dart';
import '../ui_kit.dart';

List<Widget> magLoopCards(
    MagLoopParameters p, MagLoopDesign d, Update update) {
  return [
    card('Frequency', [
      freqSlider(p.frequencyMHz, (f) => update(() => p.frequencyMHz = f),
          fMin: 1.8, fMax: 60),
      bandChips(
        (f) => update(() => p.frequencyMHz = f),
        bands: const [3.6, 7.1, 10.12, 14.2, 21.2, 28.5],
      ),
      const SizedBox(height: 8),
      infoLine('Wavelength', '${d.wavelengthM.toStringAsFixed(2)} m'),
      infoLine('Circumference',
          '${d.circumferenceM.toStringAsFixed(3)} m (${d.circumferenceWl.toStringAsFixed(3)} λ)'),
      const SizedBox(height: 6),
      if (d.tooLarge)
        statusWarn('Circumference is past a quarter wavelength — the '
            'small-loop equations flatter this design.')
      else
        statusOk('Comfortably inside the small-loop regime.'),
    ]),
    card('Loop dimensions', [
      slider(
        'Loop diameter: ${p.loopDiameterM.toStringAsFixed(2)} m',
        p.loopDiameterM,
        0.3,
        3.0,
        54,
        (v) => update(() => p.loopDiameterM = v),
      ),
      slider(
        'Conductor diameter: ${p.conductorDiameterMm.toStringAsFixed(0)} mm',
        p.conductorDiameterMm,
        4,
        60,
        56,
        (v) => update(() => p.conductorDiameterMm = v),
      ),
      const SizedBox(height: 6),
      caption('Conductor'),
      choices<LoopConductor>(LoopConductor.values, p.conductor, (c) => c.label,
          (c) => update(() => p.conductor = c)),
      note('Loss goes as the conductor surface, not its cross-section: fat '
          'copper tube is the whole game.'),
    ]),
    card('Tuning capacitor', [
      caption('Capacitor type'),
      choices<TuningCapacitor>(TuningCapacitor.values, p.capacitor,
          (c) => c.label, (c) => update(() => p.capacitor = c)),
      const SizedBox(height: 10),
      infoLine('Loop inductance',
          '${(d.inductanceH * 1e6).toStringAsFixed(2)} µH'),
      infoLine('Loop reactance',
          '${d.inductiveReactance.toStringAsFixed(0)} Ω'),
      infoLine('Tuning capacitance',
          '${d.tuningCapacitancePf.toStringAsFixed(1)} pF'),
      const Divider(height: 20),
      slider(
        'Transmit power: ${p.powerW.toStringAsFixed(0)} W',
        p.powerW,
        5,
        500,
        99,
        (v) => update(() => p.powerW = v),
      ),
      infoLine('Loop current', '${d.loopCurrentA.toStringAsFixed(1)} A'),
      infoLine('Capacitor voltage',
          '${(d.capacitorVoltageV / 1000).toStringAsFixed(2)} kV RMS'),
      const SizedBox(height: 6),
      if (d.capacitorVoltageV > 5000)
        statusBad('Several kV across the capacitor. Vacuum or wide-gap '
            'butterfly only, and keep people away from it.')
      else if (d.capacitorVoltageV > 2000)
        statusWarn('Over 2 kV across the capacitor at this power.')
      else
        statusOk('Capacitor voltage is manageable.'),
    ]),
    card('Loss budget', [
      infoLine('Radiation resistance',
          '${(d.radiationROhms * 1000).toStringAsFixed(1)} mΩ'),
      infoLine('Conductor loss',
          '${(d.conductorLossROhms * 1000).toStringAsFixed(1)} mΩ'),
      infoLine('Capacitor loss',
          '${(d.capacitorLossROhms * 1000).toStringAsFixed(1)} mΩ'),
      const Divider(height: 20),
      infoLine('Efficiency',
          '${(100 * d.efficiency).toStringAsFixed(1)} % (${d.efficiencyDb.toStringAsFixed(1)} dB)'),
      infoLine('Unloaded Q', d.unloadedQ.toStringAsFixed(0)),
      const SizedBox(height: 6),
      if (d.efficiency < 0.10)
        statusBad('Under 10 % efficient — most of the transmitter is warming '
            'the loop. Go bigger, or go up in frequency.')
      else if (d.efficiency < 0.35)
        statusWarn('Efficiency is poor, which is normal for a small loop '
            'well below its comfortable band.')
      else
        statusOk('Respectable efficiency for a small loop.'),
    ]),
    card('Environment', [
      slider(
        p.heightWl == 0
            ? 'Height above ground: free space'
            : 'Height above ground: ${p.heightWl.toStringAsFixed(2)} λ '
                '(${(p.heightWl * d.wavelengthM).toStringAsFixed(2)} m)',
        p.heightWl,
        0,
        1.0,
        40,
        (v) => update(() => p.heightWl = v),
      ),
      note('Perfect ground. A vertically mounted loop is vertically '
          'polarised, so its image adds in phase and it keeps radiating at '
          'low angles.'),
    ]),
    card('Feed & matching', [
      caption('Feedline impedance'),
      feedlineSelector(p.feedOhms, (v) => update(() => p.feedOhms = v)),
      note('The loop itself is a fraction of an ohm; a coupling loop or '
          'gamma rod transforms it up. Assumed critically coupled here.'),
      const Divider(height: 20),
      ...matchSummary(
        feedpointROhms: d.feedpointROhms,
        qFactor: d.qFactor,
        centerSwr: d.centerSwr,
        bandwidthMHz: d.bandwidth2to1MHz,
        referenceMHz: p.frequencyMHz,
        feedpointLabel: 'Matched feedpoint R',
        qLabel: 'Loaded Q',
      ),
      note('Retuning the capacitor is not optional: the 2:1 window is '
          'narrower than most SSB signals.'),
    ]),
    card('Computed summary', [
      infoLine('Gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
      infoLine('Directivity', '${(d.gainDbi - d.efficiencyDb).toStringAsFixed(2)} dBi'),
      infoLine('Pattern', 'Figure-8 in the plane of the loop'),
      infoLine('Polarisation', d.polarization.label),
      infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
    ]),
  ];
}

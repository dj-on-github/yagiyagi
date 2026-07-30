import 'dart:math';

import 'package:flutter/material.dart';

import 'antenna_design.dart';
import 'cantenna_model.dart';
import 'dipole_model.dart';
import 'loop_model.dart';
import 'plots.dart';
import 'yagi_model.dart';

void main() {
  runApp(const YagiApp());
}

class YagiApp extends StatelessWidget {
  const YagiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antenna Designer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      home: const DesignerPage(),
    );
  }
}

class DesignerPage extends StatefulWidget {
  const DesignerPage({super.key});

  @override
  State<DesignerPage> createState() => _DesignerPageState();
}

class _DesignerPageState extends State<DesignerPage> {
  AntennaType _type = AntennaType.yagi;
  final YagiParameters _p = YagiParameters();
  final DipoleParameters _dp = DipoleParameters();
  final LoopParameters _lp = LoopParameters();
  final CantennaParameters _cp = CantennaParameters();
  final ScrollController _leftScroll = ScrollController();
  final ScrollController _rightScroll = ScrollController();

  AntennaDesign get _d => switch (_type) {
        AntennaType.yagi => YagiDesign(_p),
        AntennaType.dipole => DipoleDesign(_dp),
        AntennaType.loop => LoopDesign(_lp),
        AntennaType.waveguide => CantennaDesign(_cp),
      };

  void _update(VoidCallback fn) => setState(fn);

  @override
  void dispose() {
    _leftScroll.dispose();
    _rightScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antenna Designer'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${d.centerFrequencyMHz.toStringAsFixed(1)} MHz · '
                '${switch (_type) {
                  AntennaType.yagi => '${_p.elements} el yagi',
                  AntennaType.dipole => 'dipole',
                  AntennaType.loop => 'loop',
                  AntennaType.waveguide => 'cantenna',
                }} · '
                '${d.gainDbi.toStringAsFixed(1)} dBi',
                style: const TextStyle(fontFeatures: []),
              ),
            ),
          ),
        ],
      ),
      // The settings column (left) and the plot column (right) each get
      // their own vertical scroll bar, so either side can be scrolled
      // independently on smaller laptop screens.
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 340,
              child: Scrollbar(
                controller: _leftScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _leftScroll,
                  padding: const EdgeInsets.only(right: 12),
                  child: _settingsColumn(d),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Scrollbar(
                controller: _rightScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _rightScroll,
                  padding: const EdgeInsets.only(right: 12),
                  child: _plotsColumn(d),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- settings (left) ----------------

  Widget _settingsColumn(AntennaDesign d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card('Antenna type', [
          DropdownButtonFormField<AntennaType>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: AntennaType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (t) {
              if (t != null) _update(() => _type = t);
            },
          ),
        ]),
        if (_type == AntennaType.yagi) ..._yagiCards(YagiDesign(_p)),
        if (_type == AntennaType.dipole) ..._dipoleCards(DipoleDesign(_dp)),
        if (_type == AntennaType.loop) ..._loopCards(LoopDesign(_lp)),
        if (_type == AntennaType.waveguide)
          ..._cantennaCards(CantennaDesign(_cp)),
      ],
    );
  }

  List<Widget> _yagiCards(YagiDesign d) {
    return [
        _card('Design presets', [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _presetChip('2-el short', 2, 0.12),
              _presetChip('3-el portable', 3, 0.16),
              _presetChip('5-el general', 5, 0.18),
              _presetChip('8-el long boom', 8, 0.20),
              _presetChip('10-el contest', 10, 0.22),
            ],
          ),
        ]),
        _card('Frequency & elements', [
          _freqSlider(_p.frequencyMHz,
              (f) => _update(() => _p.frequencyMHz = f)),
          _bandChips((f) => _update(() => _p.frequencyMHz = f)),
          const SizedBox(height: 8),
          _slider(
            'Elements: ${_p.elements}  '
            '(1 reflector, 1 driven, ${d.directors} directors)',
            _p.elements.toDouble(),
            2,
            12,
            10,
            (v) => _update(() => _p.elements = v.round()),
          ),
          _infoLine('Wavelength', '${d.wavelengthM.toStringAsFixed(3)} m'),
          _infoLine('Driven element', '${d.drivenLengthM.toStringAsFixed(3)} m'),
        ]),
        _card('Geometry', [
          _slider(
            'Element spacing: ${_p.spacingWl.toStringAsFixed(2)} λ '
            '(${d.spacingM.toStringAsFixed(3)} m)',
            _p.spacingWl,
            0.08,
            0.30,
            44,
            (v) => _update(() => _p.spacingWl = v),
          ),
          _infoLine('Boom length',
              '${d.boomLengthM.toStringAsFixed(2)} m (${d.boomWl.toStringAsFixed(2)} λ)'),
          _slider(
            'Element diameter: ${_p.elementDiameterMm.toStringAsFixed(0)} mm',
            _p.elementDiameterMm,
            1,
            25,
            48,
            (v) => _update(() => _p.elementDiameterMm = v),
          ),
          _slider(
            'Reflector length: ×${_p.reflectorFactor.toStringAsFixed(3)} '
            '(${d.reflectorLengthM.toStringAsFixed(3)} m)',
            _p.reflectorFactor,
            1.00,
            1.10,
            40,
            (v) => _update(() => _p.reflectorFactor = v),
          ),
          _slider(
            'Director length: ×${_p.directorFactor.toStringAsFixed(3)}',
            _p.directorFactor,
            0.88,
            1.00,
            48,
            (v) => _update(() => _p.directorFactor = v),
          ),
          _slider(
            'Director taper: ${(_p.taper * 100).toStringAsFixed(1)} %/el',
            _p.taper,
            0,
            0.03,
            30,
            (v) => _update(() => _p.taper = v),
          ),
        ]),
        _card('Feed & matching', [
          const Text('Feed system',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 6),
          SegmentedButton<FeedType>(
            segments: FeedType.values
                .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                .toList(),
            selected: {_p.feedType},
            onSelectionChanged: (s) =>
                _update(() => _p.feedType = s.first),
          ),
          const SizedBox(height: 12),
          const Text('Feedline impedance',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 6),
          _feedlineSelector(
              _p.feedOhms, (v) => _update(() => _p.feedOhms = v)),
          const Divider(height: 20),
          _infoLine('Feedpoint R at resonance',
              '${d.feedpointROhms.toStringAsFixed(1)} Ω (before match)'),
          _infoLine(
              'Antenna Q', d.qFactor.toStringAsFixed(1)),
          _infoLine('SWR at center', '${d.centerSwr.toStringAsFixed(2)} : 1'),
          _infoLine(
            '2:1 bandwidth',
            '${d.bandwidth2to1MHz.toStringAsFixed(2)} MHz '
            '(${(100 * d.bandwidth2to1MHz / _p.frequencyMHz).toStringAsFixed(1)} %)',
          ),
        ]),
        _card('Computed summary', [
          _infoLine('Forward gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
          _infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(0)} dB'),
          _infoLine(
              'HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
          _infoLine(
              'HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
          const Divider(height: 20),
          _elementTable(d),
        ]),
    ];
  }

  List<Widget> _dipoleCards(DipoleDesign d) {
    return [
      _card('Frequency', [
        _freqSlider(_dp.frequencyMHz,
            (f) => _update(() => _dp.frequencyMHz = f)),
        _bandChips((f) => _update(() => _dp.frequencyMHz = f)),
        const SizedBox(height: 8),
        _infoLine('Wavelength', '${d.wavelengthM.toStringAsFixed(3)} m'),
        _infoLine('Resonance', '${d.resonanceMHz.toStringAsFixed(2)} MHz'),
      ]),
      _card('Dipole dimensions', [
        _slider(
          'Length factor: ${_dp.lengthFactor.toStringAsFixed(3)} × λ/2  '
          '(total ${d.totalLengthM.toStringAsFixed(3)} m)',
          _dp.lengthFactor,
          0.90,
          1.02,
          48,
          (v) => _update(() => _dp.lengthFactor = v),
        ),
        _slider(
          'Element diameter: ${_dp.diameterMm.toStringAsFixed(0)} mm',
          _dp.diameterMm,
          1,
          25,
          48,
          (v) => _update(() => _dp.diameterMm = v),
        ),
        _infoLine('Each leg', '${d.legLengthM.toStringAsFixed(3)} m'),
      ]),
      _card('Environment', [
        _slider(
          _dp.heightWl == 0
              ? 'Height above ground: free space'
              : 'Height above ground: ${_dp.heightWl.toStringAsFixed(2)} λ '
                  '(${(_dp.heightWl * d.wavelengthM).toStringAsFixed(2)} m)',
          _dp.heightWl,
          0,
          2.0,
          40,
          (v) => _update(() => _dp.heightWl = v),
        ),
        const Text(
          'Perfect ground. Set height above 0 to see ground-reflection '
          'lobes in the elevation plot.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ]),
      _card('Feed & matching', [
        const Text('Feedline impedance',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        _feedlineSelector(
            _dp.feedOhms, (v) => _update(() => _dp.feedOhms = v)),
        const Divider(height: 20),
        _infoLine('Feedpoint R at resonance',
            '${d.feedpointROhms.toStringAsFixed(1)} Ω'),
        _infoLine('Antenna Q', d.qFactor.toStringAsFixed(1)),
        _infoLine('SWR at center', '${d.centerSwr.toStringAsFixed(2)} : 1'),
        _infoLine(
          '2:1 bandwidth',
          '${d.bandwidth2to1MHz.toStringAsFixed(2)} MHz '
          '(${(100 * d.bandwidth2to1MHz / d.resonanceMHz).toStringAsFixed(1)} %)',
        ),
      ]),
      _card('Computed summary', [
        _infoLine('Gain',
            '${d.gainDbi.toStringAsFixed(1)} dBi ${d.overGround ? "(lobe peak over ground)" : "(free space)"}'),
        _infoLine('Pattern', 'Bidirectional (figure-8)'),
        _infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
        _infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
        const Divider(height: 20),
        Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
          children: [
            _row('Dimension', 'Length (m)', bold: true),
            _row('Total length', d.totalLengthM.toStringAsFixed(3)),
            _row('Each leg', d.legLengthM.toStringAsFixed(3)),
          ],
        ),
      ]),
    ];
  }

  List<Widget> _loopCards(LoopDesign d) {
    return [
      _card('Frequency', [
        _freqSlider(_lp.frequencyMHz,
            (f) => _update(() => _lp.frequencyMHz = f)),
        _bandChips((f) => _update(() => _lp.frequencyMHz = f)),
        const SizedBox(height: 8),
        _infoLine('Wavelength', '${d.wavelengthM.toStringAsFixed(3)} m'),
        _infoLine('Resonance', '${d.resonanceMHz.toStringAsFixed(2)} MHz'),
      ]),
      _card('Loop dimensions', [
        const Text('Loop shape',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        SegmentedButton<LoopShape>(
          segments: LoopShape.values
              .map((s) => ButtonSegment(value: s, label: Text(s.label)))
              .toList(),
          selected: {_lp.shape},
          onSelectionChanged: (s) => _update(() => _lp.shape = s.first),
        ),
        const SizedBox(height: 10),
        _slider(
          'Circumference: ${_lp.circumferenceFactor.toStringAsFixed(3)} λ  '
          '(${d.circumferenceM.toStringAsFixed(3)} m)',
          _lp.circumferenceFactor,
          0.95,
          1.10,
          60,
          (v) => _update(() => _lp.circumferenceFactor = v),
        ),
        _slider(
          'Wire diameter: ${_lp.wireDiameterMm.toStringAsFixed(1)} mm',
          _lp.wireDiameterMm,
          0.5,
          10,
          38,
          (v) => _update(() => _lp.wireDiameterMm = v),
        ),
        _infoLine(
          _lp.shape == LoopShape.circular ? 'Loop diameter' : 'Side length',
          '${(_lp.shape == LoopShape.circular ? d.diameterM : d.sideM).toStringAsFixed(3)} m',
        ),
      ]),
      _card('Environment', [
        _slider(
          _lp.heightWl == 0
              ? 'Height above ground: free space'
              : 'Height above ground: ${_lp.heightWl.toStringAsFixed(2)} λ '
                  '(${(_lp.heightWl * d.wavelengthM).toStringAsFixed(2)} m)',
          _lp.heightWl,
          0,
          2.0,
          40,
          (v) => _update(() => _lp.heightWl = v),
        ),
        const Text(
          'Perfect ground, loop center height. Set height above 0 to see '
          'ground-reflection lobes in the elevation plot.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ]),
      _card('Feed & matching', [
        const Text('Feedline impedance',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        _feedlineSelector(
            _lp.feedOhms, (v) => _update(() => _lp.feedOhms = v)),
        const SizedBox(height: 6),
        const Text(
          'A full-wave loop presents ~100-120 Ω, so 75 Ω coax is the '
          'classic direct feed.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const Divider(height: 20),
        _infoLine('Feedpoint R at resonance',
            '${d.feedpointROhms.toStringAsFixed(1)} Ω'),
        _infoLine('Antenna Q', d.qFactor.toStringAsFixed(1)),
        _infoLine('SWR at center', '${d.centerSwr.toStringAsFixed(2)} : 1'),
        _infoLine(
          '2:1 bandwidth',
          '${d.bandwidth2to1MHz.toStringAsFixed(2)} MHz '
          '(${(100 * d.bandwidth2to1MHz / d.resonanceMHz).toStringAsFixed(1)} %)',
        ),
      ]),
      _card('Computed summary', [
        _infoLine('Gain',
            '${d.gainDbi.toStringAsFixed(1)} dBi ${d.overGround ? "(lobe peak over ground)" : "(free space)"}'),
        _infoLine('Pattern', 'Bidirectional (broad figure-8)'),
        _infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
        _infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
        const Divider(height: 20),
        Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
          children: [
            _row('Dimension', 'Length (m)', bold: true),
            _row('Circumference', d.circumferenceM.toStringAsFixed(3)),
            if (_lp.shape == LoopShape.circular)
              _row('Diameter', d.diameterM.toStringAsFixed(3))
            else
              _row('Side length', d.sideM.toStringAsFixed(3)),
          ],
        ),
      ]),
    ];
  }

  List<Widget> _cantennaCards(CantennaDesign d) {
    return [
      _card('Frequency', [
        _freqSlider(_cp.frequencyMHz,
            (f) => _update(() => _cp.frequencyMHz = f)),
        _bandChips(
          (f) => _update(() => _cp.frequencyMHz = f),
          bands: const [433.0, 915.0, 2400.0, 5800.0],
        ),
        const SizedBox(height: 8),
        _infoLine('Wavelength', '${d.wavelengthMm.toStringAsFixed(1)} mm'),
      ]),
      _card('Can dimensions', [
        _slider(
          'Can diameter: ${_cp.canDiameterMm.toStringAsFixed(0)} mm '
          '(${(d.diameterM / d.wavelengthM).toStringAsFixed(2)} λ)',
          _cp.canDiameterMm,
          30,
          300,
          90,
          (v) => _update(() => _cp.canDiameterMm = v),
        ),
        _infoLine('TE11 cutoff', '${d.cutoffTe11MHz.toStringAsFixed(0)} MHz'),
        _infoLine('TM01 cutoff', '${d.cutoffTm01MHz.toStringAsFixed(0)} MHz'),
        _infoLine(
            'Guide wavelength',
            d.propagates
                ? '${d.guideWavelengthMm.toStringAsFixed(1)} mm'
                : '— (below cutoff)'),
        _infoLine(
            'Recommended can length',
            d.propagates
                ? '${d.recommendedCanLengthMm.toStringAsFixed(0)} mm (¾ λg)'
                : '—'),
        const SizedBox(height: 6),
        _modeStatus(d),
      ]),
      _card('Probe feed', [
        _slider(
          'Probe distance from back: '
          '${_cp.probeDistanceFactor.toStringAsFixed(2)} λg'
          '${d.propagates ? ' (${d.probeDistanceMm.toStringAsFixed(1)} mm)' : ''}',
          _cp.probeDistanceFactor,
          0.15,
          0.35,
          40,
          (v) => _update(() => _cp.probeDistanceFactor = v),
        ),
        _slider(
          'Probe length: ${_cp.probeLengthFactor.toStringAsFixed(2)} λ '
          '(${d.probeLengthMm.toStringAsFixed(1)} mm)',
          _cp.probeLengthFactor,
          0.15,
          0.35,
          40,
          (v) => _update(() => _cp.probeLengthFactor = v),
        ),
        const Text(
          'Classic starting point: probe λg/4 from the closed back, '
          'about λ/4 long.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ]),
      _card('Feed & matching', [
        const Text('Feedline impedance',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        _feedlineSelector(
            _cp.feedOhms, (v) => _update(() => _cp.feedOhms = v)),
        const Divider(height: 20),
        _infoLine('Feedpoint R at resonance',
            '${d.feedpointROhms.toStringAsFixed(1)} Ω'),
        _infoLine('Antenna Q', d.qFactor.toStringAsFixed(1)),
        _infoLine('SWR at center',
            d.propagates ? '${d.centerSwr.toStringAsFixed(2)} : 1' : 'off scale'),
        _infoLine(
          '2:1 bandwidth',
          d.propagates
              ? '${d.bandwidth2to1MHz.toStringAsFixed(1)} MHz '
                  '(${(100 * d.bandwidth2to1MHz / d.centerFrequencyMHz).toStringAsFixed(1)} %)'
              : '— (below cutoff)',
        ),
      ]),
      _card('Computed summary', [
        _infoLine('Gain', '${d.gainDbi.toStringAsFixed(1)} dBi'),
        _infoLine('Front / back', '${d.frontToBackDb.toStringAsFixed(0)} dB'),
        _infoLine('HPBW azimuth', '${d.hpbwAzDeg.toStringAsFixed(0)}°'),
        _infoLine('HPBW elevation', '${d.hpbwElDeg.toStringAsFixed(0)}°'),
        const Divider(height: 20),
        Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
          children: [
            _row('Dimension', 'Value', bold: true),
            _row('Can diameter', '${_cp.canDiameterMm.toStringAsFixed(0)} mm'),
            _row(
                'Can length (rec.)',
                d.propagates
                    ? '${d.recommendedCanLengthMm.toStringAsFixed(0)} mm'
                    : '—'),
            _row('Probe from back', '${d.probeDistanceMm.toStringAsFixed(1)} mm'),
            _row('Probe length', '${d.probeLengthMm.toStringAsFixed(1)} mm'),
          ],
        ),
      ]),
    ];
  }

  Widget _modeStatus(CantennaDesign d) {
    if (!d.propagates) {
      return const Text(
        '⚠ Below TE11 cutoff — the waveguide does not propagate at this '
        'frequency. Increase the can diameter or the frequency.',
        style: TextStyle(fontSize: 12, color: Colors.redAccent),
      );
    }
    if (d.overModed) {
      return const Text(
        '⚠ Above TM01 cutoff — the guide is over-moded; pattern and match '
        'will be erratic. Reduce diameter or frequency.',
        style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
      );
    }
    return const Text(
      '✓ Single-mode (TE11) operation.',
      style: TextStyle(fontSize: 12, color: Colors.lightGreenAccent),
    );
  }

  Widget _feedlineSelector(double current, ValueChanged<double> onChanged) {
    return SegmentedButton<double>(
      segments: const [
        ButtonSegment(value: 50.0, label: Text('50 Ω')),
        ButtonSegment(value: 75.0, label: Text('75 Ω')),
      ],
      selected: {current},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }

  Widget _elementTable(YagiDesign d) {
    final rows = <TableRow>[
      _row('Element', 'Length (m)', bold: true),
      _row('Reflector', d.reflectorLengthM.toStringAsFixed(3)),
      _row('Driven', d.drivenLengthM.toStringAsFixed(3)),
    ];
    for (var i = 0; i < d.directors; i++) {
      rows.add(_row('Director ${i + 1}', d.directorLengthM(i).toStringAsFixed(3)));
    }
    return Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
      children: rows,
    );
  }

  TableRow _row(String a, String b, {bool bold = false}) {
    final style = TextStyle(
        fontSize: 12,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: bold ? Colors.white : Colors.white70);
    return TableRow(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(a, style: style)),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(b, style: style, textAlign: TextAlign.right)),
    ]);
  }

  Widget _freqSlider(double valueMHz, ValueChanged<double> onChanged) {
    // Log-scale slider: 30 MHz .. 6000 MHz
    const fMin = 30.0, fMax = 6000.0;
    final t = log(valueMHz / fMin) / log(fMax / fMin);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Center frequency: ${valueMHz.toStringAsFixed(1)} MHz',
            style: const TextStyle(fontSize: 13)),
        Slider(
          value: t.clamp(0.0, 1.0),
          divisions: 200,
          onChanged: (v) =>
              onChanged(fMin * pow(fMax / fMin, v).toDouble()),
        ),
      ],
    );
  }

  Widget _bandChips(
    ValueChanged<double> onSelected, {
    List<double> bands = const [50.0, 145.0, 433.0, 1296.0],
  }) {
    return Wrap(
      spacing: 8,
      children: bands
          .map((f) => ActionChip(
                label: Text('${f.toStringAsFixed(0)} MHz'),
                onPressed: () => onSelected(f),
              ))
          .toList(),
    );
  }

  Widget _presetChip(String label, int elements, double spacing) {
    final selected = _p.elements == elements && _p.spacingWl == spacing;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _update(() {
        _p.elements = elements;
        _p.spacingWl = spacing;
      }),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      int divisions, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _infoLine(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(k,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(v,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  // ---------------- plots (right) ----------------

  Widget _plotsColumn(AntennaDesign d) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _plotCard(
          'Horizontal (azimuth) gain pattern',
          'Gain ${d.gainDbi.toStringAsFixed(1)} dBi · '
              'HPBW ${d.hpbwAzDeg.toStringAsFixed(0)}° · '
              'F/B ${d.frontToBackDb.toStringAsFixed(0)} dB',
          340,
          PolarGainPainter(design: d, elevation: false, color: cs.primary),
        ),
        _plotCard(
          'Elevation gain pattern',
          'HPBW ${d.hpbwElDeg.toStringAsFixed(0)}° · '
              'rings at 0 / −10 / −20 / −30 / −40 dB',
          340,
          PolarGainPainter(design: d, elevation: true, color: cs.tertiary),
        ),
        _plotCard(
          'Impedance & SWR vs frequency',
          'SWR ${d.centerSwr.toStringAsFixed(2)}:1 @ '
              '${d.centerFrequencyMHz.toStringAsFixed(1)} MHz · '
              '2:1 BW ${d.bandwidth2to1MHz.toStringAsFixed(2)} MHz',
          300,
          SwrImpedancePainter(design: d),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Simplified parametric model for exploration — verify final '
            'designs in NEC/4nec2 or similar.',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget _plotCard(
      String title, String subtitle, double height, CustomPainter painter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle,
                style:
                    const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 8),
            SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(painter: painter),
            ),
          ],
        ),
      ),
    );
  }
}

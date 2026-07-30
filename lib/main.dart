import 'package:flutter/material.dart';

import 'antenna_design.dart';
import 'cantenna_model.dart';
import 'corner_reflector_model.dart';
import 'dipole_model.dart';
import 'dish_model.dart';
import 'helix_model.dart';
import 'horn_model.dart';
import 'loop_model.dart';
import 'lpda_model.dart';
import 'magloop_model.dart';
import 'moxon_model.dart';
import 'panels.dart';
import 'patch_model.dart';
import 'phased_array_model.dart';
import 'plots.dart';
import 'ui_kit.dart';
import 'vertical_model.dart';
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

  final YagiParameters _yagi = YagiParameters();
  final DipoleParameters _dipole = DipoleParameters();
  final LoopParameters _loop = LoopParameters();
  final CantennaParameters _cantenna = CantennaParameters();
  final VerticalParameters _vertical = VerticalParameters();
  final MagLoopParameters _magLoop = MagLoopParameters();
  final LpdaParameters _lpda = LpdaParameters();
  final DishParameters _dish = DishParameters();
  final HelixParameters _helix = HelixParameters();
  final PatchParameters _patch = PatchParameters();
  final MoxonParameters _moxon = MoxonParameters();
  final HornParameters _horn = HornParameters();
  final PhasedArrayParameters _phased = PhasedArrayParameters();
  final CornerReflectorParameters _corner = CornerReflectorParameters();

  final ScrollController _leftScroll = ScrollController();
  final ScrollController _rightScroll = ScrollController();

  AntennaDesign get _d => switch (_type) {
        AntennaType.yagi => YagiDesign(_yagi),
        AntennaType.dipole => DipoleDesign(_dipole),
        AntennaType.loop => LoopDesign(_loop),
        AntennaType.waveguide => CantennaDesign(_cantenna),
        AntennaType.vertical => VerticalDesign(_vertical),
        AntennaType.magLoop => MagLoopDesign(_magLoop),
        AntennaType.lpda => LpdaDesign(_lpda),
        AntennaType.dish => DishDesign(_dish),
        AntennaType.helix => HelixDesign(_helix),
        AntennaType.patch => PatchDesign(_patch),
        AntennaType.moxon => MoxonDesign(_moxon),
        AntennaType.horn => HornDesign(_horn),
        AntennaType.phasedVerticals => PhasedArrayDesign(_phased),
        AntennaType.cornerReflector => CornerReflectorDesign(_corner),
      };

  /// Settings cards for the currently selected antenna type.
  List<Widget> _typeCards(AntennaDesign d) => switch (_type) {
        AntennaType.yagi => yagiCards(_yagi, d as YagiDesign, _update),
        AntennaType.dipole =>
          dipoleCards(_dipole, d as DipoleDesign, _update),
        AntennaType.loop => loopCards(_loop, d as LoopDesign, _update),
        AntennaType.waveguide =>
          cantennaCards(_cantenna, d as CantennaDesign, _update),
        AntennaType.vertical =>
          verticalCards(_vertical, d as VerticalDesign, _update),
        AntennaType.magLoop =>
          magLoopCards(_magLoop, d as MagLoopDesign, _update),
        AntennaType.lpda => lpdaCards(_lpda, d as LpdaDesign, _update),
        AntennaType.dish => dishCards(_dish, d as DishDesign, _update),
        AntennaType.helix => helixCards(_helix, d as HelixDesign, _update),
        AntennaType.patch => patchCards(_patch, d as PatchDesign, _update),
        AntennaType.moxon => moxonCards(_moxon, d as MoxonDesign, _update),
        AntennaType.horn => hornCards(_horn, d as HornDesign, _update),
        AntennaType.phasedVerticals =>
          phasedArrayCards(_phased, d as PhasedArrayDesign, _update),
        AntennaType.cornerReflector =>
          cornerReflectorCards(_corner, d as CornerReflectorDesign, _update),
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
    final tag = _type == AntennaType.yagi
        ? '${_yagi.elements} el yagi'
        : _type.shortLabel;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antenna Designer'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${formatMHz(d.centerFrequencyMHz)} · $tag · '
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
        card('Antenna type', [
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
        ..._typeCards(d),
      ],
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
              '${d.hpbwAzDeg >= 360 ? "omnidirectional" : "HPBW ${d.hpbwAzDeg.toStringAsFixed(0)}°"} · '
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
              '${formatMHz(d.centerFrequencyMHz)} · '
              '2:1 BW ${formatBandwidth(d.bandwidth2to1MHz)}',
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
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
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

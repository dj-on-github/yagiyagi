import 'dart:math';

import 'package:flutter/material.dart';

/// Signature the settings panels use to push a change back into the page
/// state; it is the page's setState.
typedef Update = void Function(VoidCallback fn);

/// A titled settings card in the left-hand column.
Widget card(String title, List<Widget> children) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}

/// Labelled slider. The label carries the live value, so it doubles as the
/// readout for the parameter.
Widget slider(String label, double value, double min, double max,
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

/// Key on the left, value on the right.
Widget infoLine(String k, String v) {
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

TableRow dataRow(String a, String b, {bool bold = false}) {
  final style = TextStyle(
      fontSize: 12,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: bold ? Colors.white : Colors.white70);
  return TableRow(children: [
    Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(a, style: style)),
    Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(b, style: style, textAlign: TextAlign.right)),
  ]);
}

Widget dataTable(List<TableRow> rows) => Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
      children: rows,
    );

/// Log-scale centre frequency slider.
Widget freqSlider(double valueMHz, ValueChanged<double> onChanged,
    {double fMin = 30.0, double fMax = 6000.0, String label = 'Center frequency'}) {
  final t = log(valueMHz.clamp(fMin, fMax) / fMin) / log(fMax / fMin);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: ${formatMHz(valueMHz)}',
          style: const TextStyle(fontSize: 13)),
      Slider(
        value: t.clamp(0.0, 1.0),
        divisions: 200,
        onChanged: (v) => onChanged(fMin * pow(fMax / fMin, v).toDouble()),
      ),
    ],
  );
}

String formatMHz(double f) => f < 10
    ? '${f.toStringAsFixed(3)} MHz'
    : f < 100
        ? '${f.toStringAsFixed(2)} MHz'
        : '${f.toStringAsFixed(1)} MHz';

/// Quick jump chips for the common bands of whichever antenna is selected.
Widget bandChips(
  ValueChanged<double> onSelected, {
  List<double> bands = const [50.0, 145.0, 433.0, 1296.0],
}) {
  return Wrap(
    spacing: 8,
    runSpacing: 4,
    children: bands
        .map((f) => ActionChip(
              label: Text(f < 100
                  ? '${f.toStringAsFixed(f < 10 ? 3 : 1)} MHz'
                  : '${f.toStringAsFixed(0)} MHz'),
              onPressed: () => onSelected(f),
            ))
        .toList(),
  );
}

Widget feedlineSelector(double current, ValueChanged<double> onChanged) {
  return SegmentedButton<double>(
    segments: const [
      ButtonSegment(value: 50.0, label: Text('50 Ω')),
      ButtonSegment(value: 75.0, label: Text('75 Ω')),
    ],
    selected: {current},
    onSelectionChanged: (s) => onChanged(s.first),
  );
}

/// A small caption above a control.
Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child:
          Text(text, style: const TextStyle(fontSize: 12, color: Colors.white70)),
    );

/// Explanatory small print under a control.
Widget note(String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child:
          Text(text, style: const TextStyle(fontSize: 11, color: Colors.white54)),
    );

Widget statusOk(String text) => Text('✓ $text',
    style: const TextStyle(fontSize: 12, color: Colors.lightGreenAccent));

Widget statusWarn(String text) => Text('⚠ $text',
    style: const TextStyle(fontSize: 12, color: Colors.orangeAccent));

Widget statusBad(String text) => Text('⚠ $text',
    style: const TextStyle(fontSize: 12, color: Colors.redAccent));

/// Segmented button over an enum-like list of choices.
Widget choices<T>(List<T> values, T selected, String Function(T) label,
    ValueChanged<T> onChanged) {
  return SegmentedButton<T>(
    segments: values
        .map((v) => ButtonSegment(value: v, label: Text(label(v))))
        .toList(),
    selected: {selected},
    showSelectedIcon: false,
    onSelectionChanged: (s) => onChanged(s.first),
  );
}

/// Dropdown for choice lists too wide to sit in a segmented button.
Widget dropdown<T>(List<T> values, T selected, String Function(T) label,
    ValueChanged<T> onChanged) {
  return DropdownButtonFormField<T>(
    initialValue: selected,
    isExpanded: true,
    isDense: true,
    style: const TextStyle(fontSize: 13),
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    items: values
        .map((v) => DropdownMenuItem(
            value: v,
            child: Text(label(v), style: const TextStyle(fontSize: 13))))
        .toList(),
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

/// Common feed-and-matching summary shared by every panel.
List<Widget> matchSummary({
  required double feedpointROhms,
  required double qFactor,
  required double centerSwr,
  required double bandwidthMHz,
  required double referenceMHz,
  String feedpointLabel = 'Feedpoint R at resonance',
  String qLabel = 'Antenna Q',
}) {
  return [
    infoLine(feedpointLabel, '${feedpointROhms.toStringAsFixed(1)} Ω'),
    infoLine(qLabel, qFactor.toStringAsFixed(1)),
    infoLine('SWR at center', '${centerSwr.toStringAsFixed(2)} : 1'),
    infoLine(
      '2:1 bandwidth',
      bandwidthMHz <= 0
          ? '— (no 2:1 window)'
          : '${formatBandwidth(bandwidthMHz)} '
              '(${(100 * bandwidthMHz / referenceMHz).toStringAsFixed(1)} %)',
    ),
  ];
}

String formatBandwidth(double mhz) => mhz < 0.1
    ? '${(mhz * 1000).toStringAsFixed(1)} kHz'
    : '${mhz.toStringAsFixed(mhz < 10 ? 3 : 2)} MHz';

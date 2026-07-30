import 'dart:math';

import 'package:flutter/material.dart';

import 'antenna_design.dart';

/// Polar gain plot (azimuth or elevation). 0 dB outer ring, -40 dB center,
/// spokes every 30 degrees, forward direction pointing right.
class PolarGainPainter extends CustomPainter {
  final AntennaDesign design;
  final bool elevation;
  final Color color;

  static const double minDb = -40;

  PolarGainPainter({
    required this.design,
    required this.elevation,
    required this.color,
  });

  double _gain(double angleDeg) =>
      elevation ? design.elevationDb(angleDeg) : design.azimuthDb(angleDeg);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 30;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.14);
    final spokePaint = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.10);

    // dB rings: 0, -10, -20, -30, -40
    for (var db = 0; db >= minDb; db -= 10) {
      final r = radius * (1 + db / -minDb);
      canvas.drawCircle(center, r, ringPaint);
      _text(canvas, Offset(center.dx + 3, center.dy - r - 13),
          db == 0 ? '0 dB' : '$db', 10,
          color: Colors.white60);
    }

    // spokes + angle labels
    for (var a = 0; a < 360; a += 30) {
      final rad = a * pi / 180;
      final dir = Offset(cos(rad), -sin(rad));
      canvas.drawLine(center, center + dir * radius, spokePaint);
      final lp = center + dir * (radius + 16);
      final label = a == 0 ? '0° fwd' : '$a°';
      _text(canvas, lp, label, 10,
          color: Colors.white70, align: TextAlign.center);
    }

    // pattern curve
    final path = Path();
    for (var a = 0; a <= 360; a += 2) {
      final db = _gain(a.toDouble()).clamp(minDb, 0.0);
      final r = radius * (1 + db / -minDb);
      final rad = a * pi / 180;
      final pt = center + Offset(r * cos(rad), -r * sin(rad));
      if (a == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();

    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: 0.22));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color);
  }

  @override
  bool shouldRepaint(PolarGainPainter old) =>
      old.design != design || old.elevation != elevation || old.color != color;
}

/// Rectangular impedance + SWR versus frequency plot.
/// Left axis: SWR (1..8). Right axis: ohms for R and X. Dashed red SWR=2 line.
class SwrImpedancePainter extends CustomPainter {
  final AntennaDesign design;

  SwrImpedancePainter({required this.design});

  static const double swrMax = 8;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 46.0, right = 52.0, top = 30.0, bottom = 34.0;
    final plot = Rect.fromLTRB(
        left, top, size.width - right, size.height - bottom);
    if (plot.width < 40 || plot.height < 40) return;

    final fc = design.centerFrequencyMHz;
    final fMin = fc * 0.88, fMax = fc * 1.12;
    double fx(double f) => plot.left + (f - fMin) / (fMax - fMin) * plot.width;
    double fySwr(double s) =>
        plot.bottom - ((s - 1) / (swrMax - 1)).clamp(0.0, 1.0) * plot.height;

    // sample impedance to find ohms axis range
    var maxOhm = design.feedOhms * 1.5;
    for (var i = 0; i <= 160; i++) {
      final z = design.impedanceAt(fMin + (fMax - fMin) * i / 160);
      maxOhm = max(maxOhm, max(z.r, z.x.abs()));
    }
    maxOhm = (maxOhm / 25).ceil() * 25.0;
    double fyOhm(double o) =>
        plot.bottom - ((o + maxOhm) / (2 * maxOhm)) * plot.height;

    final gridPaint = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.10);

    // frame
    canvas.drawRect(
        plot,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white.withValues(alpha: 0.25));

    // vertical frequency grid (8 divisions)
    for (var i = 0; i <= 8; i++) {
      final f = fMin + (fMax - fMin) * i / 8;
      final x = fx(f);
      canvas.drawLine(
          Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      _text(canvas, Offset(x, plot.bottom + 6), f.toStringAsFixed(1), 10,
          color: Colors.white70, align: TextAlign.center);
    }

    // left SWR axis
    for (var s = 1; s <= swrMax; s++) {
      final y = fySwr(s.toDouble());
      canvas.drawLine(
          Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _text(canvas, Offset(plot.left - 34, y - 6), '$s', 10,
          color: Colors.orangeAccent);
    }
    _text(canvas, Offset(4, plot.top - 22), 'SWR', 11,
        color: Colors.orangeAccent);

    // right ohms axis (symmetric -max..+max so X can go negative)
    for (var i = 0; i <= 4; i++) {
      final o = -maxOhm + 2 * maxOhm * i / 4;
      final y = fyOhm(o);
      _text(canvas, Offset(plot.right + 6, y - 6), o.toStringAsFixed(0), 10,
          color: Colors.lightBlueAccent);
    }
    _text(canvas, Offset(plot.right + 6, plot.top - 22), 'Ω', 11,
        color: Colors.lightBlueAccent);

    // zero-ohms reference for X
    canvas.drawLine(Offset(plot.left, fyOhm(0)), Offset(plot.right, fyOhm(0)),
        Paint()
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.30));

    // SWR = 2:1 threshold
    _dashedLine(canvas, Offset(plot.left, fySwr(2)),
        Offset(plot.right, fySwr(2)), Colors.redAccent.withValues(alpha: 0.6));
    _text(canvas, Offset(plot.right - 40, fySwr(2) - 14), '2:1', 10,
        color: Colors.redAccent);

    // center frequency marker
    _dashedLine(canvas, Offset(fx(fc), plot.top), Offset(fx(fc), plot.bottom),
        Colors.white.withValues(alpha: 0.25));

    // curves
    Path rPath = Path(), xPath = Path(), sPath = Path();
    for (var i = 0; i <= 240; i++) {
      final f = fMin + (fMax - fMin) * i / 240;
      final z = design.impedanceAt(f);
      final s = design.swrAt(f);
      final px = fx(f);
      final rPt = Offset(px, fyOhm(z.r));
      final xPt = Offset(px, fyOhm(z.x));
      final sPt = Offset(px, fySwr(s));
      if (i == 0) {
        rPath.moveTo(rPt.dx, rPt.dy);
        xPath.moveTo(xPt.dx, xPt.dy);
        sPath.moveTo(sPt.dx, sPt.dy);
      } else {
        rPath.lineTo(rPt.dx, rPt.dy);
        xPath.lineTo(xPt.dx, xPt.dy);
        sPath.lineTo(sPt.dx, sPt.dy);
      }
    }

    canvas.save();
    canvas.clipRect(plot);
    canvas.drawPath(
        rPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = Colors.lightBlueAccent);
    canvas.drawPath(
        xPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = Colors.tealAccent);
    canvas.drawPath(
        sPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = Colors.orangeAccent);
    canvas.restore();

    // minimum-SWR marker
    final minS = design.centerSwr;
    canvas.drawCircle(Offset(fx(fc), fySwr(minS)), 4,
        Paint()..color = Colors.orangeAccent);
    _text(canvas, Offset(fx(fc) + 8, fySwr(minS) - 18),
        '${minS.toStringAsFixed(2)}:1', 11,
        color: Colors.orangeAccent);

    // legend
    _legend(canvas, Offset(plot.left + 8, plot.top - 20), Colors.orangeAccent,
        'SWR');
    _legend(canvas, Offset(plot.left + 60, plot.top - 20),
        Colors.lightBlueAccent, 'R (Ω)');
    _legend(canvas, Offset(plot.left + 124, plot.top - 20), Colors.tealAccent,
        'X (Ω)');
  }

  void _legend(Canvas canvas, Offset at, Color color, String label) {
    canvas.drawRect(
        Rect.fromLTWH(at.dx, at.dy + 2, 12, 3), Paint()..color = color);
    _text(canvas, Offset(at.dx + 16, at.dy - 4), label, 11,
        color: Colors.white70);
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Color color) {
    const dash = 6.0, gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    final paint = Paint()
      ..strokeWidth = 1.2
      ..color = color;
    var d = 0.0;
    while (d < total) {
      final end = min(d + dash, total);
      canvas.drawLine(a + dir * d, a + dir * end, paint);
      d = end + gap;
    }
  }

  @override
  bool shouldRepaint(SwrImpedancePainter old) => old.design != design;
}

void _text(Canvas canvas, Offset at, String s, double size,
    {Color color = Colors.white, TextAlign align = TextAlign.left}) {
  final tp = TextPainter(
    text: TextSpan(
        text: s, style: TextStyle(color: color, fontSize: size)),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout();
  var dx = at.dx;
  if (align == TextAlign.center) dx -= tp.width / 2;
  tp.paint(canvas, Offset(dx, at.dy));
}

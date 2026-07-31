import 'dart:math';

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
import 'patch_model.dart';
import 'phased_array_model.dart';
import 'scene3d.dart';
import 'vertical_model.dart';
import 'yagi_model.dart';

// Shared palette. Antennas are mostly aluminium tube, copper wire and
// painted sheet, and keeping the materials consistent between types makes
// the drawings easier to read against each other.
const _metal = Color(0xFFB9C6CE);
const _boomColor = Color(0xFF78868E);
const _copper = Color(0xFFC08A4A);
const _panel = Color(0xFF4E6672);
const _panelEdge = Color(0xFF90A4AE);
const _substrate = Color(0xFF2F6B4F);
const _feedColor = Color(0xFFE0603F);
const _groundColor = Color(0x33546E7A);
const _gridColor = Color(0x66607D8B);

// ---------------------------------------------------------------------------
// Primitive helpers
// ---------------------------------------------------------------------------

/// Any two axes perpendicular to [axis], for sweeping rings and cylinders.
List<Vec3> _basis(Vec3 axis) {
  final a = axis.normalized;
  final helper = a.z.abs() > 0.9 ? sideAxis : upAxis;
  final u = a.cross(helper).normalized;
  return [u, a.cross(u)];
}

void _rod(List<SceneItem> out, Vec3 a, Vec3 b, double radius, Color color) {
  out.add(Tube(a, b, radius, color));
}

/// A rod chopped into pieces. Depth sorting works on whole primitives, so a
/// long rod that passes through a surface - a dish strut, a mast through a
/// ground plane - has to be split before it can be half-hidden.
void _rodSegmented(List<SceneItem> out, Vec3 a, Vec3 b, double radius,
    Color color,
    {int segments = 10}) {
  for (var i = 0; i < segments; i++) {
    out.add(Tube(
      a + (b - a) * (i / segments),
      a + (b - a) * ((i + 1) / segments),
      radius,
      color,
    ));
  }
}

void _polyline(
    List<SceneItem> out, List<Vec3> pts, double radius, Color color) {
  for (var i = 0; i + 1 < pts.length; i++) {
    out.add(Tube(pts[i], pts[i + 1], radius, color));
  }
}

/// A closed ring of tube, optionally broken by a gap at the top for a
/// capacitor or a feedpoint.
void _ring(List<SceneItem> out, Vec3 center, Vec3 axis, double radius,
    double tube, Color color,
    {int segments = 48, double gapDeg = 0, double gapAtDeg = 90}) {
  final b = _basis(axis);
  Vec3 at(double deg) {
    final t = deg * pi / 180;
    return center + b[0] * (radius * cos(t)) + b[1] * (radius * sin(t));
  }

  final half = gapDeg / 2;
  for (var i = 0; i < segments; i++) {
    final d0 = 360 * i / segments, d1 = 360 * (i + 1) / segments;
    if (gapDeg > 0) {
      final delta0 = ((d0 - gapAtDeg + 540) % 360) - 180;
      final delta1 = ((d1 - gapAtDeg + 540) % 360) - 180;
      if (delta0.abs() < half || delta1.abs() < half) continue;
    }
    out.add(Tube(at(d0), at(d1), tube, color));
  }
}

/// A filled disc, as a fan of quads so the depth sort has something to work
/// with when it is seen edge-on.
void _disc(List<SceneItem> out, Vec3 center, Vec3 axis, double radius,
    Color color,
    {int segments = 28, int rings = 3, Color? outline}) {
  final b = _basis(axis);
  Vec3 at(double r, double deg) {
    final t = deg * pi / 180;
    return center + b[0] * (r * cos(t)) + b[1] * (r * sin(t));
  }

  for (var i = 0; i < rings; i++) {
    final r0 = radius * i / rings, r1 = radius * (i + 1) / rings;
    for (var j = 0; j < segments; j++) {
      final d0 = 360 * j / segments, d1 = 360 * (j + 1) / segments;
      out.add(Facet(
        [at(r0, d0), at(r1, d0), at(r1, d1), at(r0, d1)],
        color,
        outline: outline,
      ));
    }
  }
}

/// The open side wall of a cylinder.
void _cylinderWall(List<SceneItem> out, Vec3 a, Vec3 b, double radius,
    Color color,
    {int sides = 24, Color? outline}) {
  final axis = (b - a).normalized;
  final basis = _basis(axis);
  Vec3 at(Vec3 centre, double deg) {
    final t = deg * pi / 180;
    return centre + basis[0] * (radius * cos(t)) + basis[1] * (radius * sin(t));
  }

  for (var i = 0; i < sides; i++) {
    final d0 = 360 * i / sides, d1 = 360 * (i + 1) / sides;
    out.add(Facet(
        [at(a, d0), at(b, d0), at(b, d1), at(a, d1)], color,
        outline: outline));
  }
}

void _quad(List<SceneItem> out, Vec3 p0, Vec3 p1, Vec3 p2, Vec3 p3,
    Color color,
    {Color? outline}) {
  out.add(Facet([p0, p1, p2, p3], color, outline: outline));
}

/// An axis-aligned box, used for waveguide sections and small hardware.
void _box(List<SceneItem> out, Vec3 lo, Vec3 hi, Color color,
    {Color? outline}) {
  Vec3 v(double x, double y, double z) => Vec3(x, y, z);
  final c = [
    v(lo.x, lo.y, lo.z),
    v(hi.x, lo.y, lo.z),
    v(hi.x, hi.y, lo.z),
    v(lo.x, hi.y, lo.z),
    v(lo.x, lo.y, hi.z),
    v(hi.x, lo.y, hi.z),
    v(hi.x, hi.y, hi.z),
    v(lo.x, hi.y, hi.z),
  ];
  const faces = [
    [0, 1, 2, 3],
    [4, 5, 6, 7],
    [0, 1, 5, 4],
    [2, 3, 7, 6],
    [1, 2, 6, 5],
    [3, 0, 4, 7],
  ];
  for (final f in faces) {
    out.add(Facet([c[f[0]], c[f[1]], c[f[2]], c[f[3]]], color,
        outline: outline));
  }
}

/// Ground, as a translucent sheet plus a one-metre-ish grid for scale.
void _ground(List<SceneItem> out, double extent, {double z = 0}) {
  _quad(
    out,
    Vec3(-extent, -extent, z),
    Vec3(extent, -extent, z),
    Vec3(extent, extent, z),
    Vec3(-extent, extent, z),
    _groundColor,
  );
  const divisions = 8;
  for (var i = 0; i <= divisions; i++) {
    final t = -extent + 2 * extent * i / divisions;
    out.add(Wire(Vec3(t, -extent, z), Vec3(t, extent, z), _gridColor));
    out.add(Wire(Vec3(-extent, t, z), Vec3(extent, t, z), _gridColor));
  }
}

/// A short bright stub marking where the feedline attaches.
void _feed(List<SceneItem> out, Vec3 at, Vec3 axis, double size) {
  final a = axis.normalized * size;
  out.add(Tube(at - a, at + a, size * 0.9, _feedColor));
}

/// Mast from the ground up to a horizontal antenna. Segmented because it
/// crosses the ground plane.
void _mast(List<SceneItem> out, Vec3 top, double radius) {
  if (top.z <= 0) return;
  _rodSegmented(out, Vec3(top.x, top.y, 0), top, radius, _boomColor,
      segments: 12);
}

// ---------------------------------------------------------------------------
// Per-type builders
// ---------------------------------------------------------------------------

/// Builds the 3D drawing for whichever antenna is selected. Everything is in
/// metres in the app's world frame: +x boresight, +y across, +z up.
Scene buildScene(AntennaType type, AntennaDesign design) =>
    _finish(_shapeFor(type, design));

/// Post-processing every drawing gets: legible rod thickness and a boresight
/// marker so the view can be tied back to 0 degrees on the polar plots.
Scene _finish(Scene raw) {
  final r = raw.radius;
  final c = raw.center;

  // Antenna tubing is thousands of times thinner than the antenna is long.
  // Drawn to true scale it vanishes, so rods get a floor proportional to the
  // model. Anything already thicker keeps its real diameter.
  final floor = r * 0.006;
  final items = [
    for (final item in raw.items)
      if (item is Tube && item.radius < floor)
        Tube(item.a, item.b, floor, item.color)
      else
        item,
  ];

  // Split into segments so the depth sort can bury the part of the axis that
  // passes behind the antenna.
  const boresight = Color(0x9926A69A);
  final from = c + forwardAxis * (-1.10 * r), to = c + forwardAxis * (1.25 * r);
  const steps = 20;
  for (var i = 0; i < steps; i++) {
    items.add(Wire(
      from + (to - from) * (i / steps),
      from + (to - from) * ((i + 1) / steps),
      boresight,
      decoration: true,
    ));
  }
  for (final s in [1.0, -1.0]) {
    items.add(Wire(to, to + Vec3(-0.09 * r, 0.045 * r * s, 0), boresight,
        decoration: true));
    items.add(Wire(to, to + Vec3(-0.09 * r, 0, 0.045 * r * s), boresight,
        decoration: true));
  }

  return Scene(items,
      note: raw.note,
      preferredYawDeg: raw.preferredYawDeg,
      preferredPitchDeg: raw.preferredPitchDeg);
}

Scene _shapeFor(AntennaType type, AntennaDesign design) => switch (type) {
      AntennaType.yagi => _yagi(design as YagiDesign),
      AntennaType.dipole => _dipole(design as DipoleDesign),
      AntennaType.loop => _loop(design as LoopDesign),
      AntennaType.waveguide => _cantenna(design as CantennaDesign),
      AntennaType.vertical => _vertical(design as VerticalDesign),
      AntennaType.magLoop => _magLoop(design as MagLoopDesign),
      AntennaType.lpda => _lpda(design as LpdaDesign),
      AntennaType.dish => _dish(design as DishDesign),
      AntennaType.helix => _helix(design as HelixDesign),
      AntennaType.patch => _patch(design as PatchDesign),
      AntennaType.moxon => _moxon(design as MoxonDesign),
      AntennaType.horn => _horn(design as HornDesign),
      AntennaType.phasedVerticals =>
        _phasedVerticals(design as PhasedArrayDesign),
      AntennaType.cornerReflector =>
        _cornerReflector(design as CornerReflectorDesign),
    };

Scene _yagi(YagiDesign d) {
  final out = <SceneItem>[];
  final r = d.p.elementDiameterMm / 2000;
  final x0 = -d.boomLengthM / 2; // centre the boom on the origin

  void element(double x, double length) {
    _rod(out, Vec3(x, -length / 2, 0), Vec3(x, length / 2, 0), r, _metal);
  }

  _rod(out, Vec3(x0 - 0.02 * d.wavelengthM, 0, 0),
      Vec3(x0 + d.boomLengthM + 0.02 * d.wavelengthM, 0, 0), r * 1.8,
      _boomColor);

  element(x0, d.reflectorLengthM);
  final drivenX = x0 + d.spacingM;
  element(drivenX, d.drivenLengthM);
  for (var i = 0; i < d.directors; i++) {
    element(x0 + d.spacingM * (2 + i), d.directorLengthM(i));
  }
  _feed(out, Vec3(drivenX, 0, 0), sideAxis, r * 2.2);

  return Scene(out, note: 'Boom along boresight, elements horizontal.');
}

Scene _dipole(DipoleDesign d) {
  final out = <SceneItem>[];
  final r = d.p.diameterMm / 2000;
  final z = d.overGround ? d.p.heightWl * d.wavelengthM : 0.0;
  final half = d.totalLengthM / 2;
  final gap = max(half * 0.02, r);

  _rod(out, Vec3(0, -half, z), Vec3(0, -gap, z), r, _metal);
  _rod(out, Vec3(0, gap, z), Vec3(0, half, z), r, _metal);
  _feed(out, Vec3(0, 0, z), sideAxis, gap);

  if (d.overGround) {
    _mast(out, Vec3(0, 0, z), r * 2);
    _ground(out, max(half * 1.6, z * 1.2));
  }
  return Scene(out,
      note: d.overGround
          ? 'Horizontal, over perfect ground.'
          : 'Free space.');
}

Scene _loop(LoopDesign d) {
  final out = <SceneItem>[];
  final r = d.p.wireDiameterMm / 2000;
  final z = d.overGround ? d.p.heightWl * d.wavelengthM : 0.0;
  final centre = Vec3(0, 0, z);
  // A full-wave loop radiates broadside, so its plane is across boresight.
  if (d.p.shape == LoopShape.circular) {
    _ring(out, centre, forwardAxis, d.diameterM / 2, r, _copper,
        gapDeg: 6, gapAtDeg: 90);
  } else {
    final s = d.sideM / 2;
    final gap = s * 0.05;
    // Three sides continuous, the bottom broken at the centre for the feed.
    _polyline(out, [
      Vec3(0, -s, z - s),
      Vec3(0, -s, z + s),
      Vec3(0, s, z + s),
      Vec3(0, s, z - s),
    ], r, _copper);
    _rod(out, Vec3(0, s, z - s), Vec3(0, gap, z - s), r, _copper);
    _rod(out, Vec3(0, -gap, z - s), Vec3(0, -s, z - s), r, _copper);
  }
  final bottom = d.p.shape == LoopShape.circular
      ? z - d.diameterM / 2
      : z - d.sideM / 2;
  _feed(out, Vec3(0, 0, bottom), sideAxis, r * 3);

  if (d.overGround) {
    _mast(out, Vec3(0, 0, bottom), r * 2.5);
    _ground(out, max(d.circumferenceM * 0.3, z * 1.2));
  }
  return Scene(out, note: 'Loop plane across boresight, fed at the bottom.');
}

Scene _cantenna(CantennaDesign d) {
  final out = <SceneItem>[];
  final radius = d.diameterM / 2;
  // Below cutoff the recommended length is undefined; draw a plausible can
  // so the geometry controls still do something visible.
  final lengthM = d.propagates
      ? d.recommendedCanLengthMm / 1000
      : d.diameterM * 1.5;
  final back = -lengthM / 2, mouth = lengthM / 2;

  // The can is drawn translucent: probe position is the parameter that
  // matters here, and an opaque wall hides it completely.
  _cylinderWall(out, Vec3(back, 0, 0), Vec3(mouth, 0, 0), radius,
      _panel.withValues(alpha: 0.45),
      outline: _panelEdge.withValues(alpha: 0.5));
  _disc(out, Vec3(back, 0, 0), forwardAxis, radius,
      _panel.withValues(alpha: 0.8));

  final probeX = back + (d.propagates ? d.probeDistanceMm / 1000 : lengthM / 4);
  final probeLen = d.probeLengthMm / 1000;
  final probeR = max(radius * 0.03, 0.0008);
  _rod(out, Vec3(probeX, 0, -radius), Vec3(probeX, 0, -radius + probeLen),
      probeR, _copper);
  _box(
    out,
    Vec3(probeX - radius * 0.09, -radius * 0.09, -radius - radius * 0.22),
    Vec3(probeX + radius * 0.09, radius * 0.09, -radius),
    _boomColor,
  );
  _feed(out, Vec3(probeX, 0, -radius), upAxis, probeR * 2.5);

  return Scene(out, note: 'Open end faces boresight; probe near the back.');
}

Scene _vertical(VerticalDesign d) {
  final out = <SceneItem>[];
  final r = d.p.diameterMm / 2000;
  _rod(out, Vec3.zero, Vec3(0, 0, d.radiatorLengthM), r, _metal);
  _feed(out, Vec3(0, 0, r * 3), sideAxis, r * 2);

  // Drawing 120 radials would be a grey disc; show a representative fan.
  const maxDrawn = 24;
  final drawn = min(d.p.radialCount, maxDrawn);
  final droop = d.p.radialDroopDeg * pi / 180;
  final len = d.radialLengthM;
  for (var i = 0; i < drawn; i++) {
    final a = 2 * pi * i / drawn;
    _rod(
      out,
      Vec3.zero,
      Vec3(len * cos(droop) * cos(a), len * cos(droop) * sin(a),
          -len * sin(droop)),
      r * 0.35,
      _copper,
    );
  }
  _ground(out, max(len * 1.4, d.radiatorLengthM * 1.2));

  return Scene(out,
      note: d.p.radialCount > maxDrawn
          ? '$maxDrawn of ${d.p.radialCount} radials drawn.'
          : null);
}

Scene _magLoop(MagLoopDesign d) {
  final out = <SceneItem>[];
  final loopR = d.p.loopDiameterM / 2;
  final tube = d.p.conductorDiameterMm / 2000;
  final z = d.overGround
      ? d.p.heightWl * d.wavelengthM
      : loopR * 1.15;
  final centre = Vec3(0, 0, z);

  // Vertically mounted, edge-on to boresight: the plane holds the x axis.
  _ring(out, centre, sideAxis, loopR, tube, _copper,
      segments: 64, gapDeg: 14, gapAtDeg: 270);

  // Tuning capacitor bridging the gap at the top.
  final capH = loopR * 0.09;
  _box(
    out,
    Vec3(-loopR * 0.14, -tube * 2.5, z + loopR - capH),
    Vec3(loopR * 0.14, tube * 2.5, z + loopR + capH),
    _metal,
    outline: _panelEdge,
  );

  // Coupling loop at the bottom, about a fifth of the main loop.
  _ring(out, Vec3(0, 0, z - loopR * 0.8), sideAxis, loopR * 0.2, tube * 0.4,
      _copper,
      segments: 24, gapDeg: 30, gapAtDeg: 270);
  _feed(out, Vec3(0, 0, z - loopR), sideAxis, tube * 1.5);

  if (d.overGround) _ground(out, max(loopR * 3, z * 1.4));
  return Scene(out, note: 'Vertical loop, capacitor at the top.');
}

Scene _lpda(LpdaDesign d) {
  final out = <SceneItem>[];
  final r = d.p.elementDiameterMm / 2000;
  final boom = d.boomLengthM;
  final gap = max(d.longestElementM * 0.02, r * 2.5);

  // Elements alternate between the two boom conductors - the transposed
  // feeder is what makes a log-periodic work.
  for (var i = 0; i < d.elementCount; i++) {
    final x = d.elementPositionM(i) - boom; // longest at the back
    final half = d.elementLengthM(i) / 2;
    final flip = i.isEven ? 1.0 : -1.0;
    _rod(out, Vec3(x, 0, gap / 2 * flip), Vec3(x, half, gap / 2 * flip), r,
        _metal);
    _rod(out, Vec3(x, 0, -gap / 2 * flip), Vec3(x, -half, -gap / 2 * flip), r,
        _metal);
  }
  _rod(out, Vec3(-boom - gap, 0, gap / 2), Vec3(gap, 0, gap / 2), r * 1.4,
      _boomColor);
  _rod(out, Vec3(-boom - gap, 0, -gap / 2), Vec3(gap, 0, -gap / 2), r * 1.4,
      _boomColor);
  _feed(out, Vec3(gap * 0.6, 0, 0), upAxis, gap * 0.5);

  return Scene(out,
      note: '${d.elementCount} elements, fed at the short end.');
}

Scene _dish(DishDesign d) {
  final out = <SceneItem>[];
  final radius = d.p.diameterM / 2;
  final f = d.focalLengthM;
  const rings = 9, sectors = 28;

  // Paraboloid opening towards +x: vertex at the origin, rim forward.
  Vec3 surface(double rr, double deg) {
    final t = deg * pi / 180;
    return Vec3(rr * rr / (4 * f), rr * cos(t), rr * sin(t));
  }

  for (var i = 0; i < rings; i++) {
    final r0 = radius * i / rings, r1 = radius * (i + 1) / rings;
    for (var j = 0; j < sectors; j++) {
      final d0 = 360 * j / sectors, d1 = 360 * (j + 1) / sectors;
      _quad(out, surface(r0, d0), surface(r1, d0), surface(r1, d1),
          surface(r0, d1), _panel,
          outline: i == rings - 1 ? _panelEdge : null);
    }
  }

  // Feed at the focus, looking back into the dish, on three struts.
  final feedX = f;
  final feedR = radius * d.p.blockagePercent / 100 / 2;
  _cylinderWall(out, Vec3(feedX - feedR * 1.6, 0, 0),
      Vec3(feedX + feedR * 1.6, 0, 0), max(feedR, radius * 0.02), _metal,
      sides: 14, outline: _panelEdge);
  for (var i = 0; i < 3; i++) {
    final a = 2 * pi * i / 3 + pi / 6;
    _rodSegmented(out, surface(radius, a * 180 / pi), Vec3(feedX, 0, 0),
        radius * 0.008, _boomColor);
  }
  _feed(out, Vec3(feedX + feedR * 1.6, 0, 0), forwardAxis, radius * 0.02);

  return Scene(out,
      note: 'Prime focus at ${(f * 100).toStringAsFixed(0)} cm, '
          'feed blockage shown to scale.');
}

Scene _helix(HelixDesign d) {
  final out = <SceneItem>[];
  final coilR = d.turnDiameterM / 2;
  final wire = d.p.conductorDiameterMm / 2000;
  final sense = d.p.sense == WindingSense.rightHand ? 1.0 : -1.0;
  const perTurn = 16;

  _disc(out, Vec3.zero, forwardAxis, d.groundPlaneM / 2, _panel,
      outline: _panelEdge);

  final pts = <Vec3>[];
  final steps = d.p.turns * perTurn;
  for (var i = 0; i <= steps; i++) {
    final t = i / perTurn; // turns completed
    final a = 2 * pi * t * sense;
    pts.add(Vec3(t * d.spacingM, coilR * cos(a), coilR * sin(a)));
  }
  _polyline(out, pts, wire, _copper);

  // Feed leaves the first turn and passes through the reflector.
  _rod(out, pts.first, Vec3(0, coilR, 0), wire, _copper);
  _feed(out, Vec3(0, coilR, 0), forwardAxis, wire * 2);

  return Scene(out,
      note: '${d.p.turns} turns, ${d.p.sense.label.toLowerCase()} wound.');
}

Scene _patch(PatchDesign d) {
  final out = <SceneItem>[];
  final w = d.widthM / 2, l = d.lengthM / 2;
  final h = d.heightM;
  final board = max(w, l) * 1.6;

  // Broadside is +x, so the board lies across boresight: y is the patch
  // width, z its resonant length.
  _quad(out, Vec3(0, -board, -board), Vec3(0, board, -board),
      Vec3(0, board, board), Vec3(0, -board, board), _copper);
  _box(out, Vec3(0, -board, -board), Vec3(h, board, board),
      _substrate.withValues(alpha: 0.55));
  _quad(out, Vec3(h, -w, -l), Vec3(h, w, -l), Vec3(h, w, l), Vec3(h, -w, l),
      _copper,
      outline: _panelEdge);

  // Microstrip feedline running out to the board edge.
  final fw = d.feedLineWidthMm / 2000;
  _quad(out, Vec3(h, -fw, -board), Vec3(h, fw, -board), Vec3(h, fw, -l),
      Vec3(h, -fw, -l), _copper);
  _feed(out, Vec3(h, 0, -board), forwardAxis, fw * 1.5);

  return Scene(out,
      note: 'Patch on ${d.p.substrate.label}, '
          '${d.p.heightMm.toStringAsFixed(2)} mm thick.');
}

Scene _moxon(MoxonDesign d) {
  final out = <SceneItem>[];
  final r = d.p.wireDiameterMm / 2000;
  final z = d.overGround ? d.p.heightWl * d.wavelengthM : 0.0;
  final a = d.widthM / 2, e = d.depthM / 2;
  final xd = e, xr = -e; // driven at the front, reflector behind
  final gap = max(a * 0.02, r);

  // Driven element: straight across the front with tails folded back, split
  // at the centre for the feedpoint.
  _polyline(out, [
    Vec3(xd - d.drivenTailM, -a, z),
    Vec3(xd, -a, z),
    Vec3(xd, -gap, z),
  ], r, _copper);
  _polyline(out, [
    Vec3(xd, gap, z),
    Vec3(xd, a, z),
    Vec3(xd - d.drivenTailM, a, z),
  ], r, _copper);
  _feed(out, Vec3(xd, 0, z), sideAxis, gap);

  // Reflector: one continuous wire, tails folded forwards.
  _polyline(out, [
    Vec3(xr + d.reflectorTailM, -a, z),
    Vec3(xr, -a, z),
    Vec3(xr, a, z),
    Vec3(xr + d.reflectorTailM, a, z),
  ], r, _copper);

  if (d.overGround) {
    _mast(out, Vec3(0, 0, z), r * 3);
    _ground(out, max(a * 2.2, z * 1.2));
  }
  return Scene(out,
      note: 'Tip gap ${(d.gapM * 1000).toStringAsFixed(1)} mm — '
          'the front-to-back control.');
}

Scene _horn(HornDesign d) {
  final out = <SceneItem>[];
  final a = d.guideAMm / 2000, b = d.guideBMm / 2000;
  final a1 = d.apertureAMm / 2000, b1 = d.apertureBMm / 2000;
  final flare = d.p.axialLengthMm / 1000;
  final guide = max(a * 1.6, 0.02);

  // Feed waveguide behind the throat.
  _box(out, Vec3(-guide, -a, -b), Vec3(0, a, b), _panel,
      outline: _panelEdge);

  // Four flare walls from the throat out to the aperture.
  final throat = [
    Vec3(0, -a, -b),
    Vec3(0, a, -b),
    Vec3(0, a, b),
    Vec3(0, -a, b),
  ];
  final mouth = [
    Vec3(flare, -a1, -b1),
    Vec3(flare, a1, -b1),
    Vec3(flare, a1, b1),
    Vec3(flare, -a1, b1),
  ];
  for (var i = 0; i < 4; i++) {
    final j = (i + 1) % 4;
    _quad(out, throat[i], throat[j], mouth[j], mouth[i], _panel,
        outline: _panelEdge);
  }

  // Coax transition probe a quarter guide-wavelength from the back wall.
  final probeX = -guide + guide * 0.35;
  _rod(out, Vec3(probeX, 0, -b), Vec3(probeX, 0, 0), max(b * 0.05, 0.0008),
      _copper);
  _feed(out, Vec3(probeX, 0, -b), upAxis, max(b * 0.07, 0.001));

  return Scene(out,
      note: '${d.p.guide.label} throat, '
          '${d.apertureAMm.toStringAsFixed(0)} × '
          '${d.apertureBMm.toStringAsFixed(0)} mm aperture.');
}

Scene _phasedVerticals(PhasedArrayDesign d) {
  final out = <SceneItem>[];
  final r = d.p.diameterMm / 2000;
  final half = d.spacingM / 2;
  final len = d.element.radiatorLengthM;
  final radial = d.element.radialLengthM;

  // Element 2 is the one towards boresight.
  for (final x in [-half, half]) {
    _rod(out, Vec3(x, 0, 0), Vec3(x, 0, len), r, _metal);
    _feed(out, Vec3(x, 0, r * 3), sideAxis, r * 2);
    const drawn = 12;
    for (var i = 0; i < drawn; i++) {
      final a = 2 * pi * i / drawn;
      _rod(out, Vec3(x, 0, 0),
          Vec3(x + radial * cos(a), radial * sin(a), 0), r * 0.35, _copper);
    }
    // Phasing line back to the network between the elements.
    _rod(out, Vec3(x, 0, r * 3), Vec3(0, 0, r * 3), r * 0.4, _boomColor);
  }
  _box(out, Vec3(-half * 0.12, -half * 0.06, 0),
      Vec3(half * 0.12, half * 0.06, r * 8), _boomColor);
  _ground(out, max(radial * 1.6, half * 2.4));

  return Scene(out,
      note: 'Element 2 towards boresight, '
          '${d.p.phaseDeg.toStringAsFixed(0)}° relative phase.');
}

Scene _cornerReflector(CornerReflectorDesign d) {
  final out = <SceneItem>[];
  final halfAngle = d.p.apex.degrees * pi / 360;
  final side = d.reflectorLengthM;
  final height = max(side, d.drivenLengthM * 1.2);
  final hz = height / 2;
  final wl = d.wavelengthM;

  // Two panels hinged on a vertical apex line at the origin, opening +x.
  for (final s in [1.0, -1.0]) {
    final dir = Vec3(cos(halfAngle), s * sin(halfAngle), 0);
    final tip = dir * side;
    if (d.p.rodSpacingWl <= 0) {
      _quad(out, Vec3(0, 0, -hz), tip + Vec3(0, 0, -hz),
          tip + Vec3(0, 0, hz), Vec3(0, 0, hz), _panel,
          outline: _panelEdge);
    } else {
      // A rod grid, drawn as the real thing: rods parallel to the driven
      // element, held by a frame.
      final spacing = d.p.rodSpacingWl * wl;
      final count = min((side / spacing).floor() + 1, 40);
      final step = side / max(count - 1, 1);
      for (var i = 0; i < count; i++) {
        final at = dir * (step * i);
        _rod(out, at + Vec3(0, 0, -hz), at + Vec3(0, 0, hz), wl * 0.004,
            _metal);
      }
      for (final z in [-hz, hz]) {
        _rod(out, Vec3(0, 0, z), tip + Vec3(0, 0, z), wl * 0.006, _boomColor);
      }
    }
  }

  // Driven dipole on the bisector.
  final dz = d.drivenLengthM / 2;
  final gap = max(dz * 0.03, wl * 0.002);
  final x = d.spacingM;
  final r = wl * 0.005;
  _rod(out, Vec3(x, 0, -dz), Vec3(x, 0, -gap), r, _copper);
  _rod(out, Vec3(x, 0, gap), Vec3(x, 0, dz), r, _copper);
  _feed(out, Vec3(x, 0, 0), forwardAxis, gap);

  // Looked at from the default three-quarter angle one panel is edge-on and
  // the corner reads as a flat sheet; from higher up the V is obvious.
  return Scene(out,
      note: '${d.p.apex.label} corner, driven element '
          '${d.p.spacingWl.toStringAsFixed(2)} λ from the apex.',
      preferredYawDeg: 68,
      preferredPitchDeg: 38);
}

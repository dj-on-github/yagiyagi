import 'dart:math';

import 'package:flutter/material.dart';

/// Minimal 3-vector. The app has no other need for linear algebra, so this
/// stays local rather than pulling in a package.
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  static const zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => sqrt(x * x + y * y + z * z);

  Vec3 get normalized {
    final l = length;
    return l < 1e-12 ? const Vec3(0, 0, 1) : Vec3(x / l, y / l, z / l);
  }

  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;

  @override
  String toString() => '($x, $y, $z)';
}

/// World frame used by every antenna shape:
///   +x is boresight, the direction the polar plots call 0 degrees
///   +y is horizontal, across the boresight
///   +z is up
const Vec3 forwardAxis = Vec3(1, 0, 0);
const Vec3 sideAxis = Vec3(0, 1, 0);
const Vec3 upAxis = Vec3(0, 0, 1);

/// One drawable primitive, already positioned in world space.
sealed class SceneItem {
  const SceneItem();

  /// Used for the back-to-front sort.
  Vec3 get centroid;
  Iterable<Vec3> get points;
}

/// A solid rod of [radius] metres. Drawn as an opaque round-capped stroke,
/// which under a back-to-front sort occludes exactly like a real tube.
class Tube extends SceneItem {
  final Vec3 a, b;
  final double radius;
  final Color color;

  const Tube(this.a, this.b, this.radius, this.color);

  @override
  Vec3 get centroid => (a + b) * 0.5;
  @override
  Iterable<Vec3> get points => [a, b];
}

/// A flat polygon: reflector panels, dish facets, ground planes, horn walls.
class Facet extends SceneItem {
  final List<Vec3> corners;
  final Color color;
  final Color? outline;

  const Facet(this.corners, this.color, {this.outline});

  @override
  Vec3 get centroid {
    var s = Vec3.zero;
    for (final p in corners) {
      s = s + p;
    }
    return s * (1 / corners.length);
  }

  @override
  Iterable<Vec3> get points => corners;

  /// Newell's method, so slightly non-planar quads still shade sensibly.
  Vec3 get normal {
    var n = Vec3.zero;
    for (var i = 0; i < corners.length; i++) {
      final c = corners[i], d = corners[(i + 1) % corners.length];
      n = n +
          Vec3((c.y - d.y) * (c.z + d.z), (c.z - d.z) * (c.x + d.x),
              (c.x - d.x) * (c.y + d.y));
    }
    return n.normalized;
  }
}

/// A hairline of constant screen width: ground grids, dimension guides.
class Wire extends SceneItem {
  final Vec3 a, b;
  final Color color;
  final double width;

  /// Decoration such as the boresight axis, which must not drag the camera
  /// framing around with it.
  final bool decoration;

  const Wire(this.a, this.b, this.color,
      {this.width = 1, this.decoration = false});

  @override
  Vec3 get centroid => (a + b) * 0.5;
  @override
  Iterable<Vec3> get points => [a, b];
}

/// A collection of primitives plus the bounds the camera frames itself with.
class Scene {
  final List<SceneItem> items;

  /// Optional caption, for anything the drawing simplifies.
  final String? note;

  /// Opening viewpoint, where the shared default would land somewhere
  /// unhelpful - edge-on to a reflector panel, say.
  final double? preferredYawDeg;
  final double? preferredPitchDeg;

  Scene(this.items,
      {this.note, this.preferredYawDeg, this.preferredPitchDeg});

  late final List<Vec3> _bounds = _computeBounds();

  List<Vec3> _computeBounds() {
    var lo = const Vec3(1e30, 1e30, 1e30);
    var hi = const Vec3(-1e30, -1e30, -1e30);
    var any = false;
    for (final item in items) {
      if (item is Wire && item.decoration) continue;
      for (final p in item.points) {
        if (!p.isFinite) continue;
        any = true;
        lo = Vec3(min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z));
        hi = Vec3(max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z));
      }
    }
    if (!any) return [const Vec3(-1, -1, -1), const Vec3(1, 1, 1)];
    return [lo, hi];
  }

  Vec3 get low => _bounds[0];
  Vec3 get high => _bounds[1];
  Vec3 get center => (low + high) * 0.5;

  /// Radius of the bounding sphere, never zero.
  double get radius => max((high - low).length / 2, 1e-3);

  Vec3 get size => high - low;
}

/// Orbiting camera. Distance is held as a multiple of the scene radius so
/// that retuning an antenna - which can change every dimension by an order
/// of magnitude - does not throw the framing away.
class Camera {
  final Vec3 target;
  final double distance;
  final double yawDeg;
  final double pitchDeg;
  final double fovDeg;

  const Camera({
    required this.target,
    required this.distance,
    required this.yawDeg,
    required this.pitchDeg,
    this.fovDeg = 40,
  });

  Vec3 get eye {
    final y = yawDeg * pi / 180, p = pitchDeg * pi / 180;
    return target +
        Vec3(cos(p) * cos(y), cos(p) * sin(y), sin(p)) * distance;
  }
}

/// Projects world points to the canvas and answers the depth questions the
/// painter needs.
class _View {
  final Vec3 eye, right, up, forward;
  final double scale;
  final Offset center;
  final double near;

  const _View._(this.eye, this.forward, this.right, this.up, this.scale,
      this.center, this.near);

  factory _View(Camera camera, Size size) {
    final eye = camera.eye;
    final forward = (camera.target - eye).normalized;
    // Pitch is clamped short of straight down, so this cross is never zero.
    final right = upAxis.cross(forward).normalized;
    return _View._(
      eye,
      forward,
      right,
      forward.cross(right),
      (size.height / 2) / tan(camera.fovDeg * pi / 360),
      Offset(size.width / 2, size.height / 2),
      camera.distance * 0.02,
    );
  }

  /// Distance in front of the camera. Anything at or behind [near] is clipped.
  double depth(Vec3 p) => (p - eye).dot(forward);

  Offset? project(Vec3 p) {
    final d = p - eye;
    final z = d.dot(forward);
    if (z <= near) return null;
    return center +
        Offset(d.dot(right) * scale / z, -d.dot(up) * scale / z);
  }

  /// Screen width of a rod of world radius [r] seen at depth [z].
  double widthFor(double r, double z) => 2 * r * scale / z;
}

/// Paints a [Scene] with painter's-algorithm depth sorting, one fixed light
/// and a little distance fog. It is not a general 3D engine: antennas are
/// rods, loops and flat panels, and for those this is enough.
class ScenePainter extends CustomPainter {
  final Scene scene;
  final Camera camera;
  final Color background;

  ScenePainter({
    required this.scene,
    required this.camera,
    required this.background,
  });

  /// Fixed in world space rather than to the camera: shading that changes as
  /// the model turns is most of what sells the third dimension.
  static final Vec3 _light = const Vec3(-0.35, -0.55, 0.75).normalized;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 8 || size.height < 8) return;
    final view = _View(camera, size);

    // Far items first, so nearer ones paint over them.
    final ordered = scene.items.toList()
      ..sort((a, b) => view.depth(b.centroid).compareTo(view.depth(a.centroid)));

    final fogNear = camera.distance - scene.radius;
    final fogSpan = max(2 * scene.radius, 1e-6);

    Color fogged(Color c, double z) {
      final t = ((z - fogNear) / fogSpan).clamp(0.0, 1.0) * 0.55;
      return Color.lerp(c, background, t) ?? c;
    }

    for (final item in ordered) {
      switch (item) {
        case Facet f:
          _paintFacet(canvas, view, f, fogged);
        case Tube t:
          _paintTube(canvas, view, t, fogged);
        case Wire w:
          _paintWire(canvas, view, w, fogged);
      }
    }
  }

  void _paintFacet(Canvas canvas, _View view, Facet f,
      Color Function(Color, double) fogged) {
    final pts = <Offset>[];
    for (final c in f.corners) {
      final p = view.project(c);
      if (p == null) return; // straddles the camera plane; skip the facet
      pts.add(p);
    }
    if (pts.length < 3) return;

    // Two-sided Lambert: open surfaces like a dish or a corner panel are
    // routinely seen from behind.
    final lambert = 0.42 + 0.58 * f.normal.dot(_light).abs();
    final z = view.depth(f.centroid);
    final shaded = Color.from(
      alpha: f.color.a,
      red: f.color.r * lambert,
      green: f.color.g * lambert,
      blue: f.color.b * lambert,
    );

    final path = Path()..addPolygon(pts, true);
    canvas.drawPath(path, Paint()..color = fogged(shaded, z));
    if (f.outline != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = fogged(f.outline!, z),
      );
    }
  }

  void _paintTube(Canvas canvas, _View view, Tube t,
      Color Function(Color, double) fogged) {
    final a = view.project(t.a), b = view.project(t.b);
    if (a == null || b == null) return;
    final z = max(view.depth(t.centroid), view.near);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = fogged(t.color, z)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = view.widthFor(t.radius, z).clamp(1.0, 400.0),
    );
  }

  void _paintWire(Canvas canvas, _View view, Wire w,
      Color Function(Color, double) fogged) {
    final a = view.project(w.a), b = view.project(w.b);
    if (a == null || b == null) return;
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = fogged(w.color, view.depth(w.centroid))
        ..strokeWidth = w.width,
    );
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.scene != scene ||
      old.camera != camera ||
      old.background != background;
}

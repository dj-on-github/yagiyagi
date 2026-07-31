import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'scene3d.dart';

/// Interactive 3D view of the selected antenna.
///
/// Left-drag orbits, right-drag (or shift-drag) pans, the wheel zooms and a
/// double-click puts it back. Wheel events inside the panel are claimed for
/// zooming, so the page does not scroll out from under the pointer; outside
/// it they scroll the column as usual.
///
/// The camera fits itself to the scene on every
/// frame and zoom is a multiplier on that fit, so retuning an antenna -
/// which can change every dimension by an order of magnitude - keeps the
/// framing rather than throwing the model off the panel.
class AntennaView3d extends StatefulWidget {
  final Scene scene;

  /// Changing this resets the view; it is the antenna type, so switching
  /// antennas reframes but moving a slider does not.
  final Object framingKey;

  const AntennaView3d({
    super.key,
    required this.scene,
    required this.framingKey,
  });

  @override
  State<AntennaView3d> createState() => _AntennaView3dState();
}

class _AntennaView3dState extends State<AntennaView3d> {
  static const _defaultYaw = 52.0;
  static const _defaultPitch = 22.0;
  static const _fovDeg = 40.0;

  /// Fraction of the panel the antenna should fill when framed.
  static const _fill = 0.88;

  double _yaw = _defaultYaw;
  double _pitch = _defaultPitch;

  /// Multiplier on the automatically fitted camera distance, so 1.0 always
  /// means "framed", whatever the antenna's shape or size.
  double _zoom = 1.0;

  /// Accumulated pan, in screen pixels.
  Offset _pan = Offset.zero;

  Offset? _lastDrag;
  bool _panning = false;

  /// Live pointers, so a two-finger pinch works on a touch screen.
  final Map<int, Offset> _touches = {};
  double? _pinchStart;
  double? _pinchZoom;

  @override
  void didUpdateWidget(AntennaView3d old) {
    super.didUpdateWidget(old);
    if (old.framingKey != widget.framingKey) _reset();
  }

  void _reset() {
    setState(() {
      _yaw = widget.scene.preferredYawDeg ?? _defaultYaw;
      _pitch = widget.scene.preferredPitchDeg ?? _defaultPitch;
      _zoom = 1.0;
      _pan = Offset.zero;
    });
  }

  @override
  void initState() {
    super.initState();
    _yaw = widget.scene.preferredYawDeg ?? _defaultYaw;
    _pitch = widget.scene.preferredPitchDeg ?? _defaultPitch;
  }

  void _orbit(Offset delta) {
    setState(() {
      _yaw = (_yaw - delta.dx * 0.4) % 360;
      // Stop short of the poles: the camera's up vector is undefined there.
      _pitch = (_pitch + delta.dy * 0.4).clamp(-88.0, 88.0);
    });
  }

  void _panBy(Offset delta) {
    setState(() => _pan += delta);
  }

  void _zoomBy(double factor) {
    setState(() => _zoom = (_zoom * factor).clamp(0.15, 8.0));
  }

  void _onPointerDown(PointerDownEvent e) {
    _touches[e.pointer] = e.position;
    if (_touches.length == 2) {
      final p = _touches.values.toList();
      _pinchStart = (p[0] - p[1]).distance;
      _pinchZoom = _zoom;
      _lastDrag = null;
      return;
    }
    _lastDrag = e.position;
    _panning =
        e.buttons & kSecondaryButton != 0 ||
        e.buttons & kMiddleMouseButton != 0 ||
        HardwareKeyboard.instance.isShiftPressed;
  }

  void _onPointerMove(PointerMoveEvent e) {
    _touches[e.pointer] = e.position;

    if (_touches.length >= 2 && _pinchStart != null) {
      final p = _touches.values.toList();
      final spread = (p[0] - p[1]).distance;
      if (spread > 1 && _pinchStart! > 1) {
        setState(
          () => _zoom = (_pinchZoom! * _pinchStart! / spread).clamp(0.15, 8.0),
        );
      }
      return;
    }

    final last = _lastDrag;
    if (last == null) return;
    final delta = e.position - last;
    _lastDrag = e.position;
    if (_panning) {
      _panBy(delta);
    } else {
      _orbit(delta);
    }
  }

  void _onPointerUp(PointerEvent e) {
    _touches.remove(e.pointer);
    if (_touches.length < 2) {
      _pinchStart = null;
      _pinchZoom = null;
    }
    if (_touches.isEmpty) _lastDrag = null;
  }

  /// Cumulative pinch scale within the current trackpad gesture.
  double _panZoomScale = 1.0;

  void _onPanZoomStart(PointerPanZoomStartEvent e) => _panZoomScale = 1.0;

  /// macOS delivers trackpad gestures as pan/zoom pointer events rather than
  /// scroll signals. The web build turns the same trackpad into DOM wheel
  /// events, which is why the wheel path alone worked there and nowhere else.
  void _onPanZoomUpdate(PointerPanZoomUpdateEvent e) {
    if (e.panDelta.dy != 0) {
      // panDelta follows the fingers, scrollDelta opposes them; negate so a
      // two-finger scroll zooms the same way the wheel does.
      _zoomBy(exp(-e.panDelta.dy * 0.0016));
    }
    if (e.scale > 0 && (e.scale - _panZoomScale).abs() > 1e-6) {
      _zoomBy(_panZoomScale / e.scale);
      _panZoomScale = e.scale;
    }
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent && e is! PointerScaleEvent) return;
    // Claim the event, or the surrounding scroll view acts on it as well and
    // the panel scrolls away while it zooms. The resolver calls only the
    // first handler to register, and this Listener is deeper in the hit-test
    // path than the Scrollable, so it registers first.
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      if (event is PointerScrollEvent) {
        _zoomBy(exp(event.scrollDelta.dy * 0.0016));
      } else if (event is PointerScaleEvent) {
        // Trackpad pinch: a scale above 1 means closer, so shorter camera
        // distance.
        _zoomBy(1 / event.scale.clamp(0.2, 5.0));
      }
    });
  }

  /// Camera distance that frames the scene's projected extent, rather than
  /// its bounding sphere. A Yagi is a wide flat object and a helix a long
  /// thin one; fitting the sphere would leave either one lost in the panel.
  double _fitDistance(Scene scene, Size size, Vec3 right, Vec3 up, Vec3 fwd) {
    final c = scene.center, lo = scene.low, hi = scene.high;
    var maxRight = 1e-9, maxUp = 1e-9, maxDepth = 0.0;
    for (final x in [lo.x, hi.x]) {
      for (final y in [lo.y, hi.y]) {
        for (final z in [lo.z, hi.z]) {
          final d = Vec3(x, y, z) - c;
          maxRight = max(maxRight, d.dot(right).abs());
          maxUp = max(maxUp, d.dot(up).abs());
          maxDepth = max(maxDepth, d.dot(fwd).abs());
        }
      }
    }
    final tanHalf = tan(_fovDeg * pi / 360);
    final byHeight = maxUp / (_fill * tanHalf);
    final byWidth = size.width < 1
        ? byHeight
        : maxRight * size.height / (_fill * size.width * tanHalf);
    // Back off by the depth half-extent so the nearest part stays in front
    // of the camera.
    return max(byHeight, byWidth) + maxDepth;
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final background = Theme.of(context).colorScheme.surface;

    final yawRad = _yaw * pi / 180, pitchRad = _pitch * pi / 180;
    final eyeDir = Vec3(
      cos(pitchRad) * cos(yawRad),
      cos(pitchRad) * sin(yawRad),
      sin(pitchRad),
    );
    final forward = -eyeDir;
    final right = upAxis.cross(forward).normalized;
    final up = forward.cross(right);

    return ClipRect(
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        onPointerSignal: _onPointerSignal,
        onPointerPanZoomStart: _onPanZoomStart,
        onPointerPanZoomUpdate: _onPanZoomUpdate,
        child: GestureDetector(
          onDoubleTap: _reset,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final distance =
                    _fitDistance(scene, size, right, up, forward) * _zoom;
                // Pan is held in pixels, so it has to be converted with the
                // same scale the projection uses.
                final worldPerPixel = size.height < 1
                    ? 0.0
                    : 2 * distance * tan(_fovDeg * pi / 360) / size.height;
                final target =
                    scene.center -
                    right * (_pan.dx * worldPerPixel) +
                    up * (_pan.dy * worldPerPixel);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ScenePainter(
                          scene: scene,
                          camera: Camera(
                            target: target,
                            distance: distance,
                            yawDeg: _yaw,
                            pitchDeg: _pitch,
                            fovDeg: _fovDeg,
                          ),
                          background: background,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        tooltip: 'Reset view',
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.center_focus_strong),
                        onPressed: _reset,
                      ),
                    ),
                    Positioned(
                      left: 6,
                      bottom: 4,
                      child: Text(
                        _dimensions(scene),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Overall size of the drawing, so the view carries some sense of scale.
  static String _dimensions(Scene scene) {
    final s = scene.size;
    String fmt(double m) => m >= 1
        ? '${m.toStringAsFixed(2)} m'
        : '${(m * 1000).toStringAsFixed(0)} mm';
    return 'extent  ${fmt(s.x)} × ${fmt(s.y)} × ${fmt(s.z)}';
  }
}

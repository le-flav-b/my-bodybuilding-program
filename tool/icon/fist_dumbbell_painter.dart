import 'package:material_ui/material_ui.dart';

/// The app icon: a fist gripping a dumbbell, flat, with no outlines.
///
/// The hand is the first app's icon, measured on its 512 px PNG
/// (`legacy/some_previous_app_assets/drawable-v24/icon.png`): thumb block on
/// the left with its tip over the index finger, finger tops stepping down
/// to the little finger, knuckle line, curved thumb line, diagonal wrist and
/// wrist crease. It is narrowed to 85 % and enlarged by 8 % around the bar.
/// Its black lines became transparent gaps, which also separate the hand
/// from the dumbbell, so the drawing reads when Android tints it in one
/// colour (monochrome layer). Paint it on a coloured background and the gaps
/// show that colour.
///
/// The drawing fills the painter's width (its height is about 0.78 of it)
/// and is centred on its box.
class FistDumbbellPainter extends CustomPainter {
  const new({required this.dumbbell, required this.fist});

  final Color dumbbell;
  final Color fist;

  /// Width of the gaps, in 512 px units.
  static const double gap = 10;

  static const double _handNarrow = 0.85;
  static const double _handSize = 1.08;

  /// Moves the hand left so its wrist lines up with the dumbbell's middle.
  static const double _handShift = -6;

  static RRect _box(double l, double t, double r, double b, double radius) =>
      RRect.fromLTRBR(l, t, r, b, Radius.circular(radius));

  /// Ends under the outer plates (no sliver of bar past them).
  static final RRect _bar = _box(40, 203, 471, 238, 12);
  static final List<RRect> _plates = [
    _box(30.5, 158, 63, 283, 16),
    _box(448, 158, 480.5, 283, 16),
    _box(70.5, 108, 118, 333, 22),
    _box(393, 108, 440.5, 333, 22),
  ];

  /// The drawing's bounds in 512 px units: the dumbbell's span as chosen
  /// in the proposals (x 18..493) and the scaled hand's wrist at the bottom.
  static Rect get bounds {
    final cy = _bar.center.dy;
    return Rect.fromLTRB(18, 108, 493, cy + (460 - cy) * _handSize);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final box = bounds;
    final cy = _bar.center.dy;
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..translate(size.width / 2, size.height / 2)
      ..scale(size.width / box.width)
      ..translate(-box.center.dx, -box.center.dy);

    Paint ring(double width) => Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round;

    // Dumbbell: the bar, then the plates, each cut out of what is under it.
    final dumbbellPaint = Paint()..color = dumbbell;
    canvas.drawRRect(_bar, dumbbellPaint);
    for (final plate in _plates) {
      canvas
        ..drawRRect(plate, ring(gap * 1.6))
        ..drawRRect(plate, dumbbellPaint);
    }

    // The hand, in the first icon's coordinates, narrowed and enlarged
    // around the middle of the bar.
    const scale = _handNarrow * _handSize;
    canvas
      ..save()
      ..translate(255.5 + _handShift, cy)
      ..scale(scale, _handSize)
      ..translate(-255.5, -cy);
    final silhouette = _handSilhouette();
    canvas
      ..drawPath(silhouette, ring(gap * 1.6 / scale))
      ..drawPath(silhouette, Paint()..blendMode = BlendMode.clear)
      ..drawPath(silhouette, Paint()..color = fist);

    // The first icon's inner lines, as gaps (kept as wide as the others
    // although the hand is narrowed).
    final line = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = gap / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (x, top, bottom) in const [
      (239.5, 150.0, 182.5), // index | middle, above the thumb tip
      (239.5, 214.5, 247.0), // index | middle, below the thumb tip
      (271.5, 152.0, 247.0), // middle | ring
      (303.5, 168.0, 247.0), // ring | little
    ]) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), line);
    }
    canvas
      // Knuckles: the bottom of the fingers.
      ..drawLine(const Offset(207.5, 247), const Offset(350, 247), line)
      // The thumb: its tip over the index finger, then its edge curling
      // into the palm.
      ..drawPath(
        Path()
          ..moveTo(200, 182.5)
          ..lineTo(239.5, 182.5)
          ..lineTo(239.5, 214.5)
          ..lineTo(207.5, 214.5)
          ..lineTo(207.5, 247)
          ..cubicTo(232, 252, 252, 266, 255.5, 300),
        line,
      )
      // Wrist crease.
      ..drawLine(const Offset(190, 344), const Offset(243, 344), line)
      ..restore()
      ..restore();
  }

  /// Thumb block, four fingers, palm (narrowing diagonally) and wrist.
  static Path _handSilhouette() {
    final palm = Path()
      ..moveTo(168, 240)
      ..lineTo(343, 240)
      ..lineTo(343, 282)
      ..lineTo(327, 334)
      ..lineTo(200, 334)
      ..lineTo(168, 282)
      ..close();
    final parts = <Path>[
      // Thumb: its top edge continues the line under the index fingertip
      // (182.5 + gap / 2), as in the first icon.
      Path()..addRRect(_box(168, 187.5, 247, 300, 20)), // thumb
      Path()..addRRect(_box(200, 143, 247, 256, 23.5)), // index
      Path()..addRRect(_box(232, 143, 279, 256, 23.5)), // middle
      Path()..addRRect(_box(264, 158, 311, 256, 23.5)), // ring
      Path()..addRRect(_box(296, 173, 343, 256, 23.5)), // little
      palm,
      Path()..addRRect(_box(200, 320, 327, 460, 10)), // wrist
    ];
    return parts
        .skip(1)
        .fold(
          parts.first,
          (shape, part) => Path.combine(PathOperation.union, shape, part),
        );
  }

  @override
  bool shouldRepaint(FistDumbbellPainter oldDelegate) =>
      oldDelegate.dumbbell != dumbbell || oldDelegate.fist != fist;
}

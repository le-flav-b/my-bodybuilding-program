import 'package:material_ui/material_ui.dart';

/// The app icon: a fist gripping a dumbbell, flat, with no outlines.
///
/// Drawn in a 100 × 100 box scaled to the canvas. The dumbbell is drawn
/// first; the fist is cut out of it with a thin transparent gap, and the
/// thumb and fingers are separated the same way, so the drawing still reads
/// when Android tints it in one colour (monochrome layer). Paint it on a
/// coloured background and the gaps show that colour.
class FistDumbbellPainter extends CustomPainter {
  const new({required this.dumbbell, required this.fist, this.background});

  final Color dumbbell;
  final Color fist;

  /// Filled behind the drawing (legacy icon, splash); null = transparent.
  final Color? background;

  /// Width of the gaps that separate the parts, in box units.
  static const double gap = 2.6;

  @override
  void paint(Canvas canvas, Size size) {
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background!);
    }
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..scale(size.width / 100, size.height / 100);

    final dumbbellPaint = Paint()..color = dumbbell;
    final fistPaint = Paint()..color = fist;
    final clear = Paint()..blendMode = BlendMode.clear;
    final clearStroke = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = gap * 2
      ..strokeJoin = StrokeJoin.round;

    // Dumbbell: bar, inner (big) plates, outer (small) plates, end caps.
    RRect rr(double l, double t, double r, double b, double radius) =>
        RRect.fromLTRBR(l, t, r, b, Radius.circular(radius));
    final bar = rr(2.5, 36, 97.5, 43, 2.5);
    final plates = [
      rr(13.5, 17, 22.5, 62, 4.5),
      rr(77.5, 17, 86.5, 62, 4.5),
      rr(5.5, 27, 11.5, 52, 3),
      rr(88.5, 27, 94.5, 52, 3),
    ];
    canvas.drawRRect(bar, dumbbellPaint);
    for (final p in plates) {
      canvas.drawRRect(p, dumbbellPaint);
    }

    // Fist (back of the hand towards me, fingers curled over the bar).
    final fingers = [
      rr(35, 26.5, 42.5, 50, 3.75),
      rr(42.5, 23.5, 50, 50, 3.75),
      rr(50, 24, 57.5, 50, 3.75),
      rr(57.5, 27.5, 65, 50, 3.75),
    ];
    final palm = rr(35, 40, 65, 64, 7);
    final wrist = rr(40.5, 58, 59.5, 90, 2.5);
    final thumb = rr(32.5, 45, 52, 53, 4);

    final hand = Path()..addRRect(palm);
    fingers.forEach(hand.addRRect);
    final silhouette = Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, hand, Path()..addRRect(wrist)),
      Path()..addRRect(thumb),
    );

    // Gap between the fist and the dumbbell, then the fist itself.
    canvas
      ..drawPath(silhouette, clearStroke)
      ..drawPath(silhouette, clear)
      ..drawPath(hand, fistPaint)
      ..drawRRect(wrist, fistPaint);

    // Gaps between the fingers, down to the thumb.
    final line = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = gap * 0.8
      ..strokeCap = StrokeCap.round;
    for (final x in const [42.5, 50.0, 57.5]) {
      canvas.drawLine(Offset(x, 30), Offset(x, 44), line);
    }

    // The thumb, folded across the fingers, with its own gap.
    canvas
      ..drawRRect(thumb.inflate(gap * 0.8), clear)
      ..drawRRect(thumb, fistPaint)
      ..restore();
  }

  @override
  bool shouldRepaint(FistDumbbellPainter oldDelegate) =>
      oldDelegate.dumbbell != dumbbell ||
      oldDelegate.fist != fist ||
      oldDelegate.background != background;
}

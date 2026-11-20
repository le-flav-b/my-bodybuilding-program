import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../screenshots/harness.dart';
import 'fist_dumbbell_painter.dart';

/// Renders the launcher icon layers into `android/app/src/main/res`.
/// Run with `flutter test tool/icon` after changing the icon.
///
/// - `mipmap-*/ic_launcher_foreground.png`: a fist (off-white) gripping a
///   dumbbell (brand yellow) in the 66 dp safe zone of a 108 dp adaptive
///   layer (transparent); also the Android 12+ splash icon.
/// - `mipmap-*/ic_launcher_monochrome.png`: same drawing in white, for
///   themed icons.
/// - `mipmap-*/ic_launcher.png`: legacy 48 dp round square on coral.
/// - `drawable-nodpi/splash_icon.png`: the drawing on a coral circle
///   (pre-12 splash).
/// - `build/icon_preview.png`: a preview sheet (not shipped).
void main() {
  const coral = Color(0xFFF55E42);
  const yellow = Color(0xFFFFC854);
  const offWhite = Color(0xFFFCFCFC);
  const res = 'android/app/src/main/res';
  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  setUpAll(loadAppFonts);

  Future<void> render(
    WidgetTester tester,
    Widget child,
    double logical,
    double ratio,
    String path, {
    double? width,
    double? height,
  }) async {
    final w = width ?? logical;
    final h = height ?? logical;
    tester.view.devicePixelRatio = ratio;
    tester.view.physicalSize = Size(w * ratio, h * ratio);
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(width: w, height: h, child: child),
          ),
        ),
      ),
    );
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  /// The drawing in a [box] dp square, nudged up so the whole figure
  /// (dumbbell on top, wrist below) is centred.
  Widget drawing(
    double box, {
    Color dumbbell = yellow,
    Color fist = offWhite,
    Color? background,
  }) => Center(
    child: Transform.translate(
      offset: Offset(0, -box * 0.035),
      child: SizedBox.square(
        dimension: box,
        child: CustomPaint(
          painter: FistDumbbellPainter(
            dumbbell: dumbbell,
            fist: fist,
            background: background,
          ),
        ),
      ),
    ),
  );

  for (final MapEntry(key: name, value: ratio) in densities.entries) {
    testWidgets('icon $name', (tester) async {
      // Adaptive layers: 108 dp, drawing inside the 66 dp safe zone.
      await render(
        tester,
        drawing(60),
        108,
        ratio,
        '$res/mipmap-$name/ic_launcher_foreground.png',
      );
      await render(
        tester,
        drawing(60, dumbbell: Colors.white, fist: Colors.white),
        108,
        ratio,
        '$res/mipmap-$name/ic_launcher_monochrome.png',
      );
      // Legacy icon: 48 dp round square.
      await render(
        tester,
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: ColoredBox(color: coral, child: drawing(42)),
        ),
        48,
        ratio,
        '$res/mipmap-$name/ic_launcher.png',
      );
    });
  }

  testWidgets('splash icon', (tester) async {
    await render(
      tester,
      ClipOval(
        child: ColoredBox(color: coral, child: drawing(86)),
      ),
      120,
      4,
      '$res/drawable-nodpi/splash_icon.png',
    );
  });

  testWidgets('preview', (tester) async {
    // Not shipped: a sheet to look at the icon as launchers show it.
    Widget masked(ShapeBorder shape, {bool themed = false}) => SizedBox.square(
      dimension: 108,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: ColoredBox(
          color: themed ? const Color(0xFF3B4A36) : coral,
          child: OverflowBox(
            maxWidth: 160,
            maxHeight: 160,
            child: SizedBox.square(
              dimension: 160,
              child: themed
                  ? drawing(
                      60 * 160 / 108,
                      dumbbell: const Color(0xFFD4EAC6),
                      fist: const Color(0xFFD4EAC6),
                    )
                  : drawing(60 * 160 / 108),
            ),
          ),
        ),
      ),
    );
    Widget row(Color background) => ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            masked(const CircleBorder()),
            masked(
              RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            masked(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            masked(const CircleBorder(), themed: true),
            SizedBox.square(
              dimension: 108,
              child: ClipOval(
                child: ColoredBox(color: coral, child: drawing(78)),
              ),
            ),
          ],
        ),
      ),
    );
    await render(
      tester,
      Column(
        children: [
          Expanded(child: row(const Color(0xFFFCFCFC))),
          Expanded(child: row(const Color(0xFF181B1E))),
        ],
      ),
      0,
      3,
      'build/icon_preview.png',
      width: 720,
      height: 312,
    );
  });
}

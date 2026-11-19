import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../screenshots/harness.dart';

/// Renders the launcher icon layers into `android/app/src/main/res`.
/// Run with `flutter test tool/icon` after changing the icon.
///
/// - `mipmap-*/ic_launcher_foreground.png`: white dumbbell in the 66 dp
///   safe zone of a 108 dp adaptive layer (transparent).
/// - `mipmap-*/ic_launcher_monochrome.png`: same glyph, for themed icons.
/// - `mipmap-*/ic_launcher.png`: legacy 48 dp round square.
/// - `drawable/splash_icon.png`: the glyph on a coral circle (pre-12 splash).
void main() {
  const coral = Color(0xFFF55E42);
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
    String path,
  ) async {
    tester.view.devicePixelRatio = ratio;
    tester.view.physicalSize = Size.square(logical * ratio);
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.square(dimension: logical, child: child),
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

  Widget glyph(double size, Color color) => Icon(
    Symbols.fitness_center_rounded,
    size: size,
    fill: 1,
    weight: 600,
    color: color,
  );

  for (final MapEntry(key: name, value: ratio) in densities.entries) {
    testWidgets('icon $name', (tester) async {
      // Adaptive layers: 108 dp, glyph inside the 66 dp safe zone.
      final layer = Center(
        child: Transform.rotate(
          angle: -0.785398,
          child: glyph(56, Colors.white),
        ),
      );
      await render(
        tester,
        layer,
        108,
        ratio,
        '$res/mipmap-$name/ic_launcher_foreground.png',
      );
      await render(
        tester,
        layer,
        108,
        ratio,
        '$res/mipmap-$name/ic_launcher_monochrome.png',
      );
      // Legacy icon: 48 dp round square.
      await render(
        tester,
        DecoratedBox(
          decoration: BoxDecoration(
            color: coral,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: Transform.rotate(
              angle: -0.785398,
              child: glyph(30, Colors.white),
            ),
          ),
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
      DecoratedBox(
        decoration: const BoxDecoration(color: coral, shape: BoxShape.circle),
        child: Center(
          child: Transform.rotate(
            angle: -0.785398,
            child: glyph(64, Colors.white),
          ),
        ),
      ),
      120,
      4,
      '$res/drawable-nodpi/splash_icon.png',
    );
  });
}

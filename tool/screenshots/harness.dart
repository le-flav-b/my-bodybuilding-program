import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';

/// Where the rendered screens go (git-ignored).
const String screenshotDir = 'build/screenshots';

/// The design frame: 412 × 915 dp at 2×, with 24 dp status and gesture bars.
const double _pixelRatio = 2;
const double _bar = 24;

/// Loads every font of the app (Inter, Kameron, icon fonts) so text renders
/// for real instead of with the test font.
Future<void> loadAppFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Sizes the test view like the design's phone frame.
void usePhoneFrame(WidgetTester tester) {
  tester.view.devicePixelRatio = _pixelRatio;
  tester.view.physicalSize = const Size(
    AppSizes.screenWidth * _pixelRatio,
    AppSizes.screenHeight * _pixelRatio,
  );
  tester.view.padding = const FakeViewPadding(
    top: _bar * _pixelRatio,
    bottom: _bar * _pixelRatio,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
}

/// Decodes the images on screen (asset decoding needs real async in tests).
Future<void> precacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pumpAndSettle();
}

/// Writes what is on screen to `build/screenshots/<name>.png`.
Future<void> capture(WidgetTester tester, String name) async {
  await precacheImages(tester);
  final view = tester.binding.renderViews.first;
  // The root layer of the render view holds the whole frame.
  // ignore: invalid_use_of_protected_member
  final layer = view.layer! as OffsetLayer;
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & view.size * _pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$screenshotDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

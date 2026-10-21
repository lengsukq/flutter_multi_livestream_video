import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:multi_video/demo_theme.dart';
import 'package:flutter_test/flutter_test.dart';

const _capture = bool.fromEnvironment('CAPTURE_REALTIME_DESIGN');
final _captureKey = GlobalKey();

Future<void> initializeDesignCapture() async {
  if (!_capture) return;
  for (final (family, files) in [
    (
      RealtimeFonts.body,
      [
        'Onest-Regular.ttf',
        'Onest-Medium.ttf',
        'Onest-SemiBold.ttf',
        'Onest-Bold.ttf',
      ],
    ),
    (
      RealtimeFonts.display,
      ['BricolageGrotesque-Medium.ttf', 'BricolageGrotesque-Bold.ttf'],
    ),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(
        File(
          '../packages/flutter_realtime_design_ui/fonts/$file',
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
  }
  final codeFont = FontLoader('monospace');
  final menlo = File('/System/Library/Fonts/Menlo.ttc');
  codeFont.addFont(
    (menlo.existsSync()
            ? menlo
            : File(
                '../packages/flutter_realtime_design_ui/fonts/Onest-Regular.ttf',
              ))
        .readAsBytes()
        .then(ByteData.sublistView),
  );
  await codeFont.load();
  final icons = FontLoader('MaterialIcons');
  icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

ThemeData designTestTheme() => DemoTheme.themeData();

Widget designCaptureApp(Widget child) =>
    RepaintBoundary(key: _captureKey, child: child);

Future<void> captureDesign(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.pump();
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('../build/design-previews');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

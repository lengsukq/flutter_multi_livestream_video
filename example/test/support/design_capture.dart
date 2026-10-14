import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _capture = bool.fromEnvironment('CAPTURE_REALTIME_DESIGN');
final _captureKey = GlobalKey();

Future<void> initializeDesignCapture() async {
  if (!_capture) return;
  final fontPath = Platform.environment['REALTIME_DESIGN_FONT'];
  if (fontPath == null) return;
  for (final family in ['DesignSystem', 'Ahem']) {
    final loader = FontLoader(family);
    loader.addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons');
  icons.addFont(
    File(
      'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
    ).readAsBytes().then(ByteData.sublistView),
  );
  await icons.load();
}

ThemeData designTestTheme() {
  final theme = RealtimeUiTheme.light();
  return _capture
      ? theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'DesignSystem'),
        )
      : theme;
}

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

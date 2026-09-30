import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

/// Original generated images bundled locally with the demo.
class DemoBackground {
  static final Future<List<MediaBackgroundImagePreset>> presets = Future.wait(
    const <(String, String)>[
      ('office', '办公室'),
      ('library', '书房'),
      ('meeting-room', '会议室'),
      ('living-room', '客厅'),
      ('cafe', '咖啡馆'),
      ('garden', '花园'),
      ('mountains', '山水'),
      ('studio', '简洁蓝色'),
    ].map((entry) async {
      final data = await rootBundle.load(
        'assets/backgrounds/${entry.$1}-preset.png',
      );
      return MediaBackgroundImagePreset(
        id: entry.$1,
        label: entry.$2,
        imageBytes: data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        ),
      );
    }),
  );
}

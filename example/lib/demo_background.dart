import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

/// Original generated images bundled locally with the demo.
class DemoBackground {
  static Future<List<MediaBackgroundImagePreset>> loadPresets({
    bool isZh = true,
  }) => Future.wait(
    [
      ('office', isZh ? '办公室' : 'Office'),
      ('library', isZh ? '书房' : 'Library'),
      ('meeting-room', isZh ? '会议室' : 'Meeting Room'),
      ('living-room', isZh ? '客厅' : 'Living Room'),
      ('cafe', isZh ? '咖啡馆' : 'Cafe'),
      ('garden', isZh ? '花园' : 'Garden'),
      ('mountains', isZh ? '山水' : 'Mountains'),
      ('studio', isZh ? '简洁蓝色' : 'Studio'),
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

  static Future<List<MediaBackgroundImagePreset>> get presets => loadPresets();
}

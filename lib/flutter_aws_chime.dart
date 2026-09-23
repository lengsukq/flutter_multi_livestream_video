import 'flutter_aws_chime_platform_interface.dart';
export 'models/meeting_event.model.dart';
export 'models/meeting.model.dart';
export 'models/message.model.dart';
export 'models/video_tile.model.dart';

class FlutterAwsChime {
  Future<String?> getPlatformVersion() {
    return FlutterAwsChimePlatform.instance.getPlatformVersion();
  }
}

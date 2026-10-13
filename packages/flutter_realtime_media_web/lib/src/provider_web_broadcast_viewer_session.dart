import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'provider_web_session_base.dart';

class ProviderWebBroadcastViewerSession extends ProviderWebSessionBase
    implements BroadcastViewerSession {
  ProviderWebBroadcastViewerSession({
    required super.providerId,
    required super.role,
    required super.sessionId,
    required super.joinPayload,
    required super.capabilities,
  });
}

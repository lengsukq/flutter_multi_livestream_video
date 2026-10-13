import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'provider_web_bridge.dart';
import 'provider_web_profile.dart';
import 'provider_web_join_info.dart';
import 'provider_web_join_info_decoder.dart';
import 'provider_web_browser_capabilities.dart';
import 'provider_web_local_preview_session.dart';
import 'provider_web_participant_session.dart';
import 'provider_web_broadcast_host_session.dart';
import 'provider_web_broadcast_viewer_session.dart';

/// Browser implementation backed by the provider's official JavaScript SDK.
class ProviderWebSessionFactory
    implements
        MediaSessionFactory,
        MediaBackgroundCapabilitiesProvider,
        MediaLocalPreviewFactory {
  ProviderWebSessionFactory(this.providerId)
    : profile = ProviderWebProfile.forProvider(providerId);

  @override
  final String providerId;
  final ProviderWebProfile profile;

  @override
  Set<MediaRole> get supportedRoles => profile.supportedRoles;

  @override
  MediaBackgroundCapabilities backgroundCapabilitiesFor(MediaRole role) {
    if (role == MediaRole.viewer ||
        (!profile.canBlurBackground && !profile.canReplaceBackgroundImage) ||
        !browserSupportsVideoEffects) {
      return const MediaBackgroundCapabilities.none();
    }
    return MediaBackgroundCapabilities(
      canBlur: profile.canBlurBackground,
      canReplaceImage: profile.canReplaceBackgroundImage,
    );
  }

  @override
  ProviderWebJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      ProviderWebJoinInfoDecoder(providerId, profile).decode(json);

  @override
  MediaSession createSession(MediaJoinInfo joinInfo) {
    if (joinInfo is! ProviderWebJoinInfo ||
        joinInfo.providerId != providerId ||
        !supportedRoles.contains(joinInfo.role)) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'The join information does not match the $providerId adapter.',
        providerId: providerId,
      );
    }
    final sessionId =
        '${providerId}_${DateTime.now().microsecondsSinceEpoch}_'
        '${_nextSessionId++}';
    final capabilities = providerWebCapabilities(profile, joinInfo.role);
    return switch (joinInfo.role) {
      MediaRole.participant => ProviderWebParticipantSession(
        providerId: providerId,
        role: joinInfo.role,
        sessionId: sessionId,
        joinPayload: joinInfo.payload,
        capabilities: capabilities,
      ),
      MediaRole.host => ProviderWebBroadcastHostSession(
        providerId: providerId,
        role: joinInfo.role,
        sessionId: sessionId,
        joinPayload: joinInfo.payload,
        capabilities: capabilities,
      ),
      MediaRole.viewer => ProviderWebBroadcastViewerSession(
        providerId: providerId,
        role: joinInfo.role,
        sessionId: sessionId,
        joinPayload: joinInfo.payload,
        capabilities: capabilities,
      ),
    };
  }

  @override
  Future<MediaLocalPreviewSession> createLocalPreview({
    required MediaRole role,
  }) async {
    if (role == MediaRole.viewer) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: '$providerId viewers do not publish local camera video.',
        providerId: providerId,
      );
    }
    final previewId =
        'preview_${providerId}_${DateTime.now().microsecondsSinceEpoch}_'
        '${_nextPreviewId++}';
    final capabilities = providerWebCapabilities(profile, role);
    await ProviderWebBridge.createLocalPreview(
      providerId: providerId,
      previewId: previewId,
      settings: {
        'role': role.wireName,
        'cameraEnabled': false,
        'microphoneEnabled': false,
        'backgroundEffect': {
          'type': MediaBackgroundEffectType.none.name,
          'blurStrength': MediaBackgroundBlurStrength.medium.name,
        },
      },
    );
    return ProviderWebLocalPreviewSession(
      providerId: providerId,
      role: role,
      previewId: previewId,
      capabilities: capabilities,
    );
  }
}

int _nextSessionId = 0;
int _nextPreviewId = 0;

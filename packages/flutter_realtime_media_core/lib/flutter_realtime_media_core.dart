/// Provider-neutral Flutter SDK core for realtime audio/video sessions.
///
/// This package contains no provider SDK dependency. Add an adapter package
/// (`flutter_realtime_media_livekit`, and later Chime/Agora/TRTC/...)
/// and register its `MediaSessionFactory` in a `MediaRegistry`.
library;

export 'src/client/media_backend_client.dart';
export 'src/client/media_backend_config.dart';
export 'src/client/media_backend_error.dart';
export 'src/client/media_backend_transport.dart';
export 'src/client/media_backend_transport_factory.dart';
export 'src/client/media_client.dart';
export 'src/diagnostics/media_doctor.dart';
export 'src/model/media_audio_device.dart';
export 'src/model/media_capabilities.dart';
export 'src/model/media_error.dart';
export 'src/model/media_feature.dart';
export 'src/model/media_identity.dart';
export 'src/model/media_event.dart';
export 'src/model/media_message.dart';
export 'src/model/media_participant.dart';
export 'src/model/media_role.dart';
export 'src/model/media_room_mode.dart';
export 'src/model/media_snapshot.dart';
export 'src/model/media_state.dart';
export 'src/model/media_track.dart';
export 'src/session/broadcast_sessions.dart';
export 'src/session/media_credential_refresh.dart';
export 'src/session/interactive_media_session.dart';
export 'src/session/media_join_info.dart';
export 'src/session/media_room_session.dart';
export 'src/session/media_session.dart';
export 'src/session/media_session_factory.dart';
export 'src/view/media_track_view.dart';

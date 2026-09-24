import 'interactive_media_session.dart';
import 'media_session.dart';

/// One-to-many broadcast host session.
///
/// Publishes audio and video and subscribes to nothing but data messages, so
/// viewers can ask questions without publishing media.
abstract class BroadcastHostSession extends InteractiveMediaSession {}

/// One-to-many broadcast viewer session.
///
/// Deliberately exposes **no** audio/video publish method: the interface is the
/// client-side half of the broadcast guarantee. The other half is the backend:
/// viewer credentials must be issued without publish permission.
abstract class BroadcastViewerSession extends MediaSession
    implements MediaDataMessenger {}

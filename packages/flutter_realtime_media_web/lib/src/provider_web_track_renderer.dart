import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:web/web.dart' as web;

import 'provider_web_bridge.dart';
import 'provider_web_track.dart';

class ProviderWebTrackRenderer extends MediaTrackRenderer {
  const ProviderWebTrackRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) {
    if (track is! ProviderWebVideoTrack) {
      throw ArgumentError.value(
        track,
        'track',
        'ProviderWebTrackRenderer requires a ProviderWebVideoTrack.',
      );
    }
    return _ProviderWebVideoView(track: track);
  }
}

class _ProviderWebVideoView extends StatefulWidget {
  const _ProviderWebVideoView({required this.track});

  final ProviderWebVideoTrack track;

  @override
  State<_ProviderWebVideoView> createState() => _ProviderWebVideoViewState();
}

class _ProviderWebVideoViewState extends State<_ProviderWebVideoView> {
  static int _nextElementId = 0;

  late String _elementId;

  @override
  void initState() {
    super.initState();
    _elementId = 'provider-video-${_nextElementId++}';
  }

  @override
  void didUpdateWidget(covariant _ProviderWebVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.sessionId != widget.track.sessionId ||
        oldWidget.track.id != widget.track.id) {
      _detach(oldWidget.track, _elementId);
      _elementId = 'provider-video-${_nextElementId++}';
      _attach(widget.track, _elementId);
    }
  }

  void _attach(ProviderWebVideoTrack track, String elementId) {
    ProviderWebBridge.attachVideo(
      providerId: track.providerId,
      sessionId: track.sessionId,
      trackId: track.id,
      elementId: elementId,
    ).catchError((_) {});
  }

  void _detach(ProviderWebVideoTrack track, String elementId) {
    ProviderWebBridge.detachVideo(
      providerId: track.providerId,
      sessionId: track.sessionId,
      trackId: track.id,
      elementId: elementId,
    );
  }

  @override
  void dispose() {
    _detach(widget.track, _elementId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (element) {
      final container = element as web.HTMLDivElement;
      container.id = _elementId;
      container.style
        ..width = '100%'
        ..height = '100%'
        ..overflow = 'hidden'
        ..backgroundColor = '#000000';
      _attach(widget.track, _elementId);
    },
  );
}

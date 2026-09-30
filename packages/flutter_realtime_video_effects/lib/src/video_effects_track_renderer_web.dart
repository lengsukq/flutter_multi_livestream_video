import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'processed_video_track.dart';

@JS('globalThis')
external JSObject get _globalThis;

Widget buildProcessedVideoView(ProcessedVideoTrack track) =>
    _ProcessedVideoWebView(track: track);

class _ProcessedVideoWebView extends StatefulWidget {
  const _ProcessedVideoWebView({required this.track});
  final ProcessedVideoTrack track;
  @override
  State<_ProcessedVideoWebView> createState() => _ProcessedVideoWebViewState();
}

class _ProcessedVideoWebViewState extends State<_ProcessedVideoWebView> {
  web.HTMLElement? _element;

  void _attach(web.HTMLElement element) {
    if (!mounted || !_globalThis.has('RealtimeVideoEffectsBridge')) return;
    _element = element;
    element.style.width = '100%';
    element.style.height = '100%';
    final bridge = _globalThis['RealtimeVideoEffectsBridge'] as JSObject;
    // The element exists before Flutter inserts it into the DOM. Pass it
    // directly instead of looking it up by id during that insertion race.
    bridge.callMethod<JSAny?>(
      'attachPreviewElement'.toJS,
      widget.track.source.id.toJS,
      element,
    );
  }

  @override
  void didUpdateWidget(covariant _ProcessedVideoWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.source.id != widget.track.source.id &&
        _element != null) {
      _attach(_element!);
    }
  }

  @override
  void dispose() {
    final video = _element?.querySelector('video') as web.HTMLVideoElement?;
    if (video != null) {
      video.pause();
      video.srcObject = null;
    }
    video?.remove();
    _element = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (element) => _attach(element as web.HTMLElement),
  );
}

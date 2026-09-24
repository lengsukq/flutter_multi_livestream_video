import 'package:flutter/widgets.dart';

import '../model/media_track.dart';

/// Renders a provider video track.
///
/// Adapters implement this and pass it to [MediaTrackView], so shared UI never
/// imports a provider SDK.
abstract class MediaTrackRenderer {
  const MediaTrackRenderer();

  /// Builds the widget that displays [track].
  Widget buildView(BuildContext context, MediaVideoTrack track);
}

/// Displays a [MediaVideoTrack] using a provider [MediaTrackRenderer].
///
/// Renders [placeholder] (or an empty box) when [track] is null, which is the
/// common case for participants that are not publishing video yet.
class MediaTrackView extends StatelessWidget {
  const MediaTrackView({
    super.key,
    required this.renderer,
    this.track,
    this.placeholder,
    this.fit = BoxFit.cover,
  });

  /// Provider renderer, for example `LiveKitTrackRenderer()`.
  final MediaTrackRenderer renderer;

  /// Track to display, or null when nothing is published.
  final MediaVideoTrack? track;

  /// Widget shown while [track] is null.
  final Widget? placeholder;

  /// How the video fills the available space.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final current = track;
    if (current == null) {
      return placeholder ?? const SizedBox.expand();
    }
    return FittedBox(
      fit: fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: current.width > 0 ? current.width.toDouble() : 640,
        height: current.height > 0 ? current.height.toDouble() : 360,
        child: renderer.buildView(context, current),
      ),
    );
  }
}

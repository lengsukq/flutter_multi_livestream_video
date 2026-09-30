import 'package:flutter/widgets.dart';

import '../model/media_track.dart';

/// How a video frame is scaled into the space available to it.
///
/// [cover] fills the whole area and crops the overflow, which is what camera
/// tiles want. [contain] keeps every pixel of the frame and letterboxes the
/// remainder, which is what screen shares want because cropping hides content.
enum MediaVideoFit {
  /// Scale to fill the available area, cropping the part that does not fit.
  cover,

  /// Scale to show the whole frame, adding letterbox bars where needed.
  contain;

  /// Provider-neutral [BoxFit] equivalent.
  BoxFit get boxFit => switch (this) {
    MediaVideoFit.cover => BoxFit.cover,
    MediaVideoFit.contain => BoxFit.contain,
  };

  /// Provider-specific fill/render mode for [fit], when the adapter maps it.
  ///
  /// Values match `fill = 0` and `fit = 1` in the TRTC and AWS Chime SDKs.
  int get nativeFillMode => switch (this) {
    MediaVideoFit.cover => 0,
    MediaVideoFit.contain => 1,
  };
}

/// Renders a provider video track.
///
/// Adapters implement this and pass it to [MediaTrackView], so shared UI never
/// imports a provider SDK.
abstract class MediaTrackRenderer {
  const MediaTrackRenderer();

  /// Builds the widget that displays [track].
  ///
  /// [fit] is the scaling the shared UI asks for. Adapters whose native view
  /// scales the frame itself must honour it, otherwise a screen share is
  /// cropped even though the surrounding layout asked to contain it.
  Widget buildView(
    BuildContext context,
    MediaVideoTrack track, {
    MediaVideoFit fit = MediaVideoFit.cover,
  });
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
    this.fit = MediaVideoFit.cover,
  });

  /// Provider renderer, for example `LiveKitTrackRenderer()`.
  final MediaTrackRenderer renderer;

  /// Track to display, or null when nothing is published.
  final MediaVideoTrack? track;

  /// Widget shown while [track] is null.
  final Widget? placeholder;

  /// How the video fills the available space.
  final MediaVideoFit fit;

  @override
  Widget build(BuildContext context) {
    final current = track;
    if (current == null) {
      return placeholder ?? const SizedBox.expand();
    }
    return FittedBox(
      fit: fit.boxFit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: current.width > 0 ? current.width.toDouble() : 640,
        height: current.height > 0 ? current.height.toDouble() : 360,
        child: renderer.buildView(context, current, fit: fit),
      ),
    );
  }
}

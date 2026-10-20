import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import '../flutter_realtime_sdk_ui.dart';

/// Resolves the same authoritative content for the main stage and its preview.
class MeetingSharedContent {
  MeetingSharedContent({
    required this.room,
    required this.snapshot,
    required bool showClassroom,
  }) : content = room.sharedContent?.content;

  final RealtimeRoom room;
  final MediaSnapshot snapshot;
  final SharedContentState? content;

  SharedContentMode get mode {
    final declared = content?.mode;
    if (declared != null && declared != SharedContentMode.members) {
      return declared;
    }
    return snapshot.contentShareTrack != null ||
            snapshot.localScreenShareEnabled
        ? SharedContentMode.screen
        : SharedContentMode.members;
  }

  bool get active => mode != SharedContentMode.members;

  MediaVideoTrack? get track {
    final candidate = snapshot.contentShareTrack;
    if (content?.mode == SharedContentMode.screen &&
        candidate?.contentOwnerParticipantId != content!.screen.participantId) {
      return null;
    }
    return candidate;
  }

  // Use the authoritative canvas rather than a video-track object so receiving
  // a first frame or replacing a track does not discard a local focus choice.
  (SharedContentMode, String, String) get identity => (
    mode,
    content?.mode == SharedContentMode.screen
        ? content!.screen.participantId
        : mode == SharedContentMode.screen
        ? track?.contentOwnerParticipantId ?? ''
        : '',
    content?.mode == SharedContentMode.screen
        ? content!.screen.canvasId
        : mode == SharedContentMode.screen
        ? track?.id ?? ''
        : '',
  );

  Widget buildMain(BuildContext context, {required bool withAnnotations}) {
    final fallback = RealtimeScreenShareStage(
      placeholder: Center(
        child: Text(
          RealtimeStrings.of(context).isZh
              ? '等待共享画面'
              : 'Waiting for shared screen',
        ),
      ),
    );
    if (content == null || content!.mode == SharedContentMode.members) {
      return fallback;
    }
    return buildRoomSharedContentStage(
          room,
          snapshot,
          withAnnotations: withAnnotations,
          members: fallback,
        ) ??
        fallback;
  }

  Widget get _waiting => const Center(child: Icon(Icons.screen_share_outlined));

  Widget buildPreview({required bool withAnnotations}) {
    final shared = room.sharedContent;
    Widget surface;
    if (mode == SharedContentMode.whiteboard && shared != null) {
      surface = AnnotationSurface(
        session: shared.whiteboard,
        allowEditing: false,
        enableNavigation: false,
        toolbarPlacement: AnnotationToolbarPlacement.none,
        background: const ColoredBox(color: Colors.white),
      );
    } else {
      surface = MediaTrackView(
        renderer: room.renderer,
        track: track,
        placeholder: _waiting,
        fit: BoxFit.contain,
      );
      if (withAnnotations &&
          content?.mode == SharedContentMode.screen &&
          shared != null &&
          track != null) {
        surface = AnnotationSurface(
          session: shared.screenAnnotations,
          allowEditing: false,
          enableNavigation: false,
          toolbarPlacement: AnnotationToolbarPlacement.none,
          background: surface,
        );
      }
    }
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Center(
          child: AspectRatio(
            aspectRatio: mode == SharedContentMode.whiteboard
                ? 16 / 9
                : track?.aspectRatio ?? 16 / 9,
            child: surface,
          ),
        ),
      ),
    );
  }
}

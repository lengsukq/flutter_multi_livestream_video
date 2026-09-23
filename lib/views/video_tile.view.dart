import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';

import '../models/meeting_snapshot.dart';

/// Renders one native AWS Chime video tile on iOS or Android.
class MeetingVideoTileView extends StatelessWidget {
  const MeetingVideoTileView({super.key, required this.tile});

  final MeetingVideoTile tile;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Chime video is available on iOS and Android.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'videoTile',
        creationParams: tile.tileId,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    return PlatformViewLink(
      viewType: 'videoTile',
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: 'videoTile',
          layoutDirection: TextDirection.ltr,
          creationParams: tile.tileId,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        controller.addOnPlatformViewCreatedListener(
          params.onPlatformViewCreated,
        );
        controller.create();
        return controller;
      },
    );
  }
}

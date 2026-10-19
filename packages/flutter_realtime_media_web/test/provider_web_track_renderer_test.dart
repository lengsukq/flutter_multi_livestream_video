@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/services.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_web/flutter_realtime_media_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

@JS('globalThis')
external JSObject get _global;

void main() {
  testWidgets(
    'video binds the created element before DOM insertion and retains it when tracks change',
    (tester) async {
      // Widget tests replace the engine's platform-view host. Keep the DOM
      // element detached, matching Flutter's onElementCreated contract.
      final registry = _Registry();
      ui_web.debugOverridePlatformViewRegistry(registry);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform_views, (
            call,
          ) async {
            if (call.method == 'create') {
              final args = call.arguments as Map<Object?, Object?>;
              registry.views[args['id']! as int] = web.HTMLDivElement();
            } else if (call.method == 'dispose') {
              registry.views.remove(call.arguments);
            }
            return null;
          });
      addTearDown(() {
        ui_web.debugOverridePlatformViewRegistry(null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform_views, null);
      });
      final elements = <web.HTMLDivElement>[];
      final tracks = <String>[];
      final detached = <String>[];
      final bridge = JSObject();
      bridge.setProperty(
        'attachVideoElement'.toJS,
        ((
              JSString provider,
              JSString session,
              JSString track,
              web.HTMLDivElement element,
            ) {
              if (elements.isEmpty) {
                expect(element.isConnected, isFalse);
                expect(web.document.getElementById(element.id), isNull);
              }
              elements.add(element);
              tracks.add(track.toDart);
              return Future<JSAny?>.value(null).toJS;
            })
            .toJS,
      );
      bridge.setProperty(
        'detachVideo'.toJS,
        ((
              JSString provider,
              JSString session,
              JSString track,
              JSString elementId,
            ) {
              detached.add(track.toDart);
              expect(elementId.toDart, elements.first.id);
            })
            .toJS,
      );
      _global.setProperty('MediaProviderBridge'.toJS, bridge);
      addTearDown(() => _global.delete('MediaProviderBridge'.toJS));
      const renderer = ProviderWebTrackRenderer();
      Widget view(String id) => Builder(
        builder: (context) => SizedBox(
          width: 640,
          height: 360,
          child: renderer.buildView(
            context,
            ProviderWebVideoTrack(
              providerId: 'agora',
              sessionId: 'session',
              id: id,
              participantId: 'local',
              isLocal: true,
              isScreenShare: false,
            ),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(view('first'));
      await tester.pumpAndSettle();
      expect(tracks, ['first']);
      await tester.pumpWidget(view('replacement'));
      await tester.pumpAndSettle();
      expect(tracks, ['first', 'replacement']);
      expect(elements[0].isSameNode(elements[1]), isTrue);
      expect(detached, ['first']);
      await tester.pumpWidget(const SizedBox());
      expect(detached, ['first', 'replacement']);
    },
  );
}

class _Registry implements ui_web.PlatformViewRegistry {
  final views = <int, web.HTMLDivElement>{};
  @override
  Object getViewById(int viewId) => views[viewId]!;
  @override
  bool registerViewFactory(
    String viewType,
    Function viewFactory, {
    bool isVisible = true,
  }) => true;
}

import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugNetworkImageHttpClientProvider = null;
    PaintingBinding.instance.imageCache.clear();
  });
  testWidgets(
    'empty images use the first complete name character at every size',
    (tester) async {
      for (final size in [24.0, 36.0, 64.0, 88.0]) {
        for (final name in [' 张小明 ', 'alice', '👩🏽‍💻Ada']) {
          await tester.pumpWidget(
            MaterialApp(
              theme: RealtimeUiTheme.light(),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Center(
                  child: RealtimeAvatar(name: name, avatarUrl: ' ', size: size),
                ),
              ),
            ),
          );
          expect(find.text(name.trim().characters.first), findsOneWidget);
          expect(find.byType(Image), findsNothing);
          expect(
            tester.getSize(find.byType(RealtimeAvatar)),
            Size.square(size),
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
  testWidgets(
    'image links render photos and failed links recover to the name',
    (tester) async {
      final imageBytes = (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(
          recorder,
        ).drawColor(const Color(0xFF187A3D), ui.BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(1, 1);
        try {
          return (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
        } finally {
          image.dispose();
          picture.dispose();
        }
      }))!;
      for (final status in [200, 404]) {
        debugNetworkImageHttpClientProvider = () =>
            _ImageClient(status, imageBytes);
        await tester.pumpWidget(
          MaterialApp(
            theme: RealtimeUiTheme.light(),
            home: Center(
              child: RealtimeAvatar(
                name: '小明',
                avatarUrl: 'https://avatar.test/$status.png',
                size: 64,
              ),
            ),
          ),
        );
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        expect(find.text('小'), status == 200 ? findsNothing : findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      debugNetworkImageHttpClientProvider = null;
    },
  );
}

class _ImageClient extends Fake implements HttpClient {
  _ImageClient(this.status, this.bytes);
  final int status;
  final List<int> bytes;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _ImageRequest(status, bytes);
}

class _ImageRequest extends Fake implements HttpClientRequest {
  _ImageRequest(this.status, this.bytes);
  final int status;
  final List<int> bytes;
  @override
  HttpHeaders get headers => _ImageHeaders();
  @override
  Future<HttpClientResponse> close() async => _ImageResponse(status, bytes);
}

class _ImageHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.statusCode, this.bytes);
  @override
  final int statusCode;
  final List<int> bytes;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

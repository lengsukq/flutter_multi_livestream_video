import 'dart:async';

import 'package:flutter_realtime_media_ui/src/room_auxiliary_subscriptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'rebinding content drops previous stream events and preserves sources',
    () async {
      final oldUpdates = StreamController<Object?>.broadcast();
      final newUpdates = StreamController<Object?>.broadcast();
      final subscriptions = RoomAuxiliarySubscriptions();
      var redraws = 0;
      subscriptions.bindContent(oldUpdates.stream, invalidate: () => redraws++);
      oldUpdates.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(redraws, 1);
      subscriptions.bindContent(newUpdates.stream, invalidate: () => redraws++);
      oldUpdates.add(null);
      newUpdates.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(redraws, 2);
      expect(oldUpdates.hasListener, isFalse);
      subscriptions.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(newUpdates.hasListener, isFalse);
      newUpdates.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(redraws, 2);
      await oldUpdates.close();
      await newUpdates.close();
    },
  );

  test(
    'permission updates cancel independently and disposal is idempotent',
    () async {
      final content = StreamController<Object?>.broadcast();
      final permission = StreamController<Object?>.broadcast();
      final subscriptions = RoomAuxiliarySubscriptions();
      var contentCount = 0;
      var permissionCount = 0;
      subscriptions.bindContent(
        content.stream,
        invalidate: () => contentCount++,
      );
      subscriptions.bindMicrophone(
        permission.stream,
        onPermissionChanged: () => permissionCount++,
      );
      permission.add(null);
      content.add(null);
      await Future<void>.delayed(Duration.zero);
      expect((contentCount, permissionCount), (1, 1));
      subscriptions.bindMicrophone(
        null,
        onPermissionChanged: () => permissionCount++,
      );
      permission.add(null);
      content.add(null);
      await Future<void>.delayed(Duration.zero);
      expect((contentCount, permissionCount), (2, 1));
      subscriptions.dispose();
      subscriptions.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(content.hasListener, isFalse);
      expect(permission.hasListener, isFalse);
      await content.close();
      await permission.close();
    },
  );
}

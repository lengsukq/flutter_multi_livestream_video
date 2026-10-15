import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

/// Invoked after preview release; the application connects and navigates.
/// A failed entry remains on the page and can be retried with the same choices.
typedef RealtimePreJoinEnter =
    Future<void> Function(
      BuildContext context,
      MediaLocalPreviewSettings settings,
    );

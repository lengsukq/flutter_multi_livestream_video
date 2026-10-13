import 'package:flutter/widgets.dart';

typedef RealtimeRoomActionButtonBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback? onPressed,
      bool active,
      bool pending,
    );

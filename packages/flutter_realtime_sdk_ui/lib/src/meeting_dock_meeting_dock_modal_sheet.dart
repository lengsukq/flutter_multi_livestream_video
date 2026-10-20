import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

class MeetingDockMeetingDockModalSheet extends StatelessWidget {
  const MeetingDockMeetingDockModalSheet({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.extension<RealtimeUiThemeExtension>() == null
          ? RealtimeUiTheme.light()
          : theme,
      child: Builder(builder: _buildSheet),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final strings = RealtimeStrings.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: style.surface,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.sheetRadius),
            border: Border.all(color: style.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: style.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 6, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: strings.closePanel,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: style.border),
              Flexible(child: SingleChildScrollView(child: child)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

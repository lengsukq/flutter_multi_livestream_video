part of '../flutter_realtime_design_ui.dart';

/// Presents a frosted glass modal bottom sheet using the host's sheet radius
/// and a glass pill drag handle.
Future<T?> showRealtimeGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  backgroundColor: Colors.transparent,
  barrierColor:
      (Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : const Color(0xFF1D1D1F))
          .withValues(alpha: 0.40),
  elevation: 0,
  builder: (sheetContext) {
    final style = RealtimeStyle.of(sheetContext);
    return RepaintBoundary(
      child: RealtimeGlassSurface(
        radius: RealtimeUiThemeExtension.of(sheetContext).sheetRadius,
        shadow: false,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: style.borderStrong,
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.pillRadius,
                    ),
                  ),
                ),
              ),
              Flexible(child: builder(sheetContext)),
            ],
          ),
        ),
      ),
    );
  },
);

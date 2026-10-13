import 'dart:ui';
import 'package:flutter/material.dart';

class RealtimeMeetingDock extends StatelessWidget {
  const RealtimeMeetingDock({
    super.key,
    required this.mediaGroup,
    this.collaborationGroup = const [],
    this.panelsGroup = const [],
    this.exitAction,
    this.showLabels = true,
  });

  final List<Widget> mediaGroup;
  final List<Widget> collaborationGroup;
  final List<Widget> panelsGroup;
  final Widget? exitAction;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget divider() => Container(
      width: 1,
      height: showLabels ? 34 : 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
    );

    return SafeArea(
      top: false,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: showLabels ? 6 : 4,
              ),
              decoration: BoxDecoration(
                color: (isDark
                    ? const Color(0xE61E2533)
                    : const Color(0xF2FFFFFF)),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: (isDark ? Colors.white12 : Colors.black12),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Group 1: Media
                    ...mediaGroup,

                    // Divider
                    if (collaborationGroup.isNotEmpty) ...[
                      divider(),
                      ...collaborationGroup,
                    ],

                    // Divider
                    if (panelsGroup.isNotEmpty) ...[divider(), ...panelsGroup],

                    // Exit
                    if (exitAction != null) ...[divider(), exitAction!],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dock Microphone button with proper label, active state and mute toggle.

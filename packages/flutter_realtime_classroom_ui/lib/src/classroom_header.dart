import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';

class ClassroomHeader extends StatelessWidget {
  const ClassroomHeader({
    super.key,
    required this.snapshot,
    this.showCloseButton = false,
  });
  final ClassroomState snapshot;
  final bool showCloseButton;
  @override
  Widget build(BuildContext context) =>
      _buildHeader(context, snapshot, ClassroomStrings.of(context));

  Widget _buildHeader(
    BuildContext context,
    ClassroomState s,
    ClassroomStrings strings,
  ) {
    final canClose = showCloseButton;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canClose)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: RealtimeUiTokens.borderStrong.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.primarySubtle,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(color: RealtimeUiTokens.primaryBorder),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: RealtimeUiTokens.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        strings.t('classroomTitle'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: RealtimeUiTokens.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RealtimePill(
                      label: strings.t(
                        s.isTeacher ? 'teacherRole' : 'studentRole',
                      ),
                      foreground: s.isTeacher
                          ? RealtimeUiTokens.primary
                          : RealtimeUiTokens.textMuted,
                      background: s.isTeacher
                          ? RealtimeUiTokens.primarySubtle
                          : RealtimeUiTokens.surfaceSubtle,
                      borderColor: s.isTeacher
                          ? RealtimeUiTokens.primaryBorder
                          : RealtimeUiTokens.border,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Compact Online count pill: green dot + count
              RealtimePill(
                label: '${s.stats.onlineCount}',
                leadingDotColor: RealtimeUiTokens.success,
                foreground: RealtimeUiTokens.success,
                background: RealtimeUiTokens.successSubtle,
                borderColor: RealtimeUiTokens.successBorder,
              ),
              if (canClose) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: RealtimeUiTokens.textMuted,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

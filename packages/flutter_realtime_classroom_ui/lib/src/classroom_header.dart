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
    final style = RealtimeStyle.of(context);
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
                color: style.borderStrong.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: style.surfaceSubtle,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(color: style.border),
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: style.textSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        strings.t('classroomTitle'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: style.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: RealtimePill(
                        label: strings.t(
                          s.isTeacher ? 'teacherRole' : 'studentRole',
                        ),
                        foreground: style.textSecondary,
                        background: style.surfaceSubtle,
                        borderColor: style.border,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Compact Online count pill: green dot + count
              RealtimePill(
                label: '${s.stats.onlineCount}',
                leadingDotColor: style.speak,
                foreground: style.speakStrong,
                background: style.successSubtle,
                borderColor: style.successBorder,
              ),
              if (canClose) ...[
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: style.textMuted,
                  tooltip: strings.t('close'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
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

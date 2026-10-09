part of 'classroom_panel.dart';

extension _ClassroomHeader on _ClassroomPanelState {
  Widget _buildHeader(
    BuildContext context,
    ClassroomState s,
    ClassroomStrings strings,
  ) {
    final canClose = widget.showCloseButton ?? false;
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: s.isTeacher
                            ? RealtimeUiTokens.primarySubtle
                            : RealtimeUiTokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.pillRadius,
                        ),
                        border: Border.all(
                          color: s.isTeacher
                              ? RealtimeUiTokens.primaryBorder
                              : RealtimeUiTokens.border,
                        ),
                      ),
                      child: Text(
                        strings.t(s.isTeacher ? 'teacherRole' : 'studentRole'),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: s.isTeacher
                              ? RealtimeUiTokens.primary
                              : RealtimeUiTokens.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Compact Online count pill: green dot + count
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.successSubtle,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                  border: Border.all(color: RealtimeUiTokens.successBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: RealtimeUiTokens.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${s.stats.onlineCount}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: RealtimeUiTokens.success,
                      ),
                    ),
                  ],
                ),
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

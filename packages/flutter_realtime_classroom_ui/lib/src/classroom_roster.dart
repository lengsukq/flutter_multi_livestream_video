part of 'classroom_panel.dart';

extension _ClassroomRoster on _ClassroomPanelState {
  Widget _hands(ClassroomState state) {
    final strings = ClassroomStrings.of(context);
    final speakingStudents = state.students.where((s) => s.canSpeak).toList();

    if (state.raisedHands.isEmpty && speakingStudents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.surfaceSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: RealtimeUiTokens.border),
                ),
                child: Icon(
                  Icons.pan_tool_outlined,
                  size: 30,
                  color: RealtimeUiTokens.textMuted.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                strings.t('none'),
                style: const TextStyle(
                  color: RealtimeUiTokens.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.t('emptyHandsDesc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RealtimeUiTokens.textMuted,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (speakingStudents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.mic,
                  size: 15,
                  color: RealtimeUiTokens.success,
                ),
                const SizedBox(width: 6),
                Text(
                  '${strings.t('activeSpeakers')} (${speakingStudents.length})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: RealtimeUiTokens.text,
                  ),
                ),
              ],
            ),
          ),
          ...speakingStudents.map((s) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: RealtimeUiTokens.successSubtle,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
                border: Border.all(color: RealtimeUiTokens.successBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: RealtimeUiTokens.success,
                    child: Text(
                      s.displayName.isNotEmpty
                          ? s.displayName.substring(0, 1)
                          : 'S',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: RealtimeUiTokens.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.t('speakingGranted'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: RealtimeUiTokens.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: RealtimeUiTokens.danger,
                      side: const BorderSide(
                        color: RealtimeUiTokens.dangerBorder,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                      ),
                    ),
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => widget.classroom.revokeSpeak(s.userId),
                          ),
                    child: Text(strings.t('revoke')),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
        if (state.raisedHands.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.pan_tool_rounded,
                  size: 15,
                  color: RealtimeUiTokens.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  '${strings.t('tabHands')} (${state.raisedHands.length})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: RealtimeUiTokens.text,
                  ),
                ),
              ],
            ),
          ),
          ...state.raisedHands.map((s) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: RealtimeUiTokens.surface,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
                border: Border.all(color: RealtimeUiTokens.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: RealtimeUiTokens.warningSubtle,
                    child: const Icon(
                      Icons.pan_tool_alt_rounded,
                      size: 18,
                      color: RealtimeUiTokens.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: RealtimeUiTokens.text,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: RealtimeUiTokens.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                      ),
                    ),
                    onPressed: _busy
                        ? null
                        : () =>
                              _run(() => widget.classroom.grantSpeak(s.userId)),
                    child: Text(strings.t('allow')),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

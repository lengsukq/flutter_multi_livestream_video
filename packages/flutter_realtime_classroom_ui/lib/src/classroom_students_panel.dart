import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
import 'classroom_command_presenter.dart';

class ClassroomStudentsPanel extends StatefulWidget {
  const ClassroomStudentsPanel({
    super.key,
    required this.classroom,
    required this.snapshot,
    this.onActionError,
  });
  final ClassroomSession classroom;
  final ClassroomState snapshot;
  final void Function(RealtimeException error)? onActionError;
  @override
  State<ClassroomStudentsPanel> createState() => _ClassroomStudentsPanelState();
}

class _ClassroomStudentsPanelState extends State<ClassroomStudentsPanel> {
  final _studentSearch = TextEditingController();
  late final _commands = ClassroomCommandPresenter(
    onChanged: () {
      if (mounted) setState(() {});
    },
    onError: (error) => widget.onActionError?.call(error),
  );
  bool get _busy => _commands.pending;
  Future<void> _run(Future<void> Function() task) => _commands.run(task);
  @override
  void dispose() {
    _studentSearch.dispose();
    _commands.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _students(widget.snapshot);
  Widget _students(ClassroomState state) {
    final strings = ClassroomStrings.of(context);
    final search = _studentSearch.text.trim().toLowerCase();
    final students = state.students
        .where(
          (s) =>
              s.role == ClassroomRole.student &&
              (search.isEmpty ||
                  s.userId.toLowerCase().contains(search) ||
                  s.displayName.toLowerCase().contains(search)),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _studentSearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: RealtimeUiTokens.surfaceSubtle,
              prefixIcon: const Icon(Icons.search, size: 19),
              hintText: strings.t('search'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
                borderSide: const BorderSide(color: RealtimeUiTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
                borderSide: const BorderSide(color: RealtimeUiTokens.border),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: students.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = students[index];
              final mic = s.microphoneOn == null
                  ? strings.t('micUnknown')
                  : (s.microphoneOn!
                        ? strings.t('micOn')
                        : strings.t('micOff'));
              final camera = s.cameraOn == null
                  ? strings.t('cameraUnknown')
                  : (s.cameraOn!
                        ? strings.t('cameraOn')
                        : strings.t('cameraOff'));

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.surface,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(
                    color: s.canSpeak
                        ? RealtimeUiTokens.successBorder
                        : (s.handRaised
                              ? RealtimeUiTokens.warning.withValues(alpha: 0.3)
                              : RealtimeUiTokens.border),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    RealtimeAvatar(
                      name: s.displayName,
                      avatarUrl: s.avatarUrl,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                s.displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: RealtimeUiTokens.text,
                                ),
                              ),
                              if (s.handRaised) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RealtimeUiTokens.warningSubtle,
                                    borderRadius: BorderRadius.circular(
                                      RealtimeUiTokens.pillRadius,
                                    ),
                                    border: Border.all(
                                      color: RealtimeUiTokens.warning
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.pan_tool_rounded,
                                        size: 10,
                                        color: RealtimeUiTokens.warning,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        strings.t('hands'),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: RealtimeUiTokens.warning,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: s.online
                                      ? RealtimeUiTokens.success
                                      : RealtimeUiTokens.textMuted,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                "${s.online ? strings.t('online') : strings.t('offline')} · $mic · $camera",
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: RealtimeUiTokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (s.canSpeak)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RealtimeUiTokens.danger,
                          side: const BorderSide(
                            color: RealtimeUiTokens.dangerBorder,
                          ),
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
                      )
                    else if (s.handRaised)
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
                            : () => _run(
                                () => widget.classroom.grantSpeak(s.userId),
                              ),
                        child: Text(strings.t('allow')),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

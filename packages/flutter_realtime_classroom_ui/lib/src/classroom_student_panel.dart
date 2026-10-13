import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
import 'classroom_command_presenter.dart';
import 'classroom_feedback_presentation.dart';
class ClassroomStudentPanel extends StatefulWidget {
 const ClassroomStudentPanel({super.key, required this.classroom, required this.snapshot, this.onActionError});
 final ClassroomSession classroom;
 final ClassroomState snapshot;
 final void Function(RealtimeException error)? onActionError;
 @override State<ClassroomStudentPanel> createState() => _ClassroomStudentPanelState();
}
class _ClassroomStudentPanelState extends State<ClassroomStudentPanel> {

late final _commands = ClassroomCommandPresenter(onChanged: () { if (mounted) setState(() {}); }, onError: (error) => widget.onActionError?.call(error));
 bool get _busy => _commands.pending;
 Future<void> _run(Future<void> Function() task) => _commands.run(task);
@override void dispose() {  _commands.dispose(); super.dispose(); }
@override Widget build(BuildContext context) => _student(widget.snapshot);

  Widget _student(ClassroomState state) {
    final strings = ClassroomStrings.of(context);
    ClassroomStudent? self;
    for (final s in state.students) {
      if (s.userId == state.selfUserId) {
        self = s;
        break;
      }
    }
    final raised = self?.handRaised ?? false;
    final canSpeak = self?.canSpeak == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildStudentHeroCard(state, self, raised, canSpeak, strings),
        const SizedBox(height: 16),
        _buildQuickReactionsCard(state, strings),
        const SizedBox(height: 16),
        _buildActiveNoticeOrTipsCard(state, strings),
      ],
    );
  }

  Widget _buildStudentHeroCard(
    ClassroomState state,
    ClassroomStudent? self,
    bool raised,
    bool canSpeak,
    ClassroomStrings strings,
  ) {
    final isEnforced = state.capabilities.enforcesMicrophone;

    Color bg;
    Color border;
    IconData icon;
    Color iconColor;
    Color iconBg;
    String title;
    String subtitle;
    String statusTag;
    Color statusColor;

    if (canSpeak) {
      bg = RealtimeUiTokens.successSubtle;
      border = RealtimeUiTokens.successBorder;
      icon = Icons.mic_rounded;
      iconColor = RealtimeUiTokens.success;
      iconBg = RealtimeUiTokens.success.withValues(alpha: 0.14);
      title = strings.t('granted');
      subtitle = strings.t(isEnforced ? 'enforced' : 'advisory');
      statusTag = strings.t('speakingGranted');
      statusColor = RealtimeUiTokens.success;
    } else if (raised) {
      bg = RealtimeUiTokens.warningSubtle;
      border = RealtimeUiTokens.warning.withValues(alpha: 0.35);
      icon = Icons.pan_tool_rounded;
      iconColor = RealtimeUiTokens.warning;
      iconBg = RealtimeUiTokens.warning.withValues(alpha: 0.15);
      title = strings.t('handRaisedWaiting');
      subtitle = strings.t('speakingDescWaiting');
      statusTag = strings.t('hands');
      statusColor = RealtimeUiTokens.warning;
    } else {
      bg = RealtimeUiTokens.surface;
      border = RealtimeUiTokens.border;
      icon = Icons.headphones_outlined;
      iconColor = RealtimeUiTokens.primary;
      iconBg = RealtimeUiTokens.primarySubtle;
      title = strings.t('listeningMode');
      subtitle = strings.t('speakingDescListening');
      statusTag = strings.t('studentRole');
      statusColor = RealtimeUiTokens.textMuted;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        border: Border.all(color: border, width: 1.2),
        boxShadow: RealtimeUiTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: canSpeak
                                  ? RealtimeUiTokens.success
                                  : (raised
                                        ? RealtimeUiTokens.warning
                                        : RealtimeUiTokens.text),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(
                              RealtimeUiTokens.pillRadius,
                            ),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusTag,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: RealtimeUiTokens.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Main action button
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: raised
                    ? RealtimeUiTokens.warning
                    : RealtimeUiTokens.primary,
                foregroundColor: Colors.white,
                elevation: raised ? 0 : 2,
                shadowColor: RealtimeUiTokens.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.controlRadius,
                  ),
                ),
              ),
              icon: Icon(
                raised ? Icons.pan_tool : Icons.pan_tool_outlined,
                size: 20,
              ),
              label: Text(
                raised ? strings.t('lower') : strings.t('raise'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _busy
                  ? null
                  : () => _run(
                      raised
                          ? widget.classroom.lowerHand
                          : widget.classroom.raiseHand,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReactionsCard(
    ClassroomState state,
    ClassroomStrings strings,
  ) {
    final reactions = ClassroomFeedbackKind.values;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RealtimeUiTokens.surface,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        border: Border.all(color: RealtimeUiTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.thumb_up_alt_outlined,
                size: 16,
                color: RealtimeUiTokens.primary,
              ),
              const SizedBox(width: 6),
              Text(
                strings.t('quickReactions'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: RealtimeUiTokens.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: reactions.map((r) {
              return Material(
                color: RealtimeUiTokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.pillRadius,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                  onTap: _busy || !state.capabilities.canSendFeedback
                      ? null
                      : () => _run(() async {
                          await widget.classroom.sendFeedback(r);
                          if (!mounted) return;
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(
                              content: Text(
                                '${strings.t('quickSent')}: ${r.emoji} ${r.label(strings)}',
                              ),
                            ),
                          );
                        }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: RealtimeUiTokens.border),
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.pillRadius,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.emoji, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 5),
                        Text(
                          r.label(strings),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: RealtimeUiTokens.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            !state.feedbackSupported
                ? strings.t('feedbackUnavailable')
                : state.feedback.isEmpty
                ? strings.t('feedbackToTeacher')
                : '${strings.t('quickSent')}: ${state.feedback.last.kind.emoji} ${state.feedback.last.kind.label(strings)}',
            style: const TextStyle(
              fontSize: 12,
              color: RealtimeUiTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveNoticeOrTipsCard(
    ClassroomState state,
    ClassroomStrings strings,
  ) {
    final timer = state.tools?.timer;
    final notices = state.tools?.notices;

    if (timer != null) {
      final rem = timer.remaining();
      final timeStr = rem.inSeconds == 0
          ? strings.t('ended')
          : '${rem.inMinutes}:${(rem.inSeconds % 60).toString().padLeft(2, '0')}';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RealtimeUiTokens.primarySubtle,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
          border: Border.all(color: RealtimeUiTokens.primaryBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timer_outlined,
                color: RealtimeUiTokens.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.t('timer'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: RealtimeUiTokens.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timer.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: RealtimeUiTokens.text,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              timeStr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: RealtimeUiTokens.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (notices != null && notices.isNotEmpty) {
      final last = notices.last;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RealtimeUiTokens.primarySubtle.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
          border: Border.all(color: RealtimeUiTokens.primaryBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.campaign_outlined,
              color: RealtimeUiTokens.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.t(last.isFocusReminder ? 'focus' : 'announcement'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: RealtimeUiTokens.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    last.text,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: RealtimeUiTokens.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Default classroom tips card
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RealtimeUiTokens.surface,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        border: Border.all(color: RealtimeUiTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: RealtimeUiTokens.warning,
              ),
              const SizedBox(width: 6),
              Text(
                strings.t('tipsTitle'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: RealtimeUiTokens.text,
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  DefaultTabController.maybeOf(context)?.animateTo(1);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.t('goToQa'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: RealtimeUiTokens.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: RealtimeUiTokens.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings.t('tipsContent'),
            style: const TextStyle(
              fontSize: 12,
              color: RealtimeUiTokens.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

}

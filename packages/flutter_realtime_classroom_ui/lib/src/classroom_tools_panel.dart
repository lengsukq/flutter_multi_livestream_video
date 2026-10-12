import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'classroom_strings.dart';

/// Optional SDK UI for the tools extension. All actions delegate to the SDK.
class ClassroomToolsPanel extends StatefulWidget {
  const ClassroomToolsPanel({
    super.key,
    required this.classroom,
    this.showHeader = false,
    this.onClose,
  });

  final ClassroomSession classroom;
  final bool showHeader;
  final VoidCallback? onClose;

  @override
  State<ClassroomToolsPanel> createState() => _ClassroomToolsPanelState();
}

class _ClassroomToolsPanelState extends State<ClassroomToolsPanel> {
  bool _busy = false;
  bool _dialogOpen = false;
  Object? _error;
  Timer? _clock;
  StreamSubscription<Object>? _errors;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.classroom.state?.tools?.timer != null) {
        setState(() {});
      }
    });
    _errors = widget.classroom.errors.listen((error) {
      if (mounted) setState(() => _error = error);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    observeDetached(_errors?.cancel());
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish(String kind) async {
    if (_busy || _dialogOpen) return;
    setState(() => _dialogOpen = true);
    final strings = ClassroomStrings.of(context);
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => _PublishToolDialog(
          kind: kind,
          classroom: widget.classroom,
          strings: strings,
        ),
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ClassroomState>(
    stream: widget.classroom.states,
    initialData: widget.classroom.state,
    builder: (context, snapshot) {
      final state = snapshot.data;
      final tools = state?.tools;
      if (state == null || tools == null) return const SizedBox.shrink();
      final s = ClassroomStrings.of(context);
      final style = RealtimeStyle.of(context);
      final timer = tools.timer;
      final isEmpty =
          tools.notices.isEmpty &&
          tools.homework.isEmpty &&
          tools.materials.isEmpty &&
          tools.activities.isEmpty &&
          timer == null;

      return Column(
        children: [
          if (widget.showHeader) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: style.primarySubtle,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                      border: Border.all(color: style.primaryBorder),
                    ),
                    child: Icon(
                      Icons.widgets_outlined,
                      color: style.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          s.t('tools'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: style.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        RealtimePill(
                          label: s.t(
                            state.isTeacher ? 'teacherRole' : 'studentRole',
                          ),
                          foreground: state.isTeacher
                              ? style.primary
                              : style.textMuted,
                          background: state.isTeacher
                              ? style.primarySubtle
                              : style.surfaceSubtle,
                          borderColor: state.isTeacher
                              ? style.primaryBorder
                              : style.border,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: style.textMuted,
                    splashRadius: 18,
                    onPressed:
                        widget.onClose ??
                        () => Navigator.maybeOf(context)?.pop(),
                  ),
                ],
              ),
            ),
            Divider(color: style.border, height: 1),
          ],
          if (_busy)
            LinearProgressIndicator(
              minHeight: 2,
              color: style.primary,
              backgroundColor: style.primarySubtle,
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: style.dangerSubtle,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                      border: Border.all(
                        color: style.danger.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: style.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_error',
                            style: TextStyle(
                              color: style.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (state.isTeacher) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 14,
                          color: style.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.t('quickTools'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: style.textMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in <(String, IconData, Color)>[
                        (
                          'announcement',
                          Icons.campaign_outlined,
                          RealtimeUiTokens.iosBlue,
                        ),
                        (
                          'focus',
                          Icons.center_focus_strong,
                          RealtimeUiTokens.iosIndigo,
                        ),
                        (
                          'homework',
                          Icons.assignment_outlined,
                          RealtimeUiTokens.iosGreen,
                        ),
                        (
                          'materials',
                          Icons.attach_file,
                          RealtimeUiTokens.iosTeal,
                        ),
                        (
                          'timer',
                          Icons.timer_outlined,
                          RealtimeUiTokens.iosOrange,
                        ),
                        ('quiz', Icons.quiz_outlined, const Color(0xFF6366F1)),
                        ('poll', Icons.poll_outlined, const Color(0xFFEC4899)),
                      ])
                        _buildToolChip(item.$1, item.$2, item.$3, s, style),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (timer != null) _timerCard(state, timer, s, style),
                for (final notice in tools.notices.reversed)
                  _noticeCard(notice, s, style),
                for (final activity in tools.activities.reversed)
                  _activity(state, activity, s, style),
                for (final homework in tools.homework.reversed)
                  _homeworkCard(homework, s, style),
                if (tools.materials.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      s.t('linkOnly'),
                      style: TextStyle(fontSize: 12, color: style.textMuted),
                    ),
                  ),
                ],
                for (final material in tools.materials.reversed)
                  _materialCard(material, s, style),
                if (isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: RealtimeEmptyState(
                      icon: Icons.widgets_outlined,
                      title: s.t('emptyTools'),
                      subtitle: s.t('emptyToolsDesc'),
                      iconColor: style.primary,
                    ),
                  ),
                if (state.attendance.isNotEmpty)
                  _attendanceSection(state, s, style),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _buildToolChip(
    String kind,
    IconData icon,
    Color color,
    ClassroomStrings s,
    RealtimeStyle style,
  ) {
    return RealtimeGlassPressable(
      borderRadius: RealtimeUiTokens.pillRadius,
      onTap: _busy || _dialogOpen ? null : () => _publish(kind),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: style.surface,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
          border: Border.all(color: style.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: style.isDark ? 0.20 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 13, color: color),
            ),
            const SizedBox(width: 7),
            Text(
              s.t(kind),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: style.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timerCard(
    ClassroomState state,
    ClassroomTimer timer,
    ClassroomStrings s,
    RealtimeStyle style,
  ) {
    final remaining = timer.remaining();
    final isEnded = remaining.inSeconds == 0;
    final minutes = remaining.inMinutes;
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final formatted = '$minutes:$seconds';

    return RealtimeCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      radius: RealtimeUiTokens.cardRadius,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: RealtimeUiTokens.iosOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.compactRadius,
              ),
              border: Border.all(
                color: RealtimeUiTokens.iosOrange.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.timer_outlined,
              size: 20,
              color: RealtimeUiTokens.iosOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timer.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isEnded)
                      RealtimePill(
                        label: s.t('ended'),
                        foreground: style.danger,
                        background: style.dangerSubtle,
                        borderColor: style.danger.withValues(alpha: 0.3),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: style.warningSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: style.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.alarm_on_rounded,
                              size: 13,
                              color: style.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatted,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: style.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (state.isTeacher)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: style.danger,
                side: BorderSide(color: style.danger.withValues(alpha: 0.35)),
                backgroundColor: style.dangerSubtle,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                ),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: Text(
                s.t('stopTimer'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _busy ? null : () => _run(widget.classroom.stopTimer),
            ),
        ],
      ),
    );
  }

  Widget _noticeCard(
    ClassroomNotice notice,
    ClassroomStrings s,
    RealtimeStyle style,
  ) {
    final isFocus = notice.isFocusReminder;
    final fgColor = isFocus
        ? (style.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
        : style.primary;
    final bgColor = isFocus
        ? (style.isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
        : style.primarySubtle;
    final borderColor = isFocus
        ? (style.isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE))
        : style.primaryBorder;
    final icon = isFocus ? Icons.center_focus_strong : Icons.campaign_outlined;

    return RealtimeCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      radius: RealtimeUiTokens.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, size: 17, color: fgColor),
              ),
              const SizedBox(width: 10),
              RealtimePill(
                label: s.t(isFocus ? 'focus' : 'announcement'),
                foreground: fgColor,
                background: bgColor,
                borderColor: borderColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            notice.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: style.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeworkCard(
    ClassroomHomework homework,
    ClassroomStrings s,
    RealtimeStyle style,
  ) {
    return RealtimeCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      radius: RealtimeUiTokens.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.iosGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(
                    color: RealtimeUiTokens.iosGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 17,
                  color: RealtimeUiTokens.iosGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  homework.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                ),
              ),
              if (homework.dueAt != null)
                RealtimePill(
                  label:
                      '${homework.dueAt!.toLocal().month}/${homework.dueAt!.toLocal().day}',
                  leadingDotColor: style.warning,
                  foreground: style.warning,
                  background: style.warningSubtle,
                  borderColor: style.warning.withValues(alpha: 0.3),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: style.surfaceSubtle,
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.compactRadius,
              ),
              border: Border.all(color: style.border),
            ),
            child: SelectableText(
              '${homework.instructions}${homework.dueAt == null ? '' : '\n\n${s.chinese ? '截止时间' : 'Due'}: ${homework.dueAt!.toLocal()}'}',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: style.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialCard(
    ClassroomMaterial material,
    ClassroomStrings s,
    RealtimeStyle style,
  ) {
    return RealtimeCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      radius: RealtimeUiTokens.cardRadius,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: RealtimeUiTokens.iosTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.compactRadius,
              ),
              border: Border.all(
                color: RealtimeUiTokens.iosTeal.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.attach_file,
              size: 17,
              color: RealtimeUiTokens.iosTeal,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  material.url,
                  style: TextStyle(fontSize: 12, color: style.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: style.primary,
              side: BorderSide(color: style.primaryBorder),
              backgroundColor: style.primarySubtle,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
              ),
            ),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: Text(
              s.t('open'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final uri = Uri.tryParse(material.url);
                    if (uri == null ||
                        !['https', 'http'].contains(uri.scheme)) {
                      throw const FormatException('Invalid material URL');
                    }
                    if (!await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    )) {
                      throw StateError('Unable to open material');
                    }
                  }),
          ),
        ],
      ),
    );
  }

  Widget _attendanceSection(
    ClassroomState state,
    ClassroomStrings s,
    RealtimeStyle style,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.how_to_reg_rounded, size: 16, color: style.textMuted),
            const SizedBox(width: 6),
            Text(
              s.t('attendance'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: style.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            RealtimePill(
              label: '${state.attendance.length}',
              foreground: style.primary,
              background: style.primarySubtle,
              borderColor: style.primaryBorder,
            ),
          ],
        ),
        const SizedBox(height: 10),
        RealtimeCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          radius: RealtimeUiTokens.cardRadius,
          child: Column(
            children: [
              for (var i = 0; i < state.attendance.length; i++) ...[
                if (i > 0) Divider(color: style.border, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      RealtimeAvatar(
                        name: state.attendance[i].displayName,
                        size: 32,
                        isOnline: state.attendance[i].online,
                        showOnlineDot: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.attendance[i].displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: style.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${s.t('firstJoined')}: ${state.attendance[i].firstJoinedAt?.toLocal().toString().split('.').first ?? '—'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: style.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      RealtimePill(
                        label:
                            '${state.attendance[i].onlineDuration.inMinutes} ${s.t('minutes')}',
                        leadingDotColor: state.attendance[i].online
                            ? style.success
                            : style.textMuted,
                        foreground: state.attendance[i].online
                            ? style.success
                            : style.textMuted,
                        background: state.attendance[i].online
                            ? style.successSubtle
                            : style.surfaceSubtle,
                        borderColor: state.attendance[i].online
                            ? style.success.withValues(alpha: 0.35)
                            : style.border,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _activity(
    ClassroomState state,
    ClassroomActivity activity,
    ClassroomStrings s,
    RealtimeStyle style,
  ) {
    final isQuiz = activity.kind == ClassroomActivityKind.quiz;
    final totalVotes =
        activity.counts?.fold(0, (a, b) => a + b) ?? activity.responseCount;
    final fgColor = isQuiz
        ? (style.isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
        : (style.isDark ? const Color(0xFFF472B6) : const Color(0xFFBE185D));
    final bgColor = isQuiz
        ? (style.isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
        : (style.isDark ? const Color(0xFF831843) : const Color(0xFFFDF2F8));
    final borderColor = isQuiz
        ? (style.isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE))
        : (style.isDark ? const Color(0xFF9D174D) : const Color(0xFFFBCFE8));

    return RealtimeCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      radius: RealtimeUiTokens.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  isQuiz ? Icons.quiz_outlined : Icons.poll_outlined,
                  size: 19,
                  color: fgColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        RealtimePill(
                          label: s.chinese
                              ? (isQuiz ? '随堂测验' : '互动投票')
                              : (isQuiz ? 'Class Quiz' : 'Class Poll'),
                          foreground: fgColor,
                          background: bgColor,
                          borderColor: borderColor,
                        ),
                        const SizedBox(width: 6),
                        if (activity.closed)
                          RealtimePill(
                            label: s.t('ended'),
                            foreground: style.textMuted,
                            background: style.surfaceSubtle,
                            borderColor: style.border,
                          )
                        else
                          RealtimePill(
                            label: s.t('inProgress'),
                            leadingDotColor: style.success,
                            foreground: style.success,
                            background: style.successSubtle,
                            borderColor: style.success.withValues(alpha: 0.3),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: style.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              RealtimePill(
                label: '${s.t('responses')}: ${activity.responseCount}',
                foreground: style.textMuted,
                background: style.surfaceSubtle,
                borderColor: style.border,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < activity.options.length; i++)
            _buildOptionItem(
              state: state,
              activity: activity,
              index: i,
              s: s,
              style: style,
              totalVotes: totalVotes,
            ),
          if (state.isTeacher && activity.answers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 15,
                      color: style.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.t('studentAnswers'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: style.textSecondary,
                      ),
                    ),
                  ],
                ),
                children: [
                  for (final answer in activity.answers.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          RealtimeAvatar(
                            name:
                                state.students
                                    .where((st) => st.userId == answer.key)
                                    .firstOrNull
                                    ?.displayName ??
                                answer.key,
                            size: 24,
                            fontSize: 10,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.students
                                      .where((st) => st.userId == answer.key)
                                      .firstOrNull
                                      ?.displayName ??
                                  answer.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: style.text,
                              ),
                            ),
                          ),
                          RealtimePill(
                            label: activity.options[answer.value],
                            foreground: style.primary,
                            background: style.primarySubtle,
                            borderColor: style.primaryBorder,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (state.isTeacher && !activity.closed) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: style.danger,
                  side: BorderSide(color: style.danger.withValues(alpha: 0.35)),
                  backgroundColor: style.dangerSubtle,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.compactRadius,
                    ),
                  ),
                ),
                icon: const Icon(Icons.stop_circle_outlined, size: 16),
                label: Text(
                  s.t('closeActivity'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => widget.classroom.closeActivity(activity.id),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required ClassroomState state,
    required ClassroomActivity activity,
    required int index,
    required ClassroomStrings s,
    required RealtimeStyle style,
    required int totalVotes,
  }) {
    final count = (activity.counts != null && index < activity.counts!.length)
        ? activity.counts![index]
        : 0;
    final percent = totalVotes > 0 ? (count / totalVotes) : 0.0;
    final isSelf = activity.selfAnswer == index;
    final isCorrect = activity.correctOption == index;
    final showCorrect =
        isCorrect && (activity.closed || state.isTeacher || isSelf);
    final canTap = !state.isTeacher && !activity.closed && !_busy;

    final borderColor = showCorrect
        ? style.success.withValues(alpha: 0.35)
        : (isSelf ? style.primary : style.border);
    final bgColor = showCorrect
        ? style.successSubtle
        : (isSelf ? style.primarySubtle : style.surfaceSubtle);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: RealtimeGlassPressable(
        borderRadius: RealtimeUiTokens.compactRadius,
        onTap: canTap
            ? () => _run(
                () => widget.classroom.answerActivity(activity.id, index),
              )
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
            border: Border.all(
              color: borderColor,
              width: (isSelf || showCorrect) ? 1.4 : 1.0,
            ),
          ),
          child: Stack(
            children: [
              if (percent > 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percent.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            (showCorrect
                                    ? style.success
                                    : (isSelf
                                          ? style.primary
                                          : style.textMuted))
                                .withValues(alpha: style.isDark ? 0.20 : 0.10),
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (showCorrect)
                      Icon(
                        Icons.check_circle_rounded,
                        color: style.success,
                        size: 18,
                      )
                    else if (isSelf)
                      Icon(
                        Icons.radio_button_checked,
                        color: style.primary,
                        size: 18,
                      )
                    else
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: style.borderStrong,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: style.textMuted,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        activity.options[index],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: (isSelf || showCorrect)
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: style.text,
                        ),
                      ),
                    ),
                    if (showCorrect && !isSelf) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check, color: style.success, size: 16),
                    ],
                    if (activity.counts != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${(percent * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: showCorrect
                              ? style.success
                              : (isSelf ? style.primary : style.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($count)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: style.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishToolDialog extends StatefulWidget {
  const _PublishToolDialog({
    required this.kind,
    required this.classroom,
    required this.strings,
  });

  final String kind;
  final ClassroomSession classroom;
  final ClassroomStrings strings;

  @override
  State<_PublishToolDialog> createState() => _PublishToolDialogState();
}

class _PublishToolDialogState extends State<_PublishToolDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _seconds;
  late final TextEditingController _due;
  int? _correct;
  var _options = <String>[];
  Object? _dialogError;
  var _publishing = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _body = TextEditingController();
    _seconds = TextEditingController(text: '300');
    _due = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _seconds.dispose();
    _due.dispose();
    super.dispose();
  }

  List<String> _extractOptions(String text) => text
      .split('\n')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final strings = widget.strings;
    final activity = kind == 'quiz' || kind == 'poll';
    final single = kind == 'announcement' || kind == 'focus';
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    final iconData = switch (kind) {
      'announcement' => Icons.campaign_outlined,
      'focus' => Icons.center_focus_strong,
      'homework' => Icons.assignment_outlined,
      'materials' => Icons.attach_file,
      'timer' => Icons.timer_outlined,
      'quiz' => Icons.quiz_outlined,
      'poll' => Icons.poll_outlined,
      _ => Icons.widgets_outlined,
    };

    final style = RealtimeStyle.of(context);

    return AlertDialog(
      backgroundColor: style.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        side: BorderSide(color: style.border),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: style.primarySubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: style.primaryBorder),
            ),
            child: Icon(iconData, size: 20, color: style.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              strings.t(kind),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: style.text,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                enabled: !_publishing,
                maxLength: single ? 1000 : 120,
                style: TextStyle(fontSize: 14, color: style.text),
                decoration: InputDecoration(
                  labelText: strings.t(single ? 'text' : 'title'),
                  labelStyle: TextStyle(color: style.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    borderSide: BorderSide(color: style.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    borderSide: BorderSide(color: style.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    borderSide: BorderSide(color: style.primary, width: 1.5),
                  ),
                ),
              ),
              if (!single && kind != 'timer')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _body,
                    enabled: !_publishing,
                    maxLines: activity ? 5 : 3,
                    maxLength: 2000,
                    style: TextStyle(fontSize: 14, color: style.text),
                    onChanged: activity
                        ? (value) => setState(() {
                            final selected =
                                _correct != null && _correct! < _options.length
                                ? _options[_correct!]
                                : null;
                            _options = _extractOptions(value);
                            _correct =
                                selected != null &&
                                    _options
                                            .where((v) => v == selected)
                                            .length ==
                                        1
                                ? _options.indexOf(selected)
                                : null;
                            _dialogError = null;
                          })
                        : null,
                    decoration: InputDecoration(
                      labelText: strings.t(
                        activity
                            ? 'options'
                            : kind == 'materials'
                            ? 'link'
                            : 'text',
                      ),
                      labelStyle: TextStyle(color: style.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(
                          color: style.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              if (kind == 'timer')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _seconds,
                    enabled: !_publishing,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 14, color: style.text),
                    decoration: InputDecoration(
                      labelText: strings.t('seconds'),
                      labelStyle: TextStyle(color: style.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(
                          color: style.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              if (kind == 'homework')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _due,
                    enabled: !_publishing,
                    style: TextStyle(fontSize: 14, color: style.text),
                    decoration: InputDecoration(
                      labelText: 'YYYY-MM-DD (optional)',
                      labelStyle: TextStyle(color: style.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(color: style.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        borderSide: BorderSide(
                          color: style.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              if (kind == 'quiz')
                DropdownButtonFormField<int>(
                  key: ValueKey((_options.join('\n'), _correct)),
                  initialValue: _correct,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: strings.t('correct'),
                    labelStyle: TextStyle(color: style.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.controlRadius,
                      ),
                      borderSide: BorderSide(color: style.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.controlRadius,
                      ),
                      borderSide: BorderSide(color: style.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.controlRadius,
                      ),
                      borderSide: BorderSide(color: style.primary, width: 1.5),
                    ),
                  ),
                  items: List.generate(
                    _options.length,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(
                        '${index + 1}. ${_options[index]}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: style.text),
                      ),
                    ),
                  ),
                  onChanged: _publishing
                      ? null
                      : (value) => setState(() {
                          _correct = value;
                          _dialogError = null;
                        }),
                ),
              if (_publishing)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(
                    color: style.primary,
                    backgroundColor: style.primarySubtle,
                  ),
                ),
              if (_dialogError != null)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: style.dangerSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: style.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: style.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$_dialogError',
                          style: TextStyle(
                            color: style.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _publishing ? null : () => Navigator.of(context).pop(),
          child: Text(
            strings.t('cancel'),
            style: TextStyle(color: style.textMuted),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: style.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
            ),
          ),
          onPressed: _publishing
              ? null
              : () async {
                  if (activity) {
                    _options = _extractOptions(_body.text);
                    final invalid = _options.length < 2 || _options.length > 8
                        ? (zh ? '请输入 2–8 个选项。' : 'Enter 2–8 options.')
                        : _options.toSet().length != _options.length
                        ? (zh ? '选项不能重复。' : 'Options must be distinct.')
                        : kind == 'quiz' &&
                              (_correct == null || _correct! >= _options.length)
                        ? (zh
                              ? '请选择有效的正确答案。'
                              : 'Select a valid correct answer.')
                        : null;
                    if (invalid != null) {
                      setState(() => _dialogError = invalid);
                      return;
                    }
                  }
                  setState(() {
                    _publishing = true;
                    _dialogError = null;
                  });
                  try {
                    final session = widget.classroom;
                    switch (kind) {
                      case 'announcement':
                        await session.publishAnnouncement(_title.text.trim());
                      case 'focus':
                        await session.remindFocus(_title.text.trim());
                      case 'homework':
                        final dueText = _due.text.trim();
                        final dueAt = dueText.isEmpty
                            ? null
                            : DateTime.tryParse(dueText);
                        if (dueText.isNotEmpty && dueAt == null) {
                          throw const FormatException('Invalid due date');
                        }
                        await session.publishHomework(
                          title: _title.text.trim(),
                          instructions: _body.text.trim(),
                          dueAt: dueAt,
                        );
                      case 'materials':
                        await session.shareMaterial(
                          title: _title.text.trim(),
                          url: _body.text.trim(),
                        );
                      case 'timer':
                        final duration = int.tryParse(_seconds.text.trim());
                        if (duration == null) {
                          throw const FormatException(
                            'Use a duration in seconds',
                          );
                        }
                        await session.startTimer(
                          title: _title.text.trim(),
                          duration: Duration(seconds: duration),
                        );
                      case 'quiz':
                      case 'poll':
                        await session.publishActivity(
                          kind: kind == 'quiz'
                              ? ClassroomActivityKind.quiz
                              : ClassroomActivityKind.poll,
                          title: _title.text.trim(),
                          options: _options,
                          correctOption: kind == 'quiz' ? _correct : null,
                        );
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (error) {
                    if (context.mounted) {
                      setState(() {
                        _publishing = false;
                        _dialogError = error;
                      });
                    }
                  }
                },
          child: Text(strings.t('publish')),
        ),
      ],
    );
  }
}

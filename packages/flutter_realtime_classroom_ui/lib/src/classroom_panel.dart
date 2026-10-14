import 'classroom_students_panel.dart';
import 'classroom_feedback_presentation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
import 'classroom_tools_panel.dart';
import 'classroom_student_panel.dart';
import 'classroom_questions.dart';
import 'classroom_roster.dart';
import 'classroom_header.dart';
import 'classroom_feedback.dart';

/// Optional SDK-owned classroom UI styled to match Realtime SDK design tokens.
class ClassroomPanel extends StatefulWidget {
  const ClassroomPanel({
    super.key,
    required this.classroom,
    this.showCloseButton,
    this.initialTab = 0,
  });

  final ClassroomSession classroom;
  final bool? showCloseButton;
  final int initialTab;

  @override
  State<ClassroomPanel> createState() => _ClassroomPanelState();
}

class _ClassroomPanelState extends State<ClassroomPanel> {
  RealtimeException? _error;
  void _onActionError(RealtimeException error) {
    if (mounted) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ClassroomState>(
    stream: widget.classroom.states,
    initialData: widget.classroom.state,
    builder: (context, data) {
      final strings = ClassroomStrings.of(context);
      final s = data.data;
      if (s == null) {
        return Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Text(_error.toString()),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClassroomHeader(
            snapshot: s,
            showCloseButton: widget.showCloseButton ?? false,
          ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: RealtimeUiTokens.dangerSubtle,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
                border: Border.all(color: RealtimeUiTokens.dangerBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: RealtimeUiTokens.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error.toString(),
                      style: const TextStyle(
                        color: RealtimeUiTokens.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: DefaultTabController(
              key: ValueKey(
                '${s.isTeacher}-${s.tools != null}-${s.feedbackSupported}',
              ),
              length:
                  (s.isTeacher ? 3 : 2) +
                  (s.tools != null ? 1 : 0) +
                  (s.capabilities.canViewFeedback ? 1 : 0),
              initialIndex: widget.initialTab.clamp(
                0,
                (s.isTeacher ? 3 : 2) +
                    (s.tools != null ? 1 : 0) +
                    (s.capabilities.canViewFeedback ? 1 : 0) -
                    1,
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: RealtimeUiTokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.dockRadius,
                      ),
                      border: Border.all(color: RealtimeUiTokens.border),
                    ),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: RealtimeUiTokens.surface,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.pillRadius,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: RealtimeUiTokens.primary,
                      unselectedLabelColor: RealtimeUiTokens.textMuted,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                s.isTeacher
                                    ? Icons.pan_tool_outlined
                                    : Icons.touch_app_outlined,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                s.isTeacher
                                    ? strings.t('tabHands')
                                    : strings.t('interact'),
                              ),
                              if (s.isTeacher && s.stats.handsRaised > 0) ...[
                                const SizedBox(width: 6),
                                RealtimeBadge(
                                  text: '${s.stats.handsRaised}',
                                  backgroundColor: RealtimeUiTokens.warning,
                                  color: Colors.white,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Text(strings.t('qa')),
                              if (s.stats.pendingQuestions > 0) ...[
                                const SizedBox(width: 6),
                                RealtimeBadge(
                                  text: '${s.stats.pendingQuestions}',
                                  backgroundColor: RealtimeUiTokens.primary,
                                  color: Colors.white,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (s.isTeacher)
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_outline_rounded,
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(strings.t('students')),
                              ],
                            ),
                          ),
                        if (s.capabilities.canViewFeedback)
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.thumb_up_alt_outlined,
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(strings.t('feedbackTab')),
                                if (s.feedback.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  RealtimeBadge(
                                    text: '${s.feedback.length}',
                                    backgroundColor: RealtimeUiTokens.primary,
                                    color: Colors.white,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (s.tools != null)
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.widgets_outlined, size: 15),
                                const SizedBox(width: 5),
                                Text(strings.t('tools')),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        s.isTeacher
                            ? ClassroomRaisedHandsPanel(
                                classroom: widget.classroom,
                                snapshot: s,
                                onActionError: _onActionError,
                              )
                            : ClassroomStudentPanel(
                                classroom: widget.classroom,
                                snapshot: s,
                                onActionError: _onActionError,
                              ),
                        ClassroomQuestionsPanel(
                          classroom: widget.classroom,
                          snapshot: s,
                          onActionError: _onActionError,
                        ),
                        if (s.isTeacher)
                          ClassroomStudentsPanel(
                            classroom: widget.classroom,
                            snapshot: s,
                            onActionError: _onActionError,
                          ),
                        if (s.capabilities.canViewFeedback)
                          ClassroomFeedbackPanel(
                            classroom: widget.classroom,
                            snapshot: s,
                            onActionError: _onActionError,
                          ),
                        if (s.tools != null)
                          ClassroomToolsPanel(classroom: widget.classroom),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Helper method to open the unified classroom panel bottom sheet.
Future<void> showClassroomBottomSheet(
  BuildContext context, {
  required ClassroomSession classroom,
  int initialTab = 0,
}) => showRealtimeGlassBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880),
      child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.84,
        child: ClassroomPanel(
          classroom: classroom,
          showCloseButton: true,
          initialTab: initialTab,
        ),
      ),
    ),
  ),
);

/// Bottom dock control button that blends into RealtimeGlassSurface.
class ClassroomControlButton extends StatefulWidget {
  const ClassroomControlButton({
    super.key,
    required this.classroom,
    this.showLabel = false,
  });

  final ClassroomSession classroom;
  final bool showLabel;

  @override
  State<ClassroomControlButton> createState() => _ClassroomControlButtonState();
}

class _ClassroomControlButtonState extends State<ClassroomControlButton> {
  StreamSubscription<ClassroomNotification>? _subscription;
  int _unread = 0;
  bool _panelOpen = false;
  final _feedbackBubble = ClassroomFeedbackBubble();

  @override
  void initState() {
    super.initState();
    _subscription = widget.classroom.notifications.listen((notification) {
      if (!mounted) return;
      if (!_panelOpen) setState(() => _unread++);
      final state = widget.classroom.state;
      _feedbackBubble.show(
        context,
        notification,
        onView: _panelOpen ? null : () => _openPanel(showFeedback: true),
      );
      if (notification.kind == ClassroomNotificationKind.noticePublished &&
          state?.isTeacher == false &&
          state!.tools!.notices.isNotEmpty) {
        final notice = state.tools!.notices
            .where(
              (n) => notification.itemId == null || n.id == notification.itemId,
            )
            .lastOrNull;
        if (notice == null) return;
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(notice.text)));
      }
    });
  }

  @override
  void dispose() {
    _feedbackBubble.dismiss();
    observeDetached(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _openPanel({bool showFeedback = false}) async {
    setState(() {
      _unread = 0;
      _panelOpen = true;
    });
    try {
      await showClassroomBottomSheet(
        context,
        classroom: widget.classroom,
        initialTab: showFeedback ? 3 : 0,
      );
    } finally {
      if (mounted) setState(() => _panelOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final label = zh ? '课堂互动' : 'Classroom';
    final style = RealtimeStyle.of(context);
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: _openPanel,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _panelOpen
                          ? style.primarySubtle
                          : style.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _panelOpen
                            ? style.primary
                            : (style.isDark
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.transparent),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      size: 20,
                      color: _panelOpen ? style.primary : style.text,
                    ),
                  ),
                  if (_unread > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: style.danger,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: style.surface, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          '$_unread',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _panelOpen ? style.primary : style.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Backward-compatible overlay button with refined glass styling.
class ClassroomOverlayButton extends StatefulWidget {
  const ClassroomOverlayButton({super.key, required this.classroom});
  final ClassroomSession classroom;
  @override
  State<ClassroomOverlayButton> createState() => _ClassroomOverlayButtonState();
}

class _ClassroomOverlayButtonState extends State<ClassroomOverlayButton> {
  StreamSubscription<ClassroomNotification>? _subscription;
  int _unread = 0;
  bool _panelOpen = false;
  final _feedbackBubble = ClassroomFeedbackBubble();

  @override
  void initState() {
    super.initState();
    _subscription = widget.classroom.notifications.listen((notification) {
      if (!mounted) return;
      if (!_panelOpen) setState(() => _unread++);
      final state = widget.classroom.state;
      _feedbackBubble.show(
        context,
        notification,
        onView: _panelOpen ? null : () => _openPanel(showFeedback: true),
      );
      if (notification.kind == ClassroomNotificationKind.noticePublished &&
          state?.isTeacher == false &&
          state!.tools!.notices.isNotEmpty) {
        final notice = state.tools!.notices
            .where(
              (n) => notification.itemId == null || n.id == notification.itemId,
            )
            .lastOrNull;
        if (notice == null) return;
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(notice.text)));
      }
    });
  }

  @override
  void dispose() {
    _feedbackBubble.dismiss();
    observeDetached(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _openPanel({bool showFeedback = false}) async {
    setState(() {
      _unread = 0;
      _panelOpen = true;
    });
    try {
      await showClassroomBottomSheet(
        context,
        classroom: widget.classroom,
        initialTab: showFeedback ? 3 : 0,
      );
    } finally {
      if (mounted) setState(() => _panelOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = _unread == 0
        ? (zh ? '课堂互动' : 'Classroom')
        : '${zh ? '课堂互动' : 'Classroom'} ($_unread)';
    return RealtimeGlassPressable(
      borderRadius: RealtimeUiTokens.pillRadius,
      child: RealtimeGlassSurface(
        radius: RealtimeUiTokens.pillRadius,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        borderColor: isDark
            ? Colors.white.withValues(alpha: 0.16)
            : RealtimeUiTokens.primaryBorder,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : RealtimeUiTokens.surface.withValues(alpha: 0.94),
        onTap: _openPanel,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 20,
              color: isDark
                  ? const Color(0xFF818CF8)
                  : RealtimeUiTokens.primary,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : RealtimeUiTokens.text,
              ),
            ),
            if (_unread > 0) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: RealtimeUiTokens.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

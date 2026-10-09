import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
import 'classroom_tools_panel.dart';
part 'classroom_student_panel.dart';
part 'classroom_questions.dart';
part 'classroom_roster.dart';
part 'classroom_header.dart';

Color _avatarColor(String name) {
  if (name.isEmpty) return RealtimeUiTokens.primary;
  final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
  const hues = [
    Color(0xFF4F46E5),
    Color(0xFF0D9488),
    Color(0xFFD97706),
    Color(0xFFE11D48),
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
  ];
  return hues[hash % hues.length];
}

/// Optional SDK-owned classroom UI styled to match Realtime SDK design tokens.
class ClassroomPanel extends StatefulWidget {
  const ClassroomPanel({
    super.key,
    required this.classroom,
    this.showCloseButton,
  });

  final ClassroomSession classroom;
  final bool? showCloseButton;

  @override
  State<ClassroomPanel> createState() => _ClassroomPanelState();
}

class _ClassroomPanelState extends State<ClassroomPanel> {
  final _question = TextEditingController();
  final _studentSearch = TextEditingController();
  final _questionSearch = TextEditingController();
  ClassroomQuestionStatus? _questionFilter;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.classroom.start().catchError((Object e) {
        if (mounted) setState(() => _error = e);
      }),
    );
  }

  @override
  void dispose() {
    _question.dispose();
    _studentSearch.dispose();
    _questionSearch.dispose();
    super.dispose();
  }

  void _update(VoidCallback action) => setState(action);

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answer(ClassroomQuestion question) async {
    final strings = ClassroomStrings.of(context);
    final ctrl = TextEditingController(text: question.answer ?? '');
    DialogRoute<String>? route;
    try {
      route = DialogRoute<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
          ),
          title: Text(strings.t('answer')),
          content: TextField(
            controller: ctrl,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: strings.t('answer'),
              filled: true,
              fillColor: RealtimeUiTokens.surfaceSubtle,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.t('cancel')),
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
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(strings.t('submit')),
            ),
          ],
        ),
      );
      final answer = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      if (answer != null && answer.isNotEmpty) {
        await _run(() => widget.classroom.answerQuestion(question.id, answer));
      }
    } finally {
      await route?.completed;
      ctrl.dispose();
    }
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
          _buildHeader(context, s, strings),
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
              key: ValueKey('${s.isTeacher}-${s.tools != null}'),
              length: (s.isTeacher ? 3 : 2) + (s.tools != null ? 1 : 0),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: RealtimeUiTokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
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
                          RealtimeUiTokens.compactRadius - 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
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
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RealtimeUiTokens.warning,
                                    borderRadius: BorderRadius.circular(
                                      RealtimeUiTokens.pillRadius,
                                    ),
                                  ),
                                  child: Text(
                                    '${s.stats.handsRaised}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RealtimeUiTokens.primary,
                                    borderRadius: BorderRadius.circular(
                                      RealtimeUiTokens.pillRadius,
                                    ),
                                  ),
                                  child: Text(
                                    '${s.stats.pendingQuestions}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                        s.isTeacher ? _hands(s) : _student(s),
                        _questions(s),
                        if (s.isTeacher) _students(s),
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
              final avatarLetter = s.displayName.isNotEmpty
                  ? s.displayName.substring(0, 1).toUpperCase()
                  : 'S';

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
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _avatarColor(s.displayName),
                      child: Text(
                        avatarLetter,
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

/// Helper method to open the unified classroom panel bottom sheet.
Future<void> showClassroomBottomSheet(
  BuildContext context, {
  required ClassroomSession classroom,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black54,
  builder: (ctx) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880),
      child: Container(
        height: MediaQuery.sizeOf(ctx).height * 0.84,
        decoration: const BoxDecoration(
          color: RealtimeUiTokens.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(RealtimeUiTokens.sheetRadius),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x330F172A),
              blurRadius: 36,
              offset: Offset(0, -8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: ClassroomPanel(classroom: classroom, showCloseButton: true),
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

  @override
  void initState() {
    super.initState();
    _subscription = widget.classroom.notifications.listen((notification) {
      if (!mounted) return;
      if (!_panelOpen) setState(() => _unread++);
      final state = widget.classroom.state;
      if (notification.kind == ClassroomNotificationKind.noticePublished &&
          state?.isTeacher == false &&
          state!.tools!.notices.isNotEmpty) {
        final notice = state.tools!.notices.last;
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(notice.text)));
      }
    });
    unawaited(widget.classroom.start().catchError((Object _) {}));
  }

  @override
  void dispose() {
    observeDetached(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _openPanel() async {
    setState(() {
      _unread = 0;
      _panelOpen = true;
    });
    try {
      await showClassroomBottomSheet(context, classroom: widget.classroom);
    } finally {
      if (mounted) setState(() => _panelOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final label = zh ? '课堂互动' : 'Classroom';
    return Semantics(
      label: label,
      button: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RealtimeGlassIconButton(
            tooltip: label,
            icon: Icons.school_outlined,
            onPressed: _openPanel,
            active: _panelOpen,
            badgeCount: _unread,
            size: 46,
            radius: RealtimeUiTokens.controlRadius,
          ),
          if (widget.showLabel) ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _panelOpen
                    ? RealtimeUiTokens.primary
                    : RealtimeUiTokens.text,
              ),
            ),
          ],
        ],
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

  @override
  void initState() {
    super.initState();
    _subscription = widget.classroom.notifications.listen((notification) {
      if (!mounted) return;
      if (!_panelOpen) setState(() => _unread++);
      final state = widget.classroom.state;
      if (notification.kind == ClassroomNotificationKind.noticePublished &&
          state?.isTeacher == false &&
          state!.tools!.notices.isNotEmpty) {
        final notice = state.tools!.notices.last;
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(notice.text)));
      }
    });
    unawaited(widget.classroom.start().catchError((Object _) {}));
  }

  @override
  void dispose() {
    observeDetached(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _openPanel() async {
    setState(() {
      _unread = 0;
      _panelOpen = true;
    });
    try {
      await showClassroomBottomSheet(context, classroom: widget.classroom);
    } finally {
      if (mounted) setState(() => _panelOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final text = _unread == 0
        ? (zh ? '课堂互动' : 'Classroom')
        : '${zh ? '课堂互动' : 'Classroom'} ($_unread)';
    return RealtimeGlassPressable(
      borderRadius: RealtimeUiTokens.pillRadius,
      child: RealtimeGlassSurface(
        radius: RealtimeUiTokens.pillRadius,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        borderColor: RealtimeUiTokens.primaryBorder,
        fillColor: RealtimeUiTokens.surface.withValues(alpha: 0.94),
        onTap: _openPanel,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.school_outlined,
              size: 20,
              color: RealtimeUiTokens.primary,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: RealtimeUiTokens.text,
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

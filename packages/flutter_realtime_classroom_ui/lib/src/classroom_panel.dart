import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
import 'classroom_tools_panel.dart';

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
                borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                borderSide: const BorderSide(color: RealtimeUiTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
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
                  borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
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

  Widget _buildHeader(BuildContext context, ClassroomState s, ClassroomStrings strings) {
    final canClose = widget.showCloseButton ?? Navigator.canPop(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag handle pill
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
        // Header title row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.primarySubtle,
                  borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                  border: Border.all(color: RealtimeUiTokens.primaryBorder),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: RealtimeUiTokens.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.t('classroomTitle'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: RealtimeUiTokens.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.isTeacher
                              ? RealtimeUiTokens.primarySubtle
                              : RealtimeUiTokens.surfaceSubtle,
                          borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
                          border: Border.all(
                            color: s.isTeacher
                                ? RealtimeUiTokens.primaryBorder
                                : RealtimeUiTokens.border,
                          ),
                        ),
                        child: Text(
                          strings.t(s.isTeacher ? 'teacherRole' : 'studentRole'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: s.isTeacher
                                ? RealtimeUiTokens.primary
                                : RealtimeUiTokens.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              // Online count pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.successSubtle,
                  borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
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
                    const SizedBox(width: 5),
                    Text(
                      '${s.stats.onlineCount} ${strings.t('online')}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: RealtimeUiTokens.success,
                      ),
                    ),
                  ],
                ),
              ),
              if (canClose) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: RealtimeUiTokens.textMuted,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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
                borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                border: Border.all(color: RealtimeUiTokens.dangerBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 18, color: RealtimeUiTokens.danger),
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
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: RealtimeUiTokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                      border: Border.all(color: RealtimeUiTokens.border),
                    ),
                    child: TabBar(
                      isScrollable: false,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: RealtimeUiTokens.surface,
                        borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius - 3),
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
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                s.isTeacher ? Icons.pan_tool_outlined : Icons.touch_app_outlined,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Text(s.isTeacher ? strings.t('tabHands') : strings.t('interact')),
                              if (s.isTeacher && s.stats.handsRaised > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: RealtimeUiTokens.warning,
                                    borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
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
                              const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                              const SizedBox(width: 5),
                              Text(strings.t('qa')),
                              if (s.stats.pendingQuestions > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: RealtimeUiTokens.primary,
                                    borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
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
                                const Icon(Icons.people_outline_rounded, size: 15),
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
        _buildQuickReactionsCard(strings),
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
                                  : (raised ? RealtimeUiTokens.warning : RealtimeUiTokens.text),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
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
                  borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
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

  Widget _buildQuickReactionsCard(ClassroomStrings strings) {
    final reactions = [
      ('👍', strings.t('quickUnderstood')),
      ('👏', strings.t('quickGreat')),
      ('💡', strings.t('quickIdea')),
      ('❓', strings.t('quickQuestion')),
      ('🎉', strings.t('quickClap')),
    ];

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
                borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
                  onTap: () {
                    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                        ),
                        duration: const Duration(milliseconds: 1200),
                        content: Text('${strings.t('quickSent')}: ${r.$1} ${r.$2}'),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(color: RealtimeUiTokens.border),
                      borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.$1, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 5),
                        Text(
                          r.$2,
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
        ],
      ),
    );
  }

  Widget _buildActiveNoticeOrTipsCard(ClassroomState state, ClassroomStrings strings) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                const Icon(Icons.mic, size: 15, color: RealtimeUiTokens.success),
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
                borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                border: Border.all(color: RealtimeUiTokens.successBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: RealtimeUiTokens.success,
                    child: Text(
                      s.displayName.isNotEmpty ? s.displayName.substring(0, 1) : 'S',
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
                      side: const BorderSide(color: RealtimeUiTokens.dangerBorder),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                      ),
                    ),
                    onPressed: _busy
                        ? null
                        : () => _run(() => widget.classroom.revokeSpeak(s.userId)),
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
                const Icon(Icons.pan_tool_rounded, size: 15, color: RealtimeUiTokens.warning),
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
                borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
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
                        : () => _run(() => widget.classroom.grantSpeak(s.userId)),
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

  Widget _questionFilterPill(
    ClassroomQuestionStatus? value,
    String label,
    int count,
  ) {
    final selected = _questionFilter == value;
    return Material(
      color: selected ? RealtimeUiTokens.primarySubtle : RealtimeUiTokens.surfaceSubtle,
      borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
        onTap: () => setState(() => _questionFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
            border: Border.all(
              color: selected ? RealtimeUiTokens.primary : RealtimeUiTokens.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? RealtimeUiTokens.primary : RealtimeUiTokens.textMuted,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? RealtimeUiTokens.primary
                        : RealtimeUiTokens.borderStrong,
                    borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
                  ),
                  child: Text(
                    '$count',
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
      ),
    );
  }

  Widget _questions(ClassroomState state) {
    final strings = ClassroomStrings.of(context);
    final search = _questionSearch.text.trim().toLowerCase();

    final allQuestions = state.questions;
    final pendingCount = allQuestions.where((q) => q.status == ClassroomQuestionStatus.pending).length;
    final answeredCount = allQuestions.where((q) => q.status == ClassroomQuestionStatus.answered).length;
    final resolvedCount = allQuestions.where((q) => q.status == ClassroomQuestionStatus.resolved).length;

    final filtered = allQuestions
        .where(
          (q) =>
              (_questionFilter == null || q.status == _questionFilter) &&
              (search.isEmpty ||
                  q.text.toLowerCase().contains(search) ||
                  q.displayName.toLowerCase().contains(search)),
        )
        .toList();

    return Column(
      children: [
        // Search and Filters Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _questionSearch,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 19),
                  hintText: strings.t('searchQuestions'),
                  isDense: true,
                  filled: true,
                  fillColor: RealtimeUiTokens.surfaceSubtle,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                    borderSide: const BorderSide(color: RealtimeUiTokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                    borderSide: const BorderSide(color: RealtimeUiTokens.border),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _questionFilterPill(null, strings.t('filterAll'), allQuestions.length),
                    const SizedBox(width: 6),
                    _questionFilterPill(
                      ClassroomQuestionStatus.pending,
                      strings.t('filterPending'),
                      pendingCount,
                    ),
                    const SizedBox(width: 6),
                    _questionFilterPill(
                      ClassroomQuestionStatus.answered,
                      strings.t('filterAnswered'),
                      answeredCount,
                    ),
                    const SizedBox(width: 6),
                    _questionFilterPill(
                      ClassroomQuestionStatus.resolved,
                      strings.t('filterResolved'),
                      resolvedCount,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Student ask input bar
        if (!state.isTeacher)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.fromLTRB(14, 3, 6, 3),
            decoration: BoxDecoration(
              color: RealtimeUiTokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
              border: Border.all(color: RealtimeUiTokens.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _question,
                    maxLength: 500,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      counterText: '',
                      hintText: strings.t('ask'),
                      hintStyle: const TextStyle(
                        color: RealtimeUiTokens.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: RealtimeUiTokens.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 17),
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final text = _question.text.trim();
                          if (text.isEmpty) return;
                          await widget.classroom.askQuestion(text);
                          _question.clear();
                        }),
                ),
              ],
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.question_answer_outlined,
                        size: 38,
                        color: RealtimeUiTokens.textMuted.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.t('none'),
                        style: const TextStyle(
                          color: RealtimeUiTokens.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final q = filtered[index];
                    final isAnswered = q.status == ClassroomQuestionStatus.answered;
                    final isResolved = q.status == ClassroomQuestionStatus.resolved;

                    Color tagBg;
                    Color tagBorder;
                    Color tagFg;
                    String tagLabel;

                    if (isResolved) {
                      tagBg = RealtimeUiTokens.surfaceSubtle;
                      tagBorder = RealtimeUiTokens.border;
                      tagFg = RealtimeUiTokens.textMuted;
                      tagLabel = strings.t('filterResolved');
                    } else if (isAnswered) {
                      tagBg = RealtimeUiTokens.successSubtle;
                      tagBorder = RealtimeUiTokens.successBorder;
                      tagFg = RealtimeUiTokens.success;
                      tagLabel = strings.t('filterAnswered');
                    } else {
                      tagBg = RealtimeUiTokens.warningSubtle;
                      tagBorder = RealtimeUiTokens.warning.withValues(alpha: 0.3);
                      tagFg = RealtimeUiTokens.warning;
                      tagLabel = strings.t('filterPending');
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: RealtimeUiTokens.surface,
                        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
                        border: Border.all(color: RealtimeUiTokens.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tagBg,
                                  borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
                                  border: Border.all(color: tagBorder),
                                ),
                                child: Text(
                                  tagLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: tagFg,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                q.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: RealtimeUiTokens.text,
                                ),
                              ),
                              const Spacer(),
                              if (state.isTeacher && !isResolved) ...[
                                IconButton(
                                  tooltip: strings.t('answer'),
                                  splashRadius: 18,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.reply_rounded, size: 20, color: RealtimeUiTokens.primary),
                                  onPressed: _busy ? null : () => _answer(q),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: strings.t('resolve'),
                                  splashRadius: 18,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20, color: RealtimeUiTokens.success),
                                  onPressed: _busy ? null : () => _run(() => widget.classroom.resolveQuestion(q.id)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            q.text,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: RealtimeUiTokens.text,
                              height: 1.35,
                            ),
                          ),
                          if (q.answer != null && q.answer!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: RealtimeUiTokens.primarySubtle.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                                border: Border.all(color: RealtimeUiTokens.primaryBorder),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.school_rounded,
                                    size: 16,
                                    color: RealtimeUiTokens.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          strings.t('teacher'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: RealtimeUiTokens.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          q.answer!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: RealtimeUiTokens.text,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                borderSide: const BorderSide(color: RealtimeUiTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.surface,
                  borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                  border: Border.all(
                    color: s.canSpeak
                        ? RealtimeUiTokens.successBorder
                        : (s.handRaised ? RealtimeUiTokens.warning.withValues(alpha: 0.3) : RealtimeUiTokens.border),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: RealtimeUiTokens.warningSubtle,
                                    borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
                                    border: Border.all(color: RealtimeUiTokens.warning.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.pan_tool_rounded, size: 10, color: RealtimeUiTokens.warning),
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
                                  color: s.online ? RealtimeUiTokens.success : RealtimeUiTokens.textMuted,
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
                          side: const BorderSide(color: RealtimeUiTokens.dangerBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
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
                            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
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
    _subscription?.cancel();
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
    _subscription?.cancel();
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

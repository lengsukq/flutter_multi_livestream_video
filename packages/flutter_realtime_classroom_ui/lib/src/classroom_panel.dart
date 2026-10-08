import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
import 'classroom_tools_panel.dart';

/// Optional SDK-owned classroom UI styled to match Realtime SDK design tokens.
class ClassroomPanel extends StatefulWidget {
  const ClassroomPanel({super.key, required this.classroom});
  final ClassroomSession classroom;
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
          title: Text(strings.t('answer')),
          content: TextField(
            controller: ctrl,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: strings.t('answer'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
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

  Widget _statBadge(
    String label, {
    Color? fg,
    Color? bg,
    Color? border,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg ?? RealtimeUiTokens.surfaceSubtle,
      borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
      border: Border.all(color: border ?? RealtimeUiTokens.border),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: fg ?? RealtimeUiTokens.text,
      ),
    ),
  );

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
          // Stats bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _statBadge(
                  "${strings.t('online')} ${s.stats.onlineCount}",
                  fg: RealtimeUiTokens.success,
                  bg: RealtimeUiTokens.successSubtle,
                  border: RealtimeUiTokens.successBorder,
                ),
                if (s.tools != null) ...[
                  _statBadge(
                    "${strings.t('onlineStudents')} ${s.stats.onlineStudents}",
                  ),
                  _statBadge(
                    "${strings.t('studentsTotal')} ${s.stats.studentsTotal}",
                  ),
                ],
                _statBadge(
                  "${strings.t('hands')} ${s.stats.handsRaised}",
                  fg: s.stats.handsRaised > 0 ? RealtimeUiTokens.warning : null,
                  bg: s.stats.handsRaised > 0 ? RealtimeUiTokens.warningSubtle : null,
                ),
                _statBadge(
                  "${strings.t('pending')} ${s.stats.pendingQuestions}",
                  fg: s.stats.pendingQuestions > 0 ? RealtimeUiTokens.primary : null,
                  bg: s.stats.pendingQuestions > 0 ? RealtimeUiTokens.primarySubtle : null,
                ),
                _statBadge(
                  "${strings.t('messages')} ${s.stats.chatMessages}",
                ),
                if (s.isTeacher) ...[
                  _statBadge(
                    "${strings.t('handHistory')} ${s.stats.handRaisesTotal}",
                  ),
                  _statBadge(
                    "${strings.t('questionHistory')} ${s.stats.questionsTotal}",
                  ),
                  _statBadge(
                    "${strings.t('speakHistory')} ${s.stats.speakGrants}",
                  ),
                ],
              ],
            ),
          ),
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
              length: (s.isTeacher ? 3 : 2) + (s.tools != null ? 1 : 0),
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: RealtimeUiTokens.primary,
                    indicatorWeight: 2.5,
                    labelColor: RealtimeUiTokens.primary,
                    unselectedLabelColor: RealtimeUiTokens.textMuted,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    tabs: [
                      Tab(
                        text: s.isTeacher
                            ? strings.t('tabHands')
                            : strings.t('interact'),
                      ),
                      Tab(text: strings.t('qa')),
                      if (s.isTeacher) Tab(text: strings.t('students')),
                      if (s.tools != null) Tab(text: strings.t('tools')),
                    ],
                  ),
                  const Divider(height: 1, thickness: 1, color: RealtimeUiTokens.border),
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
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: canSpeak
                ? RealtimeUiTokens.successSubtle
                : RealtimeUiTokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
            border: Border.all(
              color: canSpeak
                  ? RealtimeUiTokens.successBorder
                  : RealtimeUiTokens.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canSpeak
                      ? RealtimeUiTokens.success.withValues(alpha: 0.14)
                      : RealtimeUiTokens.border,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  canSpeak ? Icons.mic : Icons.mic_off,
                  color: canSpeak
                      ? RealtimeUiTokens.success
                      : RealtimeUiTokens.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canSpeak
                          ? strings.t('granted')
                          : strings.t('waiting'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: canSpeak
                            ? RealtimeUiTokens.success
                            : RealtimeUiTokens.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.t(
                        state.capabilities.enforcesMicrophone
                            ? 'enforced'
                            : 'advisory',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: RealtimeUiTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: raised
                  ? RealtimeUiTokens.warning
                  : RealtimeUiTokens.primary,
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
    );
  }

  Widget _hands(ClassroomState state) {
    final strings = ClassroomStrings.of(context);
    if (state.raisedHands.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pan_tool_outlined,
              size: 44,
              color: RealtimeUiTokens.textMuted.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 10),
            Text(
              strings.t('none'),
              style: const TextStyle(
                color: RealtimeUiTokens.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.raisedHands.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = state.raisedHands[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: RealtimeUiTokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
            border: Border.all(color: RealtimeUiTokens.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.warningSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: RealtimeUiTokens.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.pan_tool_alt_outlined,
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
                    fontWeight: FontWeight.w600,
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
      },
    );
  }

  Widget _questions(ClassroomState state) {
    final strings = ClassroomStrings.of(context);
    final search = _questionSearch.text.trim().toLowerCase();
    final questions = state.questions
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
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionSearch,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: strings.t('searchQuestions'),
                    isDense: true,
                    filled: true,
                    fillColor: RealtimeUiTokens.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                  border: Border.all(color: RealtimeUiTokens.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ClassroomQuestionStatus?>(
                    value: _questionFilter,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(strings.t('filterAll')),
                      ),
                      ...ClassroomQuestionStatus.values.map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            strings.t(switch (value) {
                              ClassroomQuestionStatus.pending => 'filterPending',
                              ClassroomQuestionStatus.answered => 'filterAnswered',
                              ClassroomQuestionStatus.resolved => 'filterResolved',
                            }),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _questionFilter = value),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!state.isTeacher)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _question,
                    maxLength: 500,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: RealtimeUiTokens.surfaceSubtle,
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                        borderSide: const BorderSide(color: RealtimeUiTokens.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                        borderSide: const BorderSide(color: RealtimeUiTokens.border),
                      ),
                      hintText: strings.t('ask'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: RealtimeUiTokens.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 19),
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
          child: questions.isEmpty
              ? Center(
                  child: Text(
                    strings.t('none'),
                    style: const TextStyle(
                      color: RealtimeUiTokens.textMuted,
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final q = questions[index];
                    return Card(
                      elevation: 0,
                      color: RealtimeUiTokens.surfaceSubtle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                        side: const BorderSide(color: RealtimeUiTokens.border),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          q.status == ClassroomQuestionStatus.resolved
                              ? Icons.check_circle_outline
                              : (q.status == ClassroomQuestionStatus.pending
                                  ? Icons.help_outline
                                  : Icons.question_answer_outlined),
                          color: q.status == ClassroomQuestionStatus.resolved
                              ? RealtimeUiTokens.success
                              : (q.status == ClassroomQuestionStatus.pending
                                  ? RealtimeUiTokens.warning
                                  : RealtimeUiTokens.primary),
                        ),
                        title: Text(
                          q.text,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: RealtimeUiTokens.text,
                          ),
                        ),
                        subtitle: Text(
                          '${q.displayName} · ${strings.t(switch (q.status) {
                            ClassroomQuestionStatus.pending => 'filterPending',
                            ClassroomQuestionStatus.answered => 'filterAnswered',
                            ClassroomQuestionStatus.resolved => 'filterResolved',
                          })}'
                          '${q.answer == null ? '' : '\n${strings.t('teacher')}：${q.answer}'}',
                          style: const TextStyle(color: RealtimeUiTokens.textMuted),
                        ),
                        trailing: !state.isTeacher
                            ? null
                            : Wrap(
                                spacing: 0,
                                children: [
                                  if (q.status != ClassroomQuestionStatus.resolved)
                                    IconButton(
                                      tooltip: strings.t('answer'),
                                      onPressed: _busy ? null : () => _answer(q),
                                      icon: const Icon(Icons.reply_outlined),
                                    ),
                                  if (q.status != ClassroomQuestionStatus.resolved)
                                    IconButton(
                                      tooltip: strings.t('resolve'),
                                      onPressed: _busy
                                          ? null
                                          : () => _run(
                                              () => widget.classroom.resolveQuestion(
                                                q.id,
                                              ),
                                            ),
                                      icon: const Icon(Icons.done_all),
                                    ),
                                ],
                              ),
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
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _studentSearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: RealtimeUiTokens.surfaceSubtle,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: strings.t('search'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: students.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
                  border: Border.all(color: RealtimeUiTokens.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: s.handRaised
                            ? RealtimeUiTokens.warningSubtle
                            : RealtimeUiTokens.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: s.handRaised
                              ? RealtimeUiTokens.warning.withValues(alpha: 0.3)
                              : RealtimeUiTokens.border,
                        ),
                      ),
                      child: Icon(
                        s.handRaised ? Icons.pan_tool : Icons.person_outline,
                        size: 18,
                        color: s.handRaised
                            ? RealtimeUiTokens.warning
                            : RealtimeUiTokens.textMuted,
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
                              fontWeight: FontWeight.w600,
                              color: RealtimeUiTokens.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${s.online ? strings.t('online') : strings.t('offline')} · $mic · $camera",
                            style: const TextStyle(
                              fontSize: 11,
                              color: RealtimeUiTokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (s.canSpeak)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: RealtimeUiTokens.danger,
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
  backgroundColor: RealtimeUiTokens.surface,
  barrierColor: Colors.black54,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(RealtimeUiTokens.sheetRadius),
    ),
  ),
  builder: (ctx) => SizedBox(
    height: MediaQuery.sizeOf(ctx).height * 0.82,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ClassroomPanel(classroom: classroom),
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

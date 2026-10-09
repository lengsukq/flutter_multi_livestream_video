import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'classroom_strings.dart';

/// Optional SDK UI for the tools extension. All actions delegate to the SDK.
class ClassroomToolsPanel extends StatefulWidget {
  const ClassroomToolsPanel({super.key, required this.classroom});
  final ClassroomSession classroom;
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

  List<String> _options(String text) => text
      .split('\n')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  Future<void> _publish(String kind) async {
    if (_busy || _dialogOpen) return;
    setState(() => _dialogOpen = true);
    final strings = ClassroomStrings.of(context);
    final title = TextEditingController();
    final body = TextEditingController();
    final seconds = TextEditingController(text: '300');
    final due = TextEditingController();
    int? correct;
    var options = <String>[];
    Object? dialogError;
    var publishing = false;
    DialogRoute<void>? route;
    final activity = kind == 'quiz' || kind == 'poll';
    final single = kind == 'announcement' || kind == 'focus';
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    try {
      route = DialogRoute<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
            ),
            title: Text(strings.t(kind)),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      enabled: !publishing,
                      maxLength: single ? 1000 : 120,
                      decoration: InputDecoration(
                        labelText: strings.t(single ? 'text' : 'title'),
                      ),
                    ),
                    if (!single && kind != 'timer')
                      TextField(
                        controller: body,
                        enabled: !publishing,
                        maxLines: activity ? 5 : 3,
                        maxLength: 2000,
                        onChanged: activity
                            ? (value) => update(() {
                                final selected =
                                    correct != null && correct! < options.length
                                    ? options[correct!]
                                    : null;
                                options = _options(value);
                                correct =
                                    selected != null &&
                                        options
                                                .where((v) => v == selected)
                                                .length ==
                                            1
                                    ? options.indexOf(selected)
                                    : null;
                                dialogError = null;
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
                        ),
                      ),
                    if (kind == 'timer')
                      TextField(
                        controller: seconds,
                        enabled: !publishing,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: strings.t('seconds'),
                        ),
                      ),
                    if (kind == 'homework')
                      TextField(
                        controller: due,
                        enabled: !publishing,
                        decoration: const InputDecoration(
                          labelText: 'YYYY-MM-DD (optional)',
                        ),
                      ),
                    if (kind == 'quiz')
                      DropdownButtonFormField<int>(
                        key: ValueKey((options.join('\n'), correct)),
                        initialValue: correct,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: strings.t('correct'),
                        ),
                        items: List.generate(
                          options.length,
                          (index) => DropdownMenuItem(
                            value: index,
                            child: Text(
                              '${index + 1}. ${options[index]}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        onChanged: publishing
                            ? null
                            : (value) => update(() {
                                correct = value;
                                dialogError = null;
                              }),
                      ),
                    if (publishing) const LinearProgressIndicator(),
                    if (dialogError != null)
                      Text(
                        '$dialogError',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: publishing ? null : () => Navigator.pop(ctx),
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
                onPressed: publishing
                    ? null
                    : () async {
                        if (activity) {
                          options = _options(body.text);
                          final invalid =
                              options.length < 2 || options.length > 8
                              ? (zh ? '请输入 2–8 个选项。' : 'Enter 2–8 options.')
                              : options.toSet().length != options.length
                              ? (zh ? '选项不能重复。' : 'Options must be distinct.')
                              : kind == 'quiz' &&
                                    (correct == null ||
                                        correct! >= options.length)
                              ? (zh
                                    ? '请选择有效的正确答案。'
                                    : 'Select a valid correct answer.')
                              : null;
                          if (invalid != null) {
                            update(() => dialogError = invalid);
                            return;
                          }
                        }
                        update(() {
                          publishing = true;
                          dialogError = null;
                        });
                        try {
                          final session = widget.classroom;
                          switch (kind) {
                            case 'announcement':
                              await session.publishAnnouncement(
                                title.text.trim(),
                              );
                            case 'focus':
                              await session.remindFocus(title.text.trim());
                            case 'homework':
                              final dueText = due.text.trim();
                              final dueAt = dueText.isEmpty
                                  ? null
                                  : DateTime.tryParse(dueText);
                              if (dueText.isNotEmpty && dueAt == null) {
                                throw const FormatException('Invalid due date');
                              }
                              await session.publishHomework(
                                title: title.text.trim(),
                                instructions: body.text.trim(),
                                dueAt: dueAt,
                              );
                            case 'materials':
                              await session.shareMaterial(
                                title: title.text.trim(),
                                url: body.text.trim(),
                              );
                            case 'timer':
                              final duration = int.tryParse(
                                seconds.text.trim(),
                              );
                              if (duration == null) {
                                throw const FormatException(
                                  'Use a duration in seconds',
                                );
                              }
                              await session.startTimer(
                                title: title.text.trim(),
                                duration: Duration(seconds: duration),
                              );
                            case 'quiz':
                            case 'poll':
                              await session.publishActivity(
                                kind: kind == 'quiz'
                                    ? ClassroomActivityKind.quiz
                                    : ClassroomActivityKind.poll,
                                title: title.text.trim(),
                                options: options,
                                correctOption: kind == 'quiz' ? correct : null,
                              );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (error) {
                          if (ctx.mounted) {
                            update(() {
                              publishing = false;
                              dialogError = error;
                            });
                          }
                        }
                      },
                child: Text(strings.t('publish')),
              ),
            ],
          ),
        ),
      );
      await Navigator.of(context, rootNavigator: true).push(route);
    } finally {
      await route?.completed;
      title.dispose();
      body.dispose();
      seconds.dispose();
      due.dispose();
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
      final timer = tools.timer;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '$_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (state.isTeacher)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in <(String, IconData)>[
                  ('announcement', Icons.campaign_outlined),
                  ('focus', Icons.center_focus_strong),
                  ('homework', Icons.assignment_outlined),
                  ('materials', Icons.attach_file),
                  ('timer', Icons.timer_outlined),
                  ('quiz', Icons.quiz_outlined),
                  ('poll', Icons.poll_outlined),
                ])
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: RealtimeUiTokens.text,
                      side: const BorderSide(color: RealtimeUiTokens.border),
                      backgroundColor: RealtimeUiTokens.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                      ),
                    ),
                    onPressed: _busy || _dialogOpen
                        ? null
                        : () => _publish(item.$1),
                    icon: Icon(
                      item.$2,
                      size: 18,
                      color: RealtimeUiTokens.primary,
                    ),
                    label: Text(s.t(item.$1)),
                  ),
              ],
            ),
          if (timer != null)
            Card(
              elevation: 0,
              color: RealtimeUiTokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.cardRadius,
                ),
                side: const BorderSide(color: RealtimeUiTokens.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(timer.title),
                subtitle: Text(
                  timer.remaining().inSeconds == 0
                      ? s.t('ended')
                      : '${timer.remaining().inMinutes}:${(timer.remaining().inSeconds % 60).toString().padLeft(2, '0')}',
                ),
                trailing: state.isTeacher
                    ? IconButton(
                        tooltip: s.t('stopTimer'),
                        onPressed: _busy
                            ? null
                            : () => _run(widget.classroom.stopTimer),
                        icon: const Icon(Icons.stop_circle_outlined),
                      )
                    : null,
              ),
            ),
          for (final notice in tools.notices.reversed)
            Card(
              elevation: 0,
              color: RealtimeUiTokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.cardRadius,
                ),
                side: const BorderSide(color: RealtimeUiTokens.border),
              ),
              child: ListTile(
                leading: Icon(
                  notice.isFocusReminder
                      ? Icons.center_focus_strong
                      : Icons.campaign,
                ),
                title: Text(
                  s.t(notice.isFocusReminder ? 'focus' : 'announcement'),
                ),
                subtitle: SelectableText(notice.text),
              ),
            ),
          for (final activity in tools.activities.reversed)
            _activity(state, activity, s),
          for (final homework in tools.homework.reversed)
            Card(
              elevation: 0,
              color: RealtimeUiTokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.cardRadius,
                ),
                side: const BorderSide(color: RealtimeUiTokens.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: Text(homework.title),
                subtitle: SelectableText(
                  '${homework.instructions}${homework.dueAt == null ? '' : '\n${homework.dueAt!.toLocal()}'}',
                ),
              ),
            ),
          if (tools.materials.isNotEmpty)
            Text(s.t('linkOnly'), style: Theme.of(context).textTheme.bodySmall),
          for (final material in tools.materials.reversed)
            Card(
              elevation: 0,
              color: RealtimeUiTokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.cardRadius,
                ),
                side: const BorderSide(color: RealtimeUiTokens.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.attach_file),
                title: Text(material.title),
                subtitle: SelectableText(material.url),
                trailing: IconButton(
                  tooltip: s.t('open'),
                  icon: const Icon(Icons.open_in_new),
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
              ),
            ),
          if (tools.notices.isEmpty &&
              tools.homework.isEmpty &&
              tools.materials.isEmpty &&
              tools.activities.isEmpty &&
              timer == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(s.t('emptyTools')),
            ),
          if (state.attendance.isNotEmpty) ...[
            const Divider(),
            Text(
              s.t('attendance'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final attendance in state.attendance)
              ListTile(
                title: Text(attendance.displayName),
                subtitle: Text(
                  '${attendance.onlineDuration.inMinutes} ${s.t('minutes')} · ${s.t(attendance.online ? 'online' : 'offline')}\n'
                  '${s.t('firstJoined')}: ${attendance.firstJoinedAt?.toLocal() ?? '—'}'
                  '${attendance.lastLeftAt == null ? '' : '\n${s.t('lastLeft')}: ${attendance.lastLeftAt!.toLocal()}'}',
                ),
              ),
          ],
        ],
      );
    },
  );

  Widget _activity(
    ClassroomState state,
    ClassroomActivity activity,
    ClassroomStrings s,
  ) => Card(
    elevation: 0,
    color: RealtimeUiTokens.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
      side: const BorderSide(color: RealtimeUiTokens.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                activity.kind == ClassroomActivityKind.quiz
                    ? Icons.quiz_outlined
                    : Icons.poll_outlined,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activity.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (activity.closed) Chip(label: Text(s.t('ended'))),
            ],
          ),
          Text('${s.t('responses')}: ${activity.responseCount}'),
          for (var i = 0; i < activity.options.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                activity.selfAnswer == i
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(activity.options[i]),
              trailing: Wrap(
                spacing: 8,
                children: [
                  if (activity.correctOption == i)
                    const Icon(Icons.check_circle, color: Colors.green),
                  if (activity.counts != null) Text('${activity.counts![i]}'),
                ],
              ),
              onTap: state.isTeacher || activity.closed || _busy
                  ? null
                  : () => _run(
                      () => widget.classroom.answerActivity(activity.id, i),
                    ),
            ),
          if (state.isTeacher && activity.answers.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(s.t('responses')),
              children: [
                for (final answer in activity.answers.entries)
                  ListTile(
                    title: Text(
                      state.students
                              .where((student) => student.userId == answer.key)
                              .firstOrNull
                              ?.displayName ??
                          answer.key,
                    ),
                    subtitle: Text(activity.options[answer.value]),
                  ),
              ],
            ),
          if (state.isTeacher && !activity.closed)
            TextButton(
              onPressed: _busy
                  ? null
                  : () =>
                        _run(() => widget.classroom.closeActivity(activity.id)),
              child: Text(s.t('closeActivity')),
            ),
        ],
      ),
    ),
  );
}

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
                          RealtimeUiTokens.controlRadius,
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

    return AlertDialog(
      backgroundColor: RealtimeUiTokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.sheetRadius),
        side: const BorderSide(color: RealtimeUiTokens.border),
      ),
      title: Text(strings.t(kind)),
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
                decoration: InputDecoration(
                  labelText: strings.t(single ? 'text' : 'title'),
                ),
              ),
              if (!single && kind != 'timer')
                TextField(
                  controller: _body,
                  enabled: !_publishing,
                  maxLines: activity ? 5 : 3,
                  maxLength: 2000,
                  onChanged: activity
                      ? (value) => setState(() {
                          final selected =
                              _correct != null && _correct! < _options.length
                              ? _options[_correct!]
                              : null;
                          _options = _extractOptions(value);
                          _correct =
                              selected != null &&
                                  _options.where((v) => v == selected).length ==
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
                  ),
                ),
              if (kind == 'timer')
                TextField(
                  controller: _seconds,
                  enabled: !_publishing,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: strings.t('seconds')),
                ),
              if (kind == 'homework')
                TextField(
                  controller: _due,
                  enabled: !_publishing,
                  decoration: const InputDecoration(
                    labelText: 'YYYY-MM-DD (optional)',
                  ),
                ),
              if (kind == 'quiz')
                DropdownButtonFormField<int>(
                  key: ValueKey((_options.join('\n'), _correct)),
                  initialValue: _correct,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: strings.t('correct')),
                  items: List.generate(
                    _options.length,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(
                        '${index + 1}. ${_options[index]}',
                        overflow: TextOverflow.ellipsis,
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
              if (_publishing) const LinearProgressIndicator(),
              if (_dialogError != null)
                Text(
                  '$_dialogError',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _publishing ? null : () => Navigator.of(context).pop(),
          child: Text(strings.t('cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: RealtimeUiTokens.primary,
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

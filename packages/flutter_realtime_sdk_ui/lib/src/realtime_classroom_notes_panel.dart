import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'room_ui_controller.dart';
import 'classroom_sidebar_visuals.dart';

/// This export contains only authoritative notes, Q&A and class activities.
/// It is not an AI summary and its offsets are relative to room creation.
String buildClassroomLessonMinutes(
  ClassroomState state, {
  bool chinese = true,
}) {
  final lines = <String>[
    '# ${chinese ? '课堂纪要' : 'Lesson minutes'} – ${state.roomCode}',
    '',
    chinese
        ? '> 根据当前课堂真实记录生成。时间点从房间创建开始，不代表录制播放进度。'
        : '> Derived from actual classroom records. Offsets are from room creation, not the recording timeline.',
    '',
    '## ${chinese ? '笔记与章节' : 'Notes and chapters'}',
  ];
  for (final note in state.notes ?? <ClassroomNote>[]) {
    final min = note.elapsedSeconds ~/ 60;
    final sec = (note.elapsedSeconds % 60).toString().padLeft(2, '0');
    final kind = note.kind == ClassroomNoteKind.chapter
        ? (chinese ? '章节' : 'Chapter')
        : (chinese ? '笔记' : 'Note');
    lines.add('- [$min:$sec] $kind: ${note.text}');
  }
  if (state.notes?.isEmpty ?? true) {
    lines.add(chinese ? '- 暂无记录' : '- No notes recorded');
  }
  lines.addAll(['', '## ${chinese ? '课堂问答' : 'Questions'}']);
  for (final question in state.questions) {
    lines.add('- ${question.displayName}: ${question.text}');
    if (question.answer case final answer? when answer.isNotEmpty) {
      lines.add('  - ${chinese ? '回答' : 'Answer'}: $answer');
    }
  }
  if (state.questions.isEmpty) {
    lines.add(chinese ? '- 暂无问答' : '- No questions');
  }
  lines.addAll(['', '## ${chinese ? '课堂活动' : 'Activities'}']);
  for (final activity in state.tools?.activities ?? <ClassroomActivity>[]) {
    lines.add(
      '- ${activity.title} (${activity.kind.name}) – '
      '${activity.responseCount} ${chinese ? '人作答' : 'responses'}',
    );
  }
  if (state.tools?.activities.isEmpty ?? true) {
    lines.add(chinese ? '- 暂无活动' : '- No activities');
  }
  return lines.join('\n');
}

/// Teacher-only notes with real backend persistence (if configured).
/// The feature is absent for legacy classroom services.
class RealtimeClassroomNotesPanel extends StatefulWidget {
  const RealtimeClassroomNotesPanel({super.key});

  @override
  State<RealtimeClassroomNotesPanel> createState() =>
      _RealtimeClassroomNotesPanelState();
}

class _RealtimeClassroomNotesPanelState
    extends State<RealtimeClassroomNotesPanel> {
  final _composer = TextEditingController();
  bool _chapter = false;
  bool _saving = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _save(RealtimeRoomUiController controller) async {
    final text = _composer.text.trim();
    if (text.isEmpty || text.length > (_chapter ? 140 : 2000) || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await controller.addClassroomNote(text, chapter: _chapter);
      if (mounted) _composer.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(
    BuildContext context,
    ClassroomNote note,
    RealtimeRoomUiController controller,
  ) async {
    var edited = note.text;
    final changed = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(RealtimeStrings.of(dialog).isZh ? '编辑记录' : 'Edit note'),
        content: TextFormField(
          initialValue: note.text,
          onChanged: (value) => edited = value,
          maxLines: 4,
          maxLength: note.kind == ClassroomNoteKind.chapter ? 140 : 2000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(RealtimeStrings.of(dialog).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, edited.trim()),
            child: Text(RealtimeStrings.of(dialog).isZh ? '保存' : 'Save'),
          ),
        ],
      ),
    );
    if (changed != null && changed.isNotEmpty && changed != note.text) {
      try {
        await controller.updateClassroomNote(note.id, changed);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    ClassroomNote note,
    RealtimeRoomUiController controller,
  ) async {
    final zh = RealtimeStrings.of(context).isZh;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(zh ? '删除这条记录？' : 'Delete this note?'),
        content: Text(zh ? '删除后不能恢复。' : 'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(zh ? '取消' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(zh ? '删除' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await controller.deleteClassroomNote(note.id);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    final zh = strings.isZh;
    final style = RealtimeStyle.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.classroomState;
        if (!controller.canManageClassroomNotes || state?.notes == null) {
          return Center(
            child: Text(zh ? '课堂笔记服务不可用' : 'Notes service is unavailable'),
          );
        }
        final notes = state!.notes!;
        final file = state.notesPersistence == 'file';
        // The entire workspace scrolls, including the composer. A fixed
        // composer + Expanded list overflowed short desktop sidebars.
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: ClassroomSidebarCard(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClassroomSidebarSectionTitle(
                      title: zh ? '课堂记录' : 'Lesson notes',
                      icon: Icons.edit_note_rounded,
                      trailing: ClassroomSidebarStatus(
                        label: file
                            ? (zh ? '文件存储' : 'Server file')
                            : (zh ? '会话临时' : 'Session only'),
                        icon: file
                            ? Icons.cloud_done_outlined
                            : Icons.info_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      file
                          ? (zh
                                ? '服务端文件保存；关房前请导出纪要。'
                                : 'Stored on server disk. Export before closing the room.')
                          : (zh
                                ? '当前仅会话内保存；关房或重启会丢失。'
                                : 'Session-only storage. Closing or restarting removes notes.'),
                      style: TextStyle(fontSize: 11.5, color: style.textMuted),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('classroom-note-compose'),
                      controller: _composer,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: _chapter ? 140 : 2000,
                      decoration: InputDecoration(
                        hintText: _chapter
                            ? (zh ? '输入章节标题' : 'Chapter title')
                            : (zh ? '记录教学重点、学生待办…' : 'Lesson highlights…'),
                        filled: true,
                        fillColor: style.surface,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: style.border),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        isDense: true,
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                          label: Text(zh ? '笔记' : 'Note'),
                          selected: !_chapter,
                          onSelected: (_) => setState(() => _chapter = false),
                        ),
                        ChoiceChip(
                          label: Text(zh ? '章节标记' : 'Chapter'),
                          selected: _chapter,
                          onSelected: (_) => setState(() => _chapter = true),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _composer,
                          builder: (context, value, _) {
                            final text = value.text.trim();
                            final valid =
                                text.isNotEmpty &&
                                text.length <= (_chapter ? 140 : 2000);
                            return FilledButton(
                              key: const ValueKey('classroom-note-save'),
                              onPressed: _saving || !valid
                                  ? null
                                  : () => _save(controller),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(75, 38),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                _saving
                                    ? (zh ? '保存中' : 'Saving')
                                    : (zh ? '保存' : 'Save'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('classroom-minutes-copy'),
                        icon: const Icon(Icons.copy_all_outlined, size: 17),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text: buildClassroomLessonMinutes(
                                state,
                                chinese: zh,
                              ),
                            ),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(
                                content: Text(
                                  zh
                                      ? '课堂纪要已复制，请在关房前保存。'
                                      : 'Lesson minutes copied. Save them before leaving.',
                                ),
                              ),
                            );
                          }
                        },
                        label: Text(zh ? '复制课堂纪要' : 'Copy lesson minutes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
              child: ClassroomSidebarSectionTitle(
                title: zh ? '课堂时间线' : 'Lesson timeline',
                icon: Icons.timeline_rounded,
                trailing: ClassroomSidebarStatus(label: '${notes.length}'),
              ),
            ),
            notes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmarks_outlined,
                            size: 30,
                            color: style.textMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            zh ? '暂无课堂记录' : 'No lesson notes yet',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: style.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final note = notes[i];
                      final min = note.elapsedSeconds ~/ 60;
                      final sec = (note.elapsedSeconds % 60).toString().padLeft(
                        2,
                        '0',
                      );
                      return ClassroomSidebarCard(
                        padding: const EdgeInsets.all(11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  note.kind == ClassroomNoteKind.chapter
                                      ? Icons.bookmark_outline
                                      : Icons.edit_note_outlined,
                                  size: 17,
                                  color: style.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$min:$sec · ${note.kind == ClassroomNoteKind.chapter ? (zh ? '章节' : 'Chapter') : (zh ? '笔记' : 'Note')}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: style.textMuted,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: zh ? '编辑记录' : 'Edit note',
                                  iconSize: 17,
                                  onPressed: () =>
                                      _edit(context, note, controller),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: zh ? '删除记录' : 'Delete note',
                                  iconSize: 17,
                                  onPressed: () =>
                                      _delete(context, note, controller),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            Text(
                              note.text,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: style.text,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        );
      },
    );
  }
}

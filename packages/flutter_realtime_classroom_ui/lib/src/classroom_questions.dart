part of 'classroom_panel.dart';

extension _ClassroomQuestions on _ClassroomPanelState {
  Widget _questionFilterPill(
    ClassroomQuestionStatus? value,
    String label,
    int count,
  ) {
    final selected = _questionFilter == value;
    return RealtimeGlassPressable(
      borderRadius: RealtimeUiTokens.pillRadius,
      onTap: () => _update(() => _questionFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? RealtimeUiTokens.primarySubtle
              : RealtimeUiTokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
          border: Border.all(
            color: selected
                ? RealtimeUiTokens.primary
                : RealtimeUiTokens.border,
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
                color: selected
                    ? RealtimeUiTokens.primary
                    : RealtimeUiTokens.textMuted,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              RealtimeBadge(
                text: '$count',
                color: Colors.white,
                backgroundColor: selected
                    ? RealtimeUiTokens.primary
                    : RealtimeUiTokens.borderStrong,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _questions(ClassroomState state) {
    final strings = ClassroomStrings.of(context);
    final search = _questionSearch.text.trim().toLowerCase();

    final allQuestions = state.questions;
    final pendingCount = allQuestions
        .where((q) => q.status == ClassroomQuestionStatus.pending)
        .length;
    final answeredCount = allQuestions
        .where((q) => q.status == ClassroomQuestionStatus.answered)
        .length;
    final resolvedCount = allQuestions
        .where((q) => q.status == ClassroomQuestionStatus.resolved)
        .length;

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
                onChanged: (_) => _update(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 19),
                  hintText: strings.t('searchQuestions'),
                  isDense: true,
                  filled: true,
                  fillColor: RealtimeUiTokens.surfaceSubtle,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    borderSide: const BorderSide(
                      color: RealtimeUiTokens.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.controlRadius,
                    ),
                    borderSide: const BorderSide(
                      color: RealtimeUiTokens.border,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _questionFilterPill(
                      null,
                      strings.t('filterAll'),
                      allQuestions.length,
                    ),
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
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
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
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
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
                        color: RealtimeUiTokens.textMuted.withValues(
                          alpha: 0.45,
                        ),
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
                    final isAnswered =
                        q.status == ClassroomQuestionStatus.answered;
                    final isResolved =
                        q.status == ClassroomQuestionStatus.resolved;

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
                      tagBorder = RealtimeUiTokens.warning.withValues(
                        alpha: 0.3,
                      );
                      tagFg = RealtimeUiTokens.warning;
                      tagLabel = strings.t('filterPending');
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: RealtimeUiTokens.surface,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.cardRadius,
                        ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tagBg,
                                  borderRadius: BorderRadius.circular(
                                    RealtimeUiTokens.pillRadius,
                                  ),
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
                              Expanded(
                                child: Text(
                                  q.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: RealtimeUiTokens.text,
                                  ),
                                ),
                              ),
                              if (state.isTeacher && !isResolved) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: strings.t('answer'),
                                  splashRadius: 18,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.reply_rounded,
                                    size: 20,
                                    color: RealtimeUiTokens.primary,
                                  ),
                                  onPressed: _busy ? null : () => _answer(q),
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  tooltip: strings.t('resolve'),
                                  splashRadius: 18,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 20,
                                    color: RealtimeUiTokens.success,
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => widget.classroom
                                              .resolveQuestion(q.id),
                                        ),
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
                                color: RealtimeUiTokens.primarySubtle
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(
                                  RealtimeUiTokens.compactRadius,
                                ),
                                border: Border.all(
                                  color: RealtimeUiTokens.primaryBorder,
                                ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
}

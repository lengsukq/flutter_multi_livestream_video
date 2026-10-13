import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'room_classroom_activities.dart';
import 'room_classroom_interactions.dart';
import 'room_ui_controller.dart';
import 'realtime_classroom_panel.dart';

class MeetingDockRealtimeClassroomPanelState extends State<RealtimeClassroomPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final theme = Theme.of(context);
    final style = RealtimeStyle.of(context);
    final controller = RealtimeRoomUiScope.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: style.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: style.border),
                  ),
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final state = controller.classroomState;
                      final pendingQ = state?.stats.pendingQuestions ?? 0;
                      final raisedHands = state?.stats.handsRaised ?? 0;

                      return TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: style.surface,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        labelColor: style.primary,
                        unselectedLabelColor: style.textMuted,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(strings.classroomQuestions),
                                if (pendingQ > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: style.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$pendingQ',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
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
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(strings.classroomHands),
                                if (raisedHands > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: RealtimeUiTokens.iosOrange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$raisedHands',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Tab(text: strings.classroomRoster),
                          Tab(text: strings.classroomActivities),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (widget.showHeader && widget.onClose != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: strings.closePanel,
                  onPressed: widget.onClose,
                  iconSize: 18,
                  style: IconButton.styleFrom(
                    backgroundColor: style.surfaceSubtle,
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(28, 28),
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
        ),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              Column(
                children: [
                  const Expanded(child: RealtimeClassroomQuestions()),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      if (!controller.canAskQuestion) {
                        return const SizedBox.shrink();
                      }
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(10, 4, 10, 10),
                        child: RealtimeClassroomQuestionComposer(),
                      );
                    },
                  ),
                ],
              ),
              const RealtimeClassroomHandQueue(),
              const RealtimeClassroomRoster(),
              const RealtimeClassroomActivityList(),
            ],
          ),
        ),
      ],
    );
  }
}

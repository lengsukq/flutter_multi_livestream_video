class ClassroomCapabilities {
  const ClassroomCapabilities({
    required this.canRaiseHand,
    required this.canAskQuestion,
    required this.canManageQuestions,
    required this.canGrantSpeak,
    required this.canViewRoster,
    this.enforcesMicrophone = false,
    this.canUseTools = false,
    this.canPublishTools = false,
    this.canSendFeedback = false,
    this.canViewFeedback = false,
  });
  final bool canRaiseHand, canAskQuestion, canManageQuestions, canGrantSpeak;
  final bool canViewRoster, enforcesMicrophone;
  final bool canUseTools, canPublishTools;
  final bool canSendFeedback, canViewFeedback;
}

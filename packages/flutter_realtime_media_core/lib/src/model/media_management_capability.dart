enum ManagementExecution { client, backend, hybrid, unsupported }

class ManagementCapability {
  const ManagementCapability({required this.execution, this.reason});

  const ManagementCapability.client({String? reason})
    : this(execution: ManagementExecution.client, reason: reason);

  const ManagementCapability.backend({String? reason})
    : this(execution: ManagementExecution.backend, reason: reason);

  const ManagementCapability.hybrid({String? reason})
    : this(execution: ManagementExecution.hybrid, reason: reason);

  const ManagementCapability.unsupported({String? reason})
    : this(execution: ManagementExecution.unsupported, reason: reason);

  final ManagementExecution execution;
  final String? reason;

  bool get supported => execution != ManagementExecution.unsupported;
  bool get requiresBackend =>
      execution == ManagementExecution.backend ||
      execution == ManagementExecution.hybrid;
  bool get canExecuteOnClient =>
      execution == ManagementExecution.client ||
      execution == ManagementExecution.hybrid;
}

class MediaManagementCapabilities {
  const MediaManagementCapabilities({
    this.listParticipants = const ManagementCapability.unsupported(),
    this.removeParticipant = const ManagementCapability.unsupported(),
    this.muteParticipant = const ManagementCapability.unsupported(),
    this.stopParticipantVideo = const ManagementCapability.unsupported(),
    this.changeParticipantRole = const ManagementCapability.unsupported(),
    this.closeRoom = const ManagementCapability.unsupported(),
  });

  final ManagementCapability listParticipants;
  final ManagementCapability removeParticipant;
  final ManagementCapability muteParticipant;
  final ManagementCapability stopParticipantVideo;
  final ManagementCapability changeParticipantRole;
  final ManagementCapability closeRoom;
}

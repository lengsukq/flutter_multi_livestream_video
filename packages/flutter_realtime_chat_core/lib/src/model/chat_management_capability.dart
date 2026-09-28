enum ChatManagementExecution { client, backend, hybrid, unsupported }

class ChatManagementCapability {
  const ChatManagementCapability({required this.execution, this.reason});

  const ChatManagementCapability.client({String? reason})
    : this(execution: ChatManagementExecution.client, reason: reason);
  const ChatManagementCapability.backend({String? reason})
    : this(execution: ChatManagementExecution.backend, reason: reason);
  const ChatManagementCapability.hybrid({String? reason})
    : this(execution: ChatManagementExecution.hybrid, reason: reason);
  const ChatManagementCapability.unsupported({String? reason})
    : this(execution: ChatManagementExecution.unsupported, reason: reason);

  final ChatManagementExecution execution;
  final String? reason;
  bool get supported => execution != ChatManagementExecution.unsupported;
}

class ChatManagementCapabilities {
  const ChatManagementCapabilities({
    this.listMembers = const ChatManagementCapability.unsupported(),
    this.removeMember = const ChatManagementCapability.unsupported(),
    this.muteMember = const ChatManagementCapability.unsupported(),
    this.banMember = const ChatManagementCapability.unsupported(),
    this.deleteMessage = const ChatManagementCapability.unsupported(),
    this.recallMessage = const ChatManagementCapability.unsupported(),
    this.manageRoles = const ChatManagementCapability.unsupported(),
    this.closeRoom = const ChatManagementCapability.unsupported(),
  });

  final ChatManagementCapability listMembers;
  final ChatManagementCapability removeMember;
  final ChatManagementCapability muteMember;
  final ChatManagementCapability banMember;
  final ChatManagementCapability deleteMessage;
  final ChatManagementCapability recallMessage;
  final ChatManagementCapability manageRoles;
  final ChatManagementCapability closeRoom;
}

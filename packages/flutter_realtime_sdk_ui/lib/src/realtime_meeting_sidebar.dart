import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Participant item model for the sidebar list.
class RealtimeMeetingMemberItem {
  const RealtimeMeetingMemberItem({
    required this.id,
    required this.name,
    this.roleTitle,
    this.avatarUrl,
    this.isMuted = true,
    this.isVideoOff = false,
  });

  final String id;
  final String name;
  final String? roleTitle;
  final String? avatarUrl;
  final bool isMuted;
  final bool isVideoOff;
}

/// Right integrated sidebar with Apple Sliding Segmented Tabs (Chat / Participants)
/// matching Reference Image 2.
class RealtimeMeetingSidebar extends StatefulWidget {
  const RealtimeMeetingSidebar({
    super.key,
    required this.members,
    this.invitedMembers = const [],
    this.chatWidget,
    this.membersWidget,
    this.initialTab = 0,
    this.onClose,
  });

  final List<RealtimeMeetingMemberItem> members;
  final List<RealtimeMeetingMemberItem> invitedMembers;
  final Widget? chatWidget;
  final Widget? membersWidget;
  final int initialTab;
  final VoidCallback? onClose;

  @override
  State<RealtimeMeetingSidebar> createState() => _RealtimeMeetingSidebarState();
}

class _RealtimeMeetingSidebarState extends State<RealtimeMeetingSidebar> {
  late int _selectedTab;
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant RealtimeMeetingSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _selectedTab = widget.initialTab;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? RealtimeUiTokens.canvasDarkElevated : style.surface,
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0x2EFFFFFF) : style.border,
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        children: [
          // 1. Top Bar: Segmented Tabs [ Chat ] | [ Participants (N) ]
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: RealtimeSegmentedTabs<int>(
                    height: 40,
                    selectedValue: _selectedTab,
                    onChanged: (val) => setState(() => _selectedTab = val),
                    tabs: [
                      const RealtimeSegmentTab(value: 0, label: 'Chat'),
                      RealtimeSegmentTab(
                        value: 1,
                        label: 'Participants',
                        badge: widget.members.length,
                      ),
                    ],
                  ),
                ),
                if (widget.onClose != null) ...[
                  const SizedBox(width: 8),
                  RealtimeGlassIconButton(
                    icon: Icons.close_rounded,
                    size: 36,
                    radius: RealtimeUiTokens.compactRadius,
                    onPressed: widget.onClose,
                    tooltip: 'Close Sidebar',
                  ),
                ],
              ],
            ),
          ),

          // 2. Body: Tab 0 (Chat) or Tab 1 (Participants)
          Expanded(
            child: _selectedTab == 0
                ? (widget.chatWidget ?? const Center(child: Text('Chat Feed')))
                : widget.membersWidget ?? _buildParticipantsView(context),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsView(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;

    final filteredActive = widget.members
        .where((m) => m.name.toLowerCase().contains(_filter.toLowerCase()))
        .toList();
    final filteredInvited = widget.invitedMembers
        .where((m) => m.name.toLowerCase().contains(_filter.toLowerCase()))
        .toList();

    return Column(
      children: [
        // Search Input Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.compactRadius,
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE5E5EA),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 18, color: style.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _filter = val),
                    style: TextStyle(fontSize: 13, color: style.text),
                    decoration: InputDecoration(
                      hintText: 'Type to search',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: style.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Member List Groups
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // In Meeting Section
              _buildSectionHeader('In meeting (${filteredActive.length})'),
              const SizedBox(height: 6),
              ...filteredActive.map(
                (m) => _buildMemberTile(m, isInvited: false),
              ),

              // Invited People Section
              if (filteredInvited.isNotEmpty) ...[
                const SizedBox(height: 18),
                _buildSectionHeader(
                  'Invited people (${filteredInvited.length})',
                ),
                const SizedBox(height: 6),
                ...filteredInvited.map(
                  (m) => _buildMemberTile(m, isInvited: true),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: RealtimeUiTokens.appleTeal,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildMemberTile(
    RealtimeMeetingMemberItem member, {
    required bool isInvited,
  }) {
    final style = RealtimeStyle.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          RealtimeAvatar(
            name: member.name,
            avatarUrl: member.avatarUrl,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: style.text,
                  ),
                ),
                if (member.roleTitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    member.roleTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: style.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isInvited)
            Icon(
              member.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              size: 16,
              color: member.isMuted
                  ? RealtimeUiTokens.appleDanger
                  : RealtimeUiTokens.appleTeal,
            ),
        ],
      ),
    );
  }
}

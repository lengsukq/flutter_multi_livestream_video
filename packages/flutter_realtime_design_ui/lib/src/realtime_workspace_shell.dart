part of '../flutter_realtime_design_ui.dart';

/// Adaptive top-level navigation; destination state remains owned by the host.
class RealtimeWorkspaceShell extends StatefulWidget {
  const RealtimeWorkspaceShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.header,
    this.compactNavigation = false,
  });
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  /// Persistent host header, above navigation and the scrollable workspace.
  final Widget? header;

  /// Uses the reference 60 pt tool rail and a flat mobile navigation bar.
  final bool compactNavigation;

  @override
  State<RealtimeWorkspaceShell> createState() => _RealtimeWorkspaceShellState();
}

class _RealtimeWorkspaceShellState extends State<RealtimeWorkspaceShell> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = RealtimeBreakpoints.isWide(context, constraints.maxWidth);
      final style = RealtimeStyle.of(context);
      return RealtimeAmbientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            bottom: wide,
            child: Column(
              children: [
                if (widget.header != null) widget.header!,
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide && widget.compactNavigation)
                        Container(
                          width: 60,
                          decoration: BoxDecoration(
                            color: style.surface,
                            border: Border(
                              right: BorderSide(color: style.border),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < widget.destinations.length;
                                  i++
                                )
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: IconButton(
                                      key: ValueKey('realtime-destination-$i'),
                                      tooltip: widget.destinations[i].label,
                                      isSelected: i == widget.selectedIndex,
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            i == widget.selectedIndex
                                            ? style.accent
                                            : Colors.transparent,
                                        foregroundColor: style.textMuted,
                                        highlightColor: style.accentSoft,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      selectedIcon: IconTheme(
                                        data: IconThemeData(
                                          color: style.onAccent,
                                        ),
                                        child:
                                            widget
                                                .destinations[i]
                                                .selectedIcon ??
                                            widget.destinations[i].icon,
                                      ),
                                      icon: widget.destinations[i].icon,
                                      onPressed: () =>
                                          widget.onDestinationSelected(i),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (wide && !widget.compactNavigation)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                          child: RealtimeGlassSurface(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            blur: RealtimeUiTokens.blur,
                            child: Column(
                              children: [
                                IconButton(
                                  tooltip: MaterialLocalizations.of(
                                    context,
                                  ).showMenuTooltip,
                                  onPressed: () =>
                                      setState(() => _expanded = !_expanded),
                                  icon: const Icon(Icons.menu_rounded),
                                ),
                                Expanded(
                                  child: NavigationRail(
                                    extended: _expanded,
                                    minExtendedWidth: 190,
                                    selectedIndex: widget.selectedIndex,
                                    onDestinationSelected:
                                        widget.onDestinationSelected,
                                    destinations: widget.destinations
                                        .map(
                                          (destination) =>
                                              NavigationRailDestination(
                                                icon: destination.icon,
                                                selectedIcon:
                                                    destination.selectedIcon,
                                                label: Text(destination.label),
                                              ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : widget.compactNavigation
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: style.surface,
                    border: Border(top: BorderSide(color: style.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: NavigationBar(
                      height:
                          64 +
                          (MediaQuery.textScalerOf(context).scale(13) - 13)
                              .clamp(0, 26),
                      selectedIndex: widget.selectedIndex,
                      onDestinationSelected: widget.onDestinationSelected,
                      destinations: widget.destinations,
                    ),
                  ),
                )
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: RealtimeGlassSurface(
                      radius: RealtimeUiTokens.pillRadius,
                      blur: RealtimeUiTokens.blur,
                      child: NavigationBar(
                        height:
                            72 +
                            (MediaQuery.textScalerOf(context).scale(13) - 13)
                                .clamp(0, 26),
                        selectedIndex: widget.selectedIndex,
                        onDestinationSelected: widget.onDestinationSelected,
                        destinations: widget.destinations,
                      ),
                    ),
                  ),
                ),
        ),
      );
    },
  );
}

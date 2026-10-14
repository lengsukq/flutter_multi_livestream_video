part of '../flutter_realtime_design_ui.dart';

/// Adaptive top-level navigation; destination state remains owned by the host.
class RealtimeWorkspaceShell extends StatefulWidget {
  const RealtimeWorkspaceShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  State<RealtimeWorkspaceShell> createState() => _RealtimeWorkspaceShellState();
}

class _RealtimeWorkspaceShellState extends State<RealtimeWorkspaceShell> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 1000 &&
          MediaQuery.textScalerOf(context).scale(17) < 28;
      return RealtimeAmbientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            bottom: wide,
            child: Row(
              children: [
                if (wide)
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
                                    (destination) => NavigationRailDestination(
                                      icon: destination.icon,
                                      selectedIcon: destination.selectedIcon,
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
          bottomNavigationBar: wide
              ? null
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

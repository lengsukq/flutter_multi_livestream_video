import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';

void main() => runApp(const DesignExample());

/// This example does not import, register or initialize a media provider.
class DesignExample extends StatelessWidget {
  const DesignExample({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: RealtimeUiTheme.light(
      appearance: const RealtimeUiThemeExtension().copyWith(
        palette: RealtimeStyle.light.copyWith(primary: const Color(0xFF503C2B)),
        cardRadius: 32,
      ),
    ),
    home: const _Workspace(),
  );
}

class _Workspace extends StatefulWidget {
  const _Workspace();
  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> {
  int _selected = 0;
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RealtimeWorkspaceShell(
    selectedIndex: _selected,
    onDestinationSelected: (index) => setState(() => _selected = index),
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        label: 'Settings',
      ),
    ],
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: RealtimeCardSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _selected == 0 ? 'Your workspace' : 'Your preferences',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            RealtimeGlassTextField(controller: _name, label: 'Display name'),
            const SizedBox(height: 24),
            FilledButton(onPressed: () {}, child: const Text('Save changes')),
          ],
        ),
      ),
    ),
  );
}

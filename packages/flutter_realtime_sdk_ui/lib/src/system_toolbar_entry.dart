import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'package:flutter_realtime_whiteboard_ui/flutter_realtime_whiteboard_ui.dart';

/// Entrypoint for the secondary FlutterEngine hosting the system floating toolbar.
@pragma('vm:entry-point')
void systemAnnotationToolbarMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SystemAnnotationToolbarApp());
}

/// Standalone lightweight host application for the floating annotation toolbar.
class SystemAnnotationToolbarApp extends StatefulWidget {
  const SystemAnnotationToolbarApp({super.key});

  @override
  State<SystemAnnotationToolbarApp> createState() =>
      _SystemAnnotationToolbarAppState();
}

class _SystemAnnotationToolbarAppState
    extends State<SystemAnnotationToolbarApp> {
  static const _channel = MethodChannel(
    'flutter_realtime_screen_annotation_toolbar',
  );

  AnnotationTool _tool = AnnotationTool.pen;
  bool _drawingEnabled = true;
  bool _canEdit = true;
  bool _canUndo = true;
  bool _canClear = true;
  bool _collapsed = false;
  String _languageCode = 'en';

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_onMethodCall);
    observeDetached(_channel.invokeMethod<void>('ready').catchError((_) {}));
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'init':
      case 'update':
        final args = call.arguments as Map<dynamic, dynamic>? ?? {};
        setState(() {
          if (args['languageCode'] is String) {
            _languageCode = args['languageCode'] as String;
          }
          if (args['drawing'] is bool) {
            _drawingEnabled = args['drawing'] as bool;
          }
          if (args['canEdit'] is bool) {
            _canEdit = args['canEdit'] as bool;
          }
          if (args['canUndo'] is bool) {
            _canUndo = args['canUndo'] as bool;
          }
          if (args['canClear'] is bool) {
            _canClear = args['canClear'] as bool;
          }
          if (args['tool'] is String) {
            final toolName = args['tool'] as String;
            _tool = AnnotationTool.values.firstWhere(
              (t) => t.name == toolName,
              orElse: () => AnnotationTool.pen,
            );
          }
        });
        return null;
      default:
        return null;
    }
  }

  void _onToolSelected(AnnotationTool tool) {
    setState(() {
      _tool = tool;
      _drawingEnabled = true;
    });
    observeDetached(_channel.invokeMethod('selectTool', {'tool': tool.name}));
  }

  void _onDrawingToggle() {
    final next = !_drawingEnabled;
    setState(() => _drawingEnabled = next);
    observeDetached(_channel.invokeMethod('toggleDrawing', {'drawing': next}));
  }

  void _onUndo() {
    observeDetached(_channel.invokeMethod('undo'));
  }

  void _onClear() {
    observeDetached(_channel.invokeMethod('clear'));
  }

  void _onClose() {
    observeDetached(_channel.invokeMethod('close'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(_languageCode),
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
          surface: const Color(0xE6202530),
        ),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: _collapsed ? _buildCollapsedBubble() : _buildExpandedToolbar(),
        ),
      ),
    );
  }

  Widget _buildCollapsedBubble() {
    return Material(
      color: const Color(0xE6202530),
      elevation: 6,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _collapsed = false),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.edit, color: Colors.amber, size: 22),
        ),
      ),
    );
  }

  Widget _buildExpandedToolbar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnnotationToolbar(
          tool: _tool,
          drawingEnabled: _drawingEnabled,
          canEdit: _canEdit,
          canUndo: _canUndo,
          canClear: _canClear,
          onToolChanged: _onToolSelected,
          onDrawingToggle: _onDrawingToggle,
          onUndo: _onUndo,
          onClear: _onClear,
          onClose: _onClose,
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: _languageCode == 'zh' ? '收起工具条' : 'Collapse toolbar',
          icon: const Icon(Icons.chevron_left, size: 18),
          onPressed: () => setState(() => _collapsed = true),
        ),
      ],
    );
  }
}

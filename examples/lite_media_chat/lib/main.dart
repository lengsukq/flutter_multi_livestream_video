import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_provider_livekit/flutter_realtime_provider_livekit.dart';
import 'package:flutter_realtime_provider_ivs_chat/flutter_realtime_provider_ivs_chat.dart';

void main() => runApp(const MaterialApp(home: LiteExample()));

class LiteExample extends StatefulWidget {
  const LiteExample({super.key});
  @override
  State<LiteExample> createState() => _LiteExampleState();
}

class _LiteExampleState extends State<LiteExample> {
  final _code = TextEditingController();
  final _name = TextEditingController(text: 'Guest');
  late final _realtime = Realtime(
    backendUrl: const String.fromEnvironment('REALTIME_BACKEND_URL'),
    providers: [createLivekitProvider(), createIvsChatProvider()],
  );
  RealtimeConnection? _connection;
  bool _joining = false;
  String? _error;
  Future<void> _join() async {
    if (_joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final connection = await _realtime.open(
        RealtimeRequest.join(
          type: RealtimeExperience.meeting,
          roomCode: _code.text,
          user: RealtimeUser(id: _name.text, name: _name.text),
        ),
      );
      if (!mounted) {
        await connection.dispose();
        return;
      }
      setState(() => _connection = connection);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _connection?.mediaRoom;
    if (room != null) {
      return RealtimeRoomView(
        room: room,
        onLeave: () => setState(() => _connection = null),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Realtime Lite')),
      body: Center(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Room code'),
              ),
              if (_error != null) Text(_error!),
              FilledButton(
                onPressed: _joining ? null : _join,
                child: Text(_joining ? 'Joining…' : 'Join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

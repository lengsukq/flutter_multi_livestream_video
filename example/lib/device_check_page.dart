import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_aws_chime/handlers/method_channel_coordinator.dart';
import 'package:flutter_aws_chime/models/meeting.model.dart';
import 'package:http/http.dart' as http;

/// Device self-test: camera preview, mic/speaker status, server reachability.
/// Runs before joining any room. Chime join is NOT required here.
class DeviceCheckPage extends StatefulWidget {
  final String server;

  const DeviceCheckPage({super.key, required this.server});

  @override
  State<DeviceCheckPage> createState() => _DeviceCheckPageState();
}

class _DeviceCheckPageState extends State<DeviceCheckPage> {
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  String _cameraStatus = '未开始';
  String _micStatus = '未开始';
  String _speakerStatus = '未开始';
  String _serverStatus = '未开始';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runAll();
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _runAll() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _cameraStatus = '检测中…';
      _micStatus = '检测中…';
      _speakerStatus = '检测中…';
      _serverStatus = '检测中…';
    });
    // Order matters: camera preview FIRST while it owns the HAL.
    // Mic/speaker check pops the Chime permission dialog, which backgrounds
    // the preview surface and blanks it on some OEM ROMs (Xiaomi/MIUI).
    await _checkCamera();
    await _checkServer();
    await _checkMicAndSpeaker();
    // Re-assert preview: if the permission dialog stole the surface, the
    // controller is still alive but the texture went dark — rebind it.
    if (mounted && _camera != null) {
      try {
        await _camera!.pausePreview();
        await _camera!.resumePreview();
      } catch (_) {}
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _checkCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraStatus = '❌ 没找到摄像头（模拟器常见，真机不应出现）');
        return;
      }
      await _startPreview(0);
      setState(() => _cameraStatus = '✅ 找到 ${_cameras.length} 个摄像头，预览中');
    } catch (e) {
      setState(() => _cameraStatus = '❌ 摄像头打不开：$e\n去系统设置给 App 开相机权限后点重测');
    }
  }

  Future<void> _startPreview(int index) async {
    await _camera?.dispose();
    _camera = null;
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _camera = controller;
      _cameraIndex = index;
    });
  }

  Future<void> _switchPreviewCamera() async {
    if (_cameras.length < 2) return;
    await _startPreview((_cameraIndex + 1) % _cameras.length);
  }

  /// Mic/speaker check goes through the Chime permission + device path so it
  /// reflects what join() will actually see. No meeting is created.
  Future<void> _checkMicAndSpeaker() async {
    try {
      final coordinator = MethodChannelCoordinator();
      final PermissionCheckResult perm = await coordinator.checkPermissions();
      if (!perm.audio) {
        setState(() {
          _micStatus = '❌ 麦克风权限被拒 — 去系统设置打开后点重测';
          _speakerStatus = '—（等麦克风通过再看）';
        });
        return;
      }
      setState(() => _micStatus = '✅ 麦克风权限通过');
      final AudioCheckResult audio = await coordinator.checkAudioDevices();
      if (audio.devices.isEmpty && audio.activeDevice == null) {
        // No active meeting yet on a fresh install — device list needs a
        // session. Permission pass is the meaningful signal here.
        setState(() => _speakerStatus = '✅ 权限通过（扬声器列表需进房后可见）');
      } else {
        setState(() => _speakerStatus =
            '✅ 输出：${audio.activeDevice ?? '未知'}（共 ${audio.devices.length} 个设备）');
      }
    } catch (e) {
      setState(() {
        _micStatus = '❌ 检测异常：$e';
        _speakerStatus = '—';
      });
    }
  }

  Future<void> _checkServer() async {
    try {
      final base = widget.server.endsWith('/')
          ? widget.server.substring(0, widget.server.length - 1)
          : widget.server;
      final resp = await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        setState(() => _serverStatus = '✅ 后端连通：$base');
      } else {
        setState(() => _serverStatus = '❌ 后端 HTTP ${resp.statusCode}：$base');
      }
    } on SocketException {
      setState(() => _serverStatus = '❌ 连不上 ${widget.server}\n同 WiFi？IP 填的是 Mac 的 192.168.x.x？');
    } on TimeoutException {
      setState(() => _serverStatus = '❌ 连接超时 ${widget.server}');
    } catch (e) {
      setState(() => _serverStatus = '❌ $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备自检'),
        actions: [
          IconButton(
            tooltip: '重测',
            onPressed: _busy ? null : _runAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('进房前先过一遍：哪项红了就先修哪项，不用猜。',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            _section(
              icon: Icons.videocam,
              title: '摄像头',
              status: _cameraStatus,
              child: _camera == null
                  ? const SizedBox(
                      height: 160,
                      child: Center(child: Text('无预览 — 看上面的状态')),
                    )
                  : Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CameraPreview(_camera!),
                          ),
                        ),
                        if (_cameras.length > 1)
                          TextButton.icon(
                            onPressed: _switchPreviewCamera,
                            icon: const Icon(Icons.flip_camera_android),
                            label: const Text('切换前后摄试试'),
                          ),
                      ],
                    ),
            ),
            _section(icon: Icons.mic, title: '麦克风', status: _micStatus),
            _section(icon: Icons.volume_up, title: '扬声器', status: _speakerStatus),
            _section(
              icon: Icons.dns,
              title: '服务器 ${widget.server}',
              status: _serverStatus,
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _runAll,
              icon: const Icon(Icons.refresh),
              label: Text(_busy ? '检测中…' : '重新检测'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                // Leave a breadcrumb for join(): local mic state snapshot.
                try {
                  MeetingModel();
                } catch (_) {}
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.check),
              label: const Text('自检通过，去加入房间'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String status,
    Widget? child,
  }) {
    final ok = status.startsWith('✅');
    final bad = status.startsWith('❌');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon,
                  color: ok ? Colors.green : (bad ? Colors.red : Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(status, style: const TextStyle(fontSize: 13)),
            if (child != null) ...[const SizedBox(height: 8), child],
          ],
        ),
      ),
    );
  }
}

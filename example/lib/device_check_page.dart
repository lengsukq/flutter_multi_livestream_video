import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_aws_chime/handlers/method_channel_coordinator.dart';
import 'package:flutter_aws_chime/models/meeting.model.dart';
import 'package:http/http.dart' as http;

import 'widgets/glass_widgets.dart';

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
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '设备就绪自检',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '重新检测',
            onPressed: _busy ? null : _runAll,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Color(0xFF818CF8), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '进房前先过一遍：哪项红了就先修哪项，保障通话顺畅。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _section(
                icon: Icons.videocam_rounded,
                title: '摄像头设备',
                status: _cameraStatus,
                child: _camera == null
                    ? Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '无画面预览（请看上方状态）',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: CameraPreview(_camera!),
                            ),
                          ),
                          if (_cameras.length > 1) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _switchPreviewCamera,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.flip_camera_ios_rounded,
                                        size: 16, color: Color(0xFF818CF8)),
                                    SizedBox(width: 6),
                                    Text(
                                      '切换前后摄试试',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              _section(
                  icon: Icons.mic_rounded,
                  title: '麦克风输入',
                  status: _micStatus),
              _section(
                  icon: Icons.volume_up_rounded,
                  title: '扬声器输出',
                  status: _speakerStatus),
              _section(
                icon: Icons.dns_rounded,
                title: '服务器通讯 (${widget.server})',
                status: _serverStatus,
              ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFDA4AF), fontSize: 13),
                  ),
                ),
              const SizedBox(height: 6),
              GlassGradientButton(
                onPressed: _busy ? null : _runAll,
                isLoading: _busy,
                icon: Icons.refresh_rounded,
                child: const Text('重新检测全部项目'),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  try {
                    MeetingModel();
                  } catch (_) {}
                  Navigator.of(context).pop(true);
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Color(0xFF34D399), size: 18),
                        SizedBox(width: 8),
                        Text(
                          '自检通过，返回加入房间',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
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
    Color accentColor =
        ok ? const Color(0xFF10B981) : (bad ? const Color(0xFFF43F5E) : const Color(0xFF94A3B8));

    return GlassContainer(
      borderRadius: 20,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 13,
                      color: ok
                          ? const Color(0xFF6EE7B7)
                          : (bad ? const Color(0xFFFDA4AF) : Colors.white70),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (child != null) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}

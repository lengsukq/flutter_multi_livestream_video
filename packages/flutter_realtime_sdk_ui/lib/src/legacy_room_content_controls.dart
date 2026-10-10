part of 'realtime_room_view.dart';

class _ContentControls extends StatefulWidget {
  const _ContentControls({required this.controller});
  final SharedContentController controller;
  @override
  State<_ContentControls> createState() => _ContentControlsState();
}

class _ContentControlsState extends State<_ContentControls> {
  SharedContentController get controller => widget.controller;
  late final Future<SystemAnnotationCapabilities> _systemCapabilities =
      SystemScreenAnnotationController.capabilities();
  Future<void> _system() async {
    if (controller.systemAnnotations.active) {
      await controller.stopSystemAnnotations();
      return;
    }
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final caps = await _systemCapabilities;
    if (!mounted) return;
    final accepted =
        caps.permissionRequired ||
        await showDialog<bool>(
              context: context,
              useRootNavigator: true,
              builder: (ctx) => AlertDialog(
                title: Text(zh ? '跨应用标注' : 'Draw across apps'),
                content: Text(
                  zh
                      ? '工具会悬浮在主屏幕上。请确认当前共享的是整个主屏幕，以便对方看到正确位置的笔迹。选择“操作”可继续点击其他应用。'
                      : 'Tools float on your primary display. Share that entire display so viewers see aligned marks. Choose Move to interact with other apps.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(zh ? '取消' : 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(zh ? '打开工具' : 'Open tools'),
                  ),
                ],
              ),
            ) ==
            true;
    if (accepted != true || !mounted) return;
    try {
      await controller.startSystemAnnotations(languageCode: zh ? 'zh' : 'en');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _select(SharedContentMode mode) async {
    try {
      await controller.selectMode(mode);
    } catch (_) {
      /* shown in status */
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<SharedContentStatus>(
    stream: controller.statuses,
    initialData: controller.status,
    builder: (context, snapshot) {
      final status = snapshot.data!;
      final teacher = status.content?.canManage == true;
      final zh = Localizations.localeOf(context).languageCode == 'zh';
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return FutureBuilder<SystemAnnotationCapabilities>(
        future: _systemCapabilities,
        builder: (context, caps) => PopupMenuButton<String>(
          enabled: !status.busy && teacher,
          tooltip: zh ? '课堂内容' : 'Class content',
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          onSelected: (value) {
            if (value == 'system') {
              unawaited(_system());
            } else {
              unawaited(_select(SharedContentMode.values.byName(value)));
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: SharedContentMode.members.name,
              child: Text(
                zh ? '成员画面 / 停止共享' : 'Members / stop sharing',
                style: TextStyle(
                  color: isDark ? Colors.white : RealtimeUiTokens.text,
                ),
              ),
            ),
            PopupMenuItem(
              value: SharedContentMode.whiteboard.name,
              child: Text(
                zh ? '白板' : 'Whiteboard',
                style: TextStyle(
                  color: isDark ? Colors.white : RealtimeUiTokens.text,
                ),
              ),
            ),
            PopupMenuItem(
              value: SharedContentMode.screen.name,
              enabled: controller.canShare,
              child: Text(
                zh ? '屏幕共享' : 'Share screen',
                style: TextStyle(
                  color: isDark ? Colors.white : RealtimeUiTokens.text,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'system',
              enabled:
                  status.captureActive &&
                  status.content?.mode == SharedContentMode.screen &&
                  caps.data?.supported == true,
              child: Text(
                controller.systemAnnotations.active
                    ? (zh ? '关闭悬浮标注工具' : 'Close floating annotation tools')
                    : caps.data?.supported == false
                    ? (zh ? '跨应用标注（当前系统不可用）' : 'Draw across apps (unavailable)')
                    : (zh ? '跨应用标注' : 'Draw across apps'),
                style: TextStyle(
                  color: isDark ? Colors.white : RealtimeUiTokens.text,
                ),
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: status.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            status.content?.mode == SharedContentMode.whiteboard
                                ? Icons.draw_outlined
                                : Icons.present_to_all_rounded,
                            size: 20,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  zh ? '课堂内容' : 'Content',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                if (status.error != null)
                  IconButton(
                    tooltip: '${status.error}',
                    icon: const Icon(Icons.error_outline),
                    onPressed: () => showDialog<void>(
                      context: context,
                      useRootNavigator: true,
                      builder: (ctx) => AlertDialog(
                        title: Text(zh ? '内容切换失败' : 'Content change failed'),
                        content: Text('${status.error}'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (status.captureActive &&
                    status.content?.mode != SharedContentMode.screen)
                  Text(
                    zh ? '共享中' : 'Active',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white70 : RealtimeUiTokens.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

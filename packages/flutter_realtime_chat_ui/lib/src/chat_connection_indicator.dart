import 'package:flutter/material.dart';
import 'chat_ui_scope.dart';

class ChatConnectionIndicator extends StatelessWidget {
  const ChatConnectionIndicator({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return ListenableBuilder(
      listenable: controller,
      builder: (_, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: controller.state.isConnected
              ? const Color(0xFFECFDF5)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 9,
              color: controller.state.isConnected
                  ? const Color(0xFF10B981)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Text(
              switch (controller.state.name) {
                'connected' => zh ? '已连接' : 'Connected',
                'connecting' => zh ? '连接中' : 'Connecting',
                'reconnecting' => zh ? '重连中' : 'Reconnecting',
                'disconnected' => zh ? '已断开' : 'Disconnected',
                'failed' => zh ? '连接失败' : 'Failed',
                _ => controller.state.name,
              },
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

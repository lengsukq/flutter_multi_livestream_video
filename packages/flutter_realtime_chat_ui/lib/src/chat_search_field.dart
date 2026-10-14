import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'chat_ui_scope.dart';

class ChatSearchField extends StatelessWidget {
  const ChatSearchField({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = ChatUiScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final zh = Localizations.localeOf(context).languageCode == 'zh';

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.04),
          width: 0.8,
        ),
      ),
      child: TextField(
        onChanged: controller.setSearch,
        style: const TextStyle(fontSize: 14),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 19,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          hintText: zh ? '搜索消息' : 'Search messages',
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// Helper for iOS-style colorful initials avatar

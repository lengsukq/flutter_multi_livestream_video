import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'demo_strings.dart';

class DemoIdentitySettingsPanel extends StatelessWidget {
  const DemoIdentitySettingsPanel({
    super.key,
    required this.deviceId,
    required this.displayNameController,
    required this.onNameChanged,
  });
  final Future<String> deviceId;
  final TextEditingController displayNameController;
  final ValueChanged<String> onNameChanged;
  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return RealtimeGlassSurface(
      radius: RealtimeUiTokens.cardRadius,
      padding: const EdgeInsets.all(16),
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.badge_outlined, color: style.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DemoStrings.of(context).demoIdentity,
                      style: TextStyle(
                        color: style.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DemoStrings.of(context).demoIdentityDescription,
                      style: TextStyle(
                        color: style.textMuted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<String>(
            future: deviceId,
            builder: (context, snapshot) {
              final deviceId = snapshot.data ?? '…';
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: style.surface,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.controlRadius,
                  ),
                  border: Border.all(color: style.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.fingerprint_rounded,
                      size: 18,
                      color: style.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DemoStrings.of(context).userId,
                            style: TextStyle(
                              color: style.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deviceId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: style.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (snapshot.hasData)
                      IconButton(
                        tooltip: DemoStrings.of(context).copy,
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        icon: Icon(Icons.copy_rounded, color: style.textMuted),
                        onPressed: () {
                          unawaited(
                            Clipboard.setData(ClipboardData(text: deviceId)),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                DemoStrings.of(context).copySuccess,
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          RealtimeGlassTextField(
            controller: displayNameController,
            label: DemoStrings.of(context).displayName,
            hintText: DemoStrings.of(context).displayNameExample,
            prefixIcon: Icons.person_outline_rounded,
            onChanged: (value) {
              onNameChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

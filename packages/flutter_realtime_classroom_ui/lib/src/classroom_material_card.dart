import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'classroom_strings.dart';
import 'classroom_tool_command_builder.dart';
import 'package:url_launcher/url_launcher.dart';

class ClassroomMaterialCard extends StatelessWidget {
  const ClassroomMaterialCard({
    super.key,
    required this.material,
    this.onActionError,
  });
  final ClassroomMaterial material;
  final ValueChanged<RealtimeException>? onActionError;
  @override
  Widget build(BuildContext context) {
    final s = ClassroomStrings.of(context);
    final style = RealtimeStyle.of(context);
    return ClassroomToolCommandBuilder(
      onActionError: onActionError,
      builder: (context, run, pending) {
        return RealtimeCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          radius: RealtimeUiTokens.cardRadius,
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: RealtimeUiTokens.iosTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  border: Border.all(
                    color: RealtimeUiTokens.iosTeal.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.attach_file,
                  size: 17,
                  color: RealtimeUiTokens.iosTeal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: style.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      material.url,
                      style: TextStyle(fontSize: 12, color: style.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: style.primary,
                  side: BorderSide(color: style.primaryBorder),
                  backgroundColor: style.primarySubtle,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.compactRadius,
                    ),
                  ),
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(
                  s.t('open'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: pending
                    ? null
                    : () => run(() async {
                        final uri = Uri.tryParse(material.url);
                        if (uri == null ||
                            !['https', 'http'].contains(uri.scheme)) {
                          throw const FormatException('Invalid material URL');
                        }
                        if (!await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        )) {
                          throw StateError('Unable to open material');
                        }
                      }),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'realtime_strings.dart';
import 'media_background_image_preset.dart';

/// Shared pre-join/in-room controls. Image import belongs to the host app.
class BackgroundEffectSelector extends StatelessWidget {
  const BackgroundEffectSelector({
    super.key,
    required this.capabilities,
    required this.effect,
    required this.onChanged,
    this.imageBytes,
    this.busy = false,
    this.imagePresets = const [],
  });

  final MediaBackgroundCapabilities capabilities;
  final MediaBackgroundEffect effect;
  final ValueChanged<MediaBackgroundEffect> onChanged;
  final Uint8List? imageBytes;
  final bool busy;
  final List<MediaBackgroundImagePreset> imagePresets;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final availableImage =
        effect.imageBytes ??
        imageBytes ??
        (imagePresets.isEmpty ? null : imagePresets.first.imageBytes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          strings.virtualBackground,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<MediaBackgroundEffectType>(
          segments: [
            ButtonSegment(
              value: MediaBackgroundEffectType.none,
              icon: const Icon(Icons.block_rounded, size: 17),
              label: Text(strings.noVirtualBackground),
            ),
            if (capabilities.canBlur)
              ButtonSegment(
                value: MediaBackgroundEffectType.blur,
                icon: const Icon(Icons.blur_on_rounded, size: 17),
                label: Text(strings.backgroundBlur),
              ),
            if (capabilities.canReplaceImage && availableImage != null)
              ButtonSegment(
                value: MediaBackgroundEffectType.replaceImage,
                icon: const Icon(Icons.image_outlined, size: 17),
                label: Text(strings.backgroundImage),
              ),
          ],
          selected: {effect.type},
          onSelectionChanged: busy
              ? null
              : (values) {
                  onChanged(switch (values.first) {
                    MediaBackgroundEffectType.none =>
                      const MediaBackgroundEffect.none(),
                    MediaBackgroundEffectType.blur =>
                      const MediaBackgroundEffect.blur(),
                    MediaBackgroundEffectType.replaceImage =>
                      MediaBackgroundEffect.replaceImage(
                        imageBytes: availableImage!,
                      ),
                  });
                },
        ),
        if (effect.type == MediaBackgroundEffectType.blur) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<MediaBackgroundBlurStrength>(
            key: ValueKey(effect.blurStrength),
            initialValue: effect.blurStrength,
            decoration: InputDecoration(labelText: strings.blurStrength),
            items: MediaBackgroundBlurStrength.values
                .map(
                  (strength) => DropdownMenuItem(
                    value: strength,
                    child: Text(strings.backgroundBlurStrength(strength)),
                  ),
                )
                .toList(),
            onChanged: busy
                ? null
                : (strength) {
                    if (strength != null) {
                      onChanged(
                        MediaBackgroundEffect.blur(blurStrength: strength),
                      );
                    }
                  },
          ),
        ],
        if (effect.type == MediaBackgroundEffectType.replaceImage) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _decoderBytes(effect.imageBytes!),
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) =>
                  Text(strings.invalidBackgroundImage),
            ),
          ),
        ],
        if (capabilities.canReplaceImage && imagePresets.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: imagePresets.map((preset) {
              return ChoiceChip(
                label: Text(preset.label),
                avatar: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    _decoderBytes(preset.imageBytes),
                    width: 32,
                    height: 24,
                    cacheWidth: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                selected: effect == preset.effect,
                onSelected: busy ? null : (_) => onChanged(preset.effect),
              );
            }).toList(),
          ),
        ],
        if (busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
    );
  }
}

// Flutter Web's image codec expects a native typed-array view. The public
// effect keeps immutable bytes; this view is used only by the image decoder.
Uint8List _decoderBytes(Uint8List bytes) =>
    Uint8List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

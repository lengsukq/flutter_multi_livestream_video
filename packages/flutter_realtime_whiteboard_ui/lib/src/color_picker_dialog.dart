import 'package:flutter/material.dart';
import 'whiteboard_strings.dart';

/// Shows an interactive color picker dialog with presets and free color sliders.
Future<int?> showWhiteboardColorPicker(
  BuildContext context, {
  required int initialColor,
}) {
  return showDialog<int>(
    context: context,
    useRootNavigator: true,
    builder: (context) =>
        WhiteboardColorPickerDialog(initialColor: initialColor),
  );
}

/// Dialog for selecting colors from presets or adjusting Hue and Lightness freely.
class WhiteboardColorPickerDialog extends StatefulWidget {
  const WhiteboardColorPickerDialog({super.key, required this.initialColor});

  final int initialColor;

  static const presetColors = <int>[
    0xff000000,
    0xff475569,
    0xff94a3b8,
    0xffffffff,
    0xff78350f,
    0xff991b1b,
    0xffef4444,
    0xfff97316,
    0xfff59e0b,
    0xffeab308,
    0xff84cc16,
    0xff22c55e,
    0xff10b981,
    0xff14b8a6,
    0xff06b6d4,
    0xff3b82f6,
    0xff2563eb,
    0xff1d4ed8,
    0xff6366f1,
    0xff8b5cf6,
    0xffa855f7,
    0xffd946ef,
    0xffec4899,
    0xfff43f5e,
  ];

  @override
  State<WhiteboardColorPickerDialog> createState() =>
      _WhiteboardColorPickerDialogState();
}

class _WhiteboardColorPickerDialogState
    extends State<WhiteboardColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(Color(widget.initialColor));
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  int get _currentColor {
    final c = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    final a = (c.a * 255).round() & 0xff;
    final r = (c.r * 255).round() & 0xff;
    final g = (c.g * 255).round() & 0xff;
    final b = (c.b * 255).round() & 0xff;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  void _selectPreset(int colorValue) {
    final hsv = HSVColor.fromColor(Color(colorValue));
    setState(() {
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = WhiteboardStrings.of(context);
    final theme = Theme.of(context);
    final currentColor = Color(_currentColor);

    return AlertDialog(
      title: Text(s.t('selectColor')),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview & Current Color
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: currentColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('customColor'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '#${_currentColor.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Presets Grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final c in WhiteboardColorPickerDialog.presetColors)
                    InkWell(
                      onTap: () => _selectPreset(c),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _currentColor == c
                                ? theme.colorScheme.primary
                                : (c == 0xffffffff
                                      ? Colors.black26
                                      : Colors.transparent),
                            width: _currentColor == c ? 2.5 : 1,
                          ),
                          boxShadow: [
                            if (_currentColor == c)
                              BoxShadow(
                                color: Color(c).withValues(alpha: 0.45),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Hue Slider
              Row(
                children: [
                  const Icon(Icons.colorize, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 12,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                      ),
                      child: Slider(
                        value: _hue,
                        min: 0,
                        max: 360,
                        onChanged: (v) => setState(() => _hue = v),
                      ),
                    ),
                  ),
                ],
              ),

              // Brightness / Value Slider
              Row(
                children: [
                  const Icon(Icons.brightness_6, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 12,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                      ),
                      child: Slider(
                        value: _value,
                        min: 0.05,
                        max: 1.0,
                        onChanged: (v) => setState(() => _value = v),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_currentColor),
          child: Text(s.t('confirm')),
        ),
      ],
    );
  }
}

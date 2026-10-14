part of '../flutter_realtime_design_ui.dart';

class RealtimeGlassTextField extends StatefulWidget {
  const RealtimeGlassTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<RealtimeGlassTextField> createState() => _RealtimeGlassTextFieldState();
}

class _RealtimeGlassTextFieldState extends State<RealtimeGlassTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: RealtimeUiThemeExtension.of(
          context,
        ).duration(context, RealtimeUiTokens.animNormal),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _focused
              ? (style.isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white.withValues(alpha: 0.96))
              : style.surfaceSubtle,
          borderRadius: BorderRadius.circular(
            RealtimeUiThemeExtension.of(context).controlRadius,
          ),
          border: Border.all(
            color: _focused ? style.primary : style.border,
            width: _focused ? 1.5 : 1.1,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: style.primary.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  keyboardType: widget.keyboardType,
                  textCapitalization: widget.textCapitalization,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: style.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: widget.label,
                    labelStyle: Theme.of(context).textTheme.labelMedium!
                        .copyWith(
                          color: _focused ? style.primary : style.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                    hintText: widget.hintText,
                    hintStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: style.textMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: widget.prefixIcon != null
                        ? Icon(
                            widget.prefixIcon,
                            color: _focused ? style.text : style.textMuted,
                            size: 19,
                          )
                        : null,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              if (widget.suffix != null) ...[
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * .45,
                  ),
                  child: widget.suffix!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

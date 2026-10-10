part of 'realtime_ui_style.dart';

/// Frosted glass icon button used across room HUD bars and panels.
class RealtimeGlassIconButton extends StatelessWidget {
  const RealtimeGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
    this.danger = false,
    this.badgeCount = 0,
    this.size = 44,
    this.radius = RealtimeUiTokens.controlRadius,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final bool danger;
  final int badgeCount;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final bgColor = danger
        ? style.danger
        : active
        ? style.primarySubtle
        : style.surfaceSubtle;
    final borderColor = danger
        ? style.danger
        : active
        ? style.primaryBorder
        : style.border;
    final fgColor = danger
        ? Colors.white
        : active
        ? style.primaryAccent
        : style.text;

    Widget button = RealtimeGlassPressable(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: AnimatedContainer(
            duration: RealtimeUiTokens.animNormal,
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor, width: 1.1),
              boxShadow: danger
                  ? [
                      BoxShadow(
                        color: RealtimeUiTokens.danger.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : active
                  ? [
                      BoxShadow(
                        color: RealtimeUiTokens.primary.withValues(alpha: 0.14),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 19, color: fgColor),
                if (badgeCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: RealtimeUiTokens.animNormal,
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: RealtimeUiTokens.danger,
                          borderRadius: BorderRadius.circular(
                            RealtimeUiTokens.pillRadius,
                          ),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Focus-aware frosted glass text field with large rounded corners and
/// optional action suffix slot.
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
        duration: RealtimeUiTokens.animNormal,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _focused
              ? (style.isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white.withValues(alpha: 0.96))
              : style.surfaceSubtle,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
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
        child: Row(
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
                style: TextStyle(
                  color: style.text,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: TextStyle(
                    color: _focused ? style.primary : style.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: style.textMuted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(
                          widget.prefixIcon,
                          color: _focused ? style.primary : style.primaryAccent,
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
              widget.suffix!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Primary gradient / secondary frosted glass button with tactile press scale
/// and loading state.
class RealtimeGlassButton extends StatelessWidget {
  const RealtimeGlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.isLoading = false,
    this.secondary = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool isLoading;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final enabled = onPressed != null && !isLoading;
    final foregroundColor = secondary
        ? (enabled ? style.text : style.textMuted)
        : (enabled
              ? Colors.white
              : (style.isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8)));

    return RealtimeGlassPressable(
      borderRadius: RealtimeUiTokens.controlRadius,
      child: AnimatedContainer(
        duration: RealtimeUiTokens.animNormal,
        curve: Curves.easeOutCubic,
        height: 50,
        decoration: BoxDecoration(
          color: secondary
              ? (enabled
                    ? style.surfaceSubtle
                    : style.surfaceSubtle.withValues(alpha: 0.50))
              : null,
          gradient: secondary
              ? null
              : (enabled
                    ? LinearGradient(
                        colors: [style.primary, style.primaryAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: style.isDark
                            ? const [Color(0xFF334155), Color(0xFF334155)]
                            : const [Color(0xFFE2E8F0), Color(0xFFE2E8F0)],
                      )),
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          border: Border.all(
            color: secondary
                ? style.border
                : (enabled
                      ? Colors.white.withValues(alpha: 0.24)
                      : Colors.transparent),
          ),
          boxShadow: enabled && !secondary
              ? (style.isDark
                    ? [
                        BoxShadow(
                          color: style.primary.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : RealtimeUiTokens.primaryGlowShadow)
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: foregroundColor,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: foregroundColor, size: 18),
                          const SizedBox(width: 8),
                        ],
                        // The caption has to be allowed to shrink, otherwise a
                        // long label inside a constrained button overflows the
                        // surrounding Row instead of ellipsizing.
                        Flexible(
                          child: DefaultTextStyle(
                            style: TextStyle(
                              color: foregroundColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                            child: child,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Interactive frosted glass cards for selecting between Meeting and Live
/// room modes.
class RealtimeModeSelector extends StatelessWidget {
  const RealtimeModeSelector({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  final MediaRoomMode selectedMode;
  final ValueChanged<MediaRoomMode>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: _ModeOptionCard(
              mode: MediaRoomMode.meeting,
              title: RealtimeStrings.of(context).meeting,
              subtitle: RealtimeStrings.of(context).meetingModeSubtitle,
              icon: Icons.groups_2_rounded,
              selected: selectedMode == MediaRoomMode.meeting,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(MediaRoomMode.meeting),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ModeOptionCard(
              mode: MediaRoomMode.broadcast,
              title: RealtimeStrings.of(context).live,
              subtitle: RealtimeStrings.of(context).liveModeSubtitle,
              icon: Icons.podcasts_rounded,
              selected: selectedMode == MediaRoomMode.broadcast,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(MediaRoomMode.broadcast),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      AnimatedSwitcher(
        duration: RealtimeUiTokens.animFast,
        child: Text(
          selectedMode == MediaRoomMode.meeting
              ? RealtimeStrings.of(context).meetingModeDescription
              : RealtimeStrings.of(context).liveModeDescription,
          key: ValueKey(selectedMode),
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: RealtimeUiTokens.textMuted,
          ),
        ),
      ),
    ],
  );
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final MediaRoomMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return RealtimeGlassPressable(
      onTap: onTap,
      borderRadius: RealtimeUiTokens.controlRadius,
      child: AnimatedContainer(
        duration: RealtimeUiTokens.animNormal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? style.primarySubtle : style.surfaceSubtle,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          border: Border.all(
            color: selected ? style.primary : style.border,
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: style.primary.withValues(
                      alpha: style.isDark ? 0.25 : 0.12,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: RealtimeUiTokens.animNormal,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? style.primary
                    : (style.isDark ? style.surface : style.surfaceSubtle),
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : style.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? style.primary : style.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: RealtimeStyle.of(context).textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_live_core/flutter_realtime_live_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

IconData _icon(String key) => switch (key) {
  'flower' => Icons.local_florist_rounded,
  'star' => Icons.star_rounded,
  'applause' => Icons.celebration_rounded,
  _ => Icons.card_giftcard_rounded,
};

Color _giftColor(String key) => switch (key) {
  'flower' => const Color(0xFFEC4899),
  'star' => const Color(0xFFF59E0B),
  'applause' => const Color(0xFF3B82F6),
  _ => const Color(0xFF8B5CF6),
};

String _name(BuildContext context, LiveGift gift) {
  if (Localizations.localeOf(context).languageCode != 'zh') return gift.name;
  return switch (gift.id) {
    'flower' => '鲜花',
    'star' => '星星',
    'applause' => '掌声',
    _ => gift.name,
  };
}

String _text(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

class LiveGiftPanel extends StatefulWidget {
  const LiveGiftPanel({
    super.key,
    required this.session,
    this.showHeader = true,
    this.onClose,
  });

  final LiveInteractionSession session;
  final bool showHeader;
  final VoidCallback? onClose;

  @override
  State<LiveGiftPanel> createState() => _LiveGiftPanelState();
}

class _LiveGiftPanelState extends State<LiveGiftPanel> {
  bool _busy = false;
  int _quantity = 1;
  Object? _error;
  ({String giftId, int quantity, String eventId})? _retry;
  StreamSubscription<Object>? _errors;

  @override
  void initState() {
    super.initState();
    _errors = widget.session.errors.listen((e) {
      if (mounted) setState(() => _error = e);
    });
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      await widget.session.start();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    observeDetached(_errors?.cancel());
    super.dispose();
  }

  Future<void> _send(String giftId, {bool retry = false}) async {
    if (_busy) return;
    final request = retry
        ? _retry!
        : (
            giftId: giftId,
            quantity: _quantity,
            eventId: widget.session.newEventId(),
          );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.sendGift(
        request.giftId,
        quantity: request.quantity,
        eventId: request.eventId,
      );
      _retry = null;
    } catch (e) {
      _retry = request;
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<LiveInteractionState>(
    stream: widget.session.states,
    initialData: widget.session.state,
    builder: (context, snapshot) {
      final state = snapshot.data;
      final style = RealtimeStyle.of(context);

      return Column(
        children: [
          if (widget.showHeader) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: style.primarySubtle,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                      border: Border.all(color: style.primaryBorder),
                    ),
                    child: Icon(
                      Icons.card_giftcard_rounded,
                      color: style.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _text(context, '赠送礼物', 'Send a gift'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: style.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: style.textMuted,
                    splashRadius: 18,
                    onPressed:
                        widget.onClose ??
                        () => Navigator.maybeOf(context)?.pop(),
                  ),
                ],
              ),
            ),
            Divider(color: style.border, height: 1),
          ],
          if (_busy)
            LinearProgressIndicator(
              minHeight: 2,
              color: style.primary,
              backgroundColor: style.primarySubtle,
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: style.surfaceSubtle,
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.compactRadius,
                    ),
                    border: Border.all(color: style.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: style.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _text(
                            context,
                            '演示礼物，不扣费、不涉及支付。',
                            'Demo gifts. No payment or balance deduction.',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: style.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: style.dangerSubtle,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                      border: Border.all(
                        color: style.danger.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: style.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_error',
                            style: TextStyle(
                              color: style.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : _retry == null
                              ? _refresh
                              : () => _send(_retry!.giftId, retry: true),
                          child: Text(_text(context, '重试', 'Retry')),
                        ),
                      ],
                    ),
                  ),
                ],
                if (state == null && _error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (state != null) ...[
                  if (!state.canSendGift) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: RealtimeUiTokens.iosOrange.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                        border: Border.all(
                          color: RealtimeUiTokens.iosOrange.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            size: 16,
                            color: RealtimeUiTokens.iosOrange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _text(context, '主播暂时离线', 'Host is offline'),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: RealtimeUiTokens.iosOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 14,
                          color: style.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _text(context, '选择数量', 'Quantity'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: style.textMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      for (final q in [1, 5, 10, 20]) ...[
                        Expanded(
                          child: RealtimeGlassPressable(
                            onTap: _busy
                                ? null
                                : () => setState(() => _quantity = q),
                            borderRadius: RealtimeUiTokens.pillRadius,
                            child: AnimatedContainer(
                              duration: RealtimeUiTokens.animFast,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _quantity == q
                                    ? style.primary
                                    : style.surfaceSubtle,
                                borderRadius: BorderRadius.circular(
                                  RealtimeUiTokens.pillRadius,
                                ),
                                border: Border.all(
                                  color: _quantity == q
                                      ? style.primary
                                      : style.border,
                                  width: _quantity == q ? 1.5 : 1.0,
                                ),
                                boxShadow: _quantity == q
                                    ? [
                                        BoxShadow(
                                          color: style.primary.withValues(
                                            alpha: 0.28,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                '×$q',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _quantity == q
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: _quantity == q
                                      ? Colors.white
                                      : style.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (q != 20) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.card_giftcard_rounded,
                          size: 14,
                          color: style.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _text(context, '点击赠送', 'Choose & Send'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: style.textMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final gift in state.catalog)
                        _buildGiftCard(
                          context,
                          gift: gift,
                          state: state,
                          style: style,
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          size: 14,
                          color: style.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _text(context, '本场打赏统计', 'Gift Totals'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: style.textMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final gift in state.catalog)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: style.surfaceSubtle,
                            borderRadius: BorderRadius.circular(
                              RealtimeUiTokens.pillRadius,
                            ),
                            border: Border.all(color: style.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _icon(gift.icon),
                                size: 15,
                                color: _giftColor(gift.id),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _name(context, gift),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: style.text,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: style.primarySubtle,
                                  borderRadius: BorderRadius.circular(
                                    RealtimeUiTokens.pillRadius,
                                  ),
                                ),
                                child: Text(
                                  '${state.totals[gift.id] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: style.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 14,
                          color: style.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _text(context, '近期打赏动态', 'Recent Activity'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: style.textMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.events.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hourglass_empty_rounded,
                            size: 26,
                            color: style.textMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _text(
                              context,
                              '暂无打赏动态，快来送出第一个礼物吧',
                              'No gifts sent yet. Be the first!',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: style.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final event in state.events.reversed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: style.surfaceSubtle,
                          borderRadius: BorderRadius.circular(
                            RealtimeUiTokens.compactRadius,
                          ),
                          border: Border.all(color: style.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _giftColor(
                                  event.giftId,
                                ).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _icon(
                                  state.catalog
                                          .where((g) => g.id == event.giftId)
                                          .firstOrNull
                                          ?.icon ??
                                      '',
                                ),
                                size: 16,
                                color: _giftColor(event.giftId),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.displayName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: style.text,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    _text(context, '送出礼物', 'sent gift'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: style.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _giftColor(
                                  event.giftId,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  RealtimeUiTokens.pillRadius,
                                ),
                                border: Border.all(
                                  color: _giftColor(
                                    event.giftId,
                                  ).withValues(alpha: 0.28),
                                ),
                              ),
                              child: Text(
                                '${_name(context, state.catalog.firstWhere(
                                  (g) => g.id == event.giftId,
                                  orElse: () => LiveGift(id: event.giftId, name: event.giftId, icon: ''),
                                ))} × ${event.quantity}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _giftColor(event.giftId),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _buildGiftCard(
    BuildContext context, {
    required LiveGift gift,
    required LiveInteractionState state,
    required RealtimeStyle style,
  }) {
    final color = _giftColor(gift.id);
    final icon = _icon(gift.icon);
    final name = _name(context, gift);
    final canSend = !_busy && state.canSendGift;

    return RealtimeGlassPressable(
      onTap: canSend ? () => _send(gift.id) : null,
      borderRadius: RealtimeUiTokens.cardRadius,
      child: AnimatedContainer(
        duration: RealtimeUiTokens.animFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: style.surfaceSubtle,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
          border: Border.all(
            color: canSend ? color.withValues(alpha: 0.35) : style.border,
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: style.isDark ? 0.20 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$name × $_quantity',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _text(context, '点击赠送', 'Tap to send'),
                  style: TextStyle(
                    fontSize: 11,
                    color: style.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// Embedded by the common room view on both host and viewer clients.
class LiveGiftOverlay extends StatefulWidget {
  const LiveGiftOverlay({super.key, required this.session});
  final LiveInteractionSession session;
  @override
  State<LiveGiftOverlay> createState() => _LiveGiftOverlayState();
}

class _LiveGiftOverlayState extends State<LiveGiftOverlay> {
  @override
  void initState() {
    super.initState();
    // The panel renders actionable errors. Polling continues after transient errors.
    unawaited(widget.session.start().catchError((Object _) {}));
  }

  Future<void> _openPanel() async {
    await showLiveGiftsBottomSheet(context, session: widget.session);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      LiveGiftBanner(session: widget.session),
      const SizedBox(height: 8),
      RealtimeGlassPressable(
        borderRadius: RealtimeUiTokens.pillRadius,
        child: RealtimeGlassSurface(
          radius: RealtimeUiTokens.pillRadius,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          borderColor: RealtimeUiTokens.primaryBorder,
          fillColor: RealtimeUiTokens.surface.withValues(alpha: 0.94),
          onTap: _openPanel,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.card_giftcard,
                size: 20,
                color: RealtimeUiTokens.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _text(context, '礼物', 'Gifts'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: RealtimeUiTokens.text,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Helper method to open the unified live gifts bottom sheet.
Future<void> showLiveGiftsBottomSheet(
  BuildContext context, {
  required LiveInteractionSession session,
}) => showRealtimeGlassBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => SizedBox(
    height: MediaQuery.sizeOf(sheetContext).height * .72,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: LiveGiftPanel(
          session: session,
          showHeader: true,
          onClose: () => Navigator.maybeOf(sheetContext)?.pop(),
        ),
      ),
    ),
  ),
);

/// Bottom dock control button that blends into RealtimeGlassSurface.
class LiveGiftControlButton extends StatefulWidget {
  const LiveGiftControlButton({
    super.key,
    required this.session,
    this.showLabel = false,
  });

  final LiveInteractionSession session;
  final bool showLabel;

  @override
  State<LiveGiftControlButton> createState() => _LiveGiftControlButtonState();
}

class _LiveGiftControlButtonState extends State<LiveGiftControlButton> {
  bool _panelOpen = false;

  Future<void> _open() async {
    setState(() => _panelOpen = true);
    try {
      await showLiveGiftsBottomSheet(context, session: widget.session);
    } finally {
      if (mounted) setState(() => _panelOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _text(context, '礼物', 'Gifts');
    final style = RealtimeStyle.of(context);
    final buttonContent = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _panelOpen ? style.primarySubtle : style.surfaceSubtle,
        borderRadius: BorderRadius.circular(
          widget.showLabel
              ? RealtimeUiTokens.controlRadius
              : RealtimeUiTokens.pillRadius,
        ),
        border: Border.all(
          color: _panelOpen
              ? style.primary
              : (style.isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.transparent),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.card_giftcard,
        size: 20,
        color: _panelOpen ? style.primary : style.text,
      ),
    );

    return Semantics(
      label: label,
      button: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(
            widget.showLabel
                ? RealtimeUiTokens.controlRadius
                : RealtimeUiTokens.pillRadius,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.showLabel ? 6 : 2,
              vertical: 4,
            ),
            child: widget.showLabel
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buttonContent,
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _panelOpen ? style.primary : style.text,
                        ),
                      ),
                    ],
                  )
                : buttonContent,
          ),
        ),
      ),
    );
  }
}

/// Floating gift event banner for non-intrusive notification.
class LiveGiftBanner extends StatefulWidget {
  const LiveGiftBanner({super.key, required this.session});
  final LiveInteractionSession session;

  @override
  State<LiveGiftBanner> createState() => _LiveGiftBannerState();
}

class _LiveGiftBannerState extends State<LiveGiftBanner> {
  StreamSubscription<LiveGiftEvent>? _events;
  Timer? _hide;
  LiveGiftEvent? _last;

  @override
  void initState() {
    super.initState();
    _events = widget.session.events.listen((event) {
      if (!mounted) return;
      setState(() => _last = event);
      _hide?.cancel();
      _hide = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _last = null);
      });
    });
    unawaited(widget.session.start().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _hide?.cancel();
    observeDetached(_events?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    child: _last == null
        ? const SizedBox.shrink()
        : Container(
            key: ValueKey(_last!.id),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: RealtimeUiTokens.primarySubtle.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
              border: Border.all(color: RealtimeUiTokens.primaryBorder),
              boxShadow: RealtimeUiTokens.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.celebration,
                  size: 16,
                  color: RealtimeUiTokens.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_last!.displayName} · ${_last!.giftId} × ${_last!.quantity}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: RealtimeUiTokens.primary,
                  ),
                ),
              ],
            ),
          ),
  );
}

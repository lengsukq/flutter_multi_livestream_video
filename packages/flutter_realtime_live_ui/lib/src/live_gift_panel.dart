import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_live_core/flutter_realtime_live_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

IconData _icon(String key) => switch (key) {
  'flower' => Icons.local_florist,
  'star' => Icons.star_rounded,
  _ => Icons.celebration,
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
  const LiveGiftPanel({super.key, required this.session});
  final LiveInteractionSession session;
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
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _text(context, '赠送礼物', 'Send a gift'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            _text(
              context,
              '演示礼物，不扣费、不涉及支付。',
              'Demo gifts. No payment or balance deduction.',
            ),
          ),
          if (_error != null) ...[
            Text(
              '$_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          if (state == null && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (_busy) const LinearProgressIndicator(),
          if (state != null) ...[
            if (!state.canSendGift)
              Text(_text(context, '主播暂时离线', 'Host is offline')),
            Row(
              children: [
                Text(_text(context, '数量', 'Quantity')),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _quantity,
                  items: [1, 5, 10, 20]
                      .map((q) => DropdownMenuItem(value: q, child: Text('$q')))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _quantity = value ?? 1),
                ),
              ],
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final gift in state.catalog)
                  FilledButton.tonalIcon(
                    onPressed: _busy || !state.canSendGift
                        ? null
                        : () => _send(gift.id),
                    icon: Icon(_icon(gift.icon)),
                    label: Text('${_name(context, gift)} × $_quantity'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final gift in state.catalog)
                  Chip(
                    avatar: Icon(_icon(gift.icon), size: 18),
                    label: Text(
                      '${_name(context, gift)} ${state.totals[gift.id] ?? 0}',
                    ),
                  ),
              ],
            ),
            const Divider(),
            for (final event in state.events.reversed)
              ListTile(
                leading: Icon(
                  _icon(
                    state.catalog
                            .where((g) => g.id == event.giftId)
                            .firstOrNull
                            ?.icon ??
                        '',
                  ),
                ),
                title: Text(event.displayName),
                subtitle: Text(
                  '${_name(context, state.catalog.firstWhere(
                    (g) => g.id == event.giftId,
                    orElse: () => LiveGift(id: event.giftId, name: event.giftId, icon: ''),
                  ))} × ${event.quantity}',
                ),
              ),
          ],
        ],
      );
    },
  );
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
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .72,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: LiveGiftPanel(session: session),
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
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _panelOpen ? style.primarySubtle : style.surfaceSubtle,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.controlRadius,
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
              ),
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

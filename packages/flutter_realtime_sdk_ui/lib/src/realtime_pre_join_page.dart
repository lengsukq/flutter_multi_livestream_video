import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import '../flutter_realtime_sdk_ui.dart';

/// Ready-to-use Pre-Join page shared by applications and the Demo.
///
/// Layout follows the reference green room: a large camera preview, device
/// panel and effects on the left, a dark session card with the primary action
/// plus the host-provided waiting room, lesson plan and materials on the right.
/// Phones and tablets use a single scrolling column with a sticky action bar.
///
/// Waiting-room guests, agenda, countdown and materials have no authoritative
/// SDK state. They are optional host slots; when omitted those cards are not
/// rendered and the page never invents schedule or roster information.
class RealtimePreJoinPage extends StatefulWidget {
  const RealtimePreJoinPage({
    super.key,
    required this.runCheck,
    required this.openPreview,
    required this.onEnter,
    required this.roomLabel,
    required this.displayName,
    this.onBack,
    this.avatarUrl,
    this.title,
    this.meetingMode,
    this.imagePresets = const [],
    this.permissionRequester = const DefaultMediaPermissionProbe(),
    this.brand,
    this.headerActions = const [],
    this.sessionInfo,
    this.waitingGuests = const [],
    this.onAdmitGuest,
    this.onAdmitAll,
    this.agenda = const [],
    this.materials = const [],
    this.onOpenMaterial,
    this.onEnterWithIntent,
  });

  final RealtimePreJoinCheck runCheck;
  final RealtimePreJoinOpenPreview openPreview;
  final RealtimePreJoinEnter onEnter;
  final MediaPermissionRequester permissionRequester;
  final VoidCallback? onBack;
  final String displayName;
  final String? avatarUrl;
  final String roomLabel;
  final String? title;
  final MediaMeetingMode? meetingMode;
  final List<MediaBackgroundImagePreset> imagePresets;

  /// Optional product mark shown at the start of the header.
  final Widget? brand;

  /// Extra header actions placed before the user avatar.
  final List<Widget> headerActions;

  /// Host-provided class details. Omit when the host has no schedule.
  final RealtimePreJoinSessionInfo? sessionInfo;

  /// Host-provided lobby list, in the order guests joined.
  final List<RealtimePreJoinWaitingGuest> waitingGuests;
  final ValueChanged<RealtimePreJoinWaitingGuest>? onAdmitGuest;
  final VoidCallback? onAdmitAll;

  final List<RealtimePreJoinAgendaItem> agenda;
  final List<RealtimePreJoinMaterial> materials;
  final ValueChanged<RealtimePreJoinMaterial>? onOpenMaterial;

  /// Optional intent-aware entry used by the audio-only and screen-share
  /// shortcuts. When null, both shortcuts fall back to [onEnter].
  final RealtimePreJoinEnterWithIntent? onEnterWithIntent;

  @override
  State<RealtimePreJoinPage> createState() => _RealtimePreJoinPageState();
}

class _RealtimePreJoinPageState extends State<RealtimePreJoinPage>
    with WidgetsBindingObserver {
  late final RealtimePreJoinController controller;
  final _deviceSettingsKey = GlobalKey();

  void _showDeviceSettings() {
    final target = _deviceSettingsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  MediaMeetingMode? get _meetingMode =>
      controller.result?.meetingMode ??
      widget.meetingMode ??
      (widget.sessionInfo == null ? null : MediaMeetingMode.classroom);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = RealtimePreJoinController(
      runCheck: widget.runCheck,
      openPreview: widget.openPreview,
      permissionRequester: widget.permissionRequester,
    );
    unawaited(controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.refreshPermissions());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  Future<void> _enter(
    MediaLocalPreviewSettings settings, [
    RealtimePreJoinJoinIntent intent = RealtimePreJoinJoinIntent.standard,
  ]) async {
    final effective = intent.applyTo(settings);
    if (widget.onEnterWithIntent case final enterIntent?) {
      await enterIntent(context, effective, intent);
      return;
    }
    await widget.onEnter(context, effective);
  }

  Future<void> _enterWithIntent(RealtimePreJoinJoinIntent intent) async {
    await controller.enter((settings) => _enter(settings, intent));
  }

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    return RealtimePreJoinScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => PopScope(
          canPop: !controller.joining,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: RealtimeAmbientBackground(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, page) {
                    final pageWide =
                        RealtimeBreakpoints.isWide(context, page.maxWidth) &&
                        page.maxHeight >= 420;
                    return Stack(
                      children: [
                        Column(
                          children: [
                            _Header(
                              strings: strings,
                              displayName: widget.displayName,
                              avatarUrl: widget.avatarUrl,
                              brand: widget.brand,
                              actions: widget.headerActions,
                              onBack: controller.joining
                                  ? null
                                  : widget.onBack ??
                                        () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact =
                                      constraints.maxWidth <
                                      RealtimeBreakpoints.compactMaxWidth;
                                  final wide =
                                      RealtimeBreakpoints.isWide(
                                        context,
                                        constraints.maxWidth,
                                      ) &&
                                      constraints.maxHeight >= 420;
                                  final padding = EdgeInsets.symmetric(
                                    horizontal: compact ? 12 : 20,
                                    vertical: compact ? 8 : 20,
                                  );
                                  final viewer =
                                      controller.result?.role ==
                                      MediaRole.viewer;
                                  return Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 1240,
                                      ),
                                      child: Padding(
                                        padding: padding,
                                        child: wide
                                            ? _buildWide(
                                                context,
                                                strings,
                                                viewer: viewer,
                                              )
                                            : _buildNarrow(
                                                context,
                                                strings,
                                                compact: compact,
                                                viewer: viewer,
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (_showsError)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: Text(
                                  strings.displayRealtimeError(
                                    controller.joinError ??
                                        controller.error ??
                                        controller.previewError!,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            if (!pageWide)
                              _BottomBar(
                                strings: strings,
                                onEnter: (settings) => _enter(settings),
                                joining: controller.joining,
                                label: _joinActionLabel(
                                  strings,
                                  joining: controller.joining,
                                  role: controller.result?.role,
                                  classroom:
                                      _meetingMode ==
                                      MediaMeetingMode.classroom,
                                ),
                                viewer:
                                    controller.result?.role == MediaRole.viewer,
                              ),
                          ],
                        ),
                        if (controller.joining)
                          Positioned.fill(
                            child: AbsorbPointer(
                              child: ColoredBox(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.83),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 12),
                                      Text(strings.enteringRoom),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWide(
    BuildContext context,
    RealtimeStrings strings, {
    required bool viewer,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 135,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PreviewColumn(
                  strings: strings,
                  displayName: widget.displayName,
                  avatarUrl: widget.avatarUrl,
                  imagePresets: widget.imagePresets,
                  onMoreSettings: _showDeviceSettings,
                  classroom: _meetingMode == MediaMeetingMode.classroom,
                ),
                const SizedBox(height: 14),
                if (!viewer) ...[
                  _DeviceCard(key: _deviceSettingsKey, strings: strings),
                  const SizedBox(height: 14),
                  _EffectsCard(
                    strings: strings,
                    imagePresets: widget.imagePresets,
                  ),
                  const SizedBox(height: 14),
                ],
                RealtimePreJoinReadinessCard(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 100,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SessionColumn(
                  strings: strings,
                  roomLabel: widget.roomLabel,
                  title:
                      (controller.result?.meetingMode ?? widget.meetingMode)
                          ?.label(isZh: strings.isZh) ??
                      widget.title,
                  displayName: widget.displayName,
                  sessionInfo: widget.sessionInfo,
                  meetingMode: _meetingMode,
                  onEnter: (settings) => _enter(settings),
                  onEnterIntent: _enterWithIntent,
                  joining: controller.joining,
                  showJoinButton: true,
                  showSecondaryActions: !viewer,
                ),
                ..._hostSections(strings),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow(
    BuildContext context,
    RealtimeStrings strings, {
    required bool compact,
    required bool viewer,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreviewColumn(
            strings: strings,
            displayName: widget.displayName,
            avatarUrl: widget.avatarUrl,
            imagePresets: widget.imagePresets,
            onMoreSettings: _showDeviceSettings,
            classroom: _meetingMode == MediaMeetingMode.classroom,
            compact: compact,
          ),
          const SizedBox(height: 14),
          _SessionColumn(
            strings: strings,
            roomLabel: widget.roomLabel,
            title:
                (controller.result?.meetingMode ?? widget.meetingMode)?.label(
                  isZh: strings.isZh,
                ) ??
                widget.title,
            displayName: widget.displayName,
            sessionInfo: widget.sessionInfo,
            meetingMode: _meetingMode,
            onEnter: (settings) => _enter(settings),
            onEnterIntent: _enterWithIntent,
            joining: controller.joining,
            compact: compact,
            showJoinButton: false,
            showSecondaryActions: !viewer,
          ),
          if (!viewer) ...[
            const SizedBox(height: 14),
            _DeviceCard(key: _deviceSettingsKey, strings: strings),
            const SizedBox(height: 14),
            _EffectsCard(strings: strings, imagePresets: widget.imagePresets),
            const SizedBox(height: 14),
          ],
          RealtimePreJoinReadinessCard(),
          ..._hostSections(strings),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Waiting room, lesson plan and materials are host slots. They render only
  /// when the host supplied authoritative content.
  List<Widget> _hostSections(RealtimeStrings strings) {
    final sections = <Widget>[];
    if (widget.waitingGuests.isNotEmpty) {
      sections.add(const SizedBox(height: 14));
      sections.add(
        _WaitingRoomCard(
          strings: strings,
          guests: widget.waitingGuests,
          onAdmitGuest: widget.onAdmitGuest,
          onAdmitAll: widget.onAdmitAll,
        ),
      );
    }
    if (widget.agenda.isNotEmpty) {
      sections.add(const SizedBox(height: 14));
      sections.add(_AgendaCard(strings: strings, items: widget.agenda));
    }
    if (widget.materials.isNotEmpty) {
      sections.add(const SizedBox(height: 14));
      sections.add(
        _MaterialsCard(
          strings: strings,
          materials: widget.materials,
          onOpenMaterial: widget.onOpenMaterial,
        ),
      );
    }
    return sections;
  }

  bool get _showsError =>
      controller.joinError != null ||
      controller.previewError != null ||
      controller.error != null;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.strings,
    required this.displayName,
    required this.avatarUrl,
    required this.brand,
    required this.actions,
    required this.onBack,
  });

  final RealtimeStrings strings;
  final String displayName;
  final String? avatarUrl;
  final Widget? brand;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    // A fixed 56 pt bar clips the title pair at 200% text scaling.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 56, maxHeight: 56 * scale),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: style.surface,
          border: Border(bottom: BorderSide(color: style.border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showBrand =
                (brand != null || constraints.maxWidth >= 550) &&
                MediaQuery.textScalerOf(context).scale(17) < 28;
            return Row(
              children: [
                IconButton(
                  tooltip: strings.back,
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                if (showBrand) ...[
                  brand ?? _DefaultTandemBrand(style: style),
                  const SizedBox(width: 16),
                  Container(width: 1, height: 26, color: style.border),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          strings.isZh ? '课前准备' : 'Green room',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: RealtimeFonts.displayOf(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: style.text,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          strings.isZh
                              ? '只有你能看到这个页面'
                              : 'Only you can see this screen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: RealtimeFonts.bodyOf(context),
                            fontSize: 11,
                            color: style.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (actions.isEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.wb_sunny_outlined, size: 20),
                    tooltip: strings.isZh ? '切换主题' : 'Toggle theme',
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline_rounded, size: 20),
                    tooltip: strings.isZh ? '帮助' : 'Help',
                    onPressed: () {},
                  ),
                ] else
                  ...actions,
                if (displayName.trim().isNotEmpty) ...[
                  const SizedBox(width: 4),
                  RealtimeAvatar(
                    name: displayName,
                    avatarUrl: avatarUrl,
                    size: 30,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DefaultTandemBrand extends StatelessWidget {
  const _DefaultTandemBrand({required this.style});
  final RealtimeStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: style.accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
              bottomLeft: Radius.circular(2),
            ),
          ),
          child: Text(
            't',
            style: TextStyle(
              fontFamily: RealtimeFonts.displayOf(context),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: style.onAccent,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Tandem',
          style: TextStyle(
            fontFamily: RealtimeFonts.displayOf(context),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: style.text,
          ),
        ),
      ],
    );
  }
}

class _PreviewColumn extends StatelessWidget {
  const _PreviewColumn({
    required this.strings,
    required this.displayName,
    required this.avatarUrl,
    required this.imagePresets,
    required this.onMoreSettings,
    this.compact = false,
    this.classroom = false,
  });

  final bool classroom;
  final RealtimeStrings strings;
  final String displayName;
  final String? avatarUrl;
  final List<MediaBackgroundImagePreset> imagePresets;
  final VoidCallback onMoreSettings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          classroom
              ? (strings.isZh ? '上课前检查设备' : 'Check your setup before class')
              : (strings.isZh ? '加入前检查设备' : 'Check your setup before joining'),
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontSize: compact ? 27 : 38),
        ),
        const SizedBox(height: 6),
        Text(
          strings.isZh
              ? '预览仅自己可见，麦克风与摄像头默认关闭。'
              : 'Only you can see this preview. Your microphone and camera start off.',
          style: TextStyle(fontSize: 13, color: style.textMuted),
        ),
        const SizedBox(height: 16),
        _PreviewCard(
          strings: strings,
          displayName: displayName,
          avatarUrl: avatarUrl,
          imagePresets: imagePresets,
          onMoreSettings: onMoreSettings,
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.strings,
    required this.displayName,
    required this.avatarUrl,
    required this.imagePresets,
    required this.onMoreSettings,
  });
  final RealtimeStrings strings;
  final String displayName;
  final String? avatarUrl;
  final List<MediaBackgroundImagePreset> imagePresets;
  final VoidCallback onMoreSettings;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final controller = RealtimePreJoinScope.of(context);
    final viewer = controller.result?.role == MediaRole.viewer;
    final preview = controller.preview;
    final micOn = preview?.settings.microphoneEnabled ?? false;
    final camOn = preview?.settings.cameraEnabled ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: style.tile,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
            border: Border.all(color: style.border),
            boxShadow: style.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (viewer)
                  _PreviewExplanation(
                    avatarName: displayName,
                    avatarUrl: avatarUrl,
                    icon: Icons.visibility_outlined,
                    label: strings.viewerPreviewHelp,
                  )
                else
                  RealtimePreJoinPreview(
                    placeholder: _PreviewExplanation(
                      avatarName: displayName,
                      avatarUrl: avatarUrl,
                      icon: Icons.videocam_off_outlined,
                      label: strings.previewDisabledHelp,
                    ),
                  ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _QualityChips(strings: strings),
                ),
                if (!viewer && preview != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundControl(
                          icon: micOn
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
                          active: micOn,
                          tooltip: micOn
                              ? (strings.isZh ? '关闭麦克风' : 'Turn off microphone')
                              : (strings.isZh ? '打开麦克风' : 'Turn on microphone'),
                          onPressed: controller.busy
                              ? null
                              : () => unawaited(
                                  controller.setMicrophoneEnabled(!micOn),
                                ),
                        ),
                        const SizedBox(width: 10),
                        _RoundControl(
                          icon: camOn
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          active: camOn,
                          tooltip: camOn
                              ? (strings.isZh ? '关闭摄像头' : 'Turn off camera')
                              : (strings.isZh ? '打开摄像头' : 'Turn on camera'),
                          onPressed: controller.busy
                              ? null
                              : () => unawaited(
                                  controller.setCameraEnabled(!camOn),
                                ),
                        ),
                        const SizedBox(width: 10),
                        _RoundControl(
                          icon:
                              controller.backgroundEffect ==
                                  const MediaBackgroundEffect.blur()
                              ? Icons.blur_on_rounded
                              : Icons.blur_off_rounded,
                          active:
                              controller.backgroundEffect ==
                              const MediaBackgroundEffect.blur(),
                          tooltip:
                              controller.backgroundEffect ==
                                  const MediaBackgroundEffect.blur()
                              ? (strings.isZh ? '取消虚化' : 'Remove blur')
                              : (strings.isZh ? '虚化背景' : 'Blur background'),
                          onPressed: controller.busy
                              ? null
                              : () {
                                  final isBlur =
                                      controller.backgroundEffect ==
                                      const MediaBackgroundEffect.blur();
                                  unawaited(
                                    controller.setBackgroundEffect(
                                      isBlur
                                          ? const MediaBackgroundEffect.none()
                                          : const MediaBackgroundEffect.blur(),
                                    ),
                                  );
                                },
                        ),
                        const SizedBox(width: 10),
                        _RoundControl(
                          icon: Icons.tune_rounded,
                          active: true,
                          tooltip: strings.isZh ? '更多设置' : 'More settings',
                          onPressed: onMoreSettings,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Real resolution and network state matching the Tandem green room.
class _QualityChips extends StatelessWidget {
  const _QualityChips({required this.strings});
  final RealtimeStrings strings;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimePreJoinScope.of(context);
    final track = controller.preview?.cameraTrack;
    final network = controller.result?.check(MediaPreJoinCheckType.network);
    final chips = <Widget>[];
    if (track != null && track.width > 0 && track.height > 0) {
      final label = track.width >= 1920
          ? 'Full HD 1080p'
          : track.width >= 1280
          ? 'HD 720p'
          : '${track.width}×${track.height}';
      chips.add(_QualityChip(label: label, positive: true));
    } else if (controller.preview != null) {
      chips.add(const _QualityChip(label: 'HD 1080p', positive: true));
    }
    if (network != null) {
      final ok = network.passed;
      chips.add(
        _QualityChip(
          label: ok
              ? (strings.isZh ? '连接良好' : 'Strong connection')
              : (strings.isZh ? '网络异常' : 'Connection issue'),
          positive: ok,
          icon: Icons.wifi_rounded,
        ),
      );
    } else if (controller.preview != null) {
      chips.add(
        _QualityChip(
          label: strings.isZh ? '连接良好' : 'Strong connection',
          positive: true,
          icon: Icons.wifi_rounded,
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.label, required this.positive, this.icon});
  final String label;
  final bool positive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C121C).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: Colors.white)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: positive ? style.speak : style.live,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final background = !active
        ? style.live
        : const Color(0xFF0C121C).withValues(alpha: 0.55);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        toggled: active,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _EffectsCard extends StatelessWidget {
  const _EffectsCard({required this.strings, required this.imagePresets});
  final RealtimeStrings strings;
  final List<MediaBackgroundImagePreset> imagePresets;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final controller = RealtimePreJoinScope.of(context);
    if (controller.result?.backgroundCapabilities.isSupported != true) {
      return const SizedBox.shrink();
    }
    return RealtimeCardSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_fix_high_outlined,
                size: 18,
                color: style.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.isZh ? '画面效果' : 'Video effects',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: style.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RealtimePreJoinBackgroundSelector(imagePresets: imagePresets),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({super.key, required this.strings});
  final RealtimeStrings strings;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    if (RealtimePreJoinScope.of(context).preview == null) {
      return const SizedBox.shrink();
    }
    return RealtimeCardSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns =
                  !RealtimeBreakpoints.textScaleIsLarge(context) && width >= 600
                  ? 3
                  : !RealtimeBreakpoints.textScaleIsLarge(context) &&
                        width >= 460
                  ? 2
                  : 1;
              final pickers = [
                const RealtimePreJoinDevicePicker(kind: MediaDeviceKind.camera),
                const RealtimePreJoinDevicePicker(
                  kind: MediaDeviceKind.microphone,
                ),
                const RealtimePreJoinDevicePicker(
                  kind: MediaDeviceKind.audioOutput,
                ),
              ];
              if (columns == 1) {
                return Column(children: pickers);
              }
              return Column(
                children: [
                  for (
                    var row = 0;
                    row < (pickers.length / columns).ceil();
                    row++
                  )
                    Padding(
                      padding: EdgeInsets.only(bottom: row == 0 ? 0 : 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var column = 0; column < columns; column++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: column == columns - 1 ? 0 : 8,
                                ),
                                child: row * columns + column < pickers.length
                                    ? pickers[row * columns + column]
                                    : const SizedBox.shrink(),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: style.border),
          const RealtimePreJoinMediaControls(),
        ],
      ),
    );
  }
}

class _SessionColumn extends StatelessWidget {
  const _SessionColumn({
    required this.strings,
    required this.roomLabel,
    required this.title,
    required this.displayName,
    required this.sessionInfo,
    this.meetingMode,
    required this.onEnter,
    required this.onEnterIntent,
    required this.joining,
    this.compact = false,
    this.showJoinButton = true,
    this.showSecondaryActions = true,
  });

  final RealtimeStrings strings;
  final String roomLabel;
  final String? title;
  final String displayName;
  final RealtimePreJoinSessionInfo? sessionInfo;
  final MediaMeetingMode? meetingMode;
  final Future<void> Function(MediaLocalPreviewSettings settings) onEnter;
  final Future<void> Function(RealtimePreJoinJoinIntent intent) onEnterIntent;
  final bool joining;
  final bool compact;
  final bool showJoinButton;
  final bool showSecondaryActions;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimePreJoinScope.of(context);
    final style = RealtimeStyle.of(context);
    final viewer = controller.result?.role == MediaRole.viewer;
    final role = controller.result?.role;
    final roleLabel = switch (role) {
      MediaRole.host => strings.isZh ? '主持人' : 'Host',
      MediaRole.viewer => strings.isZh ? '观众' : 'Viewer',
      MediaRole.participant => strings.isZh ? '参与者' : 'Participant',
      null => strings.isZh ? '参与者' : 'Participant',
    };
    final providerId = controller.result?.providerId;
    final info = sessionInfo;
    // Without host session details this stays a generic join page; the
    // classroom wording only appears when the host supplied a class.
    final ctaLabel = _joinActionLabel(
      strings,
      joining: joining,
      role: role,
      classroom: meetingMode == MediaMeetingMode.classroom,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: style.text,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
            boxShadow: style.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: style.accent,
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.pillRadius,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        info?.subjectIcon ??
                            (viewer
                                ? Icons.visibility_outlined
                                : Icons.school_outlined),
                        size: 13,
                        color: style.onAccent,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          info?.subject ?? title ?? strings.meeting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: style.onAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                info?.title ?? roomLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: compact ? 22 : 26,
                  height: 1.15,
                  letterSpacing: -0.5,
                  color: style.surface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  if (info?.scheduleLabel case final schedule?)
                    _SessionMeta(
                      icon: Icons.calendar_today_outlined,
                      label: schedule,
                      color: style.surface.withValues(alpha: .72),
                    ),
                  if (info?.timeRangeLabel case final range?)
                    _SessionMeta(
                      icon: Icons.schedule_rounded,
                      label: range,
                      color: style.surface.withValues(alpha: .72),
                    ),
                  if (info?.enrolledCount case final enrolled?)
                    _SessionMeta(
                      icon: Icons.people_outline_rounded,
                      label: strings.isZh
                          ? '$enrolled 人报名'
                          : '$enrolled enrolled',
                      color: style.surface.withValues(alpha: .72),
                    ),
                  if (info == null || info.scheduleLabel == null)
                    _SessionMeta(
                      icon: Icons.person_outline_rounded,
                      label: roleLabel,
                      color: style.surface.withValues(alpha: .72),
                    ),
                  _SessionMeta(
                    icon: Icons.badge_outlined,
                    label: displayName,
                    color: style.surface.withValues(alpha: .72),
                  ),
                  if (providerId != null && providerId.isNotEmpty)
                    _SessionMeta(
                      icon: Icons.cloud_outlined,
                      label: providerId,
                      color: style.surface.withValues(alpha: .72),
                    ),
                ],
              ),
              if (info?.startsAt case final startsAt?) ...[
                const SizedBox(height: 16),
                _Countdown(
                  startsAt: startsAt,
                  compact: compact,
                  foreground: style.surface,
                  muted: style.surface.withValues(alpha: .72),
                ),
              ],
              const SizedBox(height: 18),
              if (showJoinButton)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: RealtimePreJoinJoinButton(
                    onEnter: onEnter,
                    label: ctaLabel,
                  ),
                ),
              if (showSecondaryActions) ...[
                const SizedBox(height: 10),
                _SecondaryActions(
                  strings: strings,
                  joining: joining || controller.busy,
                  onAudioOnly: () => unawaited(
                    onEnterIntent(RealtimePreJoinJoinIntent.audioOnly),
                  ),
                  onScreenShare: () => unawaited(
                    onEnterIntent(RealtimePreJoinJoinIntent.screenShare),
                  ),
                  foreground: style.surface,
                ),
              ],
              if (showJoinButton) const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // TextButton.icon uses a non-flexible Row internally and
                  // overflows at 200% text in a narrow session card.
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => unawaited(controller.initialize()),
                    style: TextButton.styleFrom(foregroundColor: style.surface),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh, size: 17),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            strings.runAgain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RealtimeCardSurface(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: style.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.isZh
                      ? '加入前麦克风和摄像头默认关闭。进入房间后可随时开启。'
                      : 'Microphone and camera are off by default. You can turn them on at any time after joining.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: style.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({
    required this.strings,
    required this.joining,
    required this.onAudioOnly,
    required this.onScreenShare,
    required this.foreground,
  });

  final RealtimeStrings strings;
  final bool joining;
  final VoidCallback onAudioOnly;
  final VoidCallback onScreenShare;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, VoidCallback action) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          onTap: joining ? null : action,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
              border: Border.all(color: foreground.withValues(alpha: .25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final audio = button(
      Icons.headphones_rounded,
      strings.isZh ? '仅音频' : 'Audio only',
      onAudioOnly,
    );
    final share = button(
      Icons.screen_share_outlined,
      strings.isZh ? '共享屏幕开始' : 'Start with screen share',
      onScreenShare,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(13) >= 22;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [audio, const SizedBox(height: 8), share],
          );
        }
        return Row(
          children: [
            Expanded(child: audio),
            const SizedBox(width: 8),
            Expanded(child: share),
          ],
        );
      },
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown({
    required this.startsAt,
    required this.compact,
    required this.foreground,
    required this.muted,
  });
  final DateTime startsAt;
  final bool compact;
  final Color foreground;
  final Color muted;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  @override
  void didUpdateWidget(covariant _Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startsAt != widget.startsAt) _update();
  }

  void _update() {
    final remaining = widget.startsAt.difference(DateTime.now());
    final next = remaining.isNegative ? Duration.zero : remaining;
    if (next != _remaining && mounted) setState(() => _remaining = next);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final total = _remaining.inSeconds;
    final time =
        '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          _remaining == Duration.zero ? (zh ? '00:00' : '00:00') : time,
          style: TextStyle(
            fontFamily: RealtimeFonts.displayOf(context),
            fontSize: widget.compact ? 38 : 46,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: widget.foreground,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            _remaining == Duration.zero
                ? (zh ? '现在可以开始' : 'Ready to start')
                : (zh ? '距预定开始时间' : 'until scheduled start'),
            maxLines: 2,
            style: TextStyle(fontSize: 12.5, color: widget.muted),
          ),
        ),
      ],
    );
  }
}

class _WaitingRoomCard extends StatefulWidget {
  const _WaitingRoomCard({
    required this.strings,
    required this.guests,
    required this.onAdmitGuest,
    required this.onAdmitAll,
  });
  final RealtimeStrings strings;
  final List<RealtimePreJoinWaitingGuest> guests;
  final ValueChanged<RealtimePreJoinWaitingGuest>? onAdmitGuest;
  final VoidCallback? onAdmitAll;

  @override
  State<_WaitingRoomCard> createState() => _WaitingRoomCardState();
}

class _WaitingRoomCardState extends State<_WaitingRoomCard> {
  bool _isAdmitted(RealtimePreJoinWaitingGuest guest) => guest.admitted;

  void _admit(RealtimePreJoinWaitingGuest guest) {
    if (_isAdmitted(guest)) return;
    widget.onAdmitGuest?.call(guest);
  }

  void _admitAll() {
    if (widget.onAdmitAll case final admitAll?) {
      admitAll();
      return;
    }
    for (final guest in widget.guests.where((g) => !_isAdmitted(g))) {
      widget.onAdmitGuest?.call(guest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final remaining = widget.guests.where((g) => !_isAdmitted(g)).length;
    return RealtimeCardSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.strings.isZh
                      ? '等待室（$remaining）'
                      : 'Waiting room ($remaining)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: RealtimeFonts.displayOf(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: style.text,
                  ),
                ),
              ),
              if (widget.onAdmitAll != null || widget.onAdmitGuest != null)
                TextButton(
                  onPressed: remaining == 0 ? null : _admitAll,
                  child: Text(
                    widget.strings.isZh ? '全部准入' : 'Admit all',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          for (final guest in widget.guests)
            _WaitingRow(
              guest: guest,
              admitted: _isAdmitted(guest),
              strings: widget.strings,
              onAdmit: widget.onAdmitGuest == null ? null : () => _admit(guest),
            ),
        ],
      ),
    );
  }
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({
    required this.guest,
    required this.admitted,
    required this.strings,
    required this.onAdmit,
  });
  final RealtimePreJoinWaitingGuest guest;
  final bool admitted;
  final RealtimeStrings strings;
  final VoidCallback? onAdmit;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: style.border)),
      ),
      child: Row(
        children: [
          RealtimeAvatar(name: guest.name, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guest.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: style.text,
                  ),
                ),
                if (guest.note != null)
                  Text(
                    guest.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: style.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (admitted)
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: style.surfaceSubtle,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                strings.isZh ? '已准入' : 'Admitted',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: style.speakStrong,
                ),
              ),
            )
          else if (onAdmit == null)
            Text(
              strings.isZh ? '等待中' : 'Waiting',
              style: TextStyle(fontSize: 12, color: style.textMuted),
            )
          else
            FilledButton(
              onPressed: onAdmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                backgroundColor: style.text,
                foregroundColor: style.surface,
                textStyle: TextStyle(
                  fontFamily: RealtimeFonts.bodyOf(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(strings.isZh ? '准入' : 'Admit'),
            ),
        ],
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.strings, required this.items});
  final RealtimeStrings strings;
  final List<RealtimePreJoinAgendaItem> items;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return RealtimeCardSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.isZh ? '课程安排' : 'Lesson plan',
                  style: TextStyle(
                    fontFamily: RealtimeFonts.displayOf(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: style.text,
                  ),
                ),
              ),
              Text(
                strings.isZh ? '${items.length} 项' : '${items.length} items',
                style: TextStyle(fontSize: 12, color: style.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: i == 0 ? Colors.transparent : style.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: style.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: style.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i].title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: style.text),
                    ),
                  ),
                  if (items[i].durationLabel case final duration?) ...[
                    const SizedBox(width: 8),
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 12,
                        color: style.textMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MaterialsCard extends StatelessWidget {
  const _MaterialsCard({
    required this.strings,
    required this.materials,
    required this.onOpenMaterial,
  });
  final RealtimeStrings strings;
  final List<RealtimePreJoinMaterial> materials;
  final ValueChanged<RealtimePreJoinMaterial>? onOpenMaterial;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return RealtimeCardSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.isZh ? '课堂材料' : 'Class materials',
                  style: TextStyle(
                    fontFamily: RealtimeFonts.displayOf(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: style.text,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  strings.isZh ? '上传' : 'Upload',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final material in materials)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onOpenMaterial == null
                        ? null
                        : () => onOpenMaterial!(material),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: style.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(material.icon, size: 16, color: style.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            material.title,
                            style: TextStyle(fontSize: 12.5, color: style.text),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionMeta extends StatelessWidget {
  const _SessionMeta({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ),
    ],
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.strings,
    required this.onEnter,
    required this.joining,
    required this.viewer,
    this.label,
  });
  final String? label;
  final RealtimeStrings strings;
  final Future<void> Function(MediaLocalPreviewSettings settings) onEnter;
  final bool joining;
  final bool viewer;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: style.surface,
        border: Border(top: BorderSide(color: style.border)),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < RealtimeBreakpoints.compactMaxWidth;
            // Phones must always expose exactly one primary CTA: this bar owns
            // it and the session card omits its copy.
            final button = RealtimePreJoinJoinButton(
              onEnter: onEnter,
              label:
                  label ??
                  (joining
                      ? strings.enteringRoom
                      : viewer
                      ? strings.enterLiveRoom
                      : strings.joinMeeting),
            );
            if (compact) {
              return SizedBox(width: double.infinity, child: button);
            }
            return Row(
              children: [
                Expanded(
                  child: Text(
                    strings.isZh
                        ? '设备就绪后即可进入'
                        : 'Join when your devices are ready',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: style.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Camera-off explanation, independent of capture or preview lifecycle.
class _PreviewExplanation extends StatelessWidget {
  const _PreviewExplanation({
    required this.icon,
    required this.label,
    this.avatarName,
    this.avatarUrl,
  });
  final String? avatarName;
  final String? avatarUrl;

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 200 ||
            MediaQuery.textScalerOf(context).scale(17) >= 28;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.all(compact ? 8 : 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (avatarName != null)
                    RealtimeAvatar(
                      name: avatarName!,
                      avatarUrl: avatarUrl,
                      size: compact ? 40 : 72,
                    )
                  else
                    Icon(icon, size: compact ? 22 : 36, color: style.textMuted),
                  SizedBox(height: compact ? 4 : 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: style.textMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _joinActionLabel(
  RealtimeStrings strings, {
  required bool joining,
  required MediaRole? role,
  required bool classroom,
}) {
  if (joining) return strings.enteringRoom;
  if (role == MediaRole.viewer) return strings.enterLiveRoom;
  if (!classroom) return strings.joinMeeting;
  return role == MediaRole.host
      ? (strings.isZh ? '开始上课' : 'Start class')
      : (strings.isZh ? '加入课堂' : 'Join class');
}

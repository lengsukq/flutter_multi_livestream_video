# Flutter Realtime Design UI

> **Development package, not yet on pub.dev.** This standalone design package
> has no provider dependencies and can be tested independently, but its
> `publish_to: none` remains in effect until the
> [release checklist](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/PUB_DEV_RELEASE_GUIDE.zh-CN.md)
> is completed.

An optional, provider-independent Flutter visual system: cool-gray surfaces,
amber actions, teal live states and rounded media stages. Ships its own fonts
(Onest for body, Bricolage Grotesque for display) so the bundled pages do not
depend on network font loading.
The package depends only on Flutter. It never initializes media, chat, a backend,
or a provider. Import the public entrypoint, never `src/` files.

```dart
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';

MaterialApp(
  theme: RealtimeUiTheme.light(),
  home: const Scaffold(
    body: RealtimeCardSurface(child: Text('Your content')),
  ),
);
```

## Customize the appearance

```dart
final appearance = const RealtimeUiThemeExtension().copyWith(
  palette: RealtimeStyle.light.copyWith(
    accent: const Color(0xFF2E6FD8),
    background: const Color(0xFFF7F8FA),
  ),
  cardRadius: 24,
  controlRadius: 12,
  stageRadius: 20,
  sheetRadius: 28,
  blur: 18,
  glassOpacity: .92,
  glassEnabled: true,
  motionEnabled: true,
  bodyFontFamily: 'HostSans',
  displayFontFamily: 'HostDisplay',
);
final theme = RealtimeUiTheme.light(appearance: appearance);
```

Alternatively install the extension in an existing host's `ThemeData.extensions`.
Use `RealtimeStyle.of(context)` for the active palette and
`RealtimeUiThemeExtension.of(context)` for geometry and material preferences.
Static `RealtimeUiTokens` are defaults and compatibility constants; they do not
change when a host overrides its theme. Explicit widget arguments take priority
except that high contrast and disabled glass always force an opaque surface.

The bundled design has one light appearance. `RealtimeUiTheme.dark()` and
`RealtimeStyle.dark` remain deprecated compatibility aliases to the light design.
Existing imports through media UI and SDK UI continue to work.

## Fonts

`pubspec.yaml` declares `Onest` (400/500/600/700) and `BricolageGrotesque`
(500/700). Address them as `packages/flutter_realtime_design_ui/Onest` and
`packages/flutter_realtime_design_ui/BricolageGrotesque`, or use
`RealtimeFonts.body` / `RealtimeFonts.display`. The single-package release
rewrites those prefixes to `packages/flutter_realtime_sdk/...` and copies the
font files into the hosted package.

## Components

- `RealtimeCardSurface`, `RealtimeCard`, `RealtimeInsetGroup`: stable content.
- `RealtimeGlassSurface`, `RealtimeGlassDialog`,
  `showRealtimeGlassBottomSheet`: floating functional surfaces.
- `RealtimeGlassButton`, `RealtimeGlassIconButton`, `RealtimeGlassTextField`,
  `RealtimeCupertinoSwitchRow`: controls with host callbacks.
- `RealtimeWorkspaceShell`: navigation rail above 1000 logical pixels, bottom
  navigation below that width; the host owns selection and content state.
- `RealtimeMeetingFilmstripStage`, `RealtimeMeetingTileData`: arbitrary widget
  content in a focused media stage and participant strip, without media types.
- `RealtimeBreakpoints`: the shared compact/tablet/desktop/large thresholds so
  pages do not duplicate literals.
- `RealtimeSectionHeader`, `RealtimeStatusPill`, `RealtimeAvatarStack`,
  `RealtimeBoardSurface`, `RealtimeMeter`: small product primitives used by the
  built-in meeting, live and green-room layouts.
- `RealtimeMeetingParticipantStrip`: scrollable, keyboard-accessible participant
  thumbnails with an optional leading content preview. `showFilmstrip` hides
  the strip in `RealtimeMeetingFilmstripStage` without changing its main tile.
- `RealtimeIdleControls.reserveControlsSpace`: reserve the dock's actual height
  below a document stage; normal camera layouts retain floating controls.

Use standard `FilledButton`, `IconButton`, `TextField` and `NavigationDestination`
with `RealtimeUiTheme` when a custom component is unnecessary. Opaque surfaces
are the default, including when the extension is used without a prebuilt page.
`RealtimeGlassDialog` and `showRealtimeGlassBottomSheet` apply the SDK theme
locally when the host has not installed its extension; explicit host overrides
are preserved. Dialogs scroll as a whole so actions remain reachable with large
text, a keyboard or low-height windows.

## Accessibility and performance

High contrast and `glassEnabled: false` disable blur and make surfaces opaque.
Set `glassEnabled` from the host's platform accessibility integration when Reduce
Transparency is available. Flutter does not expose one universal transparency
preference. Reduced motion and `motionEnabled: false` remove control animations.
Glass is clipped to local component bounds. Text follows the system text scaler;
use scrolling and flexible layouts rather than clamping it.

`example/` contains a standalone application demonstrating navigation and theme
customization. It requires no provider credentials or media dependencies.

### Workspace header and compact navigation

`RealtimeWorkspaceShell(header: ..., compactNavigation: true, ...)` provides a
persistent host header, a 60 pt desktop tool rail and flat mobile navigation.
Both options are additive; existing compositions retain their navigation style.
The default `RealtimeUiTheme.light()` uses opaque surfaces. Hosts can explicitly
enable glass with `RealtimeUiThemeExtension(glassEnabled: true)`.

Use `speak` for speaking outlines and dots; use `speakStrong` for small teal text
or controls with white labels. Amber labels use `onAccent`.

# Flutter Realtime Design UI

> **Development package, not yet on pub.dev.** This standalone design package
> has no provider dependencies and can be tested independently, but its
> `publish_to: none` remains in effect until the
> [release checklist](https://github.com/lengsukq/flutter_multi_livestream_video/blob/main/doc/PUB_DEV_RELEASE_GUIDE.zh-CN.md)
> is completed.

An optional, provider-independent Flutter visual system: pearl surfaces,
restrained green actions, rounded media stages and floating glass navigation.
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
    primary: const Color(0xFF503C2B),
    surface: const Color(0xFFFFFCF8),
  ),
  cardRadius: 32,
  controlRadius: 20,
  stageRadius: 36,
  sheetRadius: 40,
  blur: 20,
  glassOpacity: .82,
  glassEnabled: true,
  motionEnabled: true,
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
- `RealtimeMeetingParticipantStrip`: scrollable, keyboard-accessible participant
  thumbnails with an optional leading content preview. `showFilmstrip` hides
  the strip in `RealtimeMeetingFilmstripStage` without changing its main tile.
- `RealtimeIdleControls.reserveControlsSpace`: reserve the dock's actual height
  below a document stage; normal camera layouts retain floating controls.

Use standard `FilledButton`, `IconButton`, `TextField` and `NavigationDestination`
with `RealtimeUiTheme` when a custom component is unnecessary. Use glass for
navigation and temporary controls rather than for every content card.

## Accessibility and performance

High contrast and `glassEnabled: false` disable blur and make surfaces opaque.
Set `glassEnabled` from the host's platform accessibility integration when Reduce
Transparency is available. Flutter does not expose one universal transparency
preference. Reduced motion and `motionEnabled: false` remove control animations.
Glass is clipped to local component bounds. Text follows the system text scaler;
use scrolling and flexible layouts rather than clamping it.

`example/` contains a standalone application demonstrating navigation and theme
customization. It requires no provider credentials or media dependencies.

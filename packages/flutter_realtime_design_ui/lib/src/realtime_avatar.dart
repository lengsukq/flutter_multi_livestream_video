part of '../flutter_realtime_design_ui.dart';

/// Saturated identity colors used by avatars and participant accents.
///
/// The first color is the brand amber; the rest match the reference product's
/// student/tutor palette so a roster reads as a set of people, not gray tiles.
abstract final class RealtimeAvatarPalette {
  static const colors = <Color>[
    Color(0xFF7A5AF8),
    Color(0xFFE2742B),
    Color(0xFF2E8B57),
    Color(0xFFC43E7A),
    Color(0xFF3B82C4),
    Color(0xFF8A6D3B),
    Color(0xFF2E6FD8),
    Color(0xFF9B4DCA),
  ];

  static Color forName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return colors.first;
    final hash = clean.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return colors[hash % colors.length];
  }
}

class RealtimeAvatar extends StatelessWidget {
  const RealtimeAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 38.0,
    this.isOnline = false,
    this.showOnlineDot = false,
    this.fontSize,
    this.color,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final bool isOnline;
  final bool showOnlineDot;
  final double? fontSize;

  /// Explicit background override; otherwise derived from [name].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cleanName = name.trim();
    final initial = cleanName.isEmpty ? '?' : cleanName.characters.first;
    final background = color ?? RealtimeAvatarPalette.forName(cleanName);
    final style = RealtimeStyle.of(context);
    final rawUrl = avatarUrl?.trim() ?? '';
    final uri = Uri.tryParse(rawUrl);
    final validImage =
        rawUrl.isNotEmpty &&
        rawUrl.length <= 2048 &&
        uri != null &&
        ['http', 'https'].contains(uri.scheme.toLowerCase()) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
    final fallback = ColoredBox(
      color: background,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize ?? size * .42,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: cleanName,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: validImage
                      ? Image.network(
                          rawUrl,
                          fit: BoxFit.cover,
                          frameBuilder: (context, child, frame, synchronous) =>
                              frame != null || synchronous ? child : fallback,
                          errorBuilder: (context, error, stack) => fallback,
                        )
                      : fallback,
                ),
              ),
              if (showOnlineDot)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: size * 0.3,
                    height: size * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? style.speak : style.borderStrong,
                      border: Border.all(
                        color: style.surface,
                        width: size > 32 ? 2.0 : 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlapping avatar stack with an optional `+N` overflow chip.
class RealtimeAvatarStack extends StatelessWidget {
  const RealtimeAvatarStack({
    super.key,
    required this.names,
    this.avatarUrls = const {},
    this.size = 28,
    this.maxVisible = 4,
    this.borderColor,
  });

  final List<String> names;
  final Map<String, String?> avatarUrls;
  final double size;
  final int maxVisible;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final visible = names.take(maxVisible).toList(growable: false);
    final overflow = names.length - visible.length;
    final overlap = size * 0.28;
    final slots = visible.length + (overflow > 0 ? 1 : 0);
    if (slots == 0) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      width: size + (slots - 1) * (size - overlap),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor ?? style.surface,
                    width: 2,
                  ),
                ),
                child: RealtimeAvatar(
                  name: visible[i],
                  avatarUrl: avatarUrls[visible[i]],
                  size: size,
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * (size - overlap),
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.border,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor ?? style.surface,
                    width: 2,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '+$overflow',
                    style: TextStyle(
                      fontSize: size * 0.34,
                      fontWeight: FontWeight.w700,
                      color: style.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

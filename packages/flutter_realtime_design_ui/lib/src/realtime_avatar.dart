part of '../flutter_realtime_design_ui.dart';

class RealtimeAvatar extends StatelessWidget {
  const RealtimeAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 38.0,
    this.isOnline = false,
    this.showOnlineDot = false,
    this.fontSize,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final bool isOnline;
  final bool showOnlineDot;
  final double? fontSize;

  static const _palette = [
    Color(0xFFEAF6EE),
    Color(0xFFF0EDF7),
    Color(0xFFFBEFE6),
    Color(0xFFEAF1F5),
  ];

  @override
  Widget build(BuildContext context) {
    final cleanName = name.trim();
    final initial = cleanName.isEmpty ? '?' : cleanName.characters.first;
    final gradientIndex = cleanName.isEmpty
        ? 0
        : cleanName.codeUnits.fold(0, (a, b) => a + b) % _palette.length;
    final background = _palette[gradientIndex];
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
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: style.text,
              fontSize: fontSize ?? size * .42,
              fontWeight: FontWeight.w600,
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
                      color: isOnline
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                      border: Border.all(
                        color: Colors.white,
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

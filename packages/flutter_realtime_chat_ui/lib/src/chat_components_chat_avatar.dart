import 'package:flutter/material.dart';

class ChatComponentsChatAvatar extends StatelessWidget {
  const ChatComponentsChatAvatar({required this.name, this.size = 30.0});
  final String name;
  final double size;

  static const _palette = [
    [Color(0xFF0EA5E9), Color(0xFF0284C7)],
    [Color(0xFF6366F1), Color(0xFF4F46E5)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFFF59E0B), Color(0xFFD97706)],
    [Color(0xFFEC4899), Color(0xFFDB2777)],
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    [Color(0xFF14B8A6), Color(0xFF0D9488)],
    [Color(0xFFF43F5E), Color(0xFFE11D48)],
  ];

  @override
  Widget build(BuildContext context) {
    final clean = name.trim();
    final initial = clean.isEmpty ? '?' : clean.characters.first.toUpperCase();
    final colorIdx = clean.isEmpty
        ? 0
        : clean.codeUnits.fold(0, (a, b) => a + b) % _palette.length;
    final colors = _palette[colorIdx];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.44,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Messages can be placed in a page, side panel, modal or overlay.

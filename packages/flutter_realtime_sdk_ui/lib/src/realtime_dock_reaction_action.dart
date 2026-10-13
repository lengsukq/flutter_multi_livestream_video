import 'package:flutter/material.dart';

class RealtimeDockReactionAction {
  const RealtimeDockReactionAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Consolidated reactions button for [RealtimeMeetingDock].
///
/// Merges quick emoji feedback (understood, great, idea, question, clap),
/// raise hand toggle (with active orange status indicator), and optional custom
/// interactions such as waving into a single clean popup menu.

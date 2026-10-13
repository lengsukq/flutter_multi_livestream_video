import 'package:flutter/material.dart';

class RealtimeDockMoreItem {
  const RealtimeDockMoreItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isActive = false,
    this.isDanger = false,
    this.badgeText,
    this.showBadgeDot = false,
    this.enabled = true,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isActive;
  final bool isDanger;
  final String? badgeText;
  final bool showBadgeDot;
  final bool enabled;
  final Color? accentColor;
}

/// A tactile squircle action item rendered inside [RealtimeDockMoreButton]'s action grid.

import 'package:flutter/material.dart';

class MeetingTheme {
  double messageViewHeight = 162;
  double messageViewWidth = 288;
  double baseUnit = 6;
  double actionViewHeight = 80;

  TextStyle chatNameTextStyle = const TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  TextStyle chatSelfNameTextStyle = TextStyle(
    color: Colors.black,
    background: Paint()..color = Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  TextStyle chatMessageTextStyle = const TextStyle(
    color: Colors.white,
    fontSize: 14,
  );

  TextStyle errorTextStyle = const TextStyle(
    color: Colors.white,
    fontSize: 12,
  );

  TextStyle nameTextStyle = const TextStyle(
    color: Colors.white,
    fontSize: 16,
  );

  Color dotActiveColor = const Color(0xFF6366F1);
  Color audioActiveColor = const Color(0xFF6366F1);
  Color errorBackground = const Color(0xFFF43F5E);

  int pageAttendeeSize = 6;

  static final MeetingTheme _instance = MeetingTheme._internal();

  factory MeetingTheme() {
    return _instance;
  }
  MeetingTheme._internal();
}

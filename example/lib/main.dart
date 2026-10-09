import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_join_screen.dart';

const _demoLocalePreferenceKey = 'realtime_media_demo_locale';
const _demoThemeModePreferenceKey = 'realtime_media_demo_theme_mode';
Locale? _initialDemoLocale;
ThemeMode _initialDemoThemeMode = ThemeMode.light;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep native status bars aligned with the SDK's light surface on iOS and
  // Android, including screens that use custom headers instead of AppBar.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFF4F7FB),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  final preferences = await SharedPreferences.getInstance();
  final savedLocale = preferences.getString(_demoLocalePreferenceKey);
  _initialDemoLocale = switch (savedLocale) {
    'zh' => const Locale('zh', 'CN'),
    'en' => const Locale('en'),
    _ => null,
  };
  final savedThemeMode = preferences.getString(_demoThemeModePreferenceKey);
  _initialDemoThemeMode = switch (savedThemeMode) {
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.light,
  };
  runApp(const ChimeExampleApp());
}

class ChimeExampleApp extends StatefulWidget {
  const ChimeExampleApp({super.key});

  @override
  State<ChimeExampleApp> createState() => _ChimeExampleAppState();
}

class _ChimeExampleAppState extends State<ChimeExampleApp> {
  Locale? _locale = _initialDemoLocale;
  ThemeMode _themeMode = _initialDemoThemeMode;

  Future<void> _setLocale(Locale locale) async {
    setState(() => _locale = locale);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _demoLocalePreferenceKey,
      locale.languageCode == 'zh' ? 'zh' : 'en',
    );
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_demoThemeModePreferenceKey, mode.name);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );
    return MaterialApp(
      title: 'Realtime Media',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: RealtimeStrings.supportedLocales,
      localizationsDelegates: RealtimeStrings.localizationsDelegates,
      theme: RealtimeUiTheme.light(),
      darkTheme: RealtimeUiTheme.dark(),
      themeMode: _themeMode,
      home: JoinScreen(
        onLocaleChanged: _setLocale,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

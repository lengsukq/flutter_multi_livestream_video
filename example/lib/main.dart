import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_theme.dart';
import 'demo_join_screen.dart';

const _demoLocalePreferenceKey = 'realtime_media_demo_locale';
Locale? _initialDemoLocale;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep native status bars aligned with the SDK's light surface on iOS and
  // Android, including screens that use custom headers instead of AppBar.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFF5F5F7),
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
  runApp(const ChimeExampleApp());
}

class ChimeExampleApp extends StatefulWidget {
  const ChimeExampleApp({super.key});

  @override
  State<ChimeExampleApp> createState() => _ChimeExampleAppState();
}

class _ChimeExampleAppState extends State<ChimeExampleApp> {
  Locale? _locale = _initialDemoLocale;

  Future<void> _setLocale(Locale locale) async {
    setState(() => _locale = locale);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _demoLocalePreferenceKey,
      locale.languageCode == 'zh' ? 'zh' : 'en',
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    return MaterialApp(
      title: 'multi-video',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: RealtimeStrings.supportedLocales,
      localizationsDelegates: RealtimeStrings.localizationsDelegates,
      theme: DemoTheme.themeData(),
      themeMode: ThemeMode.light,
      builder: (context, child) {
        final currentLocale = _locale ?? Localizations.localeOf(context);
        final isZh = currentLocale.languageCode.toLowerCase() == 'zh';
        return RealtimeStringsScope(
          strings: isZh
              ? const RealtimeStrings.zh()
              : const RealtimeStrings.en(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: JoinScreen(onLocaleChanged: _setLocale),
    );
  }
}

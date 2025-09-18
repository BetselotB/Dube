// lib/main.dart
import 'package:dube/firebase_options.dart';
import 'package:dube/l10n/app_localizations.dart';
import 'package:dube/pages/choose%20language/choose_language.dart';
import 'package:dube/pages/homepage/homepage.dart';
import 'package:dube/pages/paywall/paywall_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/locale_provider.dart'; // make sure this file exists
import 'services/trial_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      title: 'Dube',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8D99AE),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF2B2D42),
          onPrimary: const Color(0xFFFFFFFF),
          secondary: const Color(0xFF8D99AE),
          onSecondary: const Color(0xFF2B2D42),
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF2B2D42),
          background: const Color(0xFFFFFFFF),
          onBackground: const Color(0xFF2B2D42),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF2B2D42),
          elevation: 0,
          surfaceTintColor: Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
        ),
        cardTheme: CardThemeData(
          color: Color(0xFFFFFFFF),
          surfaceTintColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF2B2D42),
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF2B2D42),
          foregroundColor: Color(0xFFFFFFFF),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          selectedTileColor: const Color(0xFF8D99AE),
          iconColor: const Color(0xFF2B2D42),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF8D99AE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF8D99AE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2B2D42), width: 1.6),
          ),
          filled: true,
          fillColor: Color(0xFFFFFFFF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: Color(0xFF2B2D42),
            foregroundColor: Color(0xFFFFFFFF),
            shadowColor: Color(0xFF2B2D42),
            elevation: 2,
          ),
        ),
        splashColor: const Color(0xFF8D99AE),
        highlightColor: const Color(0xFF8D99AE),
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        }),
      ),
      locale: localeProvider.locale, // <-- set locale from provider
      supportedLocales: const [Locale('en'), Locale('am')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final double _textWidth;
  final String _logoText = 'ዱቤ';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    const textStyle = TextStyle(fontSize: 56, fontWeight: FontWeight.bold);
    final tp = TextPainter(
      text: TextSpan(text: _logoText, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    _textWidth = tp.width;

    // After the splash duration decide where to go:
    Future.delayed(const Duration(milliseconds: 1400), () async {
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Evaluate trial/paywall before routing
        final locked = await TrialService.evaluateAndPersist();
        if (!mounted) return;
        if (locked) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PaywallPage()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      } else {
        // Not signed in -> show language selector (as before)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LanguageSelector()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double barHeight = 14.0;
    final double containerWidth = _textWidth;
    final double indicatorWidth = containerWidth * 0.28;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _logoText,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: containerWidth,
                height: barHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(barHeight / 2),
                  child: Stack(
                    children: [
                      Container(color: Colors.black),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final double maxLeft =
                              containerWidth - indicatorWidth;
                          final double left = maxLeft * _controller.value;
                          return Positioned(
                            left: left,
                            top: 0,
                            bottom: 0,
                            width: indicatorWidth,
                            child: child!,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(barHeight / 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Loading...',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

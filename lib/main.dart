// lib/main.dart
import 'package:dube/l10n/app_localizations.dart';
import 'package:dube/pages/choose%20language/choose_language.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/locale_provider.dart'; // make sure this file exists

void main() {
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.white,
      ),
      locale: localeProvider.locale, // <-- set locale from provider
      supportedLocales: const [
        Locale('en'),
        Locale('am'),
      ],
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

    const textStyle = TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.bold,
    );
    final tp = TextPainter(
      text: TextSpan(text: _logoText, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    _textWidth = tp.width;

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
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

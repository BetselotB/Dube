// lib/main.dart
import 'package:dube/firebase_options.dart';
import 'package:dube/l10n/app_localizations.dart';
import 'package:dube/pages/choose%20language/choose_language.dart';
import 'package:dube/pages/homepage/homepage.dart';
import 'package:dube/pages/paywall/paywall_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/locale_provider.dart'; // make sure this file exists

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
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF8D99AE),
              brightness: Brightness.light,
            ).copyWith(
              primary: const Color(0xFF2B2D42),
              onPrimary: const Color(0xFFFFFFFF),
              secondary: const Color(0xFF8D99AE),
              onSecondary: const Color(0xFF2B2D42),
              surface: const Color(0xFFFFFFFF),
              onSurface: const Color(0xFF2B2D42),
              // ignore: deprecated_member_use
              background: const Color(0xFFFFFFFF),
              // ignore: deprecated_member_use
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF2B2D42),
          foregroundColor: Color(0xFFFFFFFF),
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: Color(0xFF2B2D42),
            foregroundColor: Color(0xFFFFFFFF),
            shadowColor: Color(0xFF2B2D42),
            elevation: 2,
          ),
        ),
        splashColor: const Color(0xFF8D99AE),
        highlightColor: const Color(0xFF8D99AE),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
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

      // Check connectivity first
      final connectivity = await Connectivity().checkConnectivity();
      // ignore: unrelated_type_equality_checks
      final isOnline = connectivity != ConnectivityResult.none;

      if (user == null) {
        // Not signed in -> show language selector (as before)
        // ignore: use_build_context_synchronously
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LanguageSelector()),
        );
        return;
      }

      if (!isOnline) {
        // Offline: skip paywall checks, allow access
        Navigator.of(
          // ignore: use_build_context_synchronously
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
        return;
      }

      // Online and signed in: check Firestore for paywall conditions
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        DateTime? createdAt = _parseFirestoreDate(doc.data()?['createdAt']);
        final String? paymentStatus = (doc.data()?['paymentStatus']) as String?;
        DateTime? paidAt = _parseFirestoreDate(doc.data()?['paidAt']);

        final now = DateTime.now();

        bool showPaywall = false;

        if (paymentStatus == null) {
          // New user: 15-day free trial from createdAt
          if (createdAt != null) {
            final trialDays = now.difference(createdAt).inDays;
            if (trialDays >= 15) showPaywall = true;
          }
        } else if (paymentStatus.toLowerCase() == 'unpaid') {
          // Already marked unpaid => require paywall
          showPaywall = true;
        } else if (paymentStatus.toLowerCase() == 'paid') {
          if (paidAt != null) {
            final daysSincePaid = now.difference(paidAt).inDays;
            if (daysSincePaid >= 365) showPaywall = true;
          }
        }

        if (!mounted) return;
        if (showPaywall) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PaywallPage()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      } catch (e) {
        // On any error, allow access (fail-open) to avoid blocking legit users
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
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

// Robustly parse Firestore date-like values into DateTime.
// Supports Timestamp, ISO8601 string, and Firestore console-like strings.
DateTime? _parseFirestoreDate(dynamic value) {
  try {
    if (value == null) return null;
    // cloud_firestore Timestamp
    if (value is Timestamp) return value.toDate();
    // milliseconds since epoch
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    // ISO-8601 string
    if (value is String) {
      // Try direct parse
      try {
        return DateTime.parse(value);
      } catch (_) {
        // Try parsing Firestore console-like: 'September 9, 2025 at 12:39:35 PM UTC+3'
        final cleaned = value.replaceAll(' at ', ' ');
        // Remove literal 'UTC' to keep offset only
        final withOffset = cleaned.replaceAll('UTC', '').trim();
        return DateTime.tryParse(withOffset);
      }
    }
  } catch (_) {}
  return null;
}

// lib/pages/choose language/choose_language.dart
import 'package:dube/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// AuthPage - adjust package path if your auth file lives elsewhere
import 'package:dube/pages/auth/auth.dart';

// LocaleProvider (make sure the file exists at lib/core/locale_provider.dart)
import '../../core/locale_provider.dart';

enum AppLanguage { english, amharic }

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  AppLanguage? _selected;

  Future<void> _onNext() async {
    if (_selected == null) return;

    final provider = Provider.of<LocaleProvider>(context, listen: false);
    final code = _selected == AppLanguage.english ? 'en' : 'am';

    await provider.setLocale(Locale(code));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }

  Widget _languageCard({
    required String label,
    required String subLabel,
    required String assetEmoji,
    required AppLanguage value,
  }) {
    final isSelected = _selected == value;
    return GestureDetector(
      onTap: () => setState(() => _selected = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? Colors.deepPurple : Colors.grey.shade100,
              ),
              child: Text(assetEmoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.black : Colors.black87,
                      )),
                  const SizedBox(height: 4),
                  Text(subLabel,
                      style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.black54 : Colors.black45)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? Colors.deepPurple : Colors.grey),
                color: isSelected ? Colors.deepPurple : Colors.white,
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use AppLocalizations.of(context) and provide fallback strings if null
    final t = AppLocalizations.of(context);

    final selectLanguage = t?.selectLanguage ?? 'Select language';
    final chooseYourLanguage = t?.chooseYourLanguage ?? 'Choose your language';
    final changeLaterHint = t?.changeLaterHint ?? 'You can change this later in settings.';
    final englishLabel = t?.englishLabel ?? 'English';
    final englishSub = t?.englishSubLabel ?? 'Use the app in English';
    final amharicLabel = t?.amharicLabel ?? 'አማርኛ';
    final amharicSub = t?.amharicSubLabel ?? 'በአማርኛ መጠቀም';
    final nextLabel = t?.next ?? 'Next';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: Text(selectLanguage, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(chooseYourLanguage, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(changeLaterHint, style: const TextStyle(color: Colors.black54)),
            ),
            const SizedBox(height: 24),
            _languageCard(label: englishLabel, subLabel: englishSub, assetEmoji: '🇺🇸', value: AppLanguage.english),
            const SizedBox(height: 14),
            _languageCard(label: amharicLabel, subLabel: amharicSub, assetEmoji: '🇪🇹', value: AppLanguage.amharic),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _selected == null ? null : _onNext,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: Text(
                    nextLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _selected == null ? Colors.white38 : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/pages/language_selector.dart
import 'package:dube/pages/auth/auth.dart';
import 'package:flutter/material.dart';

enum AppLanguage { english, amharic }

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  AppLanguage? _selected;

  void _onNext() {
    if (_selected == null) return;
    final langCode = _selected == AppLanguage.english ? 'en' : 'am';
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AuthPage(languageCode: langCode),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected ? Colors.deepPurple : Colors.grey.shade200,
              width: isSelected ? 2 : 1),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            // Visual icon / emoji
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? Colors.deepPurple : Colors.grey.shade100,
              ),
              child: Text(
                assetEmoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(width: 14),
            // Labels
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
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected ? Colors.deepPurple : Colors.grey),
                color: isSelected ? Colors.deepPurple : Colors.white,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Page padding and layout designed for legibility and large touch targets
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text('Select language', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose your language',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'You can change this later in settings.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            const SizedBox(height: 24),
            // Language options
            _languageCard(
              label: 'English',
              subLabel: 'Use the app in English',
              assetEmoji: '🇺🇸',
              value: AppLanguage.english,
            ),
            const SizedBox(height: 14),
            _languageCard(
              label: 'አማርኛ',
              subLabel: 'በአማርኛ መጠቀም',
              assetEmoji: '🇪🇹',
              value: AppLanguage.amharic,
            ),
            const Spacer(),
            // Next button
            Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _selected == null ? null : _onNext,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: Text(
                    'Next',
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

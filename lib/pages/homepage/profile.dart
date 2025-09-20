import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.profile),
      ),
      body: user == null
          ? Center(child: Text(AppLocalizations.of(context)!.notSignedIn))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFF2B2D42),
                      child: Text(
                        'U',
                        style: TextStyle(color: Color(0xFFFFFFFF)),
                      ),
                    ),
                    title: Text(user.displayName ?? 'User'),
                    subtitle: Text(user.email ?? ''),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(AppLocalizations.of(context)!.name),
                        subtitle: Text(user.displayName ?? '—'),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(user.email ?? '—'),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: const Text('UID'), // No localization for UID, keep as is
                        subtitle: Text(user.uid),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help & FAQ'),
                    subtitle: Text(AppLocalizations.of(context)!.aboutHint),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpFaqPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({super.key});

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.helpFaq),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
  leading: Icon(Icons.email, color: Colors.red),
  title: Text('Email'),
  subtitle: Text('betselotbekeley@gmail.com'),
  onTap: () async {
    // Try Gmail web first, fallback to mailto
    final gmailUrl = 'https://mail.google.com/mail/?view=cm&to=betselotbekeley@gmail.com&su=Support%20Request';
    final mailtoUrl = 'mailto:betselotbekeley@gmail.com?subject=Support%20Request';
    if (await canLaunchUrl(Uri.parse(gmailUrl))) {
      await launchUrl(Uri.parse(gmailUrl), mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse(mailtoUrl), mode: LaunchMode.externalApplication);
    }
  },
),
const Divider(height: 0),
ListTile(
  leading: Icon(Icons.telegram, color: Colors.blue),
  title: Text('Telegram'),
  subtitle: Text('@dubeappsupport'),
  onTap: () async {
    // Try to open in Telegram app, fallback to web
    final tgApp = 'tg://resolve?domain=dubeappsupport';
    final tgWeb = 'https://t.me/dubeappsupport';
    if (await canLaunchUrl(Uri.parse(tgApp))) {
      await launchUrl(Uri.parse(tgApp), mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse(tgWeb), mode: LaunchMode.externalApplication);
    }
  },
),
const Divider(height: 0),
ListTile(
  leading: Icon(Icons.facebook, color: Colors.indigo),
  title: Text('Facebook'),
  subtitle: Text('facebook.com/dubeapp'),
  onTap: () async {
    // Try to open in Facebook app, fallback to web
    final fbApp = 'fb://facewebmodal/f?href=https://web.facebook.com/profile.php?id=61581257246461';
    final fbWeb = 'https://web.facebook.com/profile.php?id=61581257246461';
    if (await canLaunchUrl(Uri.parse(fbApp))) {
      await launchUrl(Uri.parse(fbApp), mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse(fbWeb), mode: LaunchMode.externalApplication);
    }
  },
),
                const Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.phone_outlined, color: Colors.green),
                  title: Text(AppLocalizations.of(context)!.phoneNumber),
                  subtitle: const Text('+251 90 064 7953'),
                  onTap: () async {
                    final uri = Uri(scheme: 'tel', path: '+251900647953');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              ],
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: Text(
                      'Frequently Asked Questions',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _FaqSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final faqs = [
      _FaqItem(
        question: l.faqAddPersonQ,
        answer: l.faqAddPersonA,
      ),
      _FaqItem(
        question: l.faqViewDubesQ,
        answer: l.faqViewDubesA,
      ),
      _FaqItem(
        question: l.faqMarkPaidQ,
        answer: l.faqMarkPaidA,
      ),
      _FaqItem(
        question: l.faqRecoverPersonQ,
        answer: l.faqRecoverPersonA,
      ),
      _FaqItem(
        question: l.faqSearchQ,
        answer: l.faqSearchA,
      ),
      _FaqItem(
        question: l.faqOfflineQ,
        answer: l.faqOfflineA,
      ),
      _FaqItem(
        question: l.faqLanguageQ,
        answer: l.faqLanguageA,
      ),
      _FaqItem(
        question: l.faqExportQ,
        answer: l.faqExportA,
      ),
      _FaqItem(
        question: l.faqPremiumQ,
        answer: l.faqPremiumA,
      ),
      _FaqItem(
        question: l.faqBackupQ,
        answer: l.faqBackupA,
      ),
      _FaqItem(
        question: l.faqNotificationsQ,
        answer: l.faqNotificationsA,
      ),
      _FaqItem(
        question: l.faqSupportQ,
        answer: l.faqSupportA,
      ),
      _FaqItem(
        question: l.faqSecurityQ,
        answer: l.faqSecurityA,
      ),
      _FaqItem(
        question: l.faqPaywallQ,
        answer: l.faqPaywallA,
      ),
      _FaqItem(
        question: l.faqShareQ,
        answer: l.faqShareA,
      ),
    ];
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: faqs.length,
      itemBuilder: (context, i) {
        return _FaqTile(faq: faqs[i]);
      },
    );
  }
}


class _FaqTile extends StatefulWidget {
  final _FaqItem faq;
  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: ExpansionTile(
        title: Text(widget.faq.question, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(widget.faq.answer),
          )
        ],
        initiallyExpanded: _expanded,
        onExpansionChanged: (v) => setState(() => _expanded = v),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}





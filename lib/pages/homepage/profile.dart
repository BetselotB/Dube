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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.helpFaq),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppLocalizations.of(context)!.needHelpContactSupport,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(AppLocalizations.of(context)!.phoneNumber),
              subtitle: const Text('+251 90 064 7953'),
              onTap: () async {
                final uri = Uri(scheme: 'tel', path: '+251900647953');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(AppLocalizations.of(context)!.emailSupport),
              subtitle: Text(AppLocalizations.of(context)!.supportEmail), // Keep as is, or localize if needed
              onTap: () async {
                final uri = Uri(
                  scheme: 'mailto',
                  path: AppLocalizations.of(context)!.supportEmail,
                  query: Uri.encodeQueryComponent('subject=Support Request'),
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.faqHeader,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context)!.faqAddPerson),
          const SizedBox(height: 6),
          Text(AppLocalizations.of(context)!.faqViewDubes),
          const SizedBox(height: 6),
          Text(AppLocalizations.of(context)!.faqEditDeleteDube),
        ],
      ),
    );
  }
}



import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: user == null
          ? const Center(child: Text('Not signed in'))
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
                        title: const Text('Name'),
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
                        title: const Text('UID'),
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
                    subtitle: const Text('Contact info and common questions'),
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
        title: const Text('Help & FAQ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Need help?',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'If you have any questions, issues, or feedback, please reach out to us using the contact information below.',
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Phone'),
              subtitle: const Text('+1 (555) 123-4567'),
              onTap: () async {
                final uri = Uri(scheme: 'tel', path: '+15551234567');
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
              title: const Text('Email'),
              subtitle: const Text('support@dubeapp.example'),
              onTap: () async {
                final uri = Uri(
                  scheme: 'mailto',
                  path: 'support@dubeapp.example',
                  query: Uri.encodeQueryComponent('subject=Support Request'),
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'FAQ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('• How do I add a person? Use the Home screen add field.'),
          const SizedBox(height: 6),
          const Text('• How do I view dubes? Tap a person to open their dubes.'),
          const SizedBox(height: 6),
          const Text('• How do I edit/delete a dube? Use the menu on each item.'),
        ],
      ),
    );
  }
}



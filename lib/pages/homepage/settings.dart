// lib/pages/homepage/settings.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../src/local_sqlite.dart';
import '../../core/locale_provider.dart';
import '../../l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = false;
  bool _analyticsEnabled = true;
  bool _autoBackup = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _analyticsEnabled = sp.getBool('analytics_enabled') ?? true;
      _autoBackup = sp.getBool('auto_backup') ?? false;
    });
  }

  Future<void> _setPref(String key, bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, value);
  }

  // ---------------- backup / export / restore ----------------
  Future<void> _backupToCloud() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      final when = await LocalSqlite.backupToFirestore();
      if (!mounted) return;
      _showSnack('${AppLocalizations.of(context)?.backup ?? 'Backup uploaded'} — $when');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Backup failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportToFileAndShare() async {
    setState(() => _loading = true);
    try {
      final path = await LocalSqlite.exportDbToJsonFile();
      final file = File(path);
      if (!await file.exists()) throw Exception('Exported file not found');

      // Share file using share_plus
      final xfile = XFile(path);
      await Share.shareXFiles([xfile], text: AppLocalizations.of(context)?.share ?? 'Dube app backup');

      _showSnack(AppLocalizations.of(context)?.share ?? 'Exported and opening share sheet...');
    } catch (e) {
      if (mounted) _showSnack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreFromCloud() async {
    final ok = await _confirmDialog(
      title: AppLocalizations.of(context)?.restoreFromCloud ?? 'Restore from cloud?',
      message: AppLocalizations.of(context)?.restoreHint ?? 'This will replace local data with the latest cloud backup. Continue?',
      confirmLabel: AppLocalizations.of(context)?.restore ?? 'Restore',
    );
    if (!ok) return;

    setState(() => _loading = true);
    try {
      await LocalSqlite.restoreFromFirestoreLatestBackup();
      if (!mounted) return;
      _showSnack(AppLocalizations.of(context)?.restore ?? 'Restore complete');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Restore failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- account actions ----------------
  Future<void> _signOut() async {
    final ok = await _confirmDialog(
      title: AppLocalizations.of(context)?.signOut ?? 'Sign out?',
      message: AppLocalizations.of(context)?.signOut ?? 'You will be signed out from this device.',
      confirmLabel: AppLocalizations.of(context)?.signOut ?? 'Sign out',
    );
    if (!ok) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    _showSnack(AppLocalizations.of(context)?.signOut ?? 'Signed out');
    Navigator.of(context).pop(); // go back to previous screen (Auth)
  }

  Future<void> _deleteAccount() async {
    final ok = await _confirmDialog(
      title: AppLocalizations.of(context)?.deleteAccount ?? 'Delete account?',
      message: AppLocalizations.of(context)?.deleteAccount ?? 'This will attempt to permanently delete your account. This action may require recent login.',
      confirmLabel: AppLocalizations.of(context)?.deleteAccount ?? 'Delete',
      destructive: true,
    );
    if (!ok) return;

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No signed-in user');
      await user.delete();
      if (!mounted) return;
      _showSnack('Account deleted');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Delete failed: $e\nYou may need to re-authenticate before deleting');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- preferences ----------------
  Future<void> _toggleAnalytics(bool next) async {
    setState(() => _analyticsEnabled = next);
    await _setPref('analytics_enabled', next);
    _showSnack(next ? (AppLocalizations.of(context)?.analytics ?? 'Analytics enabled') : (AppLocalizations.of(context)?.analytics ?? 'Analytics disabled'));
  }

  Future<void> _toggleAutoBackup(bool next) async {
    setState(() => _autoBackup = next);
    await _setPref('auto_backup', next);
    _showSnack(next ? AppLocalizations.of(context)?.autoBackup ?? 'Auto-backup enabled' : AppLocalizations.of(context)?.autoBackup ?? 'Auto-backup disabled');
  }

  // ---------------- language ----------------
  Future<void> _changeLanguage(Locale locale) async {
    final provider = Provider.of<LocaleProvider>(context, listen: false);
    await provider.setLocale(locale);
    _showSnack('${AppLocalizations.of(context)?.language ?? 'Language'}: ${locale.languageCode}');
  }

  // ---------------- small helpers ----------------
  Future<bool> _confirmDialog({
    required String title,
    required String message,
    String confirmLabel = 'Yes',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive ? Colors.red : null,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    const versionLabel = 'Version 1.0.0';

    return Scaffold(
      appBar: AppBar(title: Text(t.settingsTitle)),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            child: Text((user?.displayName ?? 'U').isNotEmpty ? (user?.displayName ?? 'U').substring(0, 1) : 'U'),
                          ),
                          title: Text(user?.displayName ?? t.guest),
                          subtitle: Text(user?.email ?? t.notSignedIn),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'signout') _signOut();
                              if (v == 'delete') _deleteAccount();
                              if (v == 'share') Share.share(t.shareApp);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'share', child: Text(t.shareApp)),
                              if (user != null) PopupMenuItem(value: 'signout', child: Text(t.signOut)),
                              if (user != null) PopupMenuItem(value: 'delete', child: Text(t.deleteAccount)),
                            ],
                          ),
                        ),
                        if (user == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text(t.signIn),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _exportToFileAndShare,
                                    child: Text(t.exportBackup),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Backups card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.cloud_upload_outlined),
                          title: Text(t.backupToCloud),
                          subtitle: Text(t.backupHint),
                          trailing: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : ElevatedButton(
                            onPressed: _loading ? null : _backupToCloud,
                            child: Text(t.backup),
                          ),
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.upload_file_outlined),
                          title: Text(t.exportBackup),
                          subtitle: Text(t.exportHint),
                          trailing: TextButton.icon(onPressed: _loading ? null : _exportToFileAndShare, icon: const Icon(Icons.share), label: Text(t.share)),
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.cloud_download_outlined),
                          title: Text(t.restoreFromCloud),
                          subtitle: Text(t.restoreHint),
                          trailing: ElevatedButton(
                            onPressed: _loading ? null : _restoreFromCloud,
                            child: Text(t.restore),
                          ),
                        ),
                        // Auto-backup toggle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(t.autoBackup, style: const TextStyle(fontWeight: FontWeight.w600))),
                              Switch(value: _autoBackup, onChanged: (v) => _toggleAutoBackup(v)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Preferences (analytics, language)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.analytics_outlined),
                        title: Text(t.analytics),
                        subtitle: Text(t.analyticsHint),
                        trailing: Switch(value: _analyticsEnabled, onChanged: (v) => _toggleAnalytics(v)),
                      ),
                      const Divider(height: 0),
                      // Language selector inline
                      ListTile(
                        leading: const Icon(Icons.language),
                        title: Text(t.language),
                        subtitle: Text(t.languageHint),
                        onTap: () => _showLanguagePicker(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // About & other tools
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: Text(t.about),
                        subtitle: Text(t.aboutHint),
                        onTap: () => _showAbout(),
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.ios_share),
                        title: Text(t.shareApp),
                        onTap: () async {
                          await Share.share(t.shareApp);
                        },
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: Text(t.signOut),
                        onTap: _signOut,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // App info
                Center(
                  child: Column(
                    children: [
                      Text(versionLabel, style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text(t.appName, style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),

          if (_loading)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  // ---------- UI helpers ----------
  Future<void> _showLanguagePicker() async {
    final provider = Provider.of<LocaleProvider>(context, listen: false);
    final current = provider.locale?.languageCode ?? 'en';
    final t = AppLocalizations.of(context)!;

    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(t.selectLanguage, style: const TextStyle(fontWeight: FontWeight.w600))),
              RadioListTile<String>(
                title: Text(t.englishLabel),
                value: 'en',
                groupValue: current,
                onChanged: (v) {
                  Navigator.of(c).pop(v);
                },
              ),
              RadioListTile<String>(
                title: Text(t.amharicLabel),
                value: 'am',
                groupValue: current,
                onChanged: (v) {
                  Navigator.of(c).pop(v);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    await _changeLanguage(Locale(selected));
  }

  void _showAbout() {
    final t = AppLocalizations.of(context)!;
    showAboutDialog(
      context: context,
      applicationName: t.appName,
      applicationVersion: '1.0.0',
      children: [
        Text(t.aboutText),
        const SizedBox(height: 8),
        Text(t.privacy),
      ],
    );
  }
}




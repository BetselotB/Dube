// lib/pages/homepage/settings.dart
import 'package:flutter/material.dart';
import '../../src/local_sqlite.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
// for XFile used by shareXFiles

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = false;

  Future<void> _backupToCloud() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      await LocalSqlite.backupToFirestore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup uploaded to cloud')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportToFileAndShare() async {
    setState(() => _loading = true);
    try {
      final path = await LocalSqlite.exportDbToJsonFile();

      // Use Share.shareXFiles with an XFile (modern share_plus API)
      // This works for sharing files (text+file). On some platforms (iPad) you
      // might need to provide sharePositionOrigin; see share_plus docs.
      final xfile = XFile(path);
      await Share.shareXFiles([xfile], text: 'Dube app backup');

      // If you prefer a simpler text-only share, use:
      // await Share.share('Dube app backup - file at $path');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreFromCloud() async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restore from cloud'),
        content: const Text('This will replace local data with the latest cloud backup. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await LocalSqlite.restoreFromFirestoreLatestBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore complete')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          ElevatedButton.icon(onPressed: _loading ? null : _exportToFileAndShare, icon: const Icon(Icons.upload_file_outlined), label: const Text('Export backup (share file)')),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _loading ? null : _backupToCloud, icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Backup to Cloud (Firestore)')),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _loading ? null : _restoreFromCloud, icon: const Icon(Icons.cloud_download_outlined), label: const Text('Restore latest from Cloud')),
          const SizedBox(height: 18),
          if (_loading) const LinearProgressIndicator(),
        ]),
      ),
    );
  }
}

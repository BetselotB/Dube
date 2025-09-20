// lib/pages/homepage/home.dart
import 'package:dube/l10n/app_localizations.dart';
import 'package:dube/pages/homepage/dubes.dart';
import 'package:dube/components/flag.dart';
import 'package:dube/pages/homepage/settings.dart';
import 'package:dube/pages/homepage/profile.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
// Removed third-party bottom nav; using a modal bottom sheet for navigation
import '../../src/local_sqlite.dart';
import '../auth/auth.dart';
// paywall enforcement moved to splash (main.dart)

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class PersonLocal {
  final String id;
  final String name;
  final num total;
  final int? createdAt;
  PersonLocal({required this.id, required this.name, required this.total, this.createdAt});

  factory PersonLocal.fromRow(Map<String, dynamic> r) =>
      PersonLocal(
        id: r['id'],
        name: r['name'],
        total: r['total'] ?? 0,
        createdAt: r['createdAt'] as int?,
      );

  static PersonLocal fromMap(Map<String, dynamic> p) => PersonLocal(
    id: p['id'],
    name: (p['name'] ?? '').toString(),
    total: p['total'] ?? 0,
    createdAt: p['createdAt'] as int?,
  );
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _nameCtrl = TextEditingController();
  List<PersonLocal> _people = [];
  String _search = '';
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPageIndex = 0;
  bool _showDeleted = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    final rows = await LocalSqlite.getPeople(search: _search, deleted: _showDeleted);
    if (!mounted) return;
    setState(() => _people = rows.map((r) => PersonLocal.fromRow(r)).toList());
  }

  Future<void> _addPerson() async {
    if (!mounted) return;
    
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    
    try {
      // Check if person with this name exists
      final existing = await LocalSqlite.findPersonByName(name, includeDeleted: true);
      
      if (existing != null) {
        if (existing['deleted'] == 1) {
          // Ask if user wants to revive this person
          final revive = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.personExistsTitle),
              content: Text(AppLocalizations.of(context)!.revivePersonPrompt(name)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(c).pop(true),
                  child: Text(AppLocalizations.of(context)!.revive),
                ),
              ],
            ),
          );
          
          if (revive != true || !mounted) return;
          
          // Revive the person
          final revivedPerson = await LocalSqlite.insertPerson(name);
          if (!mounted) return;
          
          if (revivedPerson != null) {
            _nameCtrl.clear();
            await _loadPeople();
            
            if (!mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DubesPage(
                  personId: revivedPerson['id'],
                  personName: revivedPerson['name'],
                ),
              ),
            );
            // Reload the people list when coming back
            if (mounted) {
              await _loadPeople();
            }
          }
          return;
        } else {
          // Person exists and is active
          if (!mounted) return;
          
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.personExistsTitle),
              content: Text(AppLocalizations.of(context)!.personExistsMessage(name)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(c).pop(true),
                  child: Text(AppLocalizations.of(context)!.openExisting),
                ),
              ],
            ),
          );
          
          if (shouldOpen == true && mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DubesPage(
                  personId: existing['id'],
                  personName: existing['name'],
                ),
              ),
            );
            // Reload the people list when coming back
            if (mounted) {
              await _loadPeople();
            }
          }
          return;
        }
      }
      
      // If we get here, it's a new person
      final person = await LocalSqlite.insertPerson(name);
      if (!mounted) return;
      
      _nameCtrl.clear();
      await _loadPeople();
      
      if (person != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DubesPage(
              personId: person['id'],
              personName: person['name'],
            ),
          ),
        );
        // Reload the people list when coming back
        if (mounted) {
          await _loadPeople();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deletePerson(String id) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Mark as Completed?'),
        content: Text('This will move this person to the completed section. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text('Mark as Completed'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LocalSqlite.deletePerson(id);
    await _loadPeople();
  }
  
  Future<void> _markAllDubesAsPaid(String personId) async {
    try {
      // Get all unpaid dubes for this person
      final dubes = await LocalSqlite.getDubesForPerson(personId, showPaid: false);
      
      // Mark each dube as paid
      for (final dube in dubes) {
        await LocalSqlite.markDubeAsPaid(dube['id']);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All dubes marked as paid')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking dubes as paid: $e')),
        );
      }
    }
  }

  Widget _buildDrawer(User user) {
    return Drawer(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(user.displayName ?? 'User'),
                accountEmail: Text(user.email ?? ''),
                currentAccountPicture: const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF2B2D42),
                  child: Text(
                    'U',
                    style: TextStyle(color: Color(0xFFFFFFFF)),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: Text(AppLocalizations.of(context)!.settings),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(AppLocalizations.of(context)!.profile),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: Text(AppLocalizations.of(context)!.helpFaq),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpFaqPage()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(AppLocalizations.of(context)!.logout),
                onTap: _logout,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  AppLocalizations.of(context)!.appVersion('1.0.0'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthPage()));
  }Future<void> _shareApp() async {
  const url = 'https://www.youtube.com/';
  final text = 'Check out this app! $url';

  try {
    // Share basic text + url
    await Share.share(text, subject: 'My App');
    // optional: show a confirmation
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share sheet opened')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to share: $e')),
    );
  }
}

  // removed obsolete bottom sheet switcher (replaced by PageView + FAB)

  void _gotoDubes(String personName, String personId, {bool readOnly = false}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                DubesPage(personId: personId, personName: personName, readOnly: readOnly),
          ),
        )
        .then((_) => _loadPeople());
  }

  // Deleted persons open in read-only dubes view; no separate dialog needed

  Widget _buildHomeTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.addPersonName,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addPerson(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _showDeleted ? null : _addPerson,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                ),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, icon: const Icon(Icons.people_outline), label: Text(AppLocalizations.of(context)!.active)),
              ButtonSegment(value: 1, icon: const Icon(Icons.delete_outline), label: Text(AppLocalizations.of(context)!.paid)),
            ],
            selected: {_showDeleted ? 1 : 0},
            onSelectionChanged: (s) async {
              final v = s.first;
              setState(() => _showDeleted = v == 1);
              await _loadPeople();
            },
            showSelectedIcon: false,
          ),
        ),
        SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: AppLocalizations.of(context)!.searchPeople,
            ),
            onChanged: (v) async {
              _search = v;
              await _loadPeople();
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _people.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noPeopleYet))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _people.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = _people[i];
                    final initials = _getInitials(p.name);
                    return Card(
                      child: ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(child: Text(initials)),
                            if (p.createdAt != null)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: AgingFlag(
                                  createdAtMillis: p.createdAt!,
                                  size: 12,
                                ),
                              ),
                          ],
                        ),
                        title: Text(p.name),
                        subtitle: Text('\$${p.total.toString()}'),
                        onTap: () => _gotoDubes(p.name, p.id, readOnly: _showDeleted),
                        trailing: _showDeleted
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'mark_completed') {
                                    // Mark person as completed (moves to paid section)
                                    await _deletePerson(p.id);
                                  } else if (v == 'mark_all_paid') {
                                    // Mark all person's dubes as paid but keep in active list
                                    await _markAllDubesAsPaid(p.id);
                                    await _loadPeople();
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'mark_completed',
                                    child: Text('Mark as Completed'),
                                  ),
                                  PopupMenuItem(
                                    value: 'mark_all_paid',
                                    child: Text('Mark All Dubes as Paid'),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDubesTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, icon: const Icon(Icons.people_outline), label: Text(AppLocalizations.of(context)!.active)),
              ButtonSegment(value: 1, icon: const Icon(Icons.delete_outline), label: Text(AppLocalizations.of(context)!.paid)),
            ],
            selected: {_showDeleted ? 1 : 0},
            onSelectionChanged: (s) async {
              final v = s.first;
              setState(() => _showDeleted = v == 1);
              await _loadPeople();
            },
            showSelectedIcon: false,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: AppLocalizations.of(context)!.searchPeopleToViewDubes,
            ),
            onChanged: (v) async {
              _search = v;
              await _loadPeople();
            },
          ),
        ),
        Expanded(
          child: _people.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noPeopleYet))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _people.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = _people[i];
                    final initials = _getInitials(p.name);
                    return Card(
                      child: ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(child: Text(initials)),
                            if (p.createdAt != null)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: AgingFlag(
                                  createdAtMillis: p.createdAt!,
                                  size: 12,
                                ),
                              ),
                          ],
                        ),
                        title: Text(p.name),
                        subtitle: Text('\$${p.total.toString()}'),
                        onTap: () => _gotoDubes(p.name, p.id, readOnly: _showDeleted),
                        trailing: _showDeleted
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'mark_completed') {
                                    // Mark person as completed (moves to paid section)
                                    await _deletePerson(p.id);
                                  } else if (v == 'mark_all_paid') {
                                    // Mark all person's dubes as paid but keep in active list
                                    await _markAllDubesAsPaid(p.id);
                                    await _loadPeople();
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'mark_completed',
                                    child: Text('Mark as Completed'),
                                  ),
                                  PopupMenuItem(
                                    value: 'mark_all_paid',
                                    child: Text('Mark All Dubes as Paid'),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      Future.microtask(() {
        if (mounted)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthPage()),
          );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(AppLocalizations.of(context)!.whoOwesYou),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: AppLocalizations.of(context)!.logout,
            onPressed: _shareApp,
          ),
        ],
      ),
      drawer: _buildDrawer(user),
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentPageIndex = i),
        children: [
          _buildHomeTab(context),
          _buildDubesTab(context),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final target = _currentPageIndex == 0 ? 1 : 0;
          _pageController.animateToPage(
            target,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
          );
        },
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            _currentPageIndex == 0 ? AppLocalizations.of(context)!.goToDubes : AppLocalizations.of(context)!.goToHome,
            key: ValueKey(_currentPageIndex),
          ),
        ),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            _currentPageIndex == 0
                ? Icons.description_outlined
                : Icons.home_outlined,
            key: ValueKey('icon-$_currentPageIndex'),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

// lib/pages/homepage/home.dart
import 'package:dube/pages/homepage/dubes.dart';
import 'package:dube/components/flag.dart';
import 'package:dube/pages/homepage/settings.dart';
import 'package:dube/pages/homepage/profile.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await LocalSqlite.insertPerson(name);
    _nameCtrl.clear();
    await _loadPeople();

    // find newly created person id to open dubes page
    final rows = await LocalSqlite.getAllPeople(search: name);
    final created = rows.firstWhere(
      (r) => (r['name'] ?? '') == name,
      orElse: () => {},
    );
    if (created.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              DubesPage(personId: created['id'], personName: created['name']),
        ),
      );
    }
  }

  Future<void> _deletePerson(String id) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('paid person'),
        content: const Text(
          'Did this person pay you?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('yes'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LocalSqlite.deletePerson(id);
    await _loadPeople();
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
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help & FAQ'),
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
                title: const Text('Logout'),
                onTap: _logout,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'App version 1.0.0',
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

  Widget _buildHomeTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Add person name',
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
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.people_outline), label: Text('Active')),
              ButtonSegment(value: 1, icon: Icon(Icons.delete_outline), label: Text('paid')),
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
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search people',
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
              ? const Center(child: Text('No people yet'))
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
                                onSelected: (v) {
                                  if (v == 'paid') _deletePerson(p.id);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'paid',
                                    child: Text('paid'),
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

  Widget _buildDubesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.people_outline), label: Text('Active')),
              ButtonSegment(value: 1, icon: Icon(Icons.delete_outline), label: Text('paid')),
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
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search people to view dubes',
            ),
            onChanged: (v) async {
              _search = v;
              await _loadPeople();
            },
          ),
        ),
        Expanded(
          child: _people.isEmpty
              ? const Center(child: Text('No people yet'))
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
                                onSelected: (v) {
                                  if (v == 'paid') _deletePerson(p.id);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'paid',
                                    child: Text('paid'),
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
        title: const Text('👋 Who owes you 💸'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: _buildDrawer(user),
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentPageIndex = i),
        children: [
          _buildHomeTab(),
          _buildDubesTab(),
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
            _currentPageIndex == 0 ? 'Go to Dubes' : 'Go to Home',
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

Widget buildHomeTab({
  required TextEditingController nameCtrl,
  required VoidCallback addPerson,
  required String search,
  required ValueChanged<String> onSearchChanged,
  required List<PersonLocal> people,
  required String Function(String) getInitials,
  required void Function(String, String) gotoDubes,
  required void Function(String) deletePerson,
}) {
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Add person name',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => addPerson(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: addPerson,
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
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search people',
          ),
          onChanged: onSearchChanged,
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: people.isEmpty
            ? const Center(child: Text('No people yet'))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: people.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = people[i];
                  final initials = getInitials(p.name);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(initials)),
                      title: Text(p.name),
                      subtitle: Text('\$${p.total.toString()}'),
                      onTap: () => gotoDubes(p.name, p.id),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'paid') deletePerson(p.id);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'paid', child: Text('paid')),
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

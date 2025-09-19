// lib/pages/homepage/home.dart
import 'package:dube/l10n/app_localizations.dart';
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
      // ignore: use_build_context_synchronously
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
        title: Text(AppLocalizations.of(context)!.paidPerson),
        content: Text(AppLocalizations.of(context)!.didPersonPay),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(AppLocalizations.of(context)!.yes),
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
                                onSelected: (v) {
                                  if (v == 'paid') _deletePerson(p.id);
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'paid',
                                    child: Text(AppLocalizations.of(context)!.paid),
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
                                onSelected: (v) {
                                  if (v == 'paid') _deletePerson(p.id);
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'paid',
                                    child: Text(AppLocalizations.of(context)!.paid),
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
          // ignore: curly_braces_in_flow_control_structures, use_build_context_synchronously
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
            icon: const Icon(Icons.logout),
            tooltip: AppLocalizations.of(context)!.logout,
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

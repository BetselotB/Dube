// lib/pages/homepage/home.dart
import 'package:dube/pages/homepage/dubes.dart';
import 'package:dube/pages/homepage/settings.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../src/local_sqlite.dart';
import '../auth/auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class PersonLocal {
  final String id;
  final String name;
  final num total;
  PersonLocal({required this.id, required this.name, required this.total});

  factory PersonLocal.fromRow(Map<String, dynamic> r) => PersonLocal(id: r['id'], name: r['name'], total: r['total'] ?? 0);
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _nameCtrl = TextEditingController();
  int _selectedIndex = 0;
  List<PersonLocal> _people = [];
  String _search = '';

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    final rows = await LocalSqlite.getAllPeople(search: _search);
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
    final created = rows.firstWhere((r) => (r['name'] ?? '') == name, orElse: () => {});
    if (created.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DubesPage(personId: created['id'], personName: created['name'])));
    }
  }

  Future<void> _deletePerson(String id) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete person'),
        content: const Text('Delete this person and their dubes? (soft delete)'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
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
                currentAccountPicture: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.indigo,
                  child: Text((user.displayName ?? 'U').isNotEmpty ? (user.displayName ?? 'U').substring(0, 1) : 'U', style: const TextStyle(color: Colors.white)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help & FAQ'),
                onTap: () => Navigator.of(context).pop(),
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
                child: Text('App version 1.0.0', style: Theme.of(context).textTheme.bodySmall),
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
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthPage()));
  }

  void _gotoDubes(String personName, String personId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DubesPage(personId: personId, personName: personName))).then((_) => _loadPeople());
  }

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
                  decoration: const InputDecoration(labelText: 'Add person name', border: OutlineInputBorder()),
                  onSubmitted: (_) => _addPerson(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _addPerson, style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)), child: const Icon(Icons.add)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search people'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _people.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = _people[i];
                    final initials = _getInitials(p.name);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text(initials)),
                        title: Text(p.name),
                        subtitle: Text('\$${p.total.toString()}'),
                        onTap: () => _gotoDubes(p.name, p.id),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'delete') _deletePerson(p.id);
                          },
                          itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.description_outlined, size: 72, color: Colors.indigo.shade400),
          const SizedBox(height: 18),
          const Text('Dubes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Select a person from Home to view their dubes (transactions).', textAlign: TextAlign.center),
        ]),
      ),
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
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthPage()));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold( 
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        title: const Text('Selam — Who owes what?'),
        actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _logout)],
      ),
      drawer: _buildDrawer(user),
body: AnimatedSwitcher(
  duration: const Duration(milliseconds: 260),
  transitionBuilder: (Widget child, Animation<double> animation) {
    // slide from right when switching to Dubes, slide to left when back to Home
    final inFromRight = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation);
    return SlideTransition(position: inFromRight, child: child);
  },
  child: _selectedIndex == 0
      ? KeyedSubtree(key: const ValueKey('home'), child: _buildHomeTab())
      : KeyedSubtree(key: const ValueKey('dubes'), child: _buildDubesTab()),
),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.06), blurRadius: 8, offset: Offset(0, 4))]),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child:GNav(
  gap: 8,
  selectedIndex: _selectedIndex,
  onTabChange: (index) {
    // If user tapped the Dubes tab, open the shared DubesPage route.
    if (index == 1) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DubesPage()));
      // keep selected index at home (or update if you prefer)
      setState(() => _selectedIndex = 0);
      return;
    }
    setState(() => _selectedIndex = index);
  },
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  tabs: const [
    GButton(icon: Icons.home_outlined, text: 'Home'),
    GButton(icon: Icons.description_outlined, text: 'Dubes'),
  ],
),

          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}

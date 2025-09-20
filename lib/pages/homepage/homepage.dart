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
  final GlobalKey<RefreshIndicatorState> _homeRefreshKey = GlobalKey<RefreshIndicatorState>();
  final GlobalKey<RefreshIndicatorState> _dubesRefreshKey = GlobalKey<RefreshIndicatorState>();

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

class _HomePageState extends State<HomePage> with RouteAware {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _nameCtrl = TextEditingController();
  List<PersonLocal> _people = [];
  String _search = '';
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPageIndex = 0;
  bool _showDeleted = false;
  
  // Statistics
  Map<String, dynamic> _stats = {
    'totalDubes': 0,
    'totalAmount': 0.0,
    'paidDubes': 0,
    'unpaidDubes': 0,
    'paidAmount': 0.0,
    'unpaidAmount': 0.0,
    'peopleCount': 0,
  };

  FirebaseAuth get _auth => FirebaseAuth.instance;

  RouteObserver<PageRoute> get routeObserver => RouteObserver<PageRoute>();

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _nameCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when coming back to this page
    _loadPeople();
  }
  Future<void> _handleRefresh() async {
  // reload people and statistics
  await _loadPeople();
  await _loadStatistics();
  // small delay so the UX feels responsive even if DB is fast
  await Future.delayed(Duration(milliseconds: 200));
}


  Future<void> _loadStatistics() async {
    try {
      final stats = await LocalSqlite.getStatistics();
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading statistics: $e')),
        );
      }
    }
  }

  Future<void> _loadPeople() async {
    final rows = await LocalSqlite.getPeople(search: _search, deleted: _showDeleted);
    if (!mounted) return;
    setState(() {
      _people = rows.map((r) => PersonLocal.fromRow(r)).toList();
      _stats['peopleCount'] = _people.length;
    });
    await _loadStatistics();
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
        title: Text('ጨርሰዋል/Mark as Completed?'),
        content: Text('This will move this person to the completed section. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text('ጨርሰዋል/Mark as Completed'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LocalSqlite.deletePerson(id);
    await _loadPeople();
  }
  
  Future<void> _markAllDubesAsPaid(String personId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmAction),
        content: Text(AppLocalizations.of(context)!.confirmMarkAllPaid),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Get all unpaid dubes for this person
      final dubes = await LocalSqlite.getDubesForPerson(personId, showPaid: false);
      
      // Mark each dube as paid
      for (final dube in dubes) {
        await LocalSqlite.markDubeAsPaid(dube['id']);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.allDubesMarkedPaid)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.errorMarkingPaid}: $e')),
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
                currentAccountPicture: CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF2B2D42),
                  child: Text(
                    'U',
                    style: TextStyle(color: Color(0xFFFFFFFF)),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.settings),
                title: Text(AppLocalizations.of(context)!.settings),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SettingsPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.person_outline),
                title: Text(AppLocalizations.of(context)!.profile),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ProfilePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.help_outline),
                title: Text(AppLocalizations.of(context)!.helpFaq),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => HelpFaqPage()),
                  );
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.logout),
                title: Text(AppLocalizations.of(context)!.logout),
                onTap: _logout,
              ),
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  AppLocalizations.of(context)!.appVersion('1.0.0'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SizedBox(height: 24),
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
    ).pushReplacement(
      MaterialPageRoute(builder: (_) => AuthPage()),
    );
  }

  Future<void> _shareApp() async {
    const url = 'https://www.youtube.com/';
    final text = 'Check out this app! $url';

    try {
      // Share basic text + url
      await Share.share(text, subject: 'My App');
      // optional: show a confirmation
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share sheet opened')),
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
        // Statistics Card
        _buildStatistics(),
        
        // Search bar
        Padding(
          padding: EdgeInsets.all(12.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchPeople,
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (v) {
              setState(() => _search = v);
              _loadPeople();
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(12),
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
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showDeleted ? null : _addPerson,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                icon: Icon(Icons.add, size: 20),
                label: Text(AppLocalizations.of(context)!.add),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, icon: Icon(Icons.people_outline), label: Text(AppLocalizations.of(context)!.active)),
              ButtonSegment(value: 1, icon: Icon(Icons.delete_outline), label: Text(AppLocalizations.of(context)!.paid)),
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
          padding: EdgeInsets.symmetric(horizontal: 12.0),
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
        SizedBox(height: 8),
        Expanded(
          child: _people.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.noPeopleYet,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: _people.length,
                  itemBuilder: (context, i) => _buildPersonItem(context, _people[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildDubesTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, icon: Icon(Icons.people_outline), label: Text(AppLocalizations.of(context)!.active)),
              ButtonSegment(value: 1, icon: Icon(Icons.delete_outline), label: Text(AppLocalizations.of(context)!.paid)),
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
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _people.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = _people[i];
                    final initials = _getInitials(p.name);
                    return Card(
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: 40, maxWidth: 40),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                child: Text(initials, style: TextStyle(fontSize: 12)),
                                radius: 16,
                              ),
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
                        ),
                        title: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '\$${p.total.toString()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => _gotoDubes(p.name, p.id, readOnly: _showDeleted),
                        trailing: _showDeleted
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Complete Button
                                  _buildActionButton(
                                    icon: Icons.check_circle,
                                    color: Colors.green,
                                    tooltip: AppLocalizations.of(context)!.markCompleted,
                                    onTap: () => _deletePerson(p.id),
                                  ),
                                  SizedBox(width: 8),
                                  // Mark All Paid Button
                                  _buildActionButton(
                                    icon: Icons.done_all,
                                    color: Colors.blue,
                                    tooltip: AppLocalizations.of(context)!.markAllPaid,
                                    onTap: () async {
                                      await _markAllDubesAsPaid(p.id);
                                      await _loadPeople();
                                    },
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

  // Person List Item Widget
  Widget _buildPersonItem(BuildContext context, PersonLocal person) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _gotoDubes(person.name, person.id, readOnly: _showDeleted),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Avatar with AgingFlag
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blueGrey[800] : Colors.blueGrey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(person.name),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                  ),
                  if (person.createdAt != null)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: AgingFlag(
                        createdAtMillis: person.createdAt!,
                        size: 12,
                      ),
                    ),
                ],
              ),
              SizedBox(width: 12),
              // Name and Amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      '\$${person.total.toString()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons
              if (!_showDeleted) ..._buildActionButtons(person),
            ],
          ),
        ),
      ),
    );
  }

  // Build action buttons
  List<Widget> _buildActionButtons(PersonLocal person) {
    return [
      // Complete Button
      _buildActionButton(
        icon: Icons.check_circle,
        color: Colors.green,
        tooltip: AppLocalizations.of(context)!.markCompleted,
        onTap: () => _deletePerson(person.id),
      ),
      SizedBox(width: 8),
      // Mark All Paid Button
      _buildActionButton(
        icon: Icons.done_all,
        color: Colors.blue,
        tooltip: AppLocalizations.of(context)!.markAllPaid,
        onTap: () async {
          await _markAllDubesAsPaid(person.id);
          await _loadPeople();
        },
      ),
    ];
  }

  // Action Button Widget
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: tooltip,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
            ),
          ),
        ),
        SizedBox(height: 2),
        Text(
          tooltip,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, {Color? color}) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    return Card(
      margin: EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Padding(
        padding: EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Dubes',
                    _stats['totalDubes'].toString(),
                  ),
                ),
                Expanded(
                  child: _buildStatCard(
                    'People',
                    _stats['peopleCount'].toString(),
                  ),
                ),
                Expanded(
                  child: _buildStatCard(
                    'Total Amount',
                    '\$${_stats['totalAmount'].toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Paid',
                    '\$${_stats['paidAmount'].toStringAsFixed(0)}',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatCard(
                    '${_stats['paidDubes']} dubes',
                    '${_stats['totalDubes'] > 0 ? ((_stats['paidDubes'] / _stats['totalDubes']) * 100).toStringAsFixed(0) : 0}%',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatCard(
                    'Unpaid',
                    '\$${_stats['unpaidAmount'].toStringAsFixed(0)}',
                    color: Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatCard(
                    '${_stats['unpaidDubes']} dubes',
                    '${_stats['totalDubes'] > 0 ? ((_stats['unpaidDubes'] / _stats['totalDubes']) * 100).toStringAsFixed(0) : 0}%',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      Future.microtask(() {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => AuthPage()),
          );
        }
      });
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${AppLocalizations.of(context)!.welcome}${user.displayName != null ? ',' : ''}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (user.displayName != null)
              Text(
                user.displayName!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(AppLocalizations.of(context)!.whoOwesYou),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            tooltip: AppLocalizations.of(context)!.logout,
            onPressed: _shareApp,
          ),
        ],
      ),
      drawer: _buildDrawer(user),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: BouncingScrollPhysics(),
          onPageChanged: (i) => setState(() => _currentPageIndex = i),
          children: [
            _buildHomeTab(context),
            _buildDubesTab(context),
          ],
        ),
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

  }

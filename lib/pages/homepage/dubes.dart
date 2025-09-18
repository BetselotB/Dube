// lib/pages/dubes/dubes.dart
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../src/local_sqlite.dart';

class DubesPage extends StatefulWidget {
  // personId/personName are optional. If personId==null => show people search/list.
  final String? personId;
  final String? personName;
  const DubesPage({super.key, this.personId, this.personName});

  /// Use this to push with a smooth transition from Home:
  static Route route({String? personId, String? personName}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          DubesPage(personId: personId, personName: personName),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // slide from right (or change Offset to (0,1) to slide from bottom)
        final tween = Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  @override
  State<DubesPage> createState() => _DubesPageState();
}

class _DubesPageState extends State<DubesPage> {
  // For manage mode (when personId != null)
  List<Map<String, dynamic>> _dubes = [];
  final TextEditingController _searchCtrl = TextEditingController();

  // For people list mode (when personId == null)
  List<Map<String, dynamic>> _people = [];
  final TextEditingController _peopleSearchCtrl = TextEditingController();

  // bottom nav index: 0 = Home, 1 = Dubes (current)
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    if (widget.personId == null) {
      _loadPeople();
    } else {
      _loadDubes();
    }
  }

  // ---------- People list mode ----------
  Future<void> _loadPeople() async {
    final rows = await LocalSqlite.getAllPeople(search: _peopleSearchCtrl.text);
    if (!mounted) return;
    setState(() => _people = rows);
  }

  // ---------- Manage mode (dubes for person) ----------
  Future<void> _loadDubes() async {
    if (widget.personId == null) return;
    final rows = await LocalSqlite.getDubesForPerson(
      widget.personId!,
      search: _searchCtrl.text,
    );
    if (!mounted) return;
    setState(() => _dubes = rows);
  }

  Future<void> _addDube() async {
    final itemCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add Dube (item)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: itemCtrl,
                decoration: const InputDecoration(labelText: 'Item name'),
              ),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price (per item)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final item = itemCtrl.text.trim();
    final qty = int.tryParse(qtyCtrl.text) ?? 1;
    final price = double.tryParse(priceCtrl.text) ?? 0.0;
    await LocalSqlite.insertDube(
      personId: widget.personId!,
      itemName: item,
      quantity: qty,
      priceAtTaken: price,
    );
    await _loadDubes();
  }

  Future<void> _editDube(Map<String, dynamic> d) async {
    final itemCtrl = TextEditingController(text: d['itemName'] ?? '');
    final qtyCtrl = TextEditingController(
      text: (d['quantity'] ?? 1).toString(),
    );
    final priceCtrl = TextEditingController(
      text: (d['priceAtTaken'] ?? 0).toString(),
    );
    final noteCtrl = TextEditingController(text: (d['note'] ?? ''));

    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Dube'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: itemCtrl,
                decoration: const InputDecoration(labelText: 'Item name'),
              ),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price (per item)',
                ),
              ),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final qty = int.tryParse(qtyCtrl.text) ?? 1;
    final price = double.tryParse(priceCtrl.text) ?? 0.0;
    await LocalSqlite.updateDube(
      d['id'] as String,
      itemName: itemCtrl.text.trim(),
      quantity: qty,
      priceAtTaken: price,
      note: noteCtrl.text.trim(),
    );
    await _loadDubes();
  }

  Future<void> _deleteDube(Map<String, dynamic> d) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Dube'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LocalSqlite.deleteDube(d['id'] as String);
    await _loadDubes();
  }

  // When showing people list, delete person functionality:
  Future<void> _deletePerson(String id) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete person'),
        content: const Text(
          'Delete this person and their dubes? (soft delete)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LocalSqlite.deletePerson(id);
    await _loadPeople();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _peopleSearchCtrl.dispose();
    super.dispose();
  }

  Widget _buildPeopleListMode() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _peopleSearchCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search people',
            ),
            onChanged: (v) => _loadPeople(),
          ),
        ),
        Expanded(
          child: _people.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 72,
                        color: Colors.indigo.shade400,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'No people yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add people from the Home tab or use the Add button there.',
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPeople,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _people.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, i) {
                      final p = _people[i];
                      final name = p['name'] ?? '—';
                      final initials = _getInitials(name);
                      return ListTile(
                        leading: CircleAvatar(child: Text(initials)),
                        title: Text(name),
                        subtitle: Text('\$${(p['total'] ?? 0).toString()}'),
                        onTap: () {
                          // Open the same page but in manage mode for the chosen person
                          Navigator.of(context)
                              .push(
                                DubesPage.route(
                                  personId: p['id'],
                                  personName: p['name'],
                                ),
                              )
                              .then((_) => _loadPeople());
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'delete') _deletePerson(p['id']);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildManageMode() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search item or note',
            ),
            onChanged: (v) => _loadDubes(),
          ),
        ),
        Expanded(
          child: _dubes.isEmpty
              ? const Center(child: Text('No dubes yet'))
              : ListView.separated(
                  itemCount: _dubes.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final d = _dubes[i];
                    final created = DateTime.fromMillisecondsSinceEpoch(
                      d['createdAt'] as int,
                    );
                    return ListTile(
                      title: Text(
                        '${d['itemName'] ?? '—'}  x${d['quantity'] ?? 1}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price: \$${(d['priceAtTaken'] ?? 0).toString()}  •  Amount: \$${(d['amount'] ?? 0).toString()}',
                          ),
                          if ((d['note'] ?? '').toString().isNotEmpty)
                            Text(d['note'] ?? ''),
                          Text('${created.toLocal()}'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _editDube(d);
                          if (v == 'delete') _deleteDube(d);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                      isThreeLine: true,
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
    final body = widget.personId == null
        ? _buildPeopleListMode()
        : _buildManageMode();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.personId == null
              ? 'Dubes — People'
              : 'Dubes — ${widget.personName ?? 'Person'}',
        ),
        actions: widget.personId == null
            ? null
            : [IconButton(onPressed: _addDube, icon: const Icon(Icons.add))],
      ),
      body: body,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.06),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: GNav(
              gap: 8,
              selectedIndex: _selectedIndex, // 0 = Home, 1 = Dubes
              onTabChange: (index) {
                if (index == 0) {
                  Navigator.of(context).pop(); // back to Home
                  return;
                }
                setState(() => _selectedIndex = index); // stay on Dubes
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
}

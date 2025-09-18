// lib/pages/dubes/dubes.dart
import 'package:flutter/material.dart';
import '../../src/local_sqlite.dart';

class DubesPage extends StatefulWidget {
  final String personId;
  final String personName;
  const DubesPage({super.key, required this.personId, required this.personName});

  @override
  State<DubesPage> createState() => _DubesPageState();
}

class _DubesPageState extends State<DubesPage> {
  List<Map<String, dynamic>> _dubes = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDubes();
  }

  Future<void> _loadDubes() async {
    final rows = await LocalSqlite.getDubesForPerson(widget.personId, search: _searchCtrl.text);
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item name')),
            TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
            TextField(controller: priceCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (per item)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;

    final item = itemCtrl.text.trim();
    final qty = int.tryParse(qtyCtrl.text) ?? 1;
    final price = double.tryParse(priceCtrl.text) ?? 0.0;
    await LocalSqlite.insertDube(personId: widget.personId, itemName: item, quantity: qty, priceAtTaken: price);
    await _loadDubes();
  }

  Future<void> _editDube(Map<String, dynamic> d) async {
    final itemCtrl = TextEditingController(text: d['itemName'] ?? '');
    final qtyCtrl = TextEditingController(text: (d['quantity'] ?? 1).toString());
    final priceCtrl = TextEditingController(text: (d['priceAtTaken'] ?? 0).toString());
    final noteCtrl = TextEditingController(text: (d['note'] ?? ''));

    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Dube'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item name')),
            TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
            TextField(controller: priceCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (per item)')),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;
    final qty = int.tryParse(qtyCtrl.text) ?? 1;
    final price = double.tryParse(priceCtrl.text) ?? 0.0;
    await LocalSqlite.updateDube(d['id'] as String, itemName: itemCtrl.text.trim(), quantity: qty, priceAtTaken: price, note: noteCtrl.text.trim());
    await _loadDubes();
  }

  Future<void> _deleteDube(Map<String, dynamic> d) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Dube'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok != true) return;
    await LocalSqlite.deleteDube(d['id'] as String);
    await _loadDubes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dubes — ${widget.personName}'),
        actions: [IconButton(onPressed: _addDube, icon: const Icon(Icons.add))],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12.0), child: TextField(controller: _searchCtrl, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search item or note'), onChanged: (v) => _loadDubes())),
        Expanded(
          child: _dubes.isEmpty
              ? const Center(child: Text('No dubes yet'))
              : ListView.separated(
                  itemCount: _dubes.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final d = _dubes[i];
                    final created = DateTime.fromMillisecondsSinceEpoch(d['createdAt'] as int);
                    return ListTile(
                      title: Text('${d['itemName'] ?? '—'}  x${d['quantity'] ?? 1}'),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Price: \$${(d['priceAtTaken'] ?? 0).toString()}  •  Amount: \$${(d['amount'] ?? 0).toString()}'),
                        if ((d['note'] ?? '').toString().isNotEmpty) Text(d['note'] ?? ''),
                        Text('${created.toLocal()}'),
                      ]),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _editDube(d);
                          if (v == 'delete') _deleteDube(d);
                        },
                        itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

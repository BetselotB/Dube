// lib/pages/dubes/dubes.dart
import 'package:dube/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../src/local_sqlite.dart';
import 'package:intl/intl.dart';

class DubesPage extends StatefulWidget {
  /// If [personId] is null, show people list mode.
  /// If [personId] is provided, show dubes management for that person.
  final String? personId;
  final String? personName;
  final bool readOnly;
  const DubesPage({super.key, this.personId, this.personName, this.readOnly = false});

  /// Push this with a slide transition from Home
  static Route route({String? personId, String? personName}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          DubesPage(personId: personId, personName: personName),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
  // Dubes for a specific person
  List<Map<String, dynamic>> _dubes = [];
  final TextEditingController _searchCtrl = TextEditingController();

  // People list mode
  List<Map<String, dynamic>> _people = [];
  final TextEditingController _peopleSearchCtrl = TextEditingController();

  // Form controllers
  final _itemNameCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  int _quantity = 1;

  // No bottom nav here; this page focuses on either people or a person's dubes

  @override
  void initState() {
    super.initState();
    if (widget.personId == null) {
      _loadPeople();
    } else {
      _loadDubes();
    }
  }

  @override
  void dispose() {
    _itemNameCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _searchCtrl.dispose();
    _peopleSearchCtrl.dispose();
    super.dispose();
  }

  void _incrementQuantity() {
    setState(() {
      _quantity++;
      _quantityCtrl.text = _quantity.toString();
    });
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
        _quantityCtrl.text = _quantity.toString();
      });
    }
  }

  // ---------- People ----------
  Future<void> _loadPeople() async {
    final rows = await LocalSqlite.getAllPeople(search: _peopleSearchCtrl.text);
    if (!mounted) return;
    setState(() => _people = rows);
  }

  Future<void> _deletePerson(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.paidPerson),
        content: Text(
          AppLocalizations.of(context)!.didPersonPay,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(AppLocalizations.of(context)!.paid),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LocalSqlite.deletePerson(id);
    await _loadPeople();
  }

  // ---------- Dubes ----------
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
    if (widget.readOnly) return;
    final item = _itemNameCtrl.text.trim();
    final qty = int.tryParse(_quantityCtrl.text) ?? 1;
    final price = double.tryParse(_priceCtrl.text) ?? 0.0;

    if (item.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.enterItemNameAndValidPrice)),
      );
      return;
    }

    await LocalSqlite.insertDube(
      personId: widget.personId!,
      itemName: item,
      quantity: qty,
      priceAtTaken: price,
    );
    
    // Clear the form
    _itemNameCtrl.clear();
    _priceCtrl.clear();
    setState(() {
      _quantity = 1;
      _quantityCtrl.text = '1';
    });
    
    await _loadDubes();
    // Scroll to top to show the newly added item
    if (mounted && _dubes.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
        );
      }
    }
  }

  Future<void> _editDube(Map<String, dynamic> d) async {
    if (widget.readOnly) return;
    final itemCtrl = TextEditingController(text: d['itemName'] ?? '');
    final qtyCtrl = TextEditingController(
      text: (d['quantity'] ?? 1).toString(),
    );
    final priceCtrl = TextEditingController(
      text: (d['priceAtTaken'] ?? 0).toString(),
    );
    final noteCtrl = TextEditingController(text: d['note'] ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.editDube),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: itemCtrl,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.itemName),
            ),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.quantity),
            ),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.pricePerItem),
            ),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.noteOptional),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(AppLocalizations.of(context)!.save),
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

  // delete dube handled by markAsPaid for now

  Future<void> _markAsPaid(String id, double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.markAsPaid),
        content: Text(AppLocalizations.of(context)!.areYouSureMarkAsPaid),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text(AppLocalizations.of(context)!.markAsPaid),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Here you would update your database to mark this item as paid
      // For now, we'll just remove it from the list
      await LocalSqlite.deleteDube(id);
      await _loadDubes();
    }
  }

  Widget _buildDubeItem(Map<String, dynamic> d) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: InkWell(
        onTap: () => _editDube(d).then((_) => _loadDubes()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d['itemName'] ?? 'No name',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${d['quantity']} × ${NumberFormat.currency(symbol: 'ETB ').format(d['priceAtTaken'])} = ${NumberFormat.currency(symbol: 'ETB ').format(d['amount'])}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (d['note'] != null && d['note'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          d['note'],
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                // ignore: deprecated_member_use
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!widget.readOnly)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  onPressed: () => _markAsPaid(d['id'], (d['amount'] as num).toDouble()),
                  tooltip: AppLocalizations.of(context)!.markAsPaid,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI ----------
  Widget _buildPeopleList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _peopleSearchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: AppLocalizations.of(context)!.searchPeople,
            ),
            onChanged: (_) => _loadPeople(),
          ),
        ),
        Expanded(
          child: _people.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 72,
                        color: Color(0xFF2B2D42),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        AppLocalizations.of(context)!.noPeopleYet,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.addPeopleFromHome,
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
                      return ListTile(
                        leading: CircleAvatar(child: Text(_getInitials(name))),
                        title: Text(name),
                        subtitle: Text('\$${(p['total'] ?? 0).toString()}'),
                        onTap: () {
                          Navigator.of(context)
                              .push(
                                DubesPage.route(
                                  personId: p['id'],
                                  personName: name,
                                ),
                              )
                              .then((_) => _loadPeople());
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'paid') _deletePerson(p['id']);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'paid',
                              child: Text(AppLocalizations.of(context)!.paid),
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

  Widget _buildDubesList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.searchItems,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  _loadDubes();
                },
              ),
            ),
            onChanged: (_) => _loadDubes(),
          ),
        ),
        if (!widget.readOnly) _buildInputForm(),
        Expanded(
          child: _dubes.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.noDubesYet))
              : ListView.builder(
                  itemCount: _dubes.length,
                  itemBuilder: (context, i) {
                    final d = _dubes[i];
                    return _buildDubeItem(d);
                  },
                ),
        ),
      ],
    );
  }

  // kept for future use if needed

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _buildInputForm() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Item name field
            TextField(
              controller: _itemNameCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.itemName,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                isDense: true,
                suffixIcon: _itemNameCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _itemNameCtrl.clear()),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
              ),
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 14),
            ),
            
            const SizedBox(height: 12),
            
            // Quantity and price row
            Row(
              children: [
                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Decrease button
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: _decrementQuantity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                      
                      // Quantity display
                      SizedBox(
                        width: 40,
                        child: TextField(
                          controller: _quantityCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (value) {
                            final qty = int.tryParse(value) ?? 1;
                            if (qty > 0) {
                              setState(() => _quantity = qty);
                            }
                          },
                        ),
                      ),
                      
                      // Increase button
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: _incrementQuantity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Price field
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.price,
                      prefixText: 'ETB ',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                      suffixIcon: _priceCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _priceCtrl.clear()),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : null,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (_) => _addDube(),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Add button
                SizedBox(
                  height: 48,
                  child: FilledButton.tonalIcon(
                    onPressed: _addDube,
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(AppLocalizations.of(context)!.add, style: const TextStyle(fontSize: 14)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.personName ?? AppLocalizations.of(context)!.dubes),
        actions: widget.personId == null
            ? null
            : [
                IconButton(
                  onPressed: _addDube,
                  icon: const Icon(Icons.add),
                  tooltip: AppLocalizations.of(context)!.addNewDube,
                ),
              ],
      ),
      body: widget.personId == null ? _buildPeopleList() : _buildDubesList(),
    );
  }
}

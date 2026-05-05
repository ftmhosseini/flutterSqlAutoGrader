import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseManagerPage extends StatefulWidget {
  const DatabaseManagerPage({super.key});

  @override
  State<DatabaseManagerPage> createState() => _DatabaseManagerPageState();
}

class _DatabaseManagerPageState extends State<DatabaseManagerPage> {
  static const _configDoc = 'sqliteConfigs/mainConfig';

  Map<String, dynamic> _config = {};
  bool _loading = true;

  List<String> _datasets = [];
  List<String> _tables = [];
  String? _selectedDataset;
  String? _selectedTable;

  final _newDatasetCtrl = TextEditingController();
  final _newTableCtrl = TextEditingController();
  final _sqlCtrl = TextEditingController();

  String _datasetError = '';
  String _tableError = '';
  String? _createResult;
  bool _createSuccess = false;
  String? _insertResult;
  bool _insertSuccess = false;

  List<Map<String, dynamic>> _columns = [];

  List<Map<String, dynamic>> _fetchedRows = [];
  List<String> _fetchedColumns = [];
  bool _showInsertForm = false;
  bool _showFetchData = false;
  String? _tableSchema;
  bool _tableNotExists = false;

  @override
  void initState() {
    super.initState();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _loadConfig();
  }

  // ── Build in-memory DB from config queries (mirrors React's loadSqliteData) ──
  Future<Database> _buildDb(String dbname) async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1);
    final queries = List<String>.from(_config[dbname]?['queries'] ?? []);
    for (final q in queries) {
      try { await db.execute(q); } catch (_) {}
    }
    return db;
  }

  Future<void> _loadConfig() async {
    final snap = await FirebaseFirestore.instance.doc(_configDoc).get();
    if (!snap.exists) { setState(() => _loading = false); return; }
    final raw = snap.data()!;
    final config = raw.map((k, v) {
      if (v is Map) {
        final inner = Map<String, dynamic>.from(v);
        if (inner['queries'] != null) inner['queries'] = List<String>.from(inner['queries']);
        return MapEntry(k, inner);
      }
      return MapEntry(k, v);
    });
    _config = config;
    final datasets = await _fetchDatasets();
    setState(() { _datasets = datasets; _loading = false; });
  }

  Future<void> _saveConfig() async {
    await FirebaseFirestore.instance.doc(_configDoc).set(_config);
  }

  // ── Mirrors fetchDatasetsDB: SELECT datasetName FROM Datasets ──
  Future<List<String>> _fetchDatasets() async {
    try {
      final db = await _buildDb('db');
      final rows = await db.rawQuery('SELECT datasetName FROM Datasets');
      await db.close();
      return rows.map((r) => r['datasetName'] as String).toList();
    } catch (_) { return []; }
  }

  // ── Mirrors fetchTablesDB: SELECT * FROM Tables WHERE datasetName = ? ──
  Future<List<String>> _fetchTables(String dataset) async {
    try {
      final db = await _buildDb('db');
      final rows = await db.rawQuery("SELECT DISTINCT tableName FROM Tables WHERE datasetName = ?", [dataset]);
      await db.close();
      return rows.map((r) => r['tableName'] as String).toList();
    } catch (_) { return []; }
  }

  // ── Mirrors getTableSchema: SELECT sql FROM sqlite_master WHERE name = ? ──
  Future<String?> _fetchSchema(String dataset, String table) async {
    try {
      final db = await _buildDb(dataset);
      final rows = await db.rawQuery("SELECT sql FROM sqlite_master WHERE type='table' AND name=?", [table]);
      await db.close();
      return rows.isEmpty ? null : rows.first['sql'] as String?;
    } catch (_) { return null; }
  }

  // ── Mirrors fetchData: SELECT * FROM table ──
  Future<void> _fetchData() async {
    try {
      final db = await _buildDb(_selectedDataset!);
      final rows = await db.rawQuery('SELECT * FROM $_selectedTable');
      // Get columns from pragma even if rows empty
      List<String> cols;
      if (rows.isNotEmpty) {
        cols = rows.first.keys.toList();
      } else {
        final pragma = await db.rawQuery("SELECT name FROM pragma_table_info(?)", [_selectedTable]);
        cols = pragma.map((r) => r['name'] as String).toList();
      }
      await db.close();
      setState(() {
        _fetchedRows = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        _fetchedColumns = cols;
        _showFetchData = true;
      });
    } catch (e) {
      setState(() { _fetchedRows = []; _fetchedColumns = []; _showFetchData = true; });
    }
  }

  void _reset() => setState(() {
    _datasetError = ''; _tableError = '';
    _createResult = null; _insertResult = null;
    _fetchedRows = []; _fetchedColumns = [];
    _showInsertForm = false;
    _showFetchData = false;
  });

  Future<void> _createDataset() async {
    _reset();
    final name = _newDatasetCtrl.text.trim().replaceAll(' ', '');
    if (name.isEmpty) { setState(() => _datasetError = 'Dataset name is required.'); return; }
    final existing = await _fetchDatasets();
    if (existing.contains(name)) { setState(() => _datasetError = 'Dataset name already exists.'); return; }

    _config['db'] ??= {'name': 'db.sqlite', 'queries': []};
    final dbQueries = _config['db']['queries'] as List;
    if (!dbQueries.any((q) => (q as String).contains('CREATE TABLE IF NOT EXISTS \'Datasets\''))) {
      dbQueries.addAll([
        "CREATE TABLE IF NOT EXISTS 'Datasets' (datasetName VARCHAR PRIMARY KEY)",
        "CREATE TABLE IF NOT EXISTS 'Tables' (tableId INTEGER PRIMARY KEY AUTOINCREMENT, tableName VARCHAR NOT NULL, datasetName VARCHAR, FOREIGN KEY (datasetName) REFERENCES Datasets(datasetName))",
      ]);
    }
    dbQueries.add("INSERT INTO Datasets (datasetName) VALUES ('$name')");
    _config[name] = {'name': '$name.sqlite', 'queries': []};
    await _saveConfig();
    final datasets = await _fetchDatasets();
    setState(() { _newDatasetCtrl.clear(); _datasets = datasets; _selectedDataset = name; _tables = []; _selectedTable = null; _tableSchema = null; });
  }

  Future<void> _createTable() async {
    _reset();
    final name = _newTableCtrl.text.trim().replaceAll(' ', '');
    if (name.isEmpty) { setState(() => _tableError = 'Table name is required.'); return; }
    if (_selectedDataset == null) { setState(() => _tableError = 'Select a dataset first.'); return; }
    final existing = await _fetchTables(_selectedDataset!);
    if (existing.map((t) => t.toLowerCase()).contains(name.toLowerCase())) {
      setState(() => _tableError = 'Table already exists in this dataset.'); return;
    }
    (_config['db']['queries'] as List).add("INSERT INTO Tables (tableName, datasetName) VALUES ('$name', '$_selectedDataset')");
    await _saveConfig();
    final tables = await _fetchTables(_selectedDataset!);
    final schema = await _fetchSchema(_selectedDataset!, name);
    setState(() { _newTableCtrl.clear(); _tables = tables; _selectedTable = name; _tableSchema = schema; _tableNotExists = schema == null; });
  }

  Future<void> _createTableFromColumns() async {
    if (_selectedTable == null || _columns.isEmpty) return;
    final colDefs = _columns.map((c) {
      String def = '${c['name']} ${c['type']}';
      if (c['nullable'] == false) def += ' NOT NULL';
      if (c['key'] == 'primary') def += ' PRIMARY KEY';
      return def;
    }).toList();
    final fks = _columns.where((c) => c['key'] == 'foreign')
        .map((c) => 'FOREIGN KEY (${c['name']}) REFERENCES ${c['refTable']}(id)').toList();
    await _submitCreateSQL('CREATE TABLE $_selectedTable (${[...colDefs, ...fks].join(', ')})');
  }

  Future<void> _submitCreateSQL(String sql) async {
    if (!sql.trim().toUpperCase().startsWith('CREATE TABLE')) {
      setState(() { _createResult = 'Invalid SQL: must start with CREATE TABLE'; _createSuccess = false; }); return;
    }
    // Test the query in a temp in-memory DB first
    try {
      final testDb = await openDatabase(inMemoryDatabasePath, version: 1);
      await testDb.execute(sql);
      await testDb.close();
    } catch (e) {
      setState(() { _createResult = 'SQL Error: ${e.toString()}'; _createSuccess = false; }); return;
    }
    // Valid — save to Firestore
    (_config[_selectedDataset!]['queries'] as List).add(sql);
    await _saveConfig();
    final schema = await _fetchSchema(_selectedDataset!, _selectedTable!);
    setState(() { _tableSchema = schema; _tableNotExists = false; _createResult = 'Table created successfully!'; _createSuccess = true; _columns = []; _sqlCtrl.clear(); });
  }

  Future<void> _submitInsertSQL() async {
    final sql = _sqlCtrl.text.trim();
    if (!sql.toUpperCase().startsWith('INSERT INTO')) {
      setState(() { _insertResult = 'Invalid SQL: must start with INSERT INTO'; _insertSuccess = false; }); return;
    }
    // Test against the real dataset DB
    try {
      final testDb = await _buildDb(_selectedDataset!);
      await testDb.execute(sql);
      await testDb.close();
    } catch (e) {
      setState(() { _insertResult = 'SQL Error: ${e.toString()}'; _insertSuccess = false; }); return;
    }
    (_config[_selectedDataset!]['queries'] as List).add(sql);
    await _saveConfig();
    setState(() { _insertResult = 'Row inserted successfully!'; _insertSuccess = true; _sqlCtrl.clear(); _fetchedRows = []; _fetchedColumns = []; });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dataset Manager', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('Create datasets, organize tables, define schemas, and inspect live data.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),

        // Datasets
        _card(title: 'Datasets in Database', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_datasets.isEmpty) const Text('No datasets yet', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
          else ..._datasets.map((ds) => _selectableRow(ds, _selectedDataset == ds, () async {
            _reset();
            final tables = await _fetchTables(ds);
            setState(() { _selectedDataset = ds; _tables = tables; _selectedTable = null; _tableSchema = null; });
          })),
          if (_datasetError.isNotEmpty) _errorText(_datasetError),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _newDatasetCtrl, decoration: const InputDecoration(hintText: 'New dataset name', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _createDataset, style: _btnStyle(), child: const Text('Create Dataset')),
          ]),
        ])),

        // Tables
        if (_selectedDataset != null) ...[
          const SizedBox(height: 16),
          _card(title: 'Tables in $_selectedDataset', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_tables.isEmpty) const Text('No tables yet', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
            else ..._tables.map((t) => _selectableRow(t, _selectedTable == t, () async {
              _reset();
              final schema = await _fetchSchema(_selectedDataset!, t);
              setState(() { _selectedTable = t; _tableSchema = schema; _tableNotExists = schema == null; });
            })),
            if (_tableError.isNotEmpty) _errorText(_tableError),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _newTableCtrl, decoration: const InputDecoration(hintText: 'New table name', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _createTable, style: _btnStyle(), child: const Text('Create Table')),
            ]),
          ])),
        ],

        // Schema
        if (_selectedTable != null) ...[
          const SizedBox(height: 16),
          _card(
            title: 'Define Schema for $_selectedTable',
            child: _tableNotExists
                ? _schemaBuilder()
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Current Schema:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(6)),
                      child: Text(_tableSchema ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    ),
                  ]),
          ),
        ],

        // Data
        if (_tableSchema != null && _selectedTable != null) ...[
          const SizedBox(height: 16),
          _card(title: 'DATA IN $_selectedTable', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ElevatedButton(onPressed: () { setState(() { _showFetchData = true; _showInsertForm = false; _insertResult = null; }); _fetchData(); }, style: _btnStyle(), child: const Text('Fetch Data')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: () { _sqlCtrl.clear(); setState(() { _fetchedRows = []; _fetchedColumns = []; _insertResult = null; _insertSuccess = false; _showInsertForm = true; }); }, style: _btnStyle(), child: const Text('Insert Data')),
            ]),
            if (_fetchedRows.isNotEmpty) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: _fetchedColumns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                  rows: _fetchedRows.map((r) => DataRow(
                    cells: _fetchedColumns.map((c) => DataCell(Text('${r[c] ?? ''}'))).toList(),
                  )).toList(),
                ),
              ),
            ] else if (_fetchedRows.isEmpty && !_showInsertForm && _showFetchData) ...[
              const SizedBox(height: 8),
              const Text('Table is empty.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
            ],
            if (_showInsertForm) ...[
              const SizedBox(height: 8),
              if (_insertResult != null) Text(_insertResult!, style: TextStyle(color: _insertSuccess ? Colors.green : Colors.red, fontSize: 13)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: TextField(controller: _sqlCtrl, decoration: InputDecoration(hintText: "INSERT INTO $_selectedTable (...) VALUES (...)", border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _submitInsertSQL, style: _btnStyle(), child: const Text('Submit')),
              ]),
            ],
          ])),
        ],
      ]),
    );
  }

  Widget _schemaBuilder() {
    final tables = <String>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_columns.isNotEmpty) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')), DataColumn(label: Text('Type')),
              DataColumn(label: Text('Nullable')), DataColumn(label: Text('Key')),
              DataColumn(label: Text('Ref Table')), DataColumn(label: Text('')),
            ],
            rows: List.generate(_columns.length, (i) {
              final c = _columns[i];
              return DataRow(cells: [
                DataCell(SizedBox(width: 100, child: TextField(onChanged: (v) => setState(() => _columns[i]['name'] = v.trim()), decoration: const InputDecoration(hintText: 'col_name', isDense: true, border: OutlineInputBorder())))),
                DataCell(DropdownButton<String>(value: c['type'], items: ['VARCHAR','INT','BIGINT','TEXT','DATE','TIMESTAMP','BOOLEAN','DECIMAL'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => _columns[i]['type'] = v))),
                DataCell(DropdownButton<bool>(value: c['nullable'] as bool, items: const [DropdownMenuItem(value: false, child: Text('NOT NULL', style: TextStyle(fontSize: 12))), DropdownMenuItem(value: true, child: Text('NULL', style: TextStyle(fontSize: 12)))], onChanged: (v) => setState(() => _columns[i]['nullable'] = v))),
                DataCell(DropdownButton<String>(value: c['key'], items: const [DropdownMenuItem(value: 'none', child: Text('None', style: TextStyle(fontSize: 12))), DropdownMenuItem(value: 'primary', child: Text('Primary Key', style: TextStyle(fontSize: 12))), DropdownMenuItem(value: 'foreign', child: Text('Foreign Key', style: TextStyle(fontSize: 12)))], onChanged: (v) => setState(() => _columns[i]['key'] = v))),
                DataCell(c['key'] == 'foreign' ? DropdownButton<String>(value: c['refTable'].isEmpty ? null : c['refTable'], hint: const Text('Select', style: TextStyle(fontSize: 12)), items: tables.where((t) => t != _selectedTable).map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => _columns[i]['refTable'] = v ?? '')) : const SizedBox()),
                DataCell(IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _columns.removeAt(i)))),
              ]);
            }),
          ),
        ),
        const SizedBox(height: 8),
      ],
      Row(children: [
        ElevatedButton(onPressed: () => setState(() => _columns.add({'name': '', 'type': 'VARCHAR', 'nullable': false, 'key': 'none', 'refTable': ''})), style: _btnStyle(), child: const Text('Add Column')),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _createTableFromColumns, style: _btnStyle(color: Colors.green), child: const Text('Create Table')),
      ]),
      if (_createResult != null) ...[
        const SizedBox(height: 8),
        Text(_createResult!, style: TextStyle(color: _createSuccess ? Colors.green : Colors.red, fontSize: 13)),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _sqlCtrl, decoration: InputDecoration(hintText: 'CREATE TABLE $_selectedTable (...)', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)))),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: () => _submitCreateSQL(_sqlCtrl.text), style: _btnStyle(), child: const Text('Submit')),
      ]),
    ]);
  }

  Widget _card({required String title, required Widget child}) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 12),
      child,
    ])),
  );

  Widget _selectableRow(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: selected ? const Color(0xFF4e73df) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.black87)),
    ),
  );

  Widget _errorText(String msg) => Padding(padding: const EdgeInsets.only(top: 4), child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12)));

  ButtonStyle _btnStyle({Color? color}) => ElevatedButton.styleFrom(backgroundColor: color ?? const Color(0xFF4e73df), foregroundColor: Colors.white);
}

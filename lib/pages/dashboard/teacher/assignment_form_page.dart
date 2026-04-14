import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../services/user_session.dart';

const _groqApiKey = String.fromEnvironment('GROQ_API_KEY');

class AssignmentFormPage extends StatefulWidget {
  final VoidCallback onDone;
  const AssignmentFormPage({super.key, required this.onDone});

  @override
  State<AssignmentFormPage> createState() => _AssignmentFormPageState();
}

class _AssignmentFormPageState extends State<AssignmentFormPage> {
  int _step = 0;
  bool _loading = true;
  String _error = '';

  // Step 0 — Details
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();

  // Step 1 — Questions
  List<String> _datasets = [];
  String? _selectedDataset;
  List<String> _tables = [];
  Map<String, dynamic> _config = {};
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _presets = [];
  bool _loadingPresets = false;

  // Step 2 — Assign
  List<Map<String, dynamic>> _cohorts = [];
  String? _selectedCohort;
  bool _notifyOnSubmit = false;
  bool _sendReminders = false;

  @override
  void initState() {
    super.initState();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final configSnap = await FirebaseFirestore.instance.doc('sqliteConfigs/mainConfig').get();
    final cohortSnap = await FirebaseFirestore.instance.collection('cohorts')
        .where('owner_user_id', isEqualTo: UserSession.uid).get();

    final config = configSnap.exists ? configSnap.data()!.map((k, v) {
      if (v is Map) {
        final inner = Map<String, dynamic>.from(v);
        if (inner['queries'] != null) inner['queries'] = List<String>.from(inner['queries']);
        return MapEntry(k, inner);
      }
      return MapEntry(k, v);
    }) : <String, dynamic>{};

    // Get dataset names from db queries
    final dbQueries = List<String>.from(config['db']?['queries'] ?? []);
    final datasets = dbQueries
        .where((q) => q.toUpperCase().startsWith('INSERT INTO DATASETS'))
        .map((q) => RegExp(r"VALUES \('(.+?)'\)", caseSensitive: false).firstMatch(q)?.group(1) ?? '')
        .where((s) => s.isNotEmpty).toList();

    setState(() {
      _config = config;
      _datasets = datasets;
      _cohorts = cohortSnap.docs.map((d) => {...d.data(), 'cohort_id': d.id}).toList();
      _loading = false;
    });
  }

  Future<Database> _buildDb(String dataset) async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1);
    for (final q in List<String>.from(_config[dataset]?['queries'] ?? [])) {
      try { await db.execute(q); } catch (_) {}
    }
    return db;
  }

  Future<void> _onDatasetChanged(String dataset) async {
    setState(() { _selectedDataset = dataset; _tables = []; _presets = []; _loadingPresets = true; });

    // Get tables
    final db = await _buildDb('db');
    final rows = await db.rawQuery('SELECT DISTINCT tableName FROM Tables WHERE datasetName = ?', [dataset]);
    await db.close();
    final tables = rows.map((r) => r['tableName'] as String).toList();

    // Build schema for AI
    final datasetDb = await _buildDb(dataset);
    final schemaMap = <String, List<Map<String, dynamic>>>{};
    for (final t in tables) {
      final cols = await datasetDb.rawQuery(
        "SELECT name, type FROM pragma_table_info(?)", [t]);
      schemaMap[t] = cols.map((c) => {'name': c['name'], 'type': c['type']}).toList();
    }
    await datasetDb.close();

    setState(() { _tables = tables; });

    // Generate presets via Groq
    if (_groqApiKey.isNotEmpty && schemaMap.isNotEmpty) {
      try {
        final schemaText = schemaMap.entries.map((e) =>
          'Table: ${e.key}\n${e.value.map((c) => '  ${c['name']} ${c['type']}').join('\n')}').join('\n\n');
        final res = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {'Authorization': 'Bearer $_groqApiKey', 'Content-Type': 'application/json'},
          body: jsonEncode({'model': 'llama-3.3-70b-versatile', 'messages': [{'role': 'user',
            'content': 'SQL instructor. Generate 10 SQL practice questions for this schema.\n\n$schemaText\n\nReturn ONLY valid JSON array. Each: {"id":1,"question":"...","answer":"SELECT ...","mark":2,"orderMatters":false,"aliasStrict":false}'}],
            'max_tokens': 2048, 'temperature': 1.0}),
        );
        if (res.statusCode == 200) {
          final raw = jsonDecode(res.body)['choices'][0]['message']['content'] as String;
          final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
          setState(() => _presets = List<Map<String, dynamic>>.from(jsonDecode(cleaned)));
        }
      } catch (_) {}
    }
    setState(() => _loadingPresets = false);
  }

  void _addQuestion() => setState(() => _questions.add({
    'question_id': DateTime.now().microsecondsSinceEpoch.toString(),
    'questionText': '', 'answer': '', 'mark': 1,
    'orderMatters': false, 'aliasStrict': false, 'max_attempts': 3,
  }));

  void _applyPreset(int idx, Map<String, dynamic> preset) => setState(() {
    _questions[idx]['questionText'] = preset['question'] ?? '';
    _questions[idx]['answer'] = preset['answer'] ?? '';
    _questions[idx]['mark'] = preset['mark'] ?? 1;
    _questions[idx]['orderMatters'] = preset['orderMatters'] ?? false;
    _questions[idx]['aliasStrict'] = preset['aliasStrict'] ?? false;
  });

  bool _validateStep() {
    if (_step == 0) {
      if (_titleCtrl.text.trim().isEmpty || _dueDateCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Title and due date are required.'); return false;
      }
      if (_dueDateCtrl.text.trim().compareTo(DateTime.now().toIso8601String().substring(0, 10)) < 0) {
        setState(() => _error = 'Due date cannot be in the past.'); return false;
      }
    }
    setState(() => _error = '');
    return true;
  }

  Future<void> _submit() async {
    if (_questions.isEmpty) { setState(() => _error = 'Add at least one question.'); return; }
    if (_questions.any((q) => (q['questionText'] as String? ?? '').trim().isEmpty || (q['answer'] as String? ?? '').trim().isEmpty)) {
      setState(() => _error = 'All questions must have text and an SQL answer.'); return;
    }
    if (_selectedCohort == null) { setState(() => _error = 'Please select a cohort.'); return; }
    // Validate each question's SQL returns results
    if (_selectedDataset != null) {
      final db = await _buildDb(_selectedDataset!);
      for (int i = 0; i < _questions.length; i++) {
        final sql = (_questions[i]['answer'] as String? ?? '').trim();
        try {
          final result = await db.rawQuery(sql);
          if (result.isEmpty) { await db.close(); setState(() => _error = 'Question ${i + 1}: SQL returns no rows.'); return; }
        } catch (e) {
          await db.close(); setState(() => _error = 'Question ${i + 1}: Invalid SQL — $e'); return;
        }
      }
      await db.close();
    }
    final totalMarks = _questions.fold<int>(0, (s, q) => s + (q['mark'] as int? ?? 0));
    await FirebaseFirestore.instance.collection('assignments').add({
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'due_date': _dueDateCtrl.text.trim(),
      'dataset': _selectedDataset,
      'student_class': _selectedCohort,
      'questions': _questions,
      'total_marks': totalMarks,
      'reminder_interval':_sendReminders,
      'enable_submission_notification':_notifyOnSubmit,
      'owner_user_id': UserSession.uid,
      'created_on': FieldValue.serverTimestamp(),
    });
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_cohorts.isEmpty) return _warningCard('No cohorts found.', 'Create a cohort first.', () => Navigator.pop(context));
    if (_datasets.isEmpty) return _warningCard('No datasets found.', 'Create a dataset first.', () => Navigator.pop(context));

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Assignment'),
        backgroundColor: const Color(0xFF4e73df),
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onDone),
      ),
      body: Column(children: [
        // Stepper header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            _stepChip(0, 'Details'),
            _stepLine(),
            _stepChip(1, 'Questions'),
            _stepLine(),
            _stepChip(2, 'Assign'),
          ]),
        ),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _step == 0 ? _stepDetails() : _step == 1 ? _stepQuestions() : _stepAssign(),
        )),

        // Footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),

            child:Column(children: [
                            if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 12), child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 12))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (_step > 0)
              OutlinedButton(onPressed: () => setState(() { _step--; _error = ''; }), child: const Text('← Previous'))
            else const SizedBox(),
            Row(children: [
              if (_step < 2)
                ElevatedButton(
                  onPressed: () { if (_validateStep()) setState(() => _step++); },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white),
                  child: const Text('Next →'),
                )
              else
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white),
                  child: const Text('Create Assignment'),
                ),
            ]),
          ]),
            ],)
        ),
      ]),
    );
  }

  // ── Step 0: Details ──────────────────────────────────────────────────────────
  Widget _stepDetails() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Assignment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    const SizedBox(height: 16),
    TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(
      controller: _dueDateCtrl,
      readOnly: true,
      decoration: const InputDecoration(labelText: 'Due Date *', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime(2100));
        if (picked != null) _dueDateCtrl.text = picked.toIso8601String().substring(0, 10);
      },
    ),
    const SizedBox(height: 20),
  ]);

  // ── Step 1: Questions ────────────────────────────────────────────────────────
  Widget _stepQuestions() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Questions & SQL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      value: _selectedDataset,
      decoration: const InputDecoration(labelText: 'Select Dataset', border: OutlineInputBorder()),
      items: _datasets.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
      onChanged: (v) { if (v != null) _onDatasetChanged(v); },
    ),
    const SizedBox(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Questions (${_questions.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
      ElevatedButton.icon(
        onPressed: _selectedDataset == null ? null : _addQuestion,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Question'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4e73df), foregroundColor: Colors.white),
      ),
    ]),
    if (_loadingPresets) const Padding(padding: EdgeInsets.all(8), child: Text('⏳ Loading AI presets...', style: TextStyle(color: Colors.grey))),
    const SizedBox(height: 8),
    ..._questions.asMap().entries.map((e) => _questionCard(e.key, e.value)),
    const SizedBox(height: 20),
  ]);

  Widget _questionCard(int i, Map<String, dynamic> q) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Question ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.red), onPressed: () => setState(() => _questions.removeAt(i))),
      ]),
      if (_tables.isNotEmpty) ...[
        const Text('Filter Presets by Table:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: _tables.map((t) {
            final selected = (q['_filterTables'] as List<String>? ?? []).contains(t);
            return FilterChip(
              label: Text(t, style: const TextStyle(fontSize: 11)),
              selected: selected,
              onSelected: (v) => setState(() {
                final list = List<String>.from(q['_filterTables'] as List? ?? []);
                v ? list.add(t) : list.remove(t);
                _questions[i]['_filterTables'] = list;
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
      if (_presets.isNotEmpty) ...[
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: 'Use AI Preset', border: OutlineInputBorder(), isDense: true),
          value: null,
          items: _presets.where((p) {
            final filterTables = List<String>.from(q['_filterTables'] as List? ?? []);
            if (filterTables.isEmpty) return true;
            final answer = (p['answer'] as String? ?? '').toLowerCase();
            // match if answer SQL contains all selected table names
            return filterTables.every((t) => answer.contains(t.toLowerCase()));
          }).toList().asMap().entries.map((e) => DropdownMenuItem(value: _presets.indexOf(e.value), child: Text(e.value['question'] as String? ?? '', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) _applyPreset(i, _presets[v]); },
        ),
        const SizedBox(height: 8),
      ],
      TextField(
        controller: TextEditingController(text: q['questionText'])..selection = TextSelection.collapsed(offset: (q['questionText'] as String).length),
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Question Text *', border: OutlineInputBorder()),
        onChanged: (v) => _questions[i]['questionText'] = v,
      ),
      const SizedBox(height: 8),
      TextField(
        controller: TextEditingController(text: q['answer'])..selection = TextSelection.collapsed(offset: (q['answer'] as String).length),
        maxLines: 2,
        style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF4e73df)),
        decoration: const InputDecoration(labelText: 'SQL Answer *', border: OutlineInputBorder()),
        onChanged: (v) => _questions[i]['answer'] = v,
      ),
      const SizedBox(height: 8),
      // Row(children: [
        
      // ]),
      Row(children: [
        SizedBox(width: 80, child: TextField(
          controller: TextEditingController(text: '${q['mark']}'),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Marks', border: OutlineInputBorder(), isDense: true),
          onChanged: (v) => _questions[i]['mark'] = int.tryParse(v) ?? 1,
        )),
        const SizedBox(width: 8),
        FilterChip(label: const Text('Order Matters', style: TextStyle(fontSize: 11)), selected: q['orderMatters'] as bool, onSelected: (v) => setState(() => _questions[i]['orderMatters'] = v)),
        const SizedBox(width: 8),
        FilterChip(label: const Text('Alias Strict', style: TextStyle(fontSize: 11)), selected: q['aliasStrict'] as bool, onSelected: (v) => setState(() => _questions[i]['aliasStrict'] = v)),
      ]),
    ])),
  );

  // ── Step 2: Assign ───────────────────────────────────────────────────────────
  Widget _stepAssign() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Assign & Publish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    const SizedBox(height: 16),
    DropdownButtonFormField<String>(
      value: _selectedCohort,
      decoration: const InputDecoration(labelText: 'Assign to Cohort *', border: OutlineInputBorder()),
      items: _cohorts.map((c) => DropdownMenuItem(value: c['cohort_id'] as String, child: Text(c['name'] as String? ?? ''))).toList(),
      onChanged: (v) => setState(() => _selectedCohort = v),
    ),
    const SizedBox(height: 16),
    Card(child: Column(children: [
      SwitchListTile(title: const Text('Notify me on submissions'), value: _notifyOnSubmit, onChanged: (v) => setState(() => _notifyOnSubmit = v)),
      SwitchListTile(title: const Text('Send reminders to students'), value: _sendReminders, onChanged: (v) => setState(() => _sendReminders = v)),
    ])),
    const SizedBox(height: 20),
  ]);

  // ── Helpers ──────────────────────────────────────────────────────────────────
  Widget _stepChip(int step, String label) {
    final active = _step == step;
    final done = _step > step;
    return Expanded(child: Column(children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: done ? Colors.green : active ? const Color(0xFF4e73df) : Colors.grey.shade300,
        child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : Text('${step + 1}', style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 12)),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: active ? const Color(0xFF4e73df) : Colors.grey, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
    ]));
  }

  Widget _stepLine() => Expanded(child: Container(height: 2, color: Colors.grey.shade300, margin: const EdgeInsets.only(bottom: 20)));

  Widget _warningCard(String title, String subtitle, VoidCallback onTap) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
      const SizedBox(height: 8),
      GestureDetector(onTap: onTap, child: Text(subtitle, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline))),
    ]))),
  ));
}

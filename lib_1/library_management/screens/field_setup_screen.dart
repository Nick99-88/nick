import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/field_config.dart';
import '../services/database_service.dart';
import 'dashboard_screen.dart';

class FieldSetupScreen extends StatefulWidget {
  final DatabaseService service;
  const FieldSetupScreen({super.key, required this.service});

  @override
  State<FieldSetupScreen> createState() => _FieldSetupScreenState();
}

class _FieldSetupScreenState extends State<FieldSetupScreen> {
  final _uuid = const Uuid();
  List<_AlmirahItem> _almirahs = [];
  List<_ExtraField> _extraFields = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await widget.service.loadLibraryConfig();
    if (config != null && mounted) {
      setState(() {
        _almirahs = config.almirahs
            .map((a) => _AlmirahItem(
                  id: a.id,
                  nameCtrl: TextEditingController(text: a.name),
                  cabins: a.cabins
                      .map((c) => _CabinItem(
                            id: c.id,
                            nameCtrl: TextEditingController(text: c.name),
                          ))
                      .toList(),
                ))
            .toList();
        _extraFields = config.extraFields
            .map((f) => _ExtraField(
                  id: f.id,
                  nameCtrl: TextEditingController(text: f.name),
                  type: f.type,
                  required: f.required,
                ))
            .toList();
      });
    }
  }

  @override
  void dispose() {
    for (final a in _almirahs) {
      a.nameCtrl.dispose();
      for (final c in a.cabins) {
        c.nameCtrl.dispose();
      }
    }
    for (final f in _extraFields) {
      f.nameCtrl.dispose();
    }
    super.dispose();
  }

  void _addAlmirah() {
    setState(() {
      _almirahs.add(_AlmirahItem(
        id: _uuid.v4(),
        nameCtrl: TextEditingController(),
        cabins: [_CabinItem(id: _uuid.v4(), nameCtrl: TextEditingController(text: 'Cabin 1'))],
      ));
    });
  }

  void _removeAlmirah(int index) {
    final a = _almirahs[index];
    a.nameCtrl.dispose();
    for (final c in a.cabins) {
      c.nameCtrl.dispose();
    }
    setState(() => _almirahs.removeAt(index));
  }

  void _addCabin(int almirahIndex) {
    setState(() {
      _almirahs[almirahIndex].cabins.add(_CabinItem(
        id: _uuid.v4(),
        nameCtrl: TextEditingController(),
      ));
    });
  }

  void _removeCabin(int almirahIndex, int cabinIndex) {
    final c = _almirahs[almirahIndex].cabins[cabinIndex];
    c.nameCtrl.dispose();
    setState(() => _almirahs[almirahIndex].cabins.removeAt(cabinIndex));
  }

  void _addField() {
    setState(() {
      _extraFields.add(_ExtraField(
        id: _uuid.v4(),
        nameCtrl: TextEditingController(),
        type: FieldType.text,
        required: false,
      ));
    });
  }

  void _removeField(int index) {
    final f = _extraFields[index];
    f.nameCtrl.dispose();
    setState(() => _extraFields.removeAt(index));
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final config = LibraryConfig(
      almirahs: _almirahs
          .where((a) => a.nameCtrl.text.trim().isNotEmpty)
          .map((a) => AlmirahConfig(
                id: a.id,
                name: a.nameCtrl.text.trim(),
                cabins: a.cabins
                    .where((c) => c.nameCtrl.text.trim().isNotEmpty)
                    .map((c) => CabinConfig(id: c.id, name: c.nameCtrl.text.trim()))
                    .toList(),
              ))
          .toList(),
      extraFields: _extraFields
          .where((f) => f.nameCtrl.text.trim().isNotEmpty)
          .map((f) => FieldConfig(
                id: f.id,
                name: f.nameCtrl.text.trim(),
                type: f.type,
                required: f.required,
                order: _extraFields.indexOf(f),
              ))
          .toList(),
    );
    await widget.service.saveLibraryConfig(config);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen(service: widget.service)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Configure Almirahs & Cabins')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Almirahs', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._almirahs.asMap().entries.map((entry) {
            final ai = entry.key;
            final a = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: a.nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Almirah name *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: _almirahs.length > 1 ? () => _removeAlmirah(ai) : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...a.cabins.asMap().entries.map((cEntry) {
                      final ci = cEntry.key;
                      final c = cEntry.value;
                      return Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.subdirectory_arrow_right, size: 18, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextField(
                                controller: c.nameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Cabin name *',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                              onPressed: a.cabins.length > 1 ? () => _removeCabin(ai, ci) : null,
                            ),
                          ],
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: TextButton.icon(
                        onPressed: () => _addCabin(ai),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Cabin'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: _addAlmirah,
            icon: const Icon(Icons.add),
            label: const Text('Add New Almirah'),
          ),
          const SizedBox(height: 24),
          Text('Extra Fields', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._extraFields.asMap().entries.map((entry) {
            final i = entry.key;
            final f = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: f.nameCtrl,
                            decoration: const InputDecoration(labelText: 'Field name', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _removeField(i),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        DropdownButton<FieldType>(
                          value: f.type,
                          items: FieldType.values
                              .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => f.type = v);
                          },
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Text('Required'),
                            Checkbox(
                              value: f.required,
                              onChanged: (v) => setState(() => f.required = v ?? false),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: _addField,
            icon: const Icon(Icons.add),
            label: const Text('Add Custom Field'),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Save & Continue'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }
}

class _AlmirahItem {
  final String id;
  final TextEditingController nameCtrl;
  List<_CabinItem> cabins;
  _AlmirahItem({required this.id, required this.nameCtrl, required this.cabins});
}

class _CabinItem {
  final String id;
  final TextEditingController nameCtrl;
  _CabinItem({required this.id, required this.nameCtrl});
}

class _ExtraField {
  final String id;
  final TextEditingController nameCtrl;
  FieldType type;
  bool required;
  _ExtraField({required this.id, required this.nameCtrl, this.type = FieldType.text, this.required = false});
}

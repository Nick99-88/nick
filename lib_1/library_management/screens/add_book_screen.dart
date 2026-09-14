import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import '../models/field_config.dart';
import '../services/database_service.dart';

class AddBookScreen extends StatefulWidget {
  final DatabaseService service;
  final Book? editBook;
  const AddBookScreen({super.key, required this.service, this.editBook});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _uuid = const Uuid();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _isbnCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _copiesCtrl = TextEditingController();
  final _availCtrl = TextEditingController();
  final _fieldCtrls = <String, dynamic>{};
  LibraryConfig? _config;
  String? _selectedAlmirahId;
  String? _selectedCabinId;
  bool _loading = true;
  bool _saving = false;

  bool get _editing => widget.editBook != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _config = await widget.service.loadLibraryConfig();
    if (_editing) {
      final b = widget.editBook!;
      _titleCtrl.text = b.title;
      _authorCtrl.text = b.author;
      _isbnCtrl.text = b.isbn ?? '';
      _descCtrl.text = b.description ?? '';
      _copiesCtrl.text = b.totalCopies?.toString() ?? '';
      _availCtrl.text = b.availableCopies?.toString() ?? '';
      _selectedAlmirahId = b.almirahId;
      _selectedCabinId = b.cabinId;
      for (final entry in b.fieldValues.entries) {
        _fieldCtrls[entry.key] = entry.value;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _isbnCtrl.dispose();
    _descCtrl.dispose();
    _copiesCtrl.dispose();
    _availCtrl.dispose();
    super.dispose();
  }

  AlmirahConfig? get _selectedAlmirah =>
      _config?.almirahs.where((a) => a.id == _selectedAlmirahId).firstOrNull;

  Widget _buildFieldWidget(FieldConfig field) {
    final value = _fieldCtrls[field.id];

    if (field.type == FieldType.boolean) {
      return CheckboxListTile(
        title: Text('${field.name}${field.required ? " *" : ""}'),
        value: _fieldCtrls[field.id] as bool? ?? (value as bool? ?? false),
        onChanged: (v) => setState(() => _fieldCtrls[field.id] = v ?? false),
      );
    }

    if (field.type == FieldType.coordinate) return _buildCoordinateField(field, value);
    if (field.type == FieldType.date) return _buildDateField(field, value);
    if (field.type == FieldType.dropdown) return _buildDropdownField(field, value);

    return _buildTextField(field, value);
  }

  Widget _buildTextField(FieldConfig field, dynamic value) {
    final existing = _fieldCtrls[field.id];
    final ctrl = (existing is TextEditingController)
        ? existing
        : TextEditingController(text: value?.toString() ?? '');
    _fieldCtrls[field.id] = ctrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: '${field.name}${field.required ? " *" : ""}',
          border: const OutlineInputBorder(),
        ),
        keyboardType: field.type == FieldType.number
            ? TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
      ),
    );
  }

  Widget _buildCoordinateField(FieldConfig field, dynamic value) {
    String x = '', y = '';
    if (value is Map) {
      x = (value['x'] ?? '').toString();
      y = (value['y'] ?? '').toString();
    }
    final xCtrl = TextEditingController(text: x);
    final yCtrl = TextEditingController(text: y);
    _fieldCtrls[field.id] = _fieldCtrls[field.id] ?? <String, String>{'x': x, 'y': y};
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.name, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: xCtrl,
                      decoration: const InputDecoration(labelText: 'X / Row', border: OutlineInputBorder(), isDense: true),
                      onChanged: (_) => _fieldCtrls[field.id] = {'x': xCtrl.text, 'y': yCtrl.text},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: yCtrl,
                      decoration: const InputDecoration(labelText: 'Y / Column', border: OutlineInputBorder(), isDense: true),
                      onChanged: (_) => _fieldCtrls[field.id] = {'x': xCtrl.text, 'y': yCtrl.text},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(FieldConfig field, dynamic value) {
    final existing = _fieldCtrls[field.id];
    final ctrl = (existing is TextEditingController)
        ? existing
        : TextEditingController(text: value?.toString() ?? '');
    _fieldCtrls[field.id] = ctrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: '${field.name}${field.required ? " *" : ""}',
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        readOnly: true,
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (date != null) {
            ctrl.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          }
        },
      ),
    );
  }

  Widget _buildDropdownField(FieldConfig field, dynamic value) {
    final options = field.options ?? [];
    String? selected = value?.toString();
    if (selected == null || !options.contains(selected)) selected = null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: InputDecoration(
          labelText: '${field.name}${field.required ? " *" : ""}',
          border: const OutlineInputBorder(),
        ),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: (v) => _fieldCtrls[field.id] = v ?? '',
      ),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    if (_selectedAlmirahId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an almirah')));
      return;
    }
    if (_selectedCabinId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a cabin')));
      return;
    }

    final fields = <String, dynamic>{};
    for (final field in _config?.extraFields ?? []) {
      final val = _fieldCtrls[field.id];
      if (field.type == FieldType.text || field.type == FieldType.number || field.type == FieldType.date) {
        fields[field.id] = (val as TextEditingController?)?.text.trim() ?? '';
      } else if (field.type == FieldType.boolean) {
        fields[field.id] = val as bool? ?? false;
      } else if (field.type == FieldType.coordinate) {
        fields[field.id] = val as Map<String, dynamic>? ?? {};
      } else if (field.type == FieldType.dropdown) {
        fields[field.id] = val as String? ?? '';
      }
    }

    setState(() => _saving = true);

    final book = Book(
      id: _editing ? widget.editBook!.id : _uuid.v4(),
      title: _titleCtrl.text.trim(),
      author: _authorCtrl.text.trim(),
      isbn: _isbnCtrl.text.trim().isEmpty ? null : _isbnCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      totalCopies: int.tryParse(_copiesCtrl.text.trim()),
      availableCopies: int.tryParse(_availCtrl.text.trim()),
      almirahId: _selectedAlmirahId,
      cabinId: _selectedCabinId,
      fieldValues: fields,
    );

    if (_editing) {
      await widget.service.updateBook(book);
    } else {
      await widget.service.addBook(book);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Book' : 'Add Book')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Book Title *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _authorCtrl,
            decoration: const InputDecoration(labelText: 'Author', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _isbnCtrl,
            decoration: const InputDecoration(labelText: 'ISBN', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _copiesCtrl,
                  decoration: const InputDecoration(labelText: 'Total Copies', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _availCtrl,
                  decoration: const InputDecoration(labelText: 'Available', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          if (_config != null && _config!.almirahs.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedAlmirahId,
              decoration: const InputDecoration(labelText: 'Select Almirah *', border: OutlineInputBorder()),
              items: _config!.almirahs.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedAlmirahId = v;
                  _selectedCabinId = null;
                });
              },
            ),
            if (_selectedAlmirah != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCabinId,
                decoration: const InputDecoration(labelText: 'Select Cabin *', border: OutlineInputBorder()),
                items: _selectedAlmirah!.cabins
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCabinId = v),
              ),
            ],
          ],
          if (_config != null && _config!.extraFields.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Extra Fields', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._config!.extraFields.map(_buildFieldWidget),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_editing ? 'Update Book' : 'Add Book'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }
}

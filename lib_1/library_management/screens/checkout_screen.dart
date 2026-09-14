import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import '../models/checkout.dart';
import '../models/field_config.dart';
import '../services/database_service.dart';
import '../widgets/receipt_dialog.dart';

class _CartItem {
  final Book book;
  int quantity;
  _CartItem(this.book, this.quantity);
}

class _ExtraField {
  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;
  _ExtraField({String key = '', String value = ''})
      : keyCtrl = TextEditingController(text: key),
        valueCtrl = TextEditingController(text: value);
  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}

class CheckoutScreen extends StatefulWidget {
  final DatabaseService service;
  final LibraryConfig? config;
  final Book? initialBook;
  const CheckoutScreen({super.key, required this.service, required this.config, this.initialBook});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _uuid = const Uuid();
  final _searchCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _extraFields = <_ExtraField>[];
  final _cart = <_CartItem>[];
  List<Book> _results = [];
  bool _searching = false;
  bool _hasClientName = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _clientCtrl.addListener(() {
      setState(() => _hasClientName = _clientCtrl.text.trim().isNotEmpty);
    });
    if (widget.initialBook != null) {
      _cart.add(_CartItem(widget.initialBook!, 1));
    }
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _clientCtrl.dispose();
    _phoneCtrl.dispose();
    for (final f in _extraFields) { f.dispose(); }
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final all = await widget.service.getBooks(search: q);
    setState(() {
      _results = all.where((b) => (b.availableCopies ?? 0) > 0).toList();
      _searching = false;
    });
  }

  void _addToCart(Book book) {
    final existing = _cart.where((c) => c.book.id == book.id).firstOrNull;
    if (existing != null) {
      final maxAdd = (book.availableCopies ?? 0) - existing.quantity;
      if (maxAdd > 0) setState(() => existing.quantity++);
    } else {
      setState(() => _cart.add(_CartItem(book, 1)));
    }
    _searchCtrl.clear();
    _results = [];
  }

  void _removeFromCart(int i) {
    setState(() => _cart.removeAt(i));
  }

  int get _totalCopies => _cart.fold(0, (s, c) => s + c.quantity);

  Future<void> _checkout() async {
    if (_cart.isEmpty || _clientCtrl.text.trim().isEmpty) return;

    final extras = <String, dynamic>{};
    for (final f in _extraFields) {
      final k = f.keyCtrl.text.trim();
      final v = f.valueCtrl.text.trim();
      if (k.isNotEmpty) extras[k] = v;
    }

    final checkouts = <Checkout>[];
    for (final item in _cart) {
      final qty = item.quantity.clamp(1, item.book.availableCopies ?? 1);
      checkouts.addAll(List.generate(qty, (_) => Checkout(
        id: _uuid.v4(),
        bookId: item.book.id,
        bookTitle: item.book.title,
        bookAuthor: item.book.author,
        clientName: _clientCtrl.text.trim(),
        clientPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        extraFields: extras,
      )));
    }

    try {
      for (final co in checkouts) {
        await widget.service.checkoutBook(co);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;
    await ReceiptDialog.showCheckoutReceipt(context, checkouts);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _addExtraField() {
    setState(() => _extraFields.add(_ExtraField()));
  }

  void _removeExtraField(int i) {
    _extraFields[i].dispose();
    setState(() => _extraFields.removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout Book')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.initialBook == null) ...[
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Search book by title or author',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { _searchCtrl.clear(); _results = []; setState(() {}); },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_searching)
            const Center(child: CircularProgressIndicator())
          else if (_results.isNotEmpty) ...[
            Text('${_results.length} book(s) available',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            ..._results.map((b) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(b.title),
                    subtitle: Text('${b.author} \u2022 Available: ${b.availableCopies}'),
                    trailing: FilledButton.tonalIcon(
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('Add'),
                      onPressed: () => _addToCart(b),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
          ],
          if (_cart.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.shopping_cart, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Cart (${_cart.length} book(s), $_totalCopies cop${_totalCopies == 1 ? 'y' : 'ies'})',
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_cart.length, (i) {
              final item = _cart[i];
              final maxAvail = item.book.availableCopies ?? 1;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.book.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(item.book.author, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: item.quantity > 1 ? () => setState(() => item.quantity--) : null,
                        visualDensity: VisualDensity.compact,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: item.quantity < maxAvail ? () => setState(() => item.quantity++) : null,
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        onPressed: () => _removeFromCart(i),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          if (_cart.isNotEmpty || widget.initialBook != null) ...[
            TextField(
              controller: _clientCtrl,
              decoration: const InputDecoration(
                labelText: 'Client / Student name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Extra Info', style: theme.textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Field'),
                  onPressed: _addExtraField,
                ),
              ],
            ),
            ...List.generate(_extraFields.length, (i) {
              final f = _extraFields[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: f.keyCtrl,
                        decoration: const InputDecoration(labelText: 'Field name', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: f.valueCtrl,
                        decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                      onPressed: () => _removeExtraField(i),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (_hasClientName && _cart.isNotEmpty) ? _checkout : null,
              icon: const Icon(Icons.swap_horiz),
              label: Text('Checkout $_totalCopies cop${_totalCopies == 1 ? 'y' : 'ies'} from ${_cart.length} book(s)'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
          if (_results.isEmpty && !_searching && _searchCtrl.text.isNotEmpty && widget.initialBook == null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_off, size: 60, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text('No available books found', style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

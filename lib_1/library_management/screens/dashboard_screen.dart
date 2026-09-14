import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../models/checkout.dart';
import '../models/field_config.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sqlite_service.dart';
import '../widgets/receipt_dialog.dart';
import 'add_book_screen.dart';
import 'checkout_screen.dart';
import 'field_setup_screen.dart';

class DashboardScreen extends StatefulWidget {
  final DatabaseService service;
  const DashboardScreen({super.key, required this.service});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  List<Book> _books = [];
  LibraryConfig? _config;
  int _bookCount = 0;
  List<Checkout> _activeCheckouts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      _config = await widget.service.loadLibraryConfig();
      _books = await widget.service.getBooks();
      _bookCount = await widget.service.getBookCount();
      _activeCheckouts = await widget.service.getActiveCheckouts();
    } catch (e) {
      debugPrint('Library refresh error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _addBook() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddBookScreen(service: widget.service)),
    );
    if (result == true) _refresh();
  }

  void _editBook(Book book) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddBookScreen(service: widget.service, editBook: book)),
    );
    if (result == true) _refresh();
  }

  void _checkout([Book? book]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(service: widget.service, config: _config, initialBook: book)),
    );
    if (result == true) _refresh();
  }

void _showCheckouts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CheckoutListSheet(
        checkouts: _activeCheckouts,
        service: widget.service,
        onReturned: (checkout) async {
          Navigator.pop(ctx);
          await widget.service.returnBook(checkout.id);
          final updatedCheckout = checkout;
          updatedCheckout.returnDate = DateTime.now();
          if (mounted) await ReceiptDialog.showReturnReceipt(context, updatedCheckout);
          _refresh();
        },
        onReturnAll: (List<Checkout> list) async {
          Navigator.pop(ctx);
          for (final co in list) {
            await widget.service.returnBook(co.id);
          }
          if (mounted) await ReceiptDialog.showReturnReceipt(context, list);
          _refresh();
        },
      ),
    );
  }

  Future<void> _deleteBook(Book book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text('Delete "${book.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await widget.service.deleteBook(book.id);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(['Dashboard', 'Books', 'Configure', 'Settings'][_selectedIndex]),
        centerTitle: true,
      ),
      floatingActionButton: _selectedIndex == 1
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'checkout',
                  onPressed: _checkout,
                  child: const Icon(Icons.swap_horiz),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'addbook',
                  onPressed: _addBook,
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _DashboardTab(bookCount: _bookCount, books: _books, config: _config, activeCheckouts: _activeCheckouts.length, onCheckoutsTap: _showCheckouts),
          _BooksTab(books: _books, config: _config, loading: _loading, onEdit: _editBook, onDelete: _deleteBook, onRefresh: _refresh, onCheckout: (book) => _checkout(book)),
          _ConfigureTab(service: widget.service, config: _config, books: _books, onChanged: _refresh),
          _SettingsTab(service: widget.service),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.book), label: 'Books'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Configure'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

String _almirahName(LibraryConfig? config, String? id) {
  if (config == null || id == null) return '';
  return config.almirahs.where((a) => a.id == id).firstOrNull?.name ?? '';
}

String _cabinName(LibraryConfig? config, String? almirahId, String? cabinId) {
  if (config == null || almirahId == null || cabinId == null) return '';
  final alm = config.almirahs.where((a) => a.id == almirahId).firstOrNull;
  if (alm == null) return '';
  return alm.cabins.where((c) => c.id == cabinId).firstOrNull?.name ?? '';
}

class _DashboardTab extends StatelessWidget {
  final int bookCount;
  final List<Book> books;
  final LibraryConfig? config;
  final int activeCheckouts;
  final VoidCallback onCheckoutsTap;
  const _DashboardTab({required this.bookCount, required this.books, required this.config, required this.activeCheckouts, required this.onCheckoutsTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final almirahCount = config?.almirahs.length ?? 1;
    final totalCabins = config?.almirahs.fold<int>(0, (sum, a) => sum + a.cabins.length) ?? 1;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Library Dashboard', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _StatCard(
                  icon: Icons.book, label: 'Total Books', value: bookCount.toString(), color: Colors.blue,
                  onTap: () => _showGrid(context, 'Books', books.map((b) => _GridItem(
                    id: b.id, title: b.title, subtitle: b.author,
                    detail: _almirahName(config, b.almirahId),
                    color: Colors.blue,
                  )).toList()),
                ),
                _StatCard(
                  icon: Icons.auto_stories, label: 'Almirahs', value: almirahCount.toString(), color: Colors.indigo,
                  onTap: () => _showGrid(context, 'Almirahs', (config?.almirahs ?? []).map((a) => _GridItem(
                    id: a.id, title: a.name,
                    subtitle: '${a.cabins.length} cabin(s)',
                    detail: '${books.where((b) => b.almirahId == a.id).length} book(s)',
                    color: Colors.indigo,
                  )).toList()),
                ),
                _StatCard(
                  icon: Icons.shelves, label: 'Cabins', value: totalCabins.toString(), color: Colors.teal,
                  onTap: () {
                    final items = <_GridItem>[];
                    for (final a in config?.almirahs ?? []) {
                      for (final c in a.cabins) {
                        final cabinBooks = books.where((b) => b.almirahId == a.id && b.cabinId == c.id).toList();
                        items.add(_GridItem(
                          id: c.id, title: c.name,
                          subtitle: a.name,
                          detail: '${cabinBooks.length} book(s)',
                          color: Colors.teal,
                        ));
                      }
                    }
                    _showGrid(context, 'Cabins', items);
                  },
                ),
                _StatCard(
                  icon: Icons.swap_horiz, label: 'Checked Out', value: activeCheckouts.toString(), color: Colors.orange,
                  onTap: onCheckoutsTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGrid(BuildContext context, String title, List<_GridItem> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                  const Spacer(),
                  Text('${items.length}', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text('Nothing here', style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(color: Colors.grey)))
                  : GridView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        return Card(
                          color: item.color.withValues(alpha: 0.08),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(ctx),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bookmark, color: item.color, size: 28),
                                  const SizedBox(height: 6),
                                  Text(item.title, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: item.color)),
                                  if (item.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(item.subtitle, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                  ],
                                  if (item.detail.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(color: item.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                      child: Text(item.detail, style: TextStyle(fontSize: 9, color: item.color)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridItem {
  final String id;
  final String title;
  final String subtitle;
  final String detail;
  final Color color;
  const _GridItem({required this.id, required this.title, this.subtitle = '', this.detail = '', required this.color});
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color)),
              Text(label, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _BooksTab extends StatefulWidget {
  final List<Book> books;
  final LibraryConfig? config;
  final bool loading;
  final Function(Book) onEdit;
  final Function(Book) onDelete;
  final VoidCallback onRefresh;
  final Function(Book) onCheckout;
  const _BooksTab({required this.books, required this.config, required this.loading, required this.onEdit, required this.onDelete, required this.onRefresh, required this.onCheckout});

  @override
  State<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<_BooksTab> {
  final _searchCtrl = TextEditingController();
  List<Book> _filtered = [];
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _filtered = widget.books;
  }

  @override
  void didUpdateWidget(_BooksTab old) {
    super.didUpdateWidget(old);
    if (widget.books != old.books) _filter();
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = widget.books.where((b) {
        final alm = _almirahName(widget.config, b.almirahId).toLowerCase();
        final cab = _cabinName(widget.config, b.almirahId, b.cabinId).toLowerCase();

        if (q.isNotEmpty) {
          final matchesSearch = b.title.toLowerCase().contains(q) ||
              b.author.toLowerCase().contains(q) ||
              (b.isbn?.toLowerCase().contains(q) ?? false) ||
              alm.contains(q) ||
              cab.contains(q);
          if (!matchesSearch) return false;
        }

        if (_dateFrom != null && b.createdAt.isBefore(_dateFrom!)) return false;
        if (_dateTo != null && b.createdAt.isAfter(_dateTo!.add(const Duration(days: 1)))) return false;

        return true;
      }).toList();
    });
  }

  void _clearDateFilter() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    _filter();
  }

  void _setDateFilter(DateTime from, DateTime to) {
    setState(() {
      _dateFrom = DateTime(from.year, from.month, from.day);
      _dateTo = DateTime(to.year, to.month, to.day);
    });
    _filter();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
    );
    if (picked != null) _setDateFilter(picked.start, picked.end);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search title, author, almirah, cabin...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => _filter(),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _dateChip('Today', () => _setDateFilter(DateTime.now(), DateTime.now())),
              _dateChip('This Week', () {
                final now = DateTime.now();
                _setDateFilter(now.subtract(Duration(days: now.weekday - 1)), now);
              }),
              _dateChip('This Month', () {
                final now = DateTime.now();
                _setDateFilter(DateTime(now.year, now.month, 1), now);
              }),
              if (_dateFrom != null || _dateTo != null)
                _dateChip('Clear', _clearDateFilter, icon: Icons.close, selected: true)
              else
                _dateChip('Custom', _pickCustomRange, icon: Icons.date_range),
            ],
          ),
        ),
        if (_dateFrom != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'From ${_dateFrom!.toString().substring(0, 10)} to ${_dateTo!.toString().substring(0, 10)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        Expanded(
          child: widget.loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No books found', style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text('Try adjusting your search or filters', style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => widget.onRefresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final book = _filtered[i];
                          final alm = _almirahName(widget.config, book.almirahId);
                          final cab = _cabinName(widget.config, book.almirahId, book.cabinId);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${book.author}${alm.isNotEmpty ? " • $alm" : ""}${cab.isNotEmpty ? " / $cab" : ""}\n${book.createdAt.toString().substring(0, 10)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if ((book.availableCopies ?? 0) > 0)
                                    IconButton(
                                      icon: const Icon(Icons.swap_horiz, color: Colors.green),
                                      tooltip: 'Checkout',
                                      onPressed: () => widget.onCheckout(book),
                                    ),
                                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => widget.onEdit(book)),
                                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => widget.onDelete(book)),
                                ],
                              ),
                              onTap: () => _showBookDetails(ctx, book),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _dateChip(String label, VoidCallback onTap, {IconData? icon, bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 4)],
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _showBookDetails(BuildContext context, Book book) {
    final alm = _almirahName(widget.config, book.almirahId);
    final cab = _cabinName(widget.config, book.almirahId, book.cabinId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(book.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (book.author.isNotEmpty) Text('Author: ${book.author}'),
              if (book.isbn != null) Text('ISBN: ${book.isbn}'),
              if (book.description != null) Text('Description: ${book.description}'),
              if (book.totalCopies != null) Text('Total Copies: ${book.totalCopies}'),
              if (book.availableCopies != null) Text('Available: ${book.availableCopies}'),
              if (alm.isNotEmpty) Text('Almirah: $alm'),
              if (cab.isNotEmpty) Text('Cabin: $cab'),
              if (book.fieldValues.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(),
                ...(widget.config?.extraFields ?? []).map((f) {
                  final v = book.fieldValues[f.id];
                  if (v == null || (v is String && v.isEmpty)) return const SizedBox.shrink();
                  String display;
                  if (f.type == FieldType.coordinate && v is Map) {
                    display = 'X: ${v['x']}, Y: ${v['y']}';
                  } else {
                    display = v.toString();
                  }
                  return Padding(padding: const EdgeInsets.only(top: 4), child: Text('${f.name}: $display'));
                }),
              ],
              const SizedBox(height: 8),
              Text('Added: ${book.createdAt.toString().substring(0, 10)}', style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _ConfigureTab extends StatelessWidget {
  final DatabaseService service;
  final LibraryConfig? config;
  final List<Book> books;
  final VoidCallback onChanged;
  const _ConfigureTab({required this.service, required this.config, required this.books, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final almirahs = config?.almirahs ?? [];

    if (almirahs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shelves, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No almirahs configured', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => FieldSetupScreen(service: service)));
                onChanged();
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Almirahs'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: almirahs.map((almirah) => _AlmirahVisual(
              almirah: almirah,
              books: books.where((b) => b.almirahId == almirah.id).toList(),
              config: config,
              theme: theme,
            )).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${almirahs.length} almirah(s) \u2022 ${almirahs.fold<int>(0, (s, a) => s + a.cabins.length)} cabin(s) \u2022 ${books.length} book(s)',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => FieldSetupScreen(service: service)));
                  onChanged();
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Manage'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlmirahVisual extends StatelessWidget {
  final AlmirahConfig almirah;
  final List<Book> books;
  final LibraryConfig? config;
  final ThemeData theme;

  const _AlmirahVisual({
    required this.almirah,
    required this.books,
    required this.config,
    required this.theme,
  });

  static const _almirahColors = [
    Color(0xFF8D6E63),
    Color(0xFF6D4C41),
    Color(0xFF5D4037),
    Color(0xFF4E342E),
    Color(0xFF3E2723),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _almirahColors[almirah.id.hashCode % _almirahColors.length];
    final w = MediaQuery.of(context).size.width * 0.55;

    return Container(
      width: w,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(Icons.shelves, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    almirah.name,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${books.length}', style: theme.textTheme.labelSmall?.copyWith(color: color)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: almirah.cabins.asMap().entries.map((entry) {
                final ci = entry.key;
                final cabin = entry.value;
                final cabinBooks = books.where((b) => b.cabinId == cabin.id).toList();
                return _CabinShelf(
                  cabin: cabin,
                  books: cabinBooks,
                  config: config,
                  theme: theme,
                  shelfColor: color,
                  isLast: ci == almirah.cabins.length - 1,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CabinShelf extends StatelessWidget {
  final CabinConfig cabin;
  final List<Book> books;
  final LibraryConfig? config;
  final ThemeData theme;
  final Color shelfColor;
  final bool isLast;

  const _CabinShelf({
    required this.cabin,
    required this.books,
    required this.config,
    required this.theme,
    required this.shelfColor,
    required this.isLast,
  });

  static const _bookColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Color(0xFFF4511E),
    Color(0xFF3949AB),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border(bottom: BorderSide(color: shelfColor.withValues(alpha: 0.4), width: isLast ? 1 : 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
            child: Row(
              children: [
                Icon(Icons.subdirectory_arrow_right, size: 14, color: shelfColor.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(cabin.name, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${books.length}', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
          if (books.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: Text('Empty', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[400], fontStyle: FontStyle.italic)),
            )
          else
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                itemCount: books.length,
                itemBuilder: (ctx, i) {
                  final book = books[i];
                  final bColor = _bookColors[book.id.hashCode.abs() % _bookColors.length];
                  final short = book.title.length > 8 ? '${book.title.substring(0, 7)}.' : book.title;
                  return GestureDetector(
                    onTap: () => _showBookPopup(context, book),
                    child: Container(
                      width: 38,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: bColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: bColor.withValues(alpha: 0.3)),
                      ),
                      child: Transform.rotate(
                        angle: 0,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Text(
                              short,
                              style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showBookPopup(BuildContext context, Book book) {
    final alm = _almirahName(config, book.almirahId);
    final cab = _cabinName(config, book.almirahId, book.cabinId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(book.title, style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.author.isNotEmpty) Text(book.author, style: theme.textTheme.bodyMedium),
            Text('$alm / $cab', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            if (book.description != null && book.description!.isNotEmpty) const SizedBox(height: 4),
            if (book.description != null && book.description!.isNotEmpty) Text(book.description!, style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  final DatabaseService service;
  const _SettingsTab({required this.service});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _api = ApiService();
  bool _uploading = false;
  bool _importing = false;

  Future<String> _export() async {
    final json = await widget.service.exportData();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/library_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    return file.path;
  }

  Future<Map<String, dynamic>?> _loginDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your credentials to connect to the server.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final email = emailCtrl.text.trim();
              final pass = passCtrl.text.trim();
              if (email.isEmpty || pass.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Email and password are required')),
                );
                return;
              }
              Navigator.pop(ctx, {'email': email, 'password': pass});
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
    emailCtrl.dispose();
    passCtrl.dispose();
    return result;
  }

  Future<void> _upload() async {
    final creds = await _loginDialog();
    if (creds == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await _api.login(creds['email'] as String, creds['password'] as String);
      final json = await widget.service.exportData();
      await _api.uploadAllData(json);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data uploaded to server successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _import() async {
    final creds = await _loginDialog();
    if (creds == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Data?'),
        content: const Text('This will replace all local data with data from the server. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _importing = true);
    try {
      await _api.login(creds['email'] as String, creds['password'] as String);
      final jsonStr = await _api.importAllData();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Clear local data first
      await widget.service.clearAllData();

      // Save imported config
      if (data['library_config'] != null) {
        final config = LibraryConfig.fromJson(data['library_config'] as Map<String, dynamic>);
        await widget.service.saveLibraryConfig(config);
      }

      // Save imported books
      final books = data['books'] as List? ?? [];
      for (final b in books) {
        final book = Book.fromJson(b as Map<String, dynamic>);
        try {
          await widget.service.addBook(book);
        } catch (_) {}
      }

      // Save imported checkouts
      final checkouts = data['checkouts'] as List? ?? [];
      for (final c in checkouts) {
        final checkout = Checkout.fromJson(c as Map<String, dynamic>);
        if (checkout.returnDate != null) {
          // Skip already-returned checkouts or add them based on preference
          continue;
        }
        try {
          await widget.service.checkoutBook(checkout);
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${books.length} book(s) and ${checkouts.length} checkout(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Offline Mode'),
            subtitle: const Text('Data is stored locally on this device'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(_uploading ? Icons.cloud_upload : Icons.cloud_upload_outlined, color: Colors.blue),
            title: const Text('Upload to Server'),
            subtitle: const Text('Push all local data to the server'),
            trailing: _uploading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _uploading ? null : _upload,
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(_importing ? Icons.cloud_download : Icons.cloud_download_outlined, color: Colors.green),
            title: const Text('Import from Server'),
            subtitle: const Text('Pull all data from the server to this device'),
            trailing: _importing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _importing ? null : _import,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Export Data'),
            subtitle: const Text('Save all books, checkouts, and config as JSON'),
            onTap: () async {
              try {
                final path = await _export();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exported to $path')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Remove all books, checkouts, and configurations'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All Data?'),
                  content: const Text('This will permanently delete all books, checkouts, and settings.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear Everything'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await widget.service.clearAllData();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data cleared')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }
}

class _CheckoutListSheet extends StatefulWidget {
  final List<Checkout> checkouts;
  final DatabaseService service;
  final Function(Checkout) onReturned;
  final Function(List<Checkout>)? onReturnAll;
  const _CheckoutListSheet({required this.checkouts, required this.service, required this.onReturned, this.onReturnAll});

  @override
  State<_CheckoutListSheet> createState() => _CheckoutListSheetState();
}

class _CheckoutListSheetState extends State<_CheckoutListSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _selectMode = false;
  final Set<String> _selected = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Checkout> get _filtered {
    if (_query.isEmpty) return widget.checkouts;
    final q = _query.toLowerCase();
    return widget.checkouts.where((co) =>
      co.clientName.toLowerCase().contains(q) ||
      co.bookTitle.toLowerCase().contains(q) ||
      co.id.toLowerCase().contains(q) ||
      co.bookAuthor.toLowerCase().contains(q) ||
      (co.clientPhone?.contains(q) ?? false)
    ).toList();
  }

  Map<String, List<Checkout>> _groupByBook(List<Checkout> list) {
    final map = <String, List<Checkout>>{};
    for (final co in list) {
      map.putIfAbsent(co.bookId, () => []).add(co);
    }
    return map;
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) { _selected.remove(id); } else { _selected.add(id); }
    });
  }

  void _selectAll(List<Checkout> list) {
    setState(() => _selected.addAll(list.map((c) => c.id)));
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Checked Out Books', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    if (_selectMode && _selected.isNotEmpty)
                      Text('${_selected.length}', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                    if (!_selectMode)
                      Text('${filtered.length}', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                    IconButton(
                      icon: Icon(_selectMode ? Icons.close_fullscreen : Icons.checklist, size: 20),
                      tooltip: _selectMode ? 'Exit select mode' : 'Select multiple',
                      onPressed: () => setState(() { _selectMode = !_selectMode; _selected.clear(); }),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                if (_selectMode && _selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.undo, size: 16),
                        label: Text('Return Selected (${_selected.length})'),
                        onPressed: () {
                          final list = widget.checkouts.where((c) => _selected.contains(c.id)).toList();
                          widget.onReturnAll?.call(list);
                        },
                      ),
                    ),
                  ),
                if (_selectMode && filtered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _selected.length == filtered.length ? _clearSelection : () => _selectAll(filtered),
                          child: Text(_selected.length == filtered.length ? 'Clear All' : 'Select All'),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, book, or ID',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_query.isNotEmpty ? Icons.search_off : Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(_query.isNotEmpty ? 'No matching checkouts' : 'No books checked out', style: theme.textTheme.headlineSmall),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final co = filtered[i];
                      final daysOut = DateTime.now().difference(co.checkoutDate).inDays;
                      final checked = _selected.contains(co.id);

                      final siblings = _groupByBook(filtered)[co.bookId] ?? [];
                      final isFirst = siblings.firstOrNull?.id == co.id;
                      final showReturnAll = isFirst && siblings.length > 1 && widget.onReturnAll != null && !_selectMode;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (_selectMode)
                                    Checkbox(
                                      value: checked,
                                      onChanged: (_) => _toggleSelect(co.id),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  Expanded(
                                    child: Text(co.bookTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: daysOut > 7 ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('$daysOut day(s)', style: TextStyle(fontSize: 11, color: daysOut > 7 ? Colors.red : Colors.orange)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.person, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(co.clientName, style: theme.textTheme.bodyMedium),
                                ],
                              ),
                              if (co.clientPhone != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.phone, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(co.clientPhone!, style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('Checked out: ${co.checkoutDate.toString().substring(0, 10)}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                                  if (siblings.length > 1)
                                    Text('  (${siblings.indexOf(co) + 1}/${siblings.length})',
                                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                                  const Spacer(),
                                  if (showReturnAll)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.undo, size: 14),
                                        label: Text('Return All (${siblings.length})', style: const TextStyle(fontSize: 11)),
                                        onPressed: () => widget.onReturnAll!(siblings),
                                      ),
                                    ),
                                  if (!_selectMode)
                                    FilledButton.tonalIcon(
                                      icon: const Icon(Icons.undo, size: 16),
                                      label: const Text('Return', style: TextStyle(fontSize: 12)),
                                      onPressed: () => widget.onReturned(co),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
